extends Node2D
# 게임 루트: 상태(편성/스테이지/결과), world_dt(히트스톱), 점수·콤보,
# 공격 → 날아감 → 충돌 → 그로기 → 연계기의 연쇄 반응 판정.

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
var scroll: float = Config.ROAD_SCROLL_SPEED

var hp: int = Config.PARTY_HP
var invuln := 0.0
var score := 0.0
var distance := 0.0        # px
var combo := 0
var max_combo := 0
var combo_timer := 0.0
var combo_pop := 0.0
var stage_time := 0.0
var slow_t := 0.0

# 연쇄
var chain_target = null    # 지금 연계기를 맞을 그로기 몬스터
var chain_id := ""         # 뛰어나올 파티원
var chain_run := 0         # 끊기지 않고 이어진 연계기 횟수
var max_chain := 0
var chain_total := 0
var groggy_total := 0      # 충돌로 그로기가 된 횟수
var bowl_total := 0        # 충돌 횟수
var kills := 0
var pit_kills := 0
var dying_bowls := 0       # 체력 0으로 날아가다 부딪힌 횟수
var result_reason := ""
var stage := 1             # 지금 스테이지(저글링 모드는 진행도가 차면 다음으로 넘어가요)
var run_label := "연쇄"    # HUD에 표시하는 연속 횟수 이름
var hitstop_gap := 0.0     # 히트스톱 사이 최소 간격(초). 0이면 제한 없음
var bowling := true        # 날아간 몬스터와 다른 몬스터·장애물의 충돌 판정(저글링 모드는 꺼요)


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


# 모드: chain(충돌 연쇄, main.tscn) / juggle(저글링, juggle.tscn)
func mode() -> String:
	return "chain"


# 이 모드에서 편성하는 인원
func party_size() -> int:
	return Config.PARTY_SIZE


func mode_name() -> String:
	return "연쇄 모드"


func switch_mode() -> void:
	Config.skip_select = false
	var next := "res://scenes/juggle.tscn" if mode() == "chain" else "res://scenes/main.tscn"
	get_tree().change_scene_to_file(next)


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
	# 선두는 히트스톱에 멈추지 않아요(멈추는 건 몬스터와 배경뿐). 공격 중에도 바로 점프할 수 있어요.
	player.update(rdt)
	party.update(rdt)
	_update_monsters(dt)
	_collide()
	_pick_chain()
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
	var pits: Array = []
	for m in monsters.get_children():
		if not m.dead and m.kind == "pit":
			pits.append(m)
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
				# 그로기인 채로 선두를 지나쳐 간 몬스터는 일어나도 선두를 치지 않아요.
				if m.position.x < player.position.x + 20.0:
					m.passed = true
		# 날아간 몬스터가 낭떠러지 위에 내려앉으면 떨어져요.
		if bowling and m.is_monster() and m.lift <= 0.0 and m.state != "walk":
			for pit in pits:
				if absf(m.position.x - pit.position.x) < pit.w / 2.0 - Config.PIT_EDGE:
					_pit_kill(m)
					break
			if m.dead:
				continue
		if m.off_screen():
			_remove(m)


func _pit_kill(m) -> void:
	kills += 1
	pit_kills += 1
	register_hit(m.center(), Config.SCORE_KILL)
	fx.text(m.center() + Vector2(0, -60), "추락!", Color("#B8C4CF"), 28)
	fx.burst(m.center(), m.color(), 8, 0.7)
	_remove(m)


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

	if not bowling:
		return
	# 충돌: 날아가는 몬스터가 다른 몬스터·장애물과 부딪혀요.
	for f in monsters.get_children():
		# 체력 0으로 날아가는 몬스터(dying)도 한 번은 부딪혀요.
		if f.dead or (f.state != "fly" and f.state != "dying"):
			continue
		var fr: Rect2 = f.rect()
		for o in monsters.get_children():
			if o == f or not o.alive() or o.state == "fly" or o.kind == "pit":
				continue
			var key: int = o.get_instance_id()
			if f.bowled.has(key) or not fr.intersects(o.rect()):
				continue
			f.bowled[key] = true
			_bowl(f, o)
			if f.dead or f.state != "fly":
				break


