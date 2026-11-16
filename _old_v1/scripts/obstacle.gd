extends Node2D
# 장애물 공통(종류별 분기)과 넉백 비행. 노드 원점 = (중심 x, 지면 y)
# 종류: wood, box, slime, steel, pit / 보스전: rock, wave

const SIZES := {
	"wood": Vector2(44, 130), "box": Vector2(56, 56), "slime": Vector2(52, 38),
	"steel": Vector2(54, 120), "pit": Vector2(210, 0),
	"rock": Vector2(62, 62), "wave": Vector2(64, 46),
}
const WOOD := Color("#C98A4B")
const STEEL := Color("#7C8792")
const SLIME := Color("#6FCF5A")

var kind := "wood"
var w := 0.0
var h := 0.0
var lift := 0.0            # 바닥에서 떠 있는 높이
var flying := false
var vx := 0.0              # 세계 기준 수평 속도(오른쪽 +)
var vy := 0.0
var rot := 0.0
var bounces := 0
var bounce_t := 0.0        # 따라잡기 추가타 판정 남은 시간
var chased := 0
var extra_vx := 0.0        # 스크롤보다 더 빨리 다가오는 속도(바위, 충격파)
var passed := false        # 플레이어와 이미 상호작용함
var dead := false
var expired := false       # 두 번째로 땅에 닿아 사라짐
var boss_obj := false
var anim := 0.0


func setup(k: String) -> void:
	kind = k
	var s: Vector2 = SIZES[k]
	w = s.x
	h = s.y
	anim = randf() * TAU
	if k == "rock":
		lift = 26.0
		extra_vx = Config.ROCK_EXTRA_SPEED
		boss_obj = true
	elif k == "wave":
		extra_vx = Config.WAVE_EXTRA_SPEED
		boss_obj = true


func rect() -> Rect2:
	return Rect2(position.x - w / 2.0, Config.GROUND_Y - lift - h, w, h)


func center() -> Vector2:
	return Vector2(position.x, Config.GROUND_Y - lift - h / 2.0)


func breakable() -> bool:
	return kind == "wood" or kind == "box" or kind == "slime"


func frag_color() -> Color:
	match kind:
		"slime": return SLIME
		"steel": return STEEL
		"rock": return Color("#8C8478")
		"wave": return Color("#A66BFF")
	return WOOD


func launch(pvx: float, pvy: float) -> void:
	flying = true
	vx = pvx
	vy = pvy
	bounces = 0
	bounce_t = 0.0
	lift = maxf(lift, 1.0)


func update(dt: float, scroll: float) -> void:
	anim += dt * 8.0
	bounce_t -= dt
	if flying:
		position.x += (vx - scroll) * dt
		vy += Config.GRAVITY * dt
		lift -= vy * dt
		rot += 9.0 * dt
		if lift <= 0.0 and vy > 0.0:
			bounces += 1
			if bounces >= 2:
				expired = true
			else:
				lift = 0.0
				vy = -vy * Config.BOUNCE_VY_KEEP
				vx *= Config.BOUNCE_VX_KEEP
				bounce_t = Config.BOUNCE_WINDOW
	else:
		position.x -= (scroll + extra_vx) * dt
	queue_redraw()


func off_screen() -> bool:
	return position.x < -w - 120.0 or position.x > 1700.0


func _draw() -> void:
	if kind == "pit":
		draw_rect(Rect2(-w / 2.0, -2, w, 240), Color("#17111C"))
		draw_rect(Rect2(-w / 2.0, -2, 8, 240), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(w / 2.0 - 8, -2, 8, 240), Color(0, 0, 0, 0.35))
		return
	draw_set_transform(Vector2(0, -lift - h / 2.0), rot if flying else 0.0)
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	match kind:
		"wood":
			draw_rect(r, WOOD)
			draw_rect(r, WOOD.darkened(0.35), false, 3.0)
			for i in range(1, 4):
				var y := -h / 2.0 + h * i / 4.0
				draw_line(Vector2(-w / 2.0, y), Vector2(w / 2.0, y), WOOD.darkened(0.3), 2.0)
				draw_circle(Vector2(-w / 2.0 + 8, y - 14), 2.5, WOOD.darkened(0.5))
				draw_circle(Vector2(w / 2.0 - 8, y - 14), 2.5, WOOD.darkened(0.5))
		"box":
			draw_rect(r, WOOD.lightened(0.08))
			draw_rect(r, WOOD.darkened(0.35), false, 4.0)
			draw_line(r.position, r.end, WOOD.darkened(0.35), 4.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y),
					WOOD.darkened(0.35), 4.0)
		"slime":
			var squash := 1.0 + (0.0 if flying else sin(anim) * 0.06)
			draw_set_transform(Vector2(0, -lift - h / 2.0 + 4), rot if flying else 0.0,
					Vector2(1.0 / squash, 0.74 * squash))
			draw_circle(Vector2.ZERO, 27, SLIME)
			draw_circle(Vector2(-8, -10), 8, SLIME.lightened(0.35))
			if flying:
				for ex: float in [-9.0, 7.0]:
					draw_line(Vector2(ex - 4, -4), Vector2(ex + 4, 4), Color(0.1, 0.25, 0.1), 3.0)
					draw_line(Vector2(ex - 4, 4), Vector2(ex + 4, -4), Color(0.1, 0.25, 0.1), 3.0)
			else:
				draw_circle(Vector2(-11, 0), 4, Color(0.1, 0.25, 0.1))
				draw_circle(Vector2(5, 0), 4, Color(0.1, 0.25, 0.1))
		"steel":
			draw_rect(r, STEEL)
			draw_rect(Rect2(r.position, Vector2(10, h)), STEEL.lightened(0.25))
			draw_rect(r, STEEL.darkened(0.45), false, 4.0)
			for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_circle(Vector2(p.x * (w / 2.0 - 10), p.y * (h / 2.0 - 10)), 4, STEEL.darkened(0.5))
			# 자물쇠 아이콘
			draw_arc(Vector2(0, -8), 9, PI, TAU, 12, Color("#22303C"), 4.0)
			draw_rect(Rect2(-13, -8, 26, 22), Color("#22303C"))
			draw_circle(Vector2(0, 2), 3.5, Color("#DCE6EE"))
		"rock":
			draw_circle(Vector2.ZERO, 31, Color("#8C8478"))
			draw_circle(Vector2(-8, -9), 12, Color("#A39A8C"))
			for i in 8:
				var a0 := anim * 0.5 + i * TAU / 8.0
				draw_arc(Vector2.ZERO, 38, a0, a0 + 0.45, 6, Color("#FF9A3D"), 3.0)
		"wave":
			var c := Color("#A66BFF")
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w / 2.0, h / 2.0), Vector2(-w / 2.0 + 10, -h / 2.0),
				Vector2(-4, -h / 2.0 + 14), Vector2(w / 2.0 + 40, h / 2.0)]), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w / 2.0 + 8, h / 2.0), Vector2(-w / 2.0 + 14, -h / 2.0 + 14),
				Vector2(0, h / 2.0)]), c.lightened(0.45))
	draw_set_transform(Vector2.ZERO)
