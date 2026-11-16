extends Node2D
# HUD: 거리·점수, 진행 바, 콤보, 파티, 버튼.
# 그로기 몬스터가 있고 준비된 파티원이 있으면 공격 버튼이 연계기 버튼으로 바뀌어요.

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

	# 가운데 위: 진행
	var p: float = game.road_progress()
	ChibiDraw.panel(self, Rect2(410, 14, 460, 58), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(426, 36), ("스테이지 %d · " % game.stage if game.mode() == "juggle" else "") + "진행 %d%%" % int(p * 100.0), 16)
	ChibiDraw.bar(self, Rect2(426, 46, 428, 14), p, Color("#FFB03D"))

	# 콤보, 연쇄
	if game.combo > 0:
		var size := int(56 * (1.0 + game.combo_pop * 0.35))
		ChibiDraw.text(self, Vector2(1190, 150), str(game.combo), size, Color("#FF8A2A"), 2, true, 8)
		ChibiDraw.text(self, Vector2(1190, 176), "COMBO", 18, Color("#FF8A2A"), 2, true, 6)
	if game.chain_run >= 1:
		ChibiDraw.text(self, Vector2(1190, 216), "%s x%d" % [game.run_label, game.chain_run], 26, ChibiDraw.GOLD, 2, true, 6)

	ChibiDraw.hud_buttons(self, game.player.atk_cd > 0.0)

	# 가운데 아래: 파티(왼쪽부터 선두 순서)와 체력
	var party = game.party
	var members: Array = party.members
	ChibiDraw.panel(self, Rect2(410, 618, 460, 92), ChibiDraw.PANEL, 12)
	for i in members.size():
		var id: String = members[i]
		var r := Rect2(424 + i * 78, 630, 68, 68)
		ChibiDraw.portrait(self, id, r)
		if i == 0:
			ChibiDraw.panel(self, r, Color.TRANSPARENT, 10, Color("#FF8A2A"), 4)
			ChibiDraw.panel(self, Rect2(r.position + Vector2(-4, -8), Vector2(40, 18)), Color("#FF8A2A"), 6)
			ChibiDraw.text(self, r.position + Vector2(16, 6), "선두", 12, Color.WHITE, 1)
		else:
			# 연계기 재사용 대기
			var c: float = party.cd[id] / Config.CHAIN_COOLDOWN
			if c > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * c)), Color(0, 0, 0, 0.6))
			elif game.chain_ready() and id == game.chain_id:
				ChibiDraw.panel(self, r, Color.TRANSPARENT, 10, ChibiDraw.GOLD, 4)
	ChibiDraw.text(self, Vector2(668, 654), "체력 %d/%d" % [game.hp, Config.PARTY_HP], 16)
	ChibiDraw.bar(self, Rect2(668, 664, 186, 16), float(game.hp) / Config.PARTY_HP, Color("#5BD66B"))
	ChibiDraw.text(self, Vector2(668, 700), "선두: %s" % Characters.name_of(members[0]), 13,
			Color(1, 1, 1, 0.7))

	if game.chain_ready():
		_draw_chain_button()
	if game.has_method("draw_hud_extra"):
		game.draw_hud_extra(self, pulse)


func _draw_chain_button() -> void:
	var c := Config.ATTACK_BTN
	var r := Config.ATTACK_BTN_R
	var id: String = game.chain_id
	var data: Dictionary = Characters.DATA[id]
	var glow := 0.5 + 0.5 * sin(pulse * 14.0)
	draw_circle(c, r + 10.0 + glow * 6.0, Color(1.0, 0.76, 0.24, 0.25 + glow * 0.2))
	draw_circle(c, r, Color(0.12, 0.1, 0.05, 0.92))
	ChibiDraw.portrait(self, id, Rect2(c - Vector2(34, 34), Vector2(68, 68)), Color(0, 0, 0, 0))
	draw_arc(c, r, 0.0, TAU, 48, ChibiDraw.GOLD, 6.0)
	# 그로기 남은 시간(테두리가 줄어듦)
	var left: float = clampf(game.chain_target.groggy_t / Config.GROGGY_TIME, 0.0, 1.0)
	draw_arc(c, r + 9.0, -PI / 2.0, -PI / 2.0 + TAU * left, 48, Color.WHITE, 4.0)
	ChibiDraw.text(self, c + Vector2(0, -r - 40), "연계기!", 30, ChibiDraw.GOLD, 1, true, 8)
	ChibiDraw.text(self, c + Vector2(0, -r - 16), "%s · %s" % [data["name"], data["move"]], 16,
			Color.WHITE, 1, false, 6)
