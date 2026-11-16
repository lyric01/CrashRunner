extends Node2D
# 화면 흔들림, 파편, 충격 별, 떠오르는 글자, 속도선

var frags: Array = []
var stars: Array = []
var texts: Array = []
var lines: Array = []
var shake_t := 0.0
var shake_dur := 0.0
var shake_str := 0.0
var _line_acc := 0.0


func shake(strength: float, dur: float) -> void:
	if shake_t <= 0.0 or strength >= shake_str:
		shake_str = strength
		shake_dur = dur
		shake_t = dur


func shake_offset() -> Vector2:
	if shake_t <= 0.0:
		return Vector2.ZERO
	var k := shake_str * shake_t / shake_dur
	return Vector2(randf_range(-k, k), randf_range(-k, k))


func burst(pos: Vector2, color: Color, count := 8, power := 1.0) -> void:
	for i in count:
		frags.append({
			"pos": pos + Vector2(randf_range(-14, 14), randf_range(-20, 20)),
			"vel": Vector2(randf_range(-160, 520), randf_range(-620, -120)) * power,
			"rot": randf() * TAU, "vr": randf_range(-14, 14),
			"size": randf_range(7, 16), "color": color.darkened(randf() * 0.25), "life": 0.9,
		})


func star(pos: Vector2, scale := 1.0) -> void:
	stars.append({"pos": pos, "t": 0.0, "scale": scale})


func text(pos: Vector2, s: String, color := Color.WHITE, size := 28, life := 0.8) -> void:
	texts.append({"pos": pos, "s": s, "color": color, "size": size, "t": 0.0, "life": life})


func update(dt: float, rdt: float, scroll: float) -> void:
	shake_t -= rdt
	for f: Dictionary in frags:
		f.vel.y += Config.GRAVITY * 0.8 * dt
		f.pos += (f.vel - Vector2(scroll * 0.5, 0)) * dt
		f.rot += f.vr * dt
		f.life -= dt
	frags = frags.filter(func(f: Dictionary) -> bool: return f.life > 0.0)
	for s: Dictionary in stars:
		s.t += rdt
	stars = stars.filter(func(s: Dictionary) -> bool: return s.t < 0.15)
	for t: Dictionary in texts:
		t.t += rdt
		t.pos.y -= 60.0 * rdt
	texts = texts.filter(func(t: Dictionary) -> bool: return t.t < t.life)

	# 속도선: 속도에 비례해 개수 증가
	_line_acc += dt * 16.0 * scroll / Config.ROAD_SCROLL_SPEED
	while _line_acc >= 1.0:
		_line_acc -= 1.0
		lines.append({"x": 1320.0, "y": randf_range(70, 530), "len": randf_range(60, 150)})
	for l: Dictionary in lines:
		l.x -= scroll * 2.4 * dt
	lines = lines.filter(func(l: Dictionary) -> bool: return l.x + l.len > -20.0)
	queue_redraw()


func _draw() -> void:
	for l: Dictionary in lines:
		draw_line(Vector2(l.x, l.y), Vector2(l.x + l.len, l.y), Color(1, 1, 1, 0.38), 2.0)
	for f: Dictionary in frags:
		draw_set_transform(f.pos, f.rot)
		var c: Color = f.color
		c.a = clampf(f.life * 2.5, 0.0, 1.0)
		draw_rect(Rect2(-f.size / 2.0, -f.size / 2.0, f.size, f.size), c)
	for s: Dictionary in stars:
		var k: float = (0.6 + s.t / 0.15 * 0.9) * s.scale
		var pts := PackedVector2Array()
		for i in 10:
			var r := (34.0 if i % 2 == 0 else 13.0) * k
			pts.append(Vector2.from_angle(i * TAU / 10.0 - PI / 2.0) * r)
		draw_set_transform(s.pos, s.t * 6.0)
		draw_colored_polygon(pts, Color(1.0, 0.92, 0.3, 1.0 - s.t / 0.15 * 0.5))
	draw_set_transform(Vector2.ZERO)
	for t: Dictionary in texts:
		var c: Color = t.color
		c.a = clampf((t.life - t.t) / 0.25, 0.0, 1.0)
		var pop := 1.0 + maxf(0.0, 0.12 - t.t) * 3.0
		ChibiDraw.text(self, t.pos, t.s, int(t.size * pop), c, 1, true, 8)
