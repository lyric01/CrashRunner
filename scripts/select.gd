extends Node2D
# 캐릭터 선택: 4명 중 조종할 1명을 고르는 화면.

var game
var picks: Array = []


func _ready() -> void:
	visible = false


func open(initial: Array) -> void:
	picks = initial.slice(0, 1)
	visible = true
	queue_redraw()


func card_rect(i: int) -> Rect2:
	return Rect2(95 + i * 280, 170, 250, 350)


func start_rect() -> Rect2:
	return Rect2(490, 570, 300, 70)


# 한 명만 고르니까, 다른 카드를 누르면 선택이 그쪽으로 옮겨 가요.
func toggle(i: int) -> void:
	picks = [Characters.ORDER[i]]
	queue_redraw()


func confirm() -> void:
	if picks.size() == 1:
		game.start_stage(picks)


func on_tap(p: Vector2) -> void:
	if start_rect().has_point(p):
		confirm()
		return
	for i in Characters.ORDER.size():
		if card_rect(i).has_point(p):
			toggle(i)


func on_key(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		confirm()
		return
	for i in 4:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			toggle(i)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12, 0.93))
	ChibiDraw.text(self, Vector2(640, 86), "캐릭터 선택", 52, Color.WHITE, 1, true)
	ChibiDraw.text(self, Vector2(640, 130), "몬스터를 쳐서 뭉치고, 강적이 오면 약점으로 쳐 보내세요.", 20,
			Color(1, 1, 1, 0.75), 1)
	for i in Characters.ORDER.size():
		var id: String = Characters.ORDER[i]
		var d: Dictionary = Characters.DATA[id]
		var rally: Dictionary = Characters.rally_of(id)
		var r := card_rect(i)
		var on := picks.has(id)
		ChibiDraw.panel(self, r, Color(0.16, 0.18, 0.25) if on else Color(0.11, 0.12, 0.17), 14,
				ChibiDraw.GOLD if on else Color(1, 1, 1, 0.15), 4 if on else 2)
		ChibiDraw.chibi(self, id, Vector2(r.get_center().x - 6, r.position.y + 200), 1.7,
				{"alpha": 1.0 if on else 0.45})
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 250), d["name"], 32, Color.WHITE, 1, true)
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 286), rally["name"], 18,
				Color(1, 1, 1, 0.85), 1)
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 314), d["desc"], 16,
				Color(1, 1, 1, 0.6), 1)
		ChibiDraw.text(self, r.end + Vector2(-14, -10), "[%d]" % (i + 1), 14, Color(1, 1, 1, 0.4), 2)
		if on:
			ChibiDraw.panel(self, Rect2(r.position + Vector2(10, 10), Vector2(70, 30)), ChibiDraw.GOLD, 8)
			ChibiDraw.text(self, r.position + Vector2(45, 32), "선택", 17, Color(0.15, 0.1, 0.0), 1, true)
	var b := start_rect()
	ChibiDraw.panel(self, b, ChibiDraw.ORANGE, 14)
	ChibiDraw.text(self, b.get_center() + Vector2(0, 11), "출발 (Enter)", 28, Color.WHITE, 1, true)
	ChibiDraw.text(self, Vector2(640, 680),
			"조작: 공격 D / J / →   점프 Space / W / ↑   (뛰어오르며 치면 위, 떨어지며 치면 아래로 보내요)", 16,
			Color(1, 1, 1, 0.55), 1)
