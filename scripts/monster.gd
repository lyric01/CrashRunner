extends Node2D
# 몬스터와 장애물 공통. 노드 원점 = (중심 x, 지면 y)
# 종류: slime(약함, 핀) / orc(단단함, 공)
#       steel(뛰어넘는 강철벽) / pit(낭떠러지) / elite(강적, 저글링 모드)
#       bat(공중 적: 맞기 전에는 머리 위 높이로 날아옴)
# 상태: walk(다가옴) → fly(맞아서 날아감) → 땅에 멈춤
#         그로기 동안에는 계속 통통 튀고, 그로기가 풀리면 down(잠깐 쓰러짐) → walk
#       공격으로 체력이 0이 되면 dying(통통 튀며 사라짐)

const DEFS := {
	"slime": {"size": Vector2(52, 38), "mass": 1.0},
	"orc": {"size": Vector2(62, 86), "mass": 1.0},
	"steel": {"size": Vector2(54, 90), "mass": 1.0},
	"pit": {"size": Vector2(210, 0), "mass": 1.0},
	"elite": {"size": Vector2(120, 170), "mass": 1.0},
	"bat": {"size": Vector2(56, 40), "mass": 1.0},
}
const WOOD := Color("#C98A4B")
const SLIME := Color("#6FCF5A")
const ORC := Color("#5E8C4A")
const STEEL := Color("#7C8792")
const ELITE := Color("#8E2F3C")
const BAT := Color("#8A5BD6")

var kind := "slime"
var w := 0.0
var h := 0.0
var mass := 1.0
var hp := 1.0
var max_hp := 1.0
var state := "walk"
var lift := 0.0            # 바닥에서 떠 있는 높이
var vx := 0.0              # 세계 기준 수평 속도(오른쪽 +)
var vy := 0.0
var rot := 0.0
var bounces := 0
var down_t := 0.0
var groggy_t := 0.0        # 0보다 크면 그로기(통통 튀는 상태)
var approach := -1.0       # 0 이상이면 땅 속도 대신 이 속도로 다가옴(강적)
var show_hp := true
var lane := ""             # 탄환이 날아가는 길: high / mid / low
var roll := false          # 바닥으로 굴러가는 탄환
var weak := ""             # 강적의 지금 약점: high / mid / low
var volley := 0            # 같이 던져진 수(한방 판정용)
var shot_t := 0.0          # 던져진 뒤 지난 시간 제한
var no_floor_t := 0.0      # 튕겨 돌아오는 동안은 선두 앞에 머무는 보정을 끔
var air_h := 0.0           # 0보다 크면 이 높이로 날아다니는 중(한 번 맞으면 0이 되어 떨어짐)
var grav := 1.0            # 중력 배율(공중에 천천히 떠 있게 할 때 낮춤)
var incoming := false      # 강적에게서 튕겨 오는 중(땅에 닿기 전)
var shot := false          # 강적에게 쳐 보낸 상태
var hop := false           # 그로기 동안 계속 통통 튐(저글링 모드)
var passed := false        # 선두와 이미 부딪힘
var dead := false          # 노드 제거됨
var hit_serial := -1       # 마지막으로 맞은 휘두르기 번호
var squash := Vector2.ONE  # 찌그러짐(맞는 순간, 땅에 닿는 순간)
var trail: Array = []      # 잔상 위치(화면 좌표)
var targeted := false      # 지금 치면 PERFECT인 몬스터 표시(흰 고리)
var flash := 0.0
var anim := 0.0


func setup(k: String) -> void:
	kind = k
	var d: Dictionary = DEFS[k]
	w = d.size.x
	h = d.size.y
	mass = d.mass
	anim = randf() * TAU
	match k:
		"slime": max_hp = Config.SLIME_HP
		"orc": max_hp = Config.ORC_HP
		"bat":
			max_hp = Config.BAT_HP
			air_h = Config.BAT_HEIGHT
			lift = air_h
		_: max_hp = 1.0
	hp = max_hp


func is_monster() -> bool:
	return kind == "slime" or kind == "orc" or kind == "bat"


func alive() -> bool:
	return not dead and state != "dying"


func groggy() -> bool:
	return alive() and groggy_t > 0.0 and (state == "fly" or state == "groggy")