# 대미지를 주고, 체력이 남으면 날려 보내요. 살아 있으면 true
# pop = true면 체력이 0일 때 날아가지 않고 그 자리에서 터져요(충돌로 죽은 경우).
func _hurt(m, dmg: float, lvx: float, lvy: float, pop := false) -> bool:
	m.hp -= dmg
	fx.text(m.center() + Vector2(randf_range(-20, 20), -m.h / 2.0 - 6.0), str(int(round(dmg))),
			Color.WHITE, 24, 0.5)
	if m.hp <= 0.0:
		m.hp = 0.0
		kills += 1
		register_hit(m.center(), Config.SCORE_KILL)
		if pop:
			fx.burst(m.center(), m.color(), 12, 1.1)
			_remove(m)
		else:
			# 공격으로 체력 0: 뒤로 통통 튀면서 사라져요.
			fx.burst(m.center(), m.color(), 5, 0.8)
			m.state = "dying"
			m.launch(maxf(lvx, Config.KNOCKBACK_VX * 0.7), minf(lvy, Config.KNOCKBACK_VY))
		return false
	register_hit(m.center(), Config.SCORE_HIT)
	m.launch(lvx * m.mass, lvy)
	return true


# 1단계: 선두의 공격 → 날아감
func _attack_hit(m) -> void:
	var data: Dictionary = Characters.DATA[party.lead()]
	if m.kind == "box":
		_shatter(m)
		return
	if m.kind == "steel":
		fx.star(m.center(), 0.7)
		fx.text(m.center() + Vector2(0, -70), "단단해! 점프!", Color("#B8C4CF"), 22)
		return
	fx.shake(7.0, 0.14)
	hitstop(Config.HITSTOP_HIT)
	fx.burst(m.center(), m.color(), 3, 0.6)
	_hurt(m, Config.ATTACK_DAMAGE * data["damage"], Config.KNOCKBACK_VX * data["push"],
			Config.KNOCKBACK_VY)


func _shatter(m) -> void:
	register_hit(m.center(), Config.SCORE_HIT)
	fx.burst(m.center(), m.color(), 10)
	fx.shake(4.0, 0.1)
	_remove(m)


func _body_hit(m) -> void:
	if invuln > 0.0:
		return
	damage(1)
	if m.kind == "box":
		fx.burst(m.center(), m.color(), 6, 0.6)
		_remove(m)
	else:
		m.passed = true


# 2단계: 날아가던 f가 o와 충돌.
# 부딪힌 o는 약하면 터지고 튼튼하면 같이 날아가요. 날아가던 f는 그로기가 돼요.
func _bowl(f, o) -> void:
	var at: Vector2 = (f.center() + o.center()) / 2.0
	bowl_total += 1
	fx.star(at, 1.2)
	fx.shake(8.0, 0.16)
	hitstop(Config.HITSTOP_BOWL)
	var push: float = maxf(f.vx * 0.9, Config.KNOCKBACK_VX * 0.6)
	if o.kind == "box":
		_shatter(o)
	elif o.kind == "steel":
		pass      # 강철벽은 그대로, 부딪힌 쪽만 그로기
	else:
		_hurt(o, Config.BOWL_DAMAGE, push, Config.KNOCKBACK_VY, true)
	if f.state == "dying":
		# 이미 죽은 채로 날아온 쪽은 한 번 부딪히고 그 자리에서 터져요(그로기 없음).
		dying_bowls += 1
		fx.burst(f.center(), f.color(), 12, 1.1)
		_remove(f)
		return
	f.hp -= Config.BOWL_SELF_DAMAGE
	if f.hp <= 0.0:
		f.hp = 0.0
		kills += 1
		register_hit(f.center(), Config.SCORE_KILL)
		fx.burst(f.center(), f.color(), 12, 1.1)
		_remove(f)
		return
	f.stun()
	groggy_total += 1
	fx.text(f.center() + Vector2(0, -f.h / 2.0 - 30.0), "그로기!", ChibiDraw.GOLD, 26, 0.6)


# ---------------------------------------------------------------- 연계기

# 그로기 몬스터 중 가장 가까운 것을 대상으로 잡고, 연계기가 준비된 파티원을 찾아요.
func _pick_chain() -> void:
	var best = null
	var busy := false
	for m in monsters.get_children():
		if not m.alive():
			continue
		m.targeted = false
		if m.state == "fly" or m.state == "groggy":
			busy = true
		if not m.groggy():
			continue
		if Config.CHAIN_LIMIT > 0 and m.chain_hits >= Config.CHAIN_LIMIT:
			continue
		if best == null or m.position.x < best.position.x:
			best = m
	chain_id = party.ready_member()
	chain_target = best if chain_id != "" else null
	if chain_target != null:
		chain_target.targeted = true
	if not busy:
		chain_run = 0


