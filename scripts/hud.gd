extends Node2D
# HUD: 거리·점수, 스테이지 진행 바, 콤보, 캐릭터와 체력, 버튼.
# 강적전 표시(겨냥, 약점, 열기 등)는 game.draw_hud_extra가 이 위에 그려요.

var game
var pulse := 0.0


func _process(delta: float) -> void:
	pulse += delta


func _draw() -> void:
	if game == null or game.party.members.is_empty():
		return
	# 왼쪽 위: 거리, 점수
	ChibiDraw.panel(self, Rect2(16, 14, 210, 92), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(30, 62), "%dm" % int(game.distance / Config.PX_PER_METER), 42,
			Color.WHITE, 0, true)
	ChibiDraw.text(self, Vector2(30, 92), "점수 %d" % int(game.score), 18, Color(1, 1, 1, 0.85))

	# 가운데 위: 스테이지 진행
	var p: float = game.road_progress()
	ChibiDraw.panel(self, Rect2(410, 14, 460, 58), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(426, 36), "스테이지 %d · 진행 %d%%" % [game.stage, int(p * 100.0)], 16)
	ChibiDraw.bar(self, Rect2(426, 46, 428, 14), p, Color("#FFB03D"))

	# 콤보, 저글
	if game.combo > 0:
		var size := int(56 * (1.0 + game.combo_pop * 0.35))
		ChibiDraw.text(self, Vector2(1190, 150), str(game.combo), size, Color("#FF8A2A"), 2, true, 8)
		ChibiDraw.text(self, Vector2(1190, 176), "COMBO", 18, Color("#FF8A2A"), 2, true, 6)
	if game.juggle_run >= 1:
		ChibiDraw.text(self, Vector2(1190, 216), "저글 x%d" % game.juggle_run, 26, ChibiDraw.GOLD, 2, true, 6)

	ChibiDraw.hud_buttons(self, game.player.atk_cd > 0.0)

	# 가운데 아래: 캐릭터와 체력
	var id: String = game.party.lead()
	ChibiDraw.panel(self, Rect2(410, 618, 460, 92), ChibiDraw.PANEL, 12)
	var r := Rect2(424, 630, 68, 68)
	ChibiDraw.portrait(self, id, r)
	ChibiDraw.panel(self, r, Color.TRANSPARENT, 10, Color("#FF8A2A"), 4)
	ChibiDraw.text(self, Vector2(510, 654), Characters.name_of(id), 18, Color.WHITE, 0, true)
	ChibiDraw.text(self, Vector2(668, 654), "체력 %d/%d" % [game.hp, Config.PARTY_HP], 16)
	ChibiDraw.bar(self, Rect2(668, 664, 186, 16), float(game.hp) / Config.PARTY_HP, Color("#5BD66B"))

	if game.has_method("draw_hud_extra"):
		game.draw_hud_extra(self, pulse)
