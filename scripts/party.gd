extends Node2D
# 파티 3명(0번 = 선두)과 꼬리물기. 뒤따르는 두 명을 여기서 그려요.
# 뒤 두 명은 연계기를 가진 파티원이고, 발동하면 뛰어나가 치고 제자리로 돌아와요.

const STRIKE_TIME := 0.34

var game
var members: Array = []
var xpos := {}             # id -> 화면 x
var cd := {}               # id -> 연계기 재사용 남은 시간
var strike_t := {}         # id -> 연계기 타격 연출 남은 시간
var strike_pos := {}
var hist: Array = []       # 선두의 높이 기록 {t, y}
var now := 0.0
var phase := 0.0


func setup(ids: Array) -> void:
	members = ids.duplicate()
	hist.clear()
	for i in members.size():
		var id: String = members[i]
		xpos[id] = slot_x(i)
		cd[id] = 0.0
		strike_t[id] = 0.0
		strike_pos[id] = Vector2.ZERO


func lead() -> String:
	return members[0]


func slot_x(i: int) -> float:
	return Config.PLAYER_X - i * Config.FOLLOW_GAP


# 연계기가 준비된 파티원(앞 순서 우선). 없으면 ""
func ready_member() -> String:
	for i in range(1, members.size()):
		if cd[members[i]] <= 0.0:
			return members[i]
	return ""


func strike(id: String, target: Vector2) -> void:
	cd[id] = Config.CHAIN_COOLDOWN
	strike_t[id] = STRIKE_TIME
	strike_pos[id] = target + Vector2(-70, 34)


func follower_y(i: int) -> float:
	var t := now - i * Config.FOLLOW_GAP / Config.ROAD_SCROLL_SPEED
	for k in range(hist.size() - 1, -1, -1):
		if hist[k].t <= t:
			return hist[k].y
	return Config.GROUND_Y


func update(dt: float) -> void:
	now += dt
	phase += dt * 16.0
	hist.append({"t": now, "y": game.player.y})
	while hist.size() > 2 and hist[1].t < now - 0.6:
		hist.pop_front()
	for id: String in members:
		cd[id] = maxf(0.0, cd[id] - dt)
		strike_t[id] = maxf(0.0, strike_t[id] - dt)
	queue_redraw()


func _draw() -> void:
	if members.is_empty():
		return
	for i in range(members.size() - 1, 0, -1):
		var id: String = members[i]
		var fy := follower_y(i)
		var pos := Vector2(xpos[id], fy)
		var out: bool = strike_t[id] > 0.0
		if out:
			# 뛰어나가 치고 돌아오기
			var k := sin((1.0 - strike_t[id] / STRIKE_TIME) * PI)
			pos = pos.lerp(strike_pos[id], pow(k, 0.6))
			var c: Color = Characters.DATA[id]["color"]
			for j in 3:
				draw_rect(Rect2(pos.x - 56 - j * 36, pos.y - 62 + j * 14, 46 - j * 8, 9),
						Color(c.r, c.g, c.b, 0.8 - j * 0.22))
		ChibiDraw.chibi(self, id, pos, 1.0 if out else 0.92, {
			"alpha": 1.0, "dash": out,
			"phase": phase + i * 1.3 if fy >= Config.GROUND_Y else 1.2,
		})
