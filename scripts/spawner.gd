extends Node
# 몬스터를 "무리"로 스폰해요. 무리 배치가 곧 레벨 디자인이에요.
# 한 줄 = [종류, 맨 앞 대상과의 거리(px)]
# 무리 표(table)는 게임 쪽에서 넣어 줘요(juggle_game.gd의 JUGGLE_GROUPS).

var game
var timer := 1.2
var first := true
var override: Array = []
var interval_scale := 1.0  # 무리 사이 간격 배율
var table: Array = []


func update(dt: float) -> void:
	timer -= dt
	if timer > 0.0 or table.is_empty() or game.stage_time > Config.ROAD_DURATION - 3.0:
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
