extends Node2D
# 고른 캐릭터를 기억해요. 지금은 한 명만 조종해요.

var game
var members: Array = []
var xpos := {}             # id -> 화면 x


func setup(ids: Array) -> void:
	members = ids.duplicate()
	for id: String in members:
		xpos[id] = Config.PLAYER_X


func lead() -> String:
	return members[0]
