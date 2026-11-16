extends Node
# 넉백 4단 연계 상태 머신과 판정.
# phase: travel(보스가 다음 상태로 이동) → window(교체 창, 슬로모션) → ... → cutin → travel → 끝
# 실패하면 travel(추락) → down(쓰러짐) → travel(복귀) → 끝

const STEPS := [
	{"id": "cow", "state": "groggy", "state_name": "그로기", "move": "들이받기"},
	{"id": "wolf", "state": "wall", "state_name": "벽 튕김", "move": "띄우기 베기"},
	{"id": "bear", "state": "fall", "state_name": "떨어짐", "move": "내리찍기"},
	{"id": "rabbit", "state": "bound", "state_name": "바운드", "move": "공중 차기 마무리"},
]

var game
var active := false
var phase := ""
var step := 0
var win_t := 0.0           # 교체 창 경과(실제 시간)
var cut_t := 0.0
var down_t := 0.0
var elapsed := 0.0         # 연계 전체 시간(실제 시간, 디버그 측정용)
var hits := 0
var segs: Array = []
var seg_t := 0.0
var seg_from := Vector2.ZERO
var rot_from := 0.0
var after := ""
var drift := Vector2.ZERO


func start() -> void:
	active = true
	step = 0
	hits = 0
	elapsed = 0.0
	game.boss.chain_controlled = true
	game.fx.text(game.boss.center() + Vector2(0, -150), "그로기!", ChibiDraw.GOLD, 44, 1.0)
	_travel(_segs_for(0), "window")


func abort() -> void:
	active = false
	phase = ""
	game.slowmo = 1.0
	game.cutin.hide_cutin()


# i번째 창이 열리기 전까지 보스가 움직이는 구간들
func _segs_for(i: int) -> Array:
	var gy := Config.GROUND_Y
	var hx := Config.BOSS_X
	match i:
		0:  # 그로기로 휘청임
			drift = Vector2(15, 0)
			return [{"to": Vector2(hx + 20, gy), "dur": 0.25, "rot": 0.2}]
		1:  # 화면 오른쪽 끝(벽)에 쾅 → 튕겨 나옴
			drift = Vector2(-160, -60)
			return [
				{"to": Vector2(1215, gy - 30), "dur": 0.26, "rot": 0.5, "slam": true},
				{"to": Vector2(1090, gy - 80), "dur": 0.18, "rot": -0.3},
			]
		2:  # 위로 높이 떠오름 → 떨어지기 시작
			drift = Vector2(0, 260)
			return [{"to": Vector2(hx, gy - 330), "dur": 0.38, "rot": -1.2}]
		3:  # 바닥에 꽂히고 튕겨 오름
			drift = Vector2(20, -80)
			return [
				{"to": Vector2(hx, gy), "dur": 0.13, "rot": 1.57, "slam": true},
				{"to": Vector2(hx + 10, gy - 170), "dur": 0.26, "rot": 2.4},
			]
	# 마무리: 멀리 날아감
	drift = Vector2(10, 30)
	return [{"to": Vector2(1190, gy - 210), "dur": 0.28, "rot": 5.0, "slam": true}]


func _travel(list: Array, next: String) -> void:
	phase = "travel"
	segs = list
	after = next
	seg_t = 0.0
	seg_from = game.boss.cpos
	rot_from = game.boss.crot
	game.slowmo = 1.0


func update(dt: float, rdt: float) -> void:
	if not active:
		return
	elapsed += rdt
	var boss = game.boss
	match phase:
		"travel":
			var seg: Dictionary = segs[0]
			seg_t += dt
			var p := clampf(seg_t / seg.dur, 0.0, 1.0)
			var e := 1.0 - (1.0 - p) * (1.0 - p)
			boss.cpos = seg_from.lerp(seg.to, e)
			boss.crot = lerpf(rot_from, seg.rot, e)
			if p >= 1.0:
				if seg.get("slam", false):
					game.fx.shake(16.0, 0.3)
					game.fx.burst(boss.center(), boss.BODY, 8)
					game.fx.star(boss.center(), 1.4)
					game.hitstop(Config.HITSTOP_SMALL)
				segs.pop_front()
				seg_t = 0.0
				seg_from = boss.cpos
				rot_from = boss.crot
				if segs.is_empty():
					_enter(after)
		"window":
			game.slowmo = Config.SLOWMO_SCALE
			if game.hitstop_t <= 0.0:
				win_t += rdt
			boss.cpos += drift * dt
			if win_t >= Config.COMBO_WINDOW:
				_fail()
		"cutin":
			game.slowmo = Config.SLOWMO_SCALE
			cut_t += rdt
			boss.cpos += drift * dt
			if cut_t >= Config.CUTIN_DURATION:
				_finish()
		"down":
			down_t -= dt
			if down_t <= 0.0:
				_travel([{"to": boss.home, "dur": 0.3, "rot": 0.0}], "end")