func rect() -> Rect2:
	return Rect2(position.x - w / 2.0, Config.GROUND_Y - lift - h, w, h)


func center() -> Vector2:
	return Vector2(position.x, Config.GROUND_Y - lift - h / 2.0)


func color() -> Color:
	match kind:
		"slime": return SLIME
		"orc": return ORC
		"steel": return STEEL
		"elite": return ELITE
		"bat": return BAT
	return WOOD


func launch(pvx: float, pvy: float) -> void:
	if state != "dying":
		state = "fly"
	vx = pvx
	vy = pvy
	air_h = 0.0
	grav = 1.0
	bounces = 0
	groggy_t = 0.0
	lift = maxf(lift, 1.0)
	squash = Config.HIT_SQUASH
	flash = 0.12


# 돌려주는 값: "", "bounce", "land", "recover", "gone"
func update(dt: float, scroll: float) -> String:
	anim += dt * 8.0
	flash -= dt
	groggy_t -= dt
	no_floor_t -= dt
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-Config.SQUASH_RECOVER * dt))
	var ev := ""
	match state:
		"walk":
			position.x -= (approach if approach >= 0.0 else scroll) * dt
			if air_h > 0.0:
				# 공중 적: 머리 위 높이에서 위아래로 흔들리며 조금 더 빨리 다가와요.
				position.x -= Config.BAT_SPEED * dt
				lift = air_h + sin(anim * 0.8) * Config.BAT_BOB
		"down":
			position.x -= scroll * dt
			down_t -= dt
			if down_t <= 0.0:
				state = "walk"
				ev = "recover"
		"groggy":
			position.x -= scroll * dt
			if groggy_t <= 0.0:
				state = "walk"
				ev = "recover"
		_:
			if dt > 0.0:
				trail.append(Vector2(position.x, -lift - h / 2.0))
				if trail.size() > 6:
					trail.pop_front()
			if state == "fly" and not shot and not incoming:
				vx -= vx * Config.KNOCK_DRAG * dt
				# 저글링 모드: 그로기 동안에는 땅에 끌려가지 않고 선두 앞에서 천천히 다가와요.
				if hop and groggy_t > 0.0 and no_floor_t <= 0.0:
					vx = maxf(vx, scroll - Config.JUGGLE_DRIFT)
			position.x += (vx - scroll) * dt
			vy += Config.GRAVITY * grav * dt
			lift -= vy * dt
			if roll:
				lift = 4.0
				vy = 0.0
			rot += clampf(vx / 110.0, 4.0, 16.0) * dt
			if state == "fly":
				position.x = minf(position.x, Config.WALL_X)
			if lift <= 0.0 and vy > 0.0:
				lift = 0.0
				bounces += 1
				incoming = false
				grav = 1.0
				squash = Config.LAND_SQUASH
				if state == "dying":
					if bounces >= 3:
						ev = "gone"
					else:
						vy = -vy * Config.BOUNCE_VY_KEEP
						vx = maxf(vx * 0.7, scroll + 160.0)
						ev = "bounce"
				elif hop and groggy_t > 0.0:
					# 저글링 모드: 그로기인 동안에는 멈추지 않고 계속 통통 튀어요.
					vy = -maxf(vy * Config.BOUNCE_VY_KEEP, Config.HOP_VY)
					vx *= Config.BOUNCE_VX_KEEP
					ev = "bounce"
				elif bounces > Config.MAX_BOUNCES:
					state = "groggy" if groggy_t > 0.0 else "down"
					down_t = Config.RECOVER_TIME
					vy = 0.0
					rot = 0.0
					trail.clear()
					ev = "land"
				else:
					vy = -vy * Config.BOUNCE_VY_KEEP
					vx *= Config.BOUNCE_VX_KEEP
					ev = "bounce"
	queue_redraw()
	return ev


func off_screen() -> bool:
	return position.x < -w - 120.0 or position.x > 1800.0


