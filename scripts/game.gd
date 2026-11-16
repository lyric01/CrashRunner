extends Node2D
# 게임의 기본 뼈대: 상태(캐릭터 선택/스테이지/결과), 시간(히트스톱), 점수·콤보,
# 캐릭터와 몬스터·장애물의 기본 판정, 입력.
# 저글링과 랠리의 규칙은 이 위에 얹은 juggle_game.gd에 있어요.

enum State { SELECT, STAGE, RESULT }

const Monster := preload("res://scripts/monster.gd")

@onready var world: Node2D = $World
@onready var scroller = $World/Scroller
@onready var monsters: Node2D = $World/Monsters
@onready var party = $World/Party
@onready var player = $World/Player
@onready var fx = $World/Fx
@onready var spawner = $Spawner
@onready var hud = $UI/Hud
@onready var result = $UI/Result
@onready var select = $UI/Select
@onready var overlay: Node2D = $UI/Overlay

var state: int = State.SELECT
var paused := false
var debug_on := false

# 히트스톱은 Engine.time_scale이 아니라 world_dt를 0으로 만들어요.
var hitstop_t := 0.0
var hitstop_gap := 0.0     # 히트스톱 사이 최소 간격(초). 0이면 제한 없음
var scroll: float = Config.ROAD_SCROLL_SPEED

var hp: int = Config.PARTY_HP
var invuln := 0.0
var score := 0.0
var distance := 0.0        # px
var combo := 0
var max_combo := 0
var combo_timer := 0.0
var combo_pop := 0.0
var stage := 1             # 지금 스테이지(진행도가 차면 다음으로 넘어가요)
var stage_time := 0.0
var slow_t := 0.0
var juggle_run := 0        # 떠 있는 몬스터를 끊기지 않고 다시 친 횟수
var max_juggle := 0
var kills := 0
var result_reason := ""


func _ready() -> void:
	randomize()
	for n in [party, player, spawner, hud, result, select]:
		n.game = self
	party.setup(Config.party)
	overlay.draw.connect(_draw_overlay)
	hud.visible = false
	if "--autoplay" in OS.get_cmdline_user_args():
		var auto: Node = load("res://scripts/autoplay.gd").new()
		auto.game = self
		add_child(auto)
	if Config.skip_select:
		start_stage(Config.party)
	else:
		select.open(Config.party)


func start_stage(ids: Array) -> void:
	Config.party = ids.duplicate()
	party.setup(ids)
	select.visible = false
	hud.visible = true
	state = State.STAGE


func _process(delta: float) -> void:
	overlay.queue_redraw()
	if paused or state != State.STAGE:
		return
	var rdt := minf(delta, 0.05)
	hitstop_t -= rdt
	var dt := 0.0 if hitstop_t > 0.0 else rdt
	_update_stage(dt, rdt)
	if state != State.STAGE:
		return
	invuln -= dt
	combo_pop = maxf(0.0, combo_pop - rdt * 5.0)
	if combo > 0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 0
	fx.update(dt, rdt, scroll)
	world.position = fx.shake_offset()
	hud.queue_redraw()


# hitstop_gap > 0이면, 히트스톱이 끝나고 그 시간 안에는 새 히트스톱이 걸리지 않아요.
# (여러 마리가 연달아 맞을 때 화면이 계속 멈추는 것을 막아요.)
func hitstop(t: float) -> void:
	if hitstop_t > -hitstop_gap and hitstop_t <= 0.0:
		return
	hitstop_t = maxf(hitstop_t, t)


# ---------------------------------------------------------------- 스테이지

func _update_stage(dt: float, rdt: float) -> void:
	stage_time += dt
	slow_t -= dt
	var ratio := 1.0
	if slow_t > 0.0:
		ratio = lerpf(1.0, Config.HIT_SLOW_RATIO, slow_t / Config.HIT_SLOW_TIME)
	scroll = Config.ROAD_SCROLL_SPEED * ratio
	distance += scroll * dt
	score += scroll * dt * Config.SCORE_PER_PX
	scroller.update(dt, rdt, scroll)
	spawner.update(dt)
	# 캐릭터는 히트스톱에 멈추지 않아요(멈추는 건 몬스터와 배경뿐). 공격 중에도 바로 점프할 수 있어요.
	player.update(rdt)
	_update_monsters(dt)
	_collide()
	_count_juggled()
	if stage_time >= Config.ROAD_DURATION:
		_finish("clear")


func road_progress() -> float:
	return clampf(stage_time / Config.ROAD_DURATION, 0.0, 1.0)


func spawn(kind: String, x: float) -> Node2D:
	var m := Monster.new()
	m.setup(kind)
	m.position = Vector2(x, Config.GROUND_Y)
	monsters.add_child(m)
	return m


func _update_monsters(dt: float) -> void:
	for m in monsters.get_children():
		if m.dead:
			continue
		var ev: String = m.update(dt, scroll)
		match ev:
			"gone":
				_remove(m)
				continue
			"bounce", "land":
				# 땅에 닿을 때마다 먼지
				fx.burst(Vector2(m.position.x, Config.GROUND_Y - 6.0), Color(0.85, 0.8, 0.7), 3, 0.35)
				if m.alive():
					fx.shake(3.0, 0.08)
			"recover":
				# 그로기인 채로 캐릭터를 지나쳐 간 몬스터는 일어나도 캐릭터를 치지 않아요.
				if m.position.x < player.position.x + 20.0:
					m.passed = true
		if m.off_screen():
			_remove(m)


