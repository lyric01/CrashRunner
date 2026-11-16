class_name Characters
# 캐릭터 데이터.
#   push: 평소 저글링에서 몬스터를 밀어내는 세기 배율
#   desc: 캐릭터 선택 화면에 보이는 한 줄 설명
# 랠리 방식의 차이는 아래 RALLY 표에 있어요.

const ORDER: Array[String] = ["bear", "wolf", "cow", "rabbit"]

static var DATA := {
	"bear": {
		"name": "곰", "color": Color("#E8604C"), "ear": "round",
		"ear_color": Color("#8A5A3C"), "hair": Color("#8A5A3C"),
		"push": 1.0, "desc": "느리고 묵직한 한 방",
	},
	"wolf": {
		"name": "늑대", "color": Color("#3D7BFF"), "ear": "pointy",
		"ear_color": Color("#8E96A3"), "hair": Color("#AEB6C2"),
		"push": 1.0, "desc": "빠른 연타",
	},
	"cow": {
		"name": "소", "color": Color("#E8D9B0"), "ear": "horn",
		"ear_color": Color("#5B4636"), "hair": Color("#5B4636"),
		"push": 1.4, "desc": "굴려서 강적 밀어내기",
	},
	"rabbit": {
		"name": "토끼", "color": Color("#F2C6D3"), "ear": "long",
		"ear_color": Color("#FFFFFF"), "hair": Color("#FFF4F7"),
		"push": 1.0, "desc": "점프 1.2배",
	},
}


static func name_of(id: String) -> String:
	return DATA[id]["name"]


static func index_of(id: String) -> int:
	return ORDER.find(id)


# ---------------------------------------------------------------- 캐릭터별 랠리 방식
# 여기에 없는 캐릭터와 빠진 값은 RALLY_DEFAULT를 써요.
#   send      보내는 속도 배율
#   ret       튕겨 돌아오는 시간 배율(클수록 느린 박자)
#   dmg       강적에게 주는 피해 배율
#   push      강적을 밀어내는 거리 배율
#   perfect   PERFECT 한 번에 오르는 열기 / good  GOOD 한 번에 오르는 열기
#   decay     열기가 초당 식는 양
#   lift_max  이 높이(px) 아래에서 받아쳐야 PERFECT (작을수록 늦게, 정확히 쳐야 함)
#   jitter    뭉치가 흩어지는 정도(0에 가까울수록 한 덩어리)
#   waves     튕겨 올 때 나뉘는 묶음 수 / wave_gap  묶음 사이 간격(초)
#   swing     공격 속도 배율(작을수록 빠르게 연타)
#   lob       true면 높이 띄워 보내요
#   air       true면 점프해서 공중에서 받아쳐야 PERFECT
#   apex      (air) 돌아온 뭉치가 정점을 찍는 높이(px). 선두 위 이 높이에서 잠깐 떠 있어요
#   stall     true면 강적전 중 공중에서 공격하는 동안 떨어지지 않고 떠 있어요(체공)
#   roll      true면 바닥으로 굴려 보내고, 굴러서 돌아와요
#   line_px   굴러오는 몬스터가 표시선에서 이 거리(px) 안에 있을 때 쳐야 PERFECT
#   hint      강적전 때 화면에 띄우는 한 줄 안내
const RALLY_DEFAULT := {
	"name": "기본", "desc": "랠리: 기본 박자",
	"send": 1.0, "ret": 1.0, "dmg": 1.0, "push": 1.0,
	"perfect": 1.0, "good": 0.3, "decay": 0.5, "lift_max": 9999.0,
	"jitter": 1.0, "waves": 1, "wave_gap": 0.0, "swing": 1.0,
	"lob": false, "air": false, "apex": 0.0, "stall": false, "roll": false, "line_px": 50.0,
	"hint": "튀는 몬스터를 쳐서 약점으로 보내세요",
}
const RALLY := {
	# 묵직한 한 덩어리: 느린 박자, 큰 한 방. 정확히 받아쳐야만 열기가 올라요.
	"bear": {
		"name": "묵직한 한 덩어리", "desc": "랠리: 느리고 묵직한 한 방",
		"send": 0.8, "ret": 1.45, "dmg": 1.7,
		"perfect": 2.0, "good": 0.0, "decay": 0.4, "lift_max": 100.0, "jitter": 0.2,
		"hint": "튀는 몬스터를 쳐서 약점으로 보내세요",
	},
	# 속사: 뭉치가 세 묶음으로 빠르게 돌아와서 연타로 받아쳐요. 열기가 빨리 오르고 빨리 식어요.
	"wolf": {
		"name": "속사", "desc": "랠리: 빠른 연타",
		"send": 1.25, "ret": 0.75, "dmg": 1.15, "push": 0.7,
		"perfect": 0.7, "good": 0.2, "decay": 0.8, "jitter": 0.6,
		"waves": 3, "wave_gap": 0.2, "swing": 0.55,
		"hint": "세 묶음으로 돌아와요. 연달아 받아치세요",
	},
	# 땅볼 밀어내기: 바닥으로 굴려 보내고 굴러서 돌아와요. 피해는 약하지만 강적을 크게 밀어내요.
	"cow": {
		"name": "땅볼 밀어내기", "desc": "랠리: 굴려서 강적 밀어내기",
		"roll": true, "line_px": 50.0, "dmg": 0.7, "push": 3.0,
		"perfect": 0.8, "good": 0.3, "decay": 0.25, "jitter": 0.3,
		"hint": "굴러오는 몬스터가 금색 선을 지날 때 치면 PERFECT",
	},
	# 토끼는 고유 방식 없이 기본 랠리를 써요(공중 받아치기·체공은 시험해 보고 뺐어요).
}


static func rally_of(id: String) -> Dictionary:
	var out: Dictionary = RALLY_DEFAULT.duplicate()
	if RALLY.has(id):
		out.merge(RALLY[id], true)
	return out
