extends Node2D
# 강철 골렘: 패턴 4종, 그로기, 넉백 연출용 위치(cpos/crot). 노드 원점 = 발

const NAME := "강철 골렘"
const BODY := Color("#6B6380")
const PATTERNS := {
	"rock": {"warn": "바위 던지기! 돌진으로 부수기", "rec": ""},
	"wave": {"warn": "충격파! 점프로 넘기", "rec": "rabbit"},
	"shield": {"warn": "방패 패턴! 곰으로 교체해서 깨기", "rec": "bear"},
	"summon": {"warn": "소환! 늑대로 한 번에 관통", "rec": "wolf"},
}

var game
var home := Vector2(Config.BOSS_X, Config.GROUND_Y)
var cpos := Vector2(Config.BOSS_X + 500.0, Config.GROUND_Y)
var crot := 0.0
var chain_controlled := false
var hp: float = Config.BOSS_HP
var groggy := 0
var push := 0.0
var flash := 0.0
var enter_x := 500.0
var run_phase := 0.0
var dying := false
var die_t := 0.0

var pattern := ""
var pt := 0.0
var pattern_timer := 1.5
var fired := false
var shield_up := false
var obj = null             # 바위·충격파
var slimes_alive := 0
var slimes_killed := 0
var bag: Array = []


func rect() -> Rect2:
	var left := 96.0 if shield_up else 70.0
	return Rect2(cpos.x - left, cpos.y - 200.0, left + 70.0, 200.0)


func center() -> Vector2:
	return cpos + Vector2(0, -100)


func update(dt: float, can_act: bool) -> void:
	run_phase += dt * 9.0
	flash -= dt
	push = move_toward(push, 0.0, 260.0 * dt)
	enter_x = move_toward(enter_x, 0.0, 600.0 * dt)
	if dying:
		die_t += dt
		crot += dt * 2.5
		cpos += Vector2(160, -40) * dt
	elif not chain_controlled:
		cpos = home + Vector2(push + enter_x, 0)
	position = cpos
	queue_redraw()
	if not can_act or dying:
		return

	pattern_timer -= dt
	if pattern == "":
		if pattern_timer <= 0.0:
			_start_pattern()
		return
	pt += dt
	match pattern:
		"rock", "wave":
			if not fired and pt >= Config.PATTERN_TELEGRAPH:
				fired = true
				obj = game.spawn(pattern, cpos.x - 110.0)
			elif fired and (not is_instance_valid(obj) or obj.dead):
				_end_pattern()
		"shield":
			if pt >= Config.SHIELD_DURATION:
				_end_pattern()
		"summon":
			if not fired and pt >= Config.PATTERN_TELEGRAPH:
				fired = true
				slimes_alive = 3
				slimes_killed = 0
				for i in 3:
					var s = game.spawn("slime", cpos.x - 140.0 - i * 84.0)
					s.boss_obj = true
					game.fx.burst(s.center(), Color("#A66BFF"), 4, 0.5)


func _start_pattern() -> void:
	if bag.is_empty():
		bag = PATTERNS.keys()
		bag.shuffle()
	pattern = bag.pop_back()
	pt = 0.0
	fired = false
	obj = null
	shield_up = pattern == "shield"
	pattern_timer = Config.PATTERN_INTERVAL


func _end_pattern() -> void:
	pattern = ""
	shield_up = false
	pattern_timer = maxf(pattern_timer, 0.6)


func cancel_pattern() -> void:
	pattern = ""
	shield_up = false
	slimes_alive = 0


# 그로기가 가득 차서 4단 연계가 시작되면 true
func add_groggy(n: int) -> bool:
	groggy = mini(Config.GROGGY_MAX, groggy + n)
	game.fx.text(cpos + Vector2(0, -250), "그로기 +%d" % n, ChibiDraw.GOLD, 24)
	if groggy >= Config.GROGGY_MAX:
		game.start_chain()
		return true
	return false


func on_rock_broken() -> void:
	add_groggy(1)


func on_wave_dodged() -> void:
	game.fx.text(Vector2(Config.PLAYER_X, Config.GROUND_Y - 150), "회피!", Color("#C9A6FF"), 26)
	add_groggy(1)


func break_shield() -> void:
	game.fx.burst(cpos + Vector2(-100, -100), ChibiDraw.GOLD, 12)
	_end_pattern()
	push = 60.0
	if not add_groggy(2):
		game.party.open_mini()


func on_slime_gone(killed: bool) -> void:
	if pattern != "summon":
		return
	slimes_alive -= 1
	if killed:
		slimes_killed += 1
	if slimes_alive <= 0:
		var all_killed := slimes_killed >= 3
		_end_pattern()
		if all_killed:
			push = 60.0
			if not add_groggy(1):
				game.party.open_mini()


func take_damage(d: float) -> void:
	if dying:
		return
	hp = maxf(0.0, hp - d)
	flash = 0.12
	game.fx.text(center() + Vector2(randf_range(-40, 40), -110), str(int(round(d))), Color.WHITE, 28)
	if hp <= 0.0:
		dying = true
		game.on_boss_dead()


func _draw() -> void:
	var a := clampf(1.0 - die_t / 1.0, 0.0, 1.0)
	var body := BODY.lerp(Color.WHITE, 0.7) if flash > 0.0 else BODY
	body.a = a
	var dark := body.darkened(0.3)
	var light := body.lightened(0.15)
	var bob := 0.0 if chain_controlled else sin(run_phase) * 4.0
	draw_set_transform(Vector2(0, -100 + bob), crot)
	var step := 0.0 if chain_controlled else sin(run_phase) * 10.0
	draw_rect(Rect2(-50, 56 + step * 0.5, 38, 44 - step * 0.5), dark)
	draw_rect(Rect2(12, 56 - step * 0.5, 38, 44 + step * 0.5), dark)
	draw_rect(Rect2(60, -40, 30, 84), dark)
	draw_rect(Rect2(-62, -48, 124, 110), body)
	draw_rect(Rect2(-62, -48, 124, 110), dark, false, 4.0)
	draw_line(Vector2(-20, -10), Vector2(6, 22), dark, 3.0)
	draw_line(Vector2(6, 22), Vector2(-6, 46), dark, 3.0)
	draw_rect(Rect2(-40, -100, 78, 56), light)
	draw_rect(Rect2(-40, -100, 78, 56), dark, false, 4.0)
	var eye := Color(1.0, 0.85, 0.3, a)
	if chain_controlled:
		# 그로기: X자 눈
		for ex: float in [-22.0, 2.0]:
			draw_line(Vector2(ex - 6, -84), Vector2(ex + 6, -70), eye, 4.0)
			draw_line(Vector2(ex - 6, -70), Vector2(ex + 6, -84), eye, 4.0)
	else:
		draw_rect(Rect2(-30, -82, 16, 9), eye)
		draw_rect(Rect2(-6, -82, 16, 9), eye)
	draw_rect(Rect2(-92, -40 - step, 30, 84), body)
	draw_rect(Rect2(-92, -40 - step, 30, 84), dark, false, 4.0)
	if shield_up:
		var pulse := 0.6 + 0.4 * sin(run_phase * 1.5)
		draw_rect(Rect2(-128, -92, 30, 176), Color("#4A5568"))
		draw_rect(Rect2(-128, -92, 30, 176), Color(1.0, 0.76, 0.24, pulse), false, 6.0)
		draw_rect(Rect2(-120, -84, 6, 160), Color("#718096"))
	draw_set_transform(Vector2.ZERO)
