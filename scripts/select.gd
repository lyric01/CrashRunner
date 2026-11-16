extends Node2D
# 파티 편성: 4명 중 3명을 고르는 화면. 고른 순서가 줄 서는 순서(1번 = 선두)예요.

var game
var picks: Array = []


func _ready() -> void:
	visible = false


func open(initial: Array) -> void:
	picks = initial.slice(0, game.party_size())
	visible = true
	queue_redraw()


func card_rect(i: int) -> Rect2:
	return Rect2(95 + i * 280, 170, 250, 350)


func mode_rect() -> Rect2:
	return Rect2(960, 40, 280, 56)


func start_rect() -> Rect2:
	return Rect2(490, 570, 300, 70)


func toggle(i: int) -> void:
	var id: String = Characters.ORDER[i]
	if picks.has(id):
		picks.erase(id)
	elif picks.size() < game.party_size():
		picks.append(id)
	queue_redraw()


func confirm() -> void:
	if picks.size() == game.party_size():
		game.start_stage(picks)


func on_tap(p: Vector2) -> void:
	if start_rect().has_point(p):
		confirm()
		return
	if mode_rect().has_point(p):
		game.switch_mode()
		return
	for i in Characters.ORDER.size():
		if card_rect(i).has_point(p):
			toggle(i)


func on_key(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		confirm()
		return
	if event.is_action_pressed("mode"):
		game.switch_mode()
		return
	for i in 4:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			toggle(i)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.08, 0.12, 0.93))
	ChibiDraw.text(self, Vector2(640, 86), "파티 편성", 52, Color.WHITE, 1, true)
	var mr := mode_rect()
	ChibiDraw.panel(self, mr, Color(0.2, 0.26, 0.4), 12, Color(1, 1, 1, 0.3), 2)
	ChibiDraw.text(self, mr.get_center() + Vector2(0, -2), game.mode_name(), 22, ChibiDraw.GOLD, 1, true)
	ChibiDraw.text(self, mr.get_center() + Vector2(0, 20), "눌러서 모드 바꾸기 (M)", 13, Color(1, 1, 1, 0.7), 1)
	var sub_title := "3명을 고르세요. 1번이 조종하는 선두이고, 2·3번이 연계기로 뛰어나와요."
	if game.mode() == "juggle":
		sub_title = "캐릭터 1명을 고르세요. 몬스터를 뭉쳐서 강적에게 쳐 보내고, 튕겨 오는 걸 받아쳐요."
	ChibiDraw.text(self, Vector2(640, 130), sub_title, 20,
			Color(1, 1, 1, 0.75), 1)
	for i in Characters.ORDER.size():
		var id: String = Characters.ORDER[i]
		var d: Dictionary = Characters.DATA[id]
		var r := card_rect(i)
		var order := picks.find(id)
		var on := order >= 0
		ChibiDraw.panel(self, r, Color(0.16, 0.18, 0.25) if on else Color(0.11, 0.12, 0.17), 14,
				ChibiDraw.GOLD if on else Color(1, 1, 1, 0.15), 4 if on else 2)
		ChibiDraw.chibi(self, id, Vector2(r.get_center().x - 6, r.position.y + 200), 1.7,
				{"alpha": 1.0 if on else 0.45})
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 250), d["name"], 32, Color.WHITE, 1, true)
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 286), d["desc"], 18,
				Color(1, 1, 1, 0.85), 1)
		ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 314), Characters.rally_of(id)["desc"] if game.mode() == "juggle" else d["desc2"], 16,
				Color(1, 1, 1, 0.6), 1)
		ChibiDraw.text(self, r.end + Vector2(-14, -10), "[%d]" % (i + 1), 14, Color(1, 1, 1, 0.4), 2)
		if on:
			var label := "1번 · 선두" if order == 0 else "%d번" % (order + 1)
			ChibiDraw.panel(self, Rect2(r.position + Vector2(10, 10), Vector2(96, 30)), ChibiDraw.GOLD, 8)
			ChibiDraw.text(self, r.position + Vector2(58, 32), label, 17, Color(0.15, 0.1, 0.0), 1, true)
	var ready: bool = picks.size() == game.party_size()
	var b := start_rect()
	ChibiDraw.panel(self, b, ChibiDraw.ORANGE if ready else Color(0.25, 0.26, 0.3), 14)
	ChibiDraw.text(self, b.get_center() + Vector2(0, 11),
			"출발 (Enter)" if ready else "%d명 더 고르기" % (game.party_size() - picks.size()), 28,
			Color.WHITE if ready else Color(1, 1, 1, 0.5), 1, true)
	var hint := "조작: 공격·연계기 D / J / →  (그로기일 때 누르면 연계기)   점프 Space / W / ↑"
	if game.mode() == "juggle":
		hint = "조작: 공격 D / J / →   점프 Space / W / ↑   (튕겨 온 뭉치는 땅에 닿기 전에 치면 퍼펙트)"
	ChibiDraw.text(self, Vector2(640, 680), hint, 16,
			Color(1, 1, 1, 0.55), 1)