func chain_ready() -> bool:
	return chain_target != null


# 연계기: 준비된 파티원이 뛰어나와 그로기 몬스터를 다시 날려요. 발동했으면 true
func do_chain() -> bool:
	if state != State.STAGE or paused or chain_target == null:
		return false
	var m = chain_target
	var id := chain_id
	var data: Dictionary = Characters.DATA[id]
	chain_target = null
	chain_run += 1
	chain_total += 1
	max_chain = maxi(max_chain, chain_run)
	m.chain_hits += 1
	m.targeted = false

	var at: Vector2 = m.center()
	party.strike(id, at)
	fx.star(at, 1.7)
	fx.shake(13.0, 0.22)
	hitstop(Config.HITSTOP_CHAIN)
	fx.burst(at, data["color"], 7, 0.8)
	fx.text(at + Vector2(-60, -m.h / 2.0 - 44.0), "%s · %s" % [data["name"], data["move"]],
			data["color"], 28)
	if chain_run >= 2:
		fx.text(at + Vector2(60, -m.h / 2.0 - 86.0), "연쇄 x%d" % chain_run, ChibiDraw.GOLD, 34, 0.9)
	var mv: Vector2 = data["move_v"]
	_hurt(m, Config.CHAIN_DAMAGE * data["damage"], mv.x, mv.y)
	return true


# ---------------------------------------------------------------- 결과

func _finish(reason: String) -> void:
	state = State.RESULT
	result_reason = reason
	world.position = Vector2.ZERO
	hud.queue_redraw()
	result.show_result({
		"reason": reason,
		"distance": int(distance / Config.PX_PER_METER),
		"score": int(score),
		"max_combo": max_combo,
		"kills": kills,
		"chains": chain_total,
		"max_chain": max_chain,
		"stage": stage,
		"show_stage": mode() == "juggle",
	})


func restart(to_select := false) -> void:
	Config.skip_select = not to_select
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 입력

# 공격 버튼 하나로 두 가지를 해요.
# 선두는 누를 때마다 항상 휘둘러요.
# 그로기 몬스터가 있고 준비된 파티원이 있으면 연계기도 같이 나가요.
func do_attack() -> void:
	if state != State.STAGE or paused:
		return
	var target = chain_target
	var chained := do_chain()
	if player.try_attack() and chained and is_instance_valid(target):
		target.hit_serial = player.serial     # 방금 연계기로 날린 대상은 이번 휘두르기에 다시 맞지 않음


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

func _draw_overlay() -> void:
	if paused:
		overlay.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		ChibiDraw.text(overlay, Vector2(640, 350), "일시정지", 64, Color.WHITE, 1, true)
		ChibiDraw.text(overlay, Vector2(640, 400), "Esc / P 또는 화면을 탭하면 계속", 22,
				Color(1, 1, 1, 0.8), 1)
	if debug_on:
		var names := ["편성", "스테이지", "결과"]
		var tg := "-"
		if chain_target != null:
			tg = "%s 체력 %.0f · 그로기 %.2f초 · %s 대기" % [
				chain_target.kind, chain_target.hp, chain_target.groggy_t, chain_id]
		var rows := [
			"FPS %d" % Engine.get_frames_per_second(),
			"상태: %s · 몬스터 %d · 스크롤 %d px/s" % [names[state], monsters.get_child_count(), int(scroll)],
			"연계기 대상: %s" % tg,
			"충돌 %d회(죽으며 %d회) → 그로기 %d회 → 연계기 %d회" % [bowl_total, dying_bowls, groggy_total, chain_total],
			"지금 연쇄 x%d · 최대 연쇄 x%d · 처치 %d (추락 %d)" % [chain_run, max_chain, kills, pit_kills],
		]
		ChibiDraw.panel(overlay, Rect2(16, 150, 420, 22.0 * rows.size() + 16), Color(0, 0, 0, 0.7), 6)
		for i in rows.size():
			ChibiDraw.text(overlay, Vector2(28, 176 + i * 22), rows[i], 15, Color(0.7, 1.0, 0.75))
