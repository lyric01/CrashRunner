extends Node
# 몬스터를 "무리"로 스폰해요. 무리 배치가 곧 레벨 디자인이에요.
# 한 줄 = [종류, 맨 앞 대상과의 거리(px)]
# 단단한 오크(공)를 앞에 두고, 뒤에 약한 슬라임·상자(핀)나 다른 오크를 둬요.

const GROUPS := [
	# 기본: 오크 하나 + 뒤에 핀 셋 → 한 번 치면 줄줄이 충돌
	[["orc", 0], ["slime", 150], ["slime", 250], ["slime", 350]],
	[["orc", 0], ["box", 160], ["slime", 260], ["box", 360]],
	# 길게 이어지는 무리: 연계기로 다시 날려야 끝까지 닿아요
	[["orc", 0], ["slime", 140], ["slime", 300], ["slime", 460], ["slime", 620]],
	[["orc", 0], ["box", 180], ["slime", 380], ["slime", 560], ["box", 740]],
	# 오크 둘: 부딪힌 오크도 같이 날아가서 2차 충돌
	[["orc", 0], ["orc", 180], ["slime", 340], ["slime", 440]],
	[["orc", 0], ["slime", 150], ["orc", 320], ["slime", 480], ["slime", 580]],
	# 저글링용(실험에서 연쇄가 가장 길게 이어진 배치): 오크끼리 260px 안쪽으로 붙여요.
	# 부딪힌 오크가 죽지 않고 같이 날아가 다음 "공"이 되기 때문에 연쇄가 안 끊겨요.
	[["orc", 0], ["orc", 150]],
	[["orc", 0], ["orc", 130], ["orc", 260]],
	[["orc", 0], ["slime", 120], ["orc", 240]],
	[["slime", 0], ["orc", 150], ["orc", 330]],
	[["orc", 0], ["orc", 180], ["steel", 420]],
	[["orc", 0], ["orc", 180], ["orc", 360], ["pit", 640]],
	# 충돌 없음: 오크 혼자 → 날아갔다가 다시 다가와요
	[["orc", 0]],
	# 약한 것만: 연쇄 없이 한 방씩
	[["slime", 0], ["slime", 120]],
	# 점프: 강철벽, 낭떠러지
	[["steel", 0]],
	[["pit", 0]],
	# 강철벽에 날려 보내기: 벽에 부딪혀도 그로기
	[["orc", 0], ["slime", 150], ["steel", 330]],
	[["steel", 0], ["orc", 320], ["slime", 470], ["slime", 570]],
	# 낭떠러지로 날려 보내기: 내려앉으면 추락
	[["orc", 0], ["slime", 160], ["pit", 430]],
	[["pit", 0], ["orc", 340], ["slime", 490], ["slime", 590]],
]

var game
var timer := 1.2
var first := true
var override: Array = []
var interval_scale := 1.0  # 무리 사이 간격 배율(모드가 조절)
var table: Array = GROUPS   # 모드가 바꿔 끼울 수 있는 무리 표


func update(dt: float) -> void:
	timer -= dt
	if timer > 0.0 or game.stage_time > Config.ROAD_DURATION - 3.0:
		return
	var group: Array = table[0] if first else table.pick_random()
	if not override.is_empty():
		group = override      # 패턴 실험용: 이 무리만 반복
	first = false
	var last: float = group[group.size() - 1][1]
	timer = randf_range(Config.SPAWN_INTERVAL_MIN, Config.SPAWN_INTERVAL_MAX) * interval_scale \
			+ last / Config.ROAD_SCROLL_SPEED
	for e: Array in group:
		game.spawn(e[0], 1380.0 + e[1])
