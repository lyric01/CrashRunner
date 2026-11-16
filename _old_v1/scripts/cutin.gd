extends Node2D
# 4단 마무리 컷인 플레이스홀더. 나중에 실제 일러스트로 바꾸기 쉽게 씬으로 분리했어요.

var game
var title := ""
var desc := ""
var t := 0.0


func show_cutin(p_title: String, p_desc: String) -> void:
	title = p_title
	desc = p_desc
	t = 0.0
	visible = true
	queue_redraw()


func hide_cutin() -> void:
	visible = false


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func _draw() -> void:
	var slide := (1.0 - clampf(t / 0.12, 0.0, 1.0)) * 1300.0
	draw_set_transform(Vector2(640 + slide, 360), deg_to_rad(-5.0))
	draw_rect(Rect2(-900, -115, 1800, 230), Color(0.05, 0.06, 0.12, 0.93))
	draw_rect(Rect2(-900, -115, 1800, 7), ChibiDraw.BLUE)
	draw_rect(Rect2(-900, 108, 1800, 7), ChibiDraw.BLUE)
	var dash_col := Color(1, 1, 1, 0.7)
	for x: float in [-560.0, -350.0]:
		var r := Rect2(x, -85, 160, 170)
		ChibiDraw.dashed_rect(self, r, dash_col)
		ChibiDraw.text(self, r.get_center() + Vector2(0, -4), "[컷인", 18, dash_col, 1)
		ChibiDraw.text(self, r.get_center() + Vector2(0, 20), "일러스트]", 18, dash_col, 1)
	ChibiDraw.text(self, Vector2(-375, 12), "→", 30, dash_col, 1, true)
	ChibiDraw.text(self, Vector2(-130, 8), title, 64, ChibiDraw.GOLD, 0, true, 10)
	ChibiDraw.text(self, Vector2(-126, 56), desc, 22, Color.WHITE)
	if game != null and game.cutin_seen:
		ChibiDraw.text(self, Vector2(520, 96), "탭해서 넘기기", 14, Color(1, 1, 1, 0.6), 2)
	draw_set_transform(Vector2.ZERO)
