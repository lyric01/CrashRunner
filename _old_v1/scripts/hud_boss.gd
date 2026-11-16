extends Node2D
# 보스전 HUD: 시간·속도, 보스 HP·그로기, 패턴 경고, 파티 바(초상화 탭 교체), 연계 창

const HudRoad := preload("res://scripts/hud_road.gd")

var game
var pulse := 0.0


func portrait_rect(i: int) -> Rect2:
	return Rect2(412.0 + i * 118.0, 610.0, 92.0, 92.0)


func _draw() -> void:
	if game == null:
		return
	pulse += 0.2
	var boss = game.boss
	var party = game.party
	var chain = game.chain
	var glow_a := 0.65 + 0.35 * sin(pulse)

	# 왼쪽 위: 남은 시간, 달리기 속도
	ChibiDraw.panel(self, Rect2(16, 14, 210, 92), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(30, 36), "남은 시간", 14, Color(1, 1, 1, 0.75))
	ChibiDraw.text(self, Vector2(30, 76), "%d초" % int(ceil(game.boss_time_left)), 38,
			Color.WHITE if game.boss_time_left > 10.0 else Color("#FF6A6A"), 0, true)
	ChibiDraw.text(self, Vector2(30, 98), "달리기 속도 %d%%" % game.speed_percent(), 15,
			ChibiDraw.GOLD if chain.active else Color(1, 1, 1, 0.85))

	# 가운데 위: 보스 이름, HP, 그로기 5칸
	ChibiDraw.panel(self, Rect2(380, 10, 520, 86), ChibiDraw.PANEL)
	ChibiDraw.text(self, Vector2(640, 34), boss.NAME, 20, Color.WHITE, 1, true)
	ChibiDraw.bar(self, Rect2(400, 42, 480, 20), boss.hp / Config.BOSS_HP, Color("#E0383E"))
	ChibiDraw.text(self, Vector2(874, 58), "%d" % int(ceil(boss.hp)), 14, Color.WHITE, 2)
	ChibiDraw.text(self, Vector2(400, 84), "그로기", 14, ChibiDraw.GOLD)
	for i in Config.GROGGY_MAX:
		var r := Rect2(462.0 + i * 84.0, 72.0, 78.0, 13.0)
		draw_rect(r, Color(0, 0, 0, 0.5))
		if i < boss.groggy:
			draw_rect(r, ChibiDraw.GOLD)

	HudRoad.draw_combo(self, game.combo, game.combo_pop)

	# 보스 위: 패턴 경고 배너
	if boss.pattern != "":
		var info: Dictionary = boss.PATTERNS[boss.pattern]
		var br := Rect2(770, 262, 430, 56)
		ChibiDraw.panel(self, br, ChibiDraw.GOLD, 10, Color("#2B2442"), 3)
		var tx := br.position.x + 18.0
		if info.rec != "":
			ChibiDraw.portrait(self, info.rec, Rect2(br.position.x + 8, br.position.y + 6, 44, 44))
			tx += 44.0
		ChibiDraw.text(self, Vector2(tx, br.position.y + 36), info.warn, 18, Color("#2B2442"), 0, true)

	ChibiDraw.hud_buttons(self, game.player.dash_cd > 0.0 and not chain.active)

	# 연계 창 / 미니 연계 창
	if chain.active and chain.phase == "window":
		var st: Dictionary = chain.STEPS[chain.step]
		var p: float = chain.win_t / Config.COMBO_WINDOW
		ChibiDraw.text(self, Vector2(640, 552), "%d단 · %s → %s!" % [
			chain.step + 1, st.state_name, Characters.name_of(st.id)], 26, ChibiDraw.GOLD, 1, true, 8)
		var bx := 440.0
		var bw := 400.0
		draw_rect(Rect2(bx, 564, bw, 16), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(bx + bw * (0.5 - Config.PERFECT_RATIO / 2.0), 564,
				bw * Config.PERFECT_RATIO, 16), Color(1.0, 0.76, 0.24, 0.9))
		draw_rect(Rect2(bx + bw * p - 3.0, 558, 6, 28), Color.WHITE)
	elif party.mini_t > 0.0:
		ChibiDraw.text(self, Vector2(640, 552), "추가타! → %s" % Characters.name_of(party.mini_target),
				26, ChibiDraw.GOLD, 1, true, 8)
		ChibiDraw.bar(self, Rect2(440, 564, 400, 12), party.mini_t / Config.MINI_COMBO_WINDOW,
				ChibiDraw.GOLD, Color(0, 0, 0, 0.65))

	# 아래: 파티 바
	ChibiDraw.panel(self, Rect2(396, 592, 488, 126), ChibiDraw.PANEL, 12)
	for i in 4:
		var id: String = Characters.ORDER[i]
		var r := portrait_rect(i)
		var is_active: bool = id == party.active
		var badge := ""
		if chain.active:
			if chain.phase == "window" and chain.STEPS[chain.step].id == id:
				badge = "지금!"
		elif party.mini_t > 0.0 and id == party.mini_target:
			badge = "추가타!"
		elif boss.pattern != "" and boss.PATTERNS[boss.pattern].rec == id and not is_active:
			badge = "추천"

		ChibiDraw.portrait(self, id, r)
		var free_swap := badge == "지금!" or badge == "추가타!"
		if not is_active and not free_swap and not chain.active and not party.can_swap(id):
			ChibiDraw.panel(self, r, Color(0, 0, 0, 0.55), 10)
		if badge != "":
			ChibiDraw.panel(self, r.grow(4), Color.TRANSPARENT, 12,
					Color(1.0, 0.76, 0.24, glow_a), 6)
			ChibiDraw.panel(self, Rect2(r.position.x + 14, r.position.y - 14, 64, 22), ChibiDraw.GOLD, 6)
			ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 3), badge, 14,
					Color("#2B2442"), 1, true)
		elif is_active:
			ChibiDraw.panel(self, r, Color.TRANSPARENT, 10, ChibiDraw.BLUE, 4)
			ChibiDraw.panel(self, Rect2(r.position.x + 14, r.position.y - 14, 64, 22), ChibiDraw.BLUE, 6)
			ChibiDraw.text(self, Vector2(r.get_center().x, r.position.y + 3), "출전 중", 13,
					Color.WHITE, 1)
		else:
			ChibiDraw.panel(self, r, Color.TRANSPARENT, 10, Color(1, 1, 1, 0.25), 2)

		ChibiDraw.text(self, r.position + Vector2(7, 20), str(i + 1), 14, Color(1, 1, 1, 0.8))
		if not is_active:
			var g: float = party.gauge[id]
			ChibiDraw.bar(self, Rect2(r.position.x + 6, r.end.y - 13, r.size.x - 12, 7), g / 100.0,
					ChibiDraw.GOLD if g >= Config.SWAP_COST else Color("#7FA8FF"))
			if party.cooldown[id] > 0.0 and not free_swap:
				ChibiDraw.text(self, r.get_center() + Vector2(0, 14), "%.1f" % party.cooldown[id], 34,
						Color.WHITE, 1, true, 8)
	ChibiDraw.text(self, Vector2(640, 715), "초상화를 탭해서 교체 (1~4)", 12, Color(1, 1, 1, 0.65), 1)

	# 중간 단계 교체: 화면 구석에 초상화가 슬쩍 들어와요.
	if party.flash_t > 0.0:
		var k := clampf((0.45 - party.flash_t) / 0.1, 0.0, 1.0) * clampf(party.flash_t / 0.1, 0.0, 1.0)
		var fr := Rect2(-120.0 + 140.0 * k, 400, 110, 110)
		ChibiDraw.portrait(self, party.flash_id, fr)
		ChibiDraw.panel(self, fr, Color.TRANSPARENT, 10, Characters.DATA[party.flash_id]["color"], 4)
