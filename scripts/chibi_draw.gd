class_name ChibiDraw
# 캐릭터·초상화 도형 그리기와 HUD 공용 그리기 도우미

const SKIN := Color(1.0, 0.89, 0.81)
const PANEL := Color(0.106, 0.122, 0.165, 0.8)
const GOLD := Color("#FFC23D")
const BLUE := Color("#3D7BFF")
const ORANGE := Color("#D4561A")

static var _bold: Font
static var _black: Font


static func font(black := false) -> Font:
	if _bold == null:
		_bold = load("res://fonts/NotoSansKR-Bold.tres")
		_black = load("res://fonts/NotoSansKR-Black.tres")
	return _black if black else _bold


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# pos는 글자 기준선. align: 0 왼쪽, 1 가운데, 2 오른쪽
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color := Color.WHITE,
		align := 0, black := false, outline := 0) -> void:
	var f := font(black)
	var p := pos
	if align != 0:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w * (0.5 if align == 1 else 1.0)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline,
				Color(0.05, 0.05, 0.1, 0.75 * color.a))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func panel(ci: CanvasItem, rect: Rect2, color: Color, radius := 10,
		border := Color.TRANSPARENT, bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	ci.draw_style_box(sb, rect)


static func bar(ci: CanvasItem, rect: Rect2, ratio: float, fg: Color,
		bg := Color(0, 0, 0, 0.5)) -> void:
	ci.draw_rect(rect, bg)
	var r := clampf(ratio, 0.0, 1.0)
	if r > 0.0:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fg)


static func circle_button(ci: CanvasItem, c: Vector2, r: float, col: Color, label: String,
		size: int, dim := false) -> void:
	ci.draw_circle(c, r, _a(col, 0.45 if dim else 0.85))
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
	text(ci, c + Vector2(0, size * 0.36), label, size, Color.WHITE, 1, true)


static func dashed_rect(ci: CanvasItem, r: Rect2, col: Color, width := 2.0, dash := 8.0) -> void:
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var c := r.end
	var d := Vector2(r.position.x, r.end.y)
	ci.draw_dashed_line(a, b, col, width, dash)
	ci.draw_dashed_line(b, c, col, width, dash)
	ci.draw_dashed_line(c, d, col, width, dash)
	ci.draw_dashed_line(d, a, col, width, dash)


# 길·보스 HUD 공용: 점프, 돌진, 일시정지 버튼
static func hud_buttons(ci: CanvasItem, dash_dim: bool) -> void:
	circle_button(ci, Config.JUMP_BTN, Config.JUMP_BTN_R, Color(0.2, 0.24, 0.33), "점프", 26)
	circle_button(ci, Config.ATTACK_BTN, Config.ATTACK_BTN_R, ORANGE, "공격", 34, dash_dim)
	ci.draw_circle(Config.PAUSE_BTN, Config.PAUSE_BTN_R, PANEL)
	ci.draw_rect(Rect2(Config.PAUSE_BTN + Vector2(-8, -9), Vector2(5, 18)), Color.WHITE)
	ci.draw_rect(Rect2(Config.PAUSE_BTN + Vector2(3, -9), Vector2(5, 18)), Color.WHITE)


# 머리(원점 = 머리 중심). 종족별 귀 포함
static func head(ci: CanvasItem, id: String, a := 1.0) -> void:
	var d: Dictionary = Characters.DATA[id]
	var ear: Color = _a(d["ear_color"], a)
	var hair: Color = _a(d["hair"], a)
	var inner := _a(Color(1.0, 0.72, 0.76), a)
	match d["ear"]:
		"round":
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(Vector2(17 * sx, -18), 10, ear)
				ci.draw_circle(Vector2(17 * sx, -18), 5, inner)
		"pointy":
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(23 * sx, -8), Vector2(18 * sx, -40), Vector2(4 * sx, -18)]), ear)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(18 * sx, -14), Vector2(16 * sx, -31), Vector2(9 * sx, -19)]), inner)
		"horn":
			var horn := _a(Color(0.97, 0.95, 0.86), a)
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(Vector2(25 * sx, -6), 7, ear)
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(20 * sx, -12), Vector2(31 * sx, -34), Vector2(9 * sx, -20)]), horn)
		"long":
			for sx: float in [-1.0, 1.0]:
				var base := Vector2(10 * sx, -14)
				var tip := Vector2(15 * sx, -46)
				ci.draw_line(base, tip, ear, 12.0)
				ci.draw_circle(tip, 6, ear)
				ci.draw_line(base + Vector2(0, -4), tip + Vector2(0, 4), inner, 4.0)
	ci.draw_circle(Vector2(0, -2), 23, hair)
	ci.draw_circle(Vector2(1, 3), 19, _a(SKIN, a))
	var eye := _a(Color(0.2, 0.16, 0.2), a)
	ci.draw_circle(Vector2(3, 3), 2.8, eye)
	ci.draw_circle(Vector2(13, 3), 2.8, eye)
	ci.draw_circle(Vector2(15, 10), 3.5, _a(Color(1.0, 0.6, 0.65, 0.6), a))


# 전신(원점 = 발). opts: alpha, phase(달리기), dash
static func chibi(ci: CanvasItem, id: String, feet: Vector2, s: float, opts := {}) -> void:
	var a: float = opts.get("alpha", 1.0)
	var ph: float = opts.get("phase", 0.0)
	var dash: bool = opts.get("dash", false)
	var d: Dictionary = Characters.DATA[id]
	var col: Color = _a(d["color"], a)
	var dark := _a(Color(0.25, 0.2, 0.25), a)
	var lean := 0.3 if dash else 0.1
	var sc := Vector2(s, s)

	ci.draw_set_transform(feet, 0.0, sc)
	var l1 := sin(ph) * 9.0
	var l2 := -l1
	if dash:
		l1 = -13.0
		l2 = 9.0
	ci.draw_rect(Rect2(-12 + l1, -16, 9, 16), dark)
	ci.draw_rect(Rect2(3 + l2, -16, 9, 16), dark)

	ci.draw_set_transform(feet, lean, sc)
	ci.draw_rect(Rect2(-17, -48, 34, 34), col)
	ci.draw_rect(Rect2(-17, -22, 34, 8), _a(col.darkened(0.2), 1.0))
	var paw_x := 36.0 if dash else 20.0 + sin(ph) * 4.0
	ci.draw_circle(Vector2(paw_x, -32), 11.0 if dash else 7.0, _a(d["ear_color"], a))

	var head_pos := feet + Vector2(sin(lean) * 66.0, -cos(lean) * 66.0) * s
	ci.draw_set_transform(head_pos, lean * 0.5, sc)
	head(ci, id, a)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func portrait(ci: CanvasItem, id: String, rect: Rect2, bg := Color(0.16, 0.18, 0.25),
		a := 1.0) -> void:
	panel(ci, rect, bg, 10)
	var s := rect.size.x / 80.0
	ci.draw_set_transform(rect.get_center() + Vector2(-2, 12) * s, 0.0, Vector2(s, s))
	head(ci, id, a)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
