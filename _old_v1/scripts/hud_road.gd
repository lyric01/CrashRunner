extends Node2D
# 길 구간 HUD: 거리·점수, 보스까지 진행 바, 콤보, 버튼, 파티 패널

var game


static func draw_combo(ci: CanvasItem, combo: int, pop: float) -> void:
	if combo <= 0:
		return
	var size := int(56 * (1.0 + pop * 0.35))
	ChibiDraw.text(ci, Vector2(1190, 74), str(combo), size, Color("#FF8A2A"), 2, true, 8)
	ChibiDraw.text(ci, Vector2(1190, 100), "COMBO", 18, Color("#FF8A2A"), 2, true, 6)


func _draw() -> void:
	if game == null:
		return
	# 왼쪽 위: 거리, 점수
	ChibiDraw.panel(self, Rect2(16, 14, 210, 92), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(30, 62), "%dm" % int(game.distance / Config.PX_PER_METER), 42,
			Color.WHITE, 0, true)
	ChibiDraw.text(self, Vector2(30, 92), "점수 %d" % int(game.score), 18, Color(1, 1, 1, 0.85))

	# 가운데 위: 보스까지 진행 바
	var p: float = game.road_progress()
	ChibiDraw.panel(self, Rect2(410, 14, 500, 58), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(426, 36), "보스까지 %d%%" % int(p * 100.0), 16)
	ChibiDraw.bar(self, Rect2(426, 46, 410, 14), p, Color("#FFB03D"))
	ChibiDraw.panel(self, Rect2(842, 38, 58, 26), Color("#D8343A"), 6)
	ChibiDraw.text(self, Vector2(871, 57), "BOSS", 15, Color.WHITE, 1, true)

	draw_combo(self, game.combo, game.combo_pop)
	ChibiDraw.hud_buttons(self, game.player.dash_cd > 0.0)

	# 가운데 아래: 파티 패널
	var party = game.party
	ChibiDraw.panel(self, Rect2(372, 610, 536, 100), ChibiDraw.PANEL, 12)
	var ar := Rect2(384, 620, 80, 80)
	ChibiDraw.portrait(self, party.active, ar)
	ChibiDraw.panel(self, ar, Color.TRANSPARENT, 10, Color("#FF8A2A"), 4)
	ChibiDraw.panel(self, Rect2(380, 612, 50, 20), Color("#FF8A2A"), 6)
	ChibiDraw.text(self, Vector2(405, 627), "에이스", 13, Color.WHITE, 1)
	ChibiDraw.text(self, Vector2(476, 646), "%s · 체력 %d/%d" % [
		Characters.name_of(party.active), game.hp, Config.PARTY_HP], 16)
	ChibiDraw.bar(self, Rect2(476, 658, 150, 16), float(game.hp) / Config.PARTY_HP, Color("#5BD66B"))
	ChibiDraw.text(self, Vector2(476, 696), "부술수록 교체 게이지 충전", 12, Color(1, 1, 1, 0.6))

	var list: Array = party.standby()
	for i in list.size():
		var id: String = list[i]
		var x := 652.0 + i * 84.0
		var g: float = party.gauge[id]
		ChibiDraw.portrait(self, id, Rect2(x, 618, 56, 56))
		ChibiDraw.bar(self, Rect2(x, 679, 56, 8), g / 100.0,
				ChibiDraw.GOLD if g >= Config.SWAP_COST else Color("#7FA8FF"))
		ChibiDraw.text(self, Vector2(x + 28, 704), "%d%%" % int(g), 13, Color.WHITE, 1)
