extends Node2D
# 결과 화면: 다시 하기, 캐릭터 변경

const TITLES := {
	"clear": ["완주!", Color("#FFC23D")],      # 자동 플레이 검증에서만 나와요
	"fail": ["실패", Color("#FF6A6A")],
	"elite": ["강적을 막지 못했어요", Color("#FF6A6A")],
	"timeout": ["시간 초과", Color("#B8C4CF")],
}

var game
var data := {}


func _ready() -> void:
	visible = false


# 0 = 다시 하기, 1 = 파티 변경
func button_rect(i: int) -> Rect2:
	return Rect2(410 + i * 240, 530, 220, 62)


func show_result(d: Dictionary) -> void:
	data = d
	visible = true
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	ChibiDraw.panel(self, Rect2(370, 90, 540, 530), Color(0.106, 0.122, 0.165, 0.96), 16,
			Color(1, 1, 1, 0.2), 2)
	var ti: Array = TITLES[data.reason]
	ChibiDraw.text(self, Vector2(640, 168), ti[0], 56, ti[1], 1, true)
	var rows := [
		["거리", "%dm" % data.distance],
		["점수", "%d" % data.score],
		["최대 콤보", "%d" % data.max_combo],
		["처치", "%d" % data.kills],
		["강적 격파", "%d마리" % data.get("elites", 0)],
		["최대 저글", "x%d" % data.max_juggle],
	]
	if data.has("stage"):
		rows.insert(0, ["도달 스테이지", "%d" % data.stage])
	var step := 48.0 if rows.size() <= 6 else 41.0
	for i in rows.size():
		var y := 232.0 + i * step
		ChibiDraw.text(self, Vector2(430, y), rows[i][0], 24, Color(1, 1, 1, 0.75))
		ChibiDraw.text(self, Vector2(850, y), rows[i][1], 28, Color.WHITE, 2, true)
		draw_line(Vector2(430, y + 14), Vector2(850, y + 14), Color(1, 1, 1, 0.12), 1.0)
	var labels := ["다시 하기 (R)", "캐릭터 변경 (T)"]
	for i in 2:
		var b := button_rect(i)
		ChibiDraw.panel(self, b, ChibiDraw.ORANGE if i == 0 else Color(0.25, 0.3, 0.42), 14)
		ChibiDraw.text(self, b.get_center() + Vector2(0, 9), labels[i], 24, Color.WHITE, 1, true)