# 떠 있는 몬스터 수를 세는 자리(저글링 규칙이 채워요).
func _count_juggled() -> void:
	pass


func on_pit_fall() -> void:
	invuln = 0.0
	damage(1)
	player.respawn()


func _remove(m) -> void:
	m.dead = true
	m.queue_free()


# 맞혔을 때의 공통 처리: 콤보, 점수
func register_hit(pos: Vector2, pts: float) -> void:
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_timer = Config.COMBO_TIMEOUT
	combo_pop = 1.0
	score += pts * (1.0 + combo / 10.0)
	fx.star(pos)


func damage(n: int) -> void:
	if invuln > 0.0 or state != State.STAGE:
		return
	hp -= n
	invuln = Config.INVULN_TIME
	slow_t = Config.HIT_SLOW_TIME
	combo = 0
	fx.shake(11.0, 0.25)
	fx.text(Vector2(player.position.x, player.y - 130.0), "-%d" % n, Color("#FF5A5A"), 34)
	if hp <= 0:
		hp = 0
		_finish("fail")


# 캐릭터의 공격·몸과 몬스터·장애물의 판정
func _collide() -> void:
	var body: Rect2 = player.body_rect()
	var atk: Rect2 = player.attack_rect()
	var swinging: bool = player.attacking()
	for m in monsters.get_children():
		if not m.alive():
			continue
		var r: Rect2 = m.rect()
		if m.kind == "pit":
			if player.on_ground and not swinging and invuln <= 0.0 \
					and absf(player.position.x - m.position.x) < m.w / 2.0 - Config.PIT_EDGE:
				player.start_fall()
			continue
		if swinging and m.hit_serial != player.serial and atk.intersects(r):
			m.hit_serial = player.serial
			_attack_hit(m)
		elif m.state == "walk" and not m.passed and body.intersects(r):
			_body_hit(m)


# 공격이 닿았을 때. 여기서는 장애물만 처리하고, 몬스터는 저글링 규칙이 처리해요.
func _attack_hit(m) -> void:
	if m.kind == "steel":
		fx.star(m.center(), 0.7)
		fx.text(m.center() + Vector2(0, -70), "단단해! 점프!", Color("#B8C4CF"), 22)


func _body_hit(m) -> void:
	if invuln > 0.0:
		return
	damage(1)
	m.passed = true


# ---------------------------------------------------------------- 결과

func result_data() -> Dictionary:
	return {
		"reason": result_reason,
		"distance": int(distance / Config.PX_PER_METER),
		"score": int(score),
		"max_combo": max_combo,
		"kills": kills,
		"max_juggle": max_juggle,
		"stage": stage,
	}


func _finish(reason: String) -> void:
	state = State.RESULT
	result_reason = reason
	world.position = Vector2.ZERO
	hud.queue_redraw()
	result.show_result(result_data())


func restart(to_select := false) -> void:
	Config.skip_select = not to_select
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 입력

func do_attack() -> void:
	if state == State.STAGE and not paused:
		player.try_attack()


func do_jump() -> void:
	if state == State.STAGE and not paused:
		player.try_jump()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_tap(event.position)
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("debug"):
		debug_on = not debug_on
	elif state == State.SELECT:
		select.on_key(event)
	elif event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("party"):
		restart(true)
	elif state == State.RESULT:
		return
	elif event.is_action_pressed("pause"):
		paused = not paused
	elif paused:
		return
	elif event.is_action_pressed("attack"):
		do_attack()
	elif event.is_action_pressed("jump"):
		do_jump()


func _on_tap(p: Vector2) -> void:
	if state == State.SELECT:
		select.on_tap(p)
		return
	if state == State.RESULT:
		if result.button_rect(0).has_point(p):
			restart()
		elif result.button_rect(1).has_point(p):
			restart(true)
		return
	if paused or p.distance_to(Config.PAUSE_BTN) <= Config.PAUSE_BTN_R + 10.0:
		paused = not paused
		return
	if p.distance_to(Config.ATTACK_BTN) <= Config.ATTACK_BTN_R + 8.0:
		do_attack()
	elif p.distance_to(Config.JUMP_BTN) <= Config.JUMP_BTN_R + 8.0:
		do_jump()


# ---------------------------------------------------------------- 오버레이(일시정지, 디버그)

func debug_rows() -> Array:
	var names := ["선택", "스테이지", "결과"]
	return [
		"FPS %d" % Engine.get_frames_per_second(),
		"상태: %s · 스테이지 %d · 몬스터 %d · 스크롤 %d px/s" % [
			names[state], stage, monsters.get_child_count(), int(scroll)],
		"지금 저글 x%d · 최대 저글 x%d · 처치 %d" % [juggle_run, max_juggle, kills],
	]


func _draw_overlay() -> void:
	if paused:
		overlay.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		ChibiDraw.text(overlay, Vector2(640, 350), "일시정지", 64, Color.WHITE, 1, true)
		ChibiDraw.text(overlay, Vector2(640, 400), "Esc / P 또는 화면을 탭하면 계속", 22,
				Color(1, 1, 1, 0.8), 1)
	if debug_on:
		var rows := debug_rows()
		ChibiDraw.panel(overlay, Rect2(16, 150, 440, 22.0 * rows.size() + 16), Color(0, 0, 0, 0.7), 6)
		for i in rows.size():
			ChibiDraw.text(overlay, Vector2(28, 176 + i * 22), rows[i], 15, Color(0.7, 1.0, 0.75))