func _draw() -> void:
	if kind == "pit":
		draw_rect(Rect2(-w / 2.0, -2, w, 240), Color("#17111C"))
		draw_rect(Rect2(-w / 2.0, -2, 8, 240), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(w / 2.0 - 8, -2, 8, 240), Color(0, 0, 0, 0.35))
		return
	var air := state == "fly" or state == "dying"
	var a := 1.0
	if state == "dying":
		a = clampf(1.0 - bounces * 0.3, 0.2, 1.0)
	var lying := state == "down"
	var dizzy := state == "groggy"
	var cy := -lift - (w / 2.0 if lying else h / 2.0)
	var r_ang := rot if air else (PI / 2.0 if lying else (sin(anim * 1.6) * 0.14 if dizzy else 0.0))
	var hurt := air or lying or dizzy
	var col := color()

	# 잔상
	if air:
		for i in trail.size():
			var p: Vector2 = trail[i]
			var k := float(i + 1) / (trail.size() + 1)
			draw_circle(Vector2(p.x - position.x, p.y), minf(w, h) * 0.42 * k, _c(col, 0.28 * k * a))

	# 찌그러짐은 발(아래쪽) 기준이 아니라 중심 기준으로 줘요.
	draw_set_transform(Vector2(0, cy), r_ang, squash)
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	match kind:
		"steel":
			draw_rect(r, STEEL)
			draw_rect(Rect2(r.position, Vector2(10, h)), STEEL.lightened(0.25))
			draw_rect(r, STEEL.darkened(0.45), false, 4.0)
			for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_circle(Vector2(p.x * (w / 2.0 - 10), p.y * (h / 2.0 - 10)), 4, STEEL.darkened(0.5))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, 12), Vector2(0, -14), Vector2(12, 12)]), Color("#22303C"))
		"elite":
			var sway := 0.0 if hurt else sin(anim * 0.5) * 3.0
			draw_rect(Rect2(-w / 2.0, -h / 2.0 + 44, w, h - 44), _c(ELITE, a))
			draw_rect(Rect2(-w / 2.0, -h / 2.0 + 44, w, h - 44), _c(ELITE.darkened(0.45), a), false, 5.0)
			draw_rect(Rect2(-40, -h / 2.0 + sway, 80, 56), _c(ELITE.lightened(0.12), a))
			draw_rect(Rect2(-40, -h / 2.0 + sway, 80, 56), _c(ELITE.darkened(0.45), a), false, 5.0)
			for hx: float in [-34.0, 22.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(hx, -h / 2.0 + sway), Vector2(hx + 12, -h / 2.0 + sway),
					Vector2(hx + 6, -h / 2.0 - 22 + sway)]), _c(Color(0.95, 0.9, 0.8), a))
			if hurt:
				_eyes(Vector2(-22, -h / 2.0 + 26), Vector2(6, -h / 2.0 + 26), 7.0, true, Color(1, 0.85, 0.3, a))
			else:
				draw_rect(Rect2(-32, -h / 2.0 + 20 + sway, 20, 9), Color(1, 0.85, 0.3, a))
				draw_rect(Rect2(-4, -h / 2.0 + 20 + sway, 20, 9), Color(1, 0.85, 0.3, a))
			# 방패는 약점이 아닌 두 곳을 가려요. 가려지지 않은 곳(금색 표시)이 약점이에요.
			var zones := {"high": [-h / 2.0 - 26.0, 70.0], "mid": [-h / 2.0 + 48.0, 66.0], "low": [h / 2.0 - 52.0, 52.0]}
			for z: String in zones:
				var zy: float = zones[z][0]
				var zh: float = zones[z][1]
				if z == weak and not hurt:
					var pr := 13.0 + sin(anim * 1.5) * 3.0
					draw_circle(Vector2(-w / 2.0 - 8, zy + zh / 2.0), pr + 5.0, Color(1.0, 0.76, 0.24, 0.35 * a))
					draw_circle(Vector2(-w / 2.0 - 8, zy + zh / 2.0), pr, Color(1.0, 0.85, 0.3, a))
				elif weak != "open":
					draw_rect(Rect2(-w / 2.0 - 26, zy, 30, zh - 4.0), _c(STEEL, a))
					draw_rect(Rect2(-w / 2.0 - 26, zy, 30, zh - 4.0), _c(STEEL.darkened(0.5), a), false, 4.0)
		"bat":
			var flap := 0.0 if hurt else sin(anim * 2.4) * 15.0
			for sx: float in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(8 * sx, -6), Vector2(42 * sx, -16 - flap), Vector2(36 * sx, 6 - flap * 0.4),
					Vector2(24 * sx, 0), Vector2(15 * sx, 12)]), _c(BAT.darkened(0.3), a))
				draw_colored_polygon(PackedVector2Array([
					Vector2(5 * sx, -12), Vector2(13 * sx, -27), Vector2(15 * sx, -10)]), _c(BAT, a))
			draw_circle(Vector2.ZERO, 17, _c(BAT, a))
			draw_circle(Vector2(-4, 4), 9, _c(BAT.lightened(0.2), a))
			_eyes(Vector2(-8, -3), Vector2(5, -3), 3.5, hurt, Color(1.0, 0.9, 0.4, a))
		"slime":
			var wob := 1.0 + (0.0 if hurt else sin(anim) * 0.06)
			draw_set_transform(Vector2(0, cy + 4), r_ang, Vector2(squash.x / wob, squash.y * 0.74 * wob))
			draw_circle(Vector2.ZERO, 27, _c(SLIME, a))
			draw_circle(Vector2(-8, -10), 8, _c(SLIME.lightened(0.35), a))
			_eyes(Vector2(-11, 0), Vector2(5, 0), 4.0, hurt, Color(0.1, 0.25, 0.1, a))
		"orc":
			var bob := 0.0 if hurt else sin(anim) * 2.0
			draw_rect(Rect2(-w / 2.0, -h / 2.0 + 26 + bob, w, h - 26 - bob), _c(ORC.darkened(0.25), a))
			draw_rect(Rect2(-w / 2.0, h / 2.0 - 22, w, 8), _c(Color("#6B4A2E"), a))
			draw_circle(Vector2(-2, -h / 2.0 + 24 + bob), 27, _c(ORC, a))
			_eyes(Vector2(-14, -h / 2.0 + 20 + bob), Vector2(0, -h / 2.0 + 20 + bob), 4.0, hurt,
					Color(0.1, 0.12, 0.1, a))
			for tx: float in [-18.0, 2.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(tx, -h / 2.0 + 36 + bob), Vector2(tx + 8, -h / 2.0 + 36 + bob),
					Vector2(tx + 4, -h / 2.0 + 24 + bob)]), Color(1, 1, 0.9, a))
			draw_line(Vector2(-w / 2.0 - 4, 6), Vector2(-w / 2.0 - 24, -30), _c(Color("#6B4A2E"), a), 9.0)
	if flash > 0.0 and kind != "steel":
		draw_rect(r.grow(4.0), Color(1, 1, 1, 0.7 * clampf(flash / 0.12, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO)

	var top := -lift - h
	# 머리 위 체력 바(단단한 몬스터만)
	if show_hp and (kind == "orc" or kind == "elite") and alive():
		ChibiDraw.bar(self, Rect2(-34, top - 18, 68, 7), hp / max_hp, Color("#FF5A5A"))
	# 그로기: 머리 위에서 도는 별 + 남은 시간
	if groggy():
		for i in 3:
			var ang := anim * 0.9 + i * TAU / 3.0
			var sp := Vector2(cos(ang) * 26.0, top - 34.0 + sin(ang) * 7.0)
			draw_circle(sp, 6.0, ChibiDraw.GOLD)
			draw_circle(sp, 2.5, Color.WHITE)
		ChibiDraw.bar(self, Rect2(-34, top - 8, 68, 5), groggy_t / Config.REBOUND_GROGGY, ChibiDraw.GOLD)
		if targeted:
			var c := Vector2(0, -lift - h / 2.0)
			var rad := maxf(w, h) * 0.75 + sin(anim * 2.0) * 4.0
			draw_arc(c, rad + 3.0, 0.0, TAU, 40, Color(0, 0, 0, 0.45), 11.0)
			draw_arc(c, rad + 3.0, 0.0, TAU, 40, Color.WHITE, 7.0)
			draw_arc(c, rad - 4.0, 0.0, TAU, 40, ChibiDraw.GOLD, 4.0)


func _c(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _eyes(p1: Vector2, p2: Vector2, s: float, hurt: bool, col: Color) -> void:
	for p: Vector2 in [p1, p2]:
		if hurt:
			draw_line(p + Vector2(-s, -s), p + Vector2(s, s), col, 3.0)
			draw_line(p + Vector2(-s, s), p + Vector2(s, -s), col, 3.0)
		else:
			draw_circle(p, s, col)