func _enter(next: String) -> void:
	match next:
		"window":
			phase = "window"
			win_t = 0.0
		"cutin":
			phase = "cutin"
			cut_t = 0.0
			game.cutin.show_cutin("교체 시너지!", "소 → 늑대 → 곰 → 토끼 · 넉백 4단 연계")
		"down":
			phase = "down"
			down_t = Config.BOSS_RECOVER_TIME
		"end":
			_end()


func on_swap(id: String) -> void:
	if phase == "cutin":
		skip_cutin()
	elif phase == "window" and id == STEPS[step].id:
		_strike()
	# 엉뚱한 초상화는 아무 일도 없어요(창은 계속 흐름).


func on_dash() -> void:
	on_swap(game.party.active)


# 큰 컷인은 같은 판에서 두 번째부터 탭으로 넘길 수 있어요.
func skip_cutin() -> void:
	if phase == "cutin" and game.cutin_seen:
		cut_t = Config.CUTIN_DURATION


func _strike() -> void:
	var st: Dictionary = STEPS[step]
	var p := win_t / Config.COMBO_WINDOW
	var perfect := absf(p - 0.5) <= Config.PERFECT_RATIO / 2.0
	game.party.swap_to(st.id, true)
	var dmg := Config.COMBO_BASE_DAMAGE
	if Characters.DATA[st.id]["bonus_state"] == st.state:
		dmg *= Config.STATE_BONUS
	if perfect:
		dmg *= Config.PERFECT_BONUS
	var boss = game.boss
	var at: Vector2 = boss.center()
	game.player.strike_at(boss.cpos)
	game.fx.star(at, 1.6)
	game.fx.shake(12.0, 0.2)
	game.hitstop(Config.HITSTOP_BIG)
	game.fx.text(at + Vector2(-110, -40), "%d단 · %s" % [step + 1, st.move],
			Characters.DATA[st.id]["color"], 30)
	if perfect:
		game.fx.text(at + Vector2(0, -150), "PERFECT", ChibiDraw.GOLD, 40, 0.9)
	hits += 1
	step += 1
	boss.take_damage(dmg)
	if not active:      # 이 타격으로 보스가 쓰러짐
		return
	_travel(_segs_for(step), "cutin" if step >= STEPS.size() else "window")


func _fail() -> void:
	var boss = game.boss
	game.fx.text(boss.center() + Vector2(0, -130), "연계 끊김", Color(0.85, 0.85, 0.9), 26)
	var x := clampf(boss.cpos.x, 900.0, 1150.0)
	_travel([{"to": Vector2(x, Config.GROUND_Y), "dur": 0.3, "rot": 1.57, "slam": true}], "down")


func _finish() -> void:
	game.cutin.hide_cutin()
	game.cutin_seen = true
	game.chain_success += 1
	var boss = game.boss
	game.fx.star(boss.center(), 2.2)
	game.fx.shake(20.0, 0.4)
	game.hitstop(Config.HITSTOP_BIG)
	game.fx.text(boss.center() + Vector2(-60, -160), "마무리!", ChibiDraw.GOLD, 46, 1.0)
	boss.take_damage(Config.COMBO_FINISH_DAMAGE)
	if not active:
		return
	_travel([{"to": boss.home, "dur": 0.35, "rot": TAU}], "end")


func _end() -> void:
	active = false
	phase = ""
	var boss = game.boss
	boss.chain_controlled = false
	boss.crot = 0.0
	boss.groggy = 0
	boss.pattern_timer = 1.2
	game.slowmo = 1.0
	game.last_chain_time = elapsed
	game.last_chain_hits = hits
	game.invuln = maxf(game.invuln, 0.5)
