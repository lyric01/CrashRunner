extends Node2D
# 배경 패럴랙스(먼 산, 가까운 언덕, 지면). 길 팔레트와 보스 팔레트를 boss_mix로 섞어요.

var off_far := 0.0
var off_mid := 0.0
var off_ground := 0.0
var boss_mix := 0.0
var to_boss := false


func update(dt: float, rdt: float, scroll: float) -> void:
	off_far += scroll * 0.12 * dt
	off_mid += scroll * 0.35 * dt
	off_ground += scroll * dt
	boss_mix = move_toward(boss_mix, 1.0 if to_boss else 0.0, rdt * 1.5)
	queue_redraw()


func _draw() -> void:
	var m := boss_mix
	var gy := Config.GROUND_Y
	var sky := Color("#CFE6F5").lerp(Color("#2B2442"), m)
	var far := Color("#A8C8DE").lerp(Color("#3B3358"), m)
	var mid := Color("#8FBF8C").lerp(Color("#463D66"), m)
	var ground := Color("#6E5240").lerp(Color("#3A2E40"), m)
	var grass := Color("#7DB36A").lerp(Color("#57476A"), m)
	draw_rect(Rect2(-60, -60, 1400, 840), sky)

	# 먼 산 (보스전에서는 폐허 기둥이 겹쳐요)
	var period := 420.0
	var base := int(floor(off_far / period))
	for k in range(-1, 5):
		var x := k * period - fposmod(off_far, period)
		var peak := 300.0 + 60.0 * sin((base + k) * 1.7)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, gy + 2), Vector2(x + 210, peak), Vector2(x + 420, gy + 2)]), far)
		if m > 0.01:
			var c := Color("#3B3358").darkened(0.15)
			c.a = m
			var hgt := 190.0 + 50.0 * sin((base + k) * 2.3)
			draw_rect(Rect2(x + 60, gy - hgt, 46, hgt), c)
			draw_rect(Rect2(x + 50, gy - hgt, 66, 14), c)
			draw_rect(Rect2(x + 250, gy - hgt * 0.6, 40, hgt * 0.6), c)

	# 가까운 언덕
	var pts := PackedVector2Array()
	var x2 := -60.0
	while x2 <= 1340.0:
		var wx := x2 + off_mid
		pts.append(Vector2(x2, 492.0 + 30.0 * sin(wx * 0.008) + 14.0 * sin(wx * 0.021)))
		x2 += 40.0
	pts.append(Vector2(1340, gy + 2))
	pts.append(Vector2(-60, gy + 2))
	draw_colored_polygon(pts, mid)

	# 지면
	draw_rect(Rect2(-60, gy, 1400, 240), ground)
	draw_rect(Rect2(-60, gy, 1400, 14), grass)
	var stripe := ground.darkened(0.18)
	var gp := 170.0
	for k in range(-1, 10):
		var x := k * gp - fposmod(off_ground, gp)
		draw_rect(Rect2(x, gy + 34, 64, 8), stripe)
		draw_rect(Rect2(x + 90, gy + 84, 44, 8), stripe)
		draw_rect(Rect2(x + 30, gy + 128, 70, 8), stripe)
