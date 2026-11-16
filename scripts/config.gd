extends Node
# 자동 로드(Autoload) 이름: Config
# 모든 튜닝 값은 여기에서만 관리해요.

# --- 판 사이에 유지되는 값 ---
var party: Array = ["bear"]                 # 고른 캐릭터
var drift_mult := 1.0                        # 강화 '자석': 흩어진 몬스터가 돌아오는 속도 배율
var skip_select := false                     # "다시 하기"는 캐릭터 선택을 건너뛰어요

# --- 공통 ---
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const GROUND_Y := 560.0
const PLAYER_X := 300.0
const GRAVITY := 2600.0
const JUMP_VELOCITY := -980.0           # 토끼는 RABBIT_JUMP_MULT 배
const RABBIT_JUMP_MULT := 1.2
const AIR_JUMPS := 1                    # 공중에서 추가로 뛸 수 있는 횟수(1 = 더블 점프)
const DOUBLE_JUMP_VELOCITY := -608.0    # 더블 점프 속도. 높이는 속도의 제곱에 비례해요(-860이면 지금의 2배 높이)
const COYOTE_TIME := 0.12               # 낭떠러지로 떨어지기 시작한 뒤 이 시간 안에는 점프 가능(초)
const PIT_RESCUE_DEPTH := 70.0          # 낭떠러지에 이만큼(px)보다 깊이 빠지면 더블 점프로도 못 나와요
const PARTY_HP := 10
const INVULN_TIME := 0.8

# --- 공격 ---
const ATTACK_DURATION := 0.22
const ATTACK_COOLDOWN := 0.35
const ATTACK_LUNGE := 0.0               # 휘두르며 앞으로 튀어나가는 거리(0 = 제자리에서 휘두름)
const ATTACK_REACH := 230.0             # 몸 앞쪽 판정 폭(돌진이 없어진 만큼 넓혔어요)

# --- 스테이지 ---
const ROAD_SCROLL_SPEED := 520.0        # px/초
const SPAWN_INTERVAL_MIN := 1.0         # 무리와 무리 사이 간격(초). 줄일수록 빽빽해요
const SPAWN_INTERVAL_MAX := 1.5
const COMBO_TIMEOUT := 2.5
const SCORE_HIT := 50.0
const SCORE_KILL := 100.0
const SCORE_PER_PX := 0.02              # 거리 점수
const PX_PER_METER := 50.0
const HIT_SLOW_RATIO := 0.5             # 맞았을 때 감속
const HIT_SLOW_TIME := 0.8
const PIT_EDGE := 14.0                  # 낭떠러지 가장자리 여유(px)

# --- 몬스터 ---
const SLIME_HP := 2.0                   # 약한 몬스터(핀)
const ORC_HP := 12.0                    # 단단한 몬스터(공)

# --- 몬스터가 맞고 튀는 연출 ---
const KNOCK_DRAG := 2.0                 # 초당 감속 비율(처음엔 빠르고 금방 느려짐)
const HIT_SQUASH := Vector2(0.55, 1.4)  # 맞는 순간 찌그러짐
const LAND_SQUASH := Vector2(1.4, 0.6)  # 땅에 닿는 순간 납작해짐
const SQUASH_RECOVER := 14.0            # 원래 모양으로 돌아오는 빠르기
const BOUNCE_VX_KEEP := 0.6             # 땅에 튕길 때 남는 수평 속도 비율
const BOUNCE_VY_KEEP := 0.55
const MAX_BOUNCES := 2                  # 이만큼 튀고 멈춰요
const RECOVER_TIME := 0.35              # 부딪히지 못하고 떨어졌을 때 일어나는 시간
const WALL_X := 1240.0                  # 이보다 오른쪽으로는 안 나가요
const HITSTOP_HIT := 0.07
const HITSTOP_IMPACT := 0.06            # 몬스터가 강적에 부딪혔을 때

# --- 저글링과 랠리 ---
# 흐름: 일반 공격으로 몬스터를 뭉친다 → 강적이 오면 쳐서 보낸다 → 튕겨 오는 뭉치를 받아친다(랠리)
const JUGGLE_GROGGY := 2.0              # 맞고 날아간 뒤 그로기 시간(초)
const HOP_VY := 560.0                   # 그로기 중 통통 튀는 최소 높이(속도)
const JUGGLE_VX := 1000.0               # 일반 공격 넉백(짧게: 선두 바로 앞에서 저글링)
const JUGGLE_VY := -620.0
const JUGGLE_DRIFT := 140.0             # 그로기 몬스터가 화면에서 선두 쪽으로 다가오는 속도(px/초)
const HITSTOP_BURST := 0.2
const HITSTOP_GAP := 0.3                # 히트스톱이 끝난 뒤 이 시간 동안은 새로 걸리지 않아요
const BLAST_VX := 2500.0                # 강적 격파: 화면 밖으로 튕겨 나가는 속도
const BLAST_VY := -1050.0

# 공중 적(박쥐): 머리 위로 날아와요. 땅에서는 닿지 않고 점프해서 쳐야 해요.
const BAT_HP := 4.0
const BAT_HEIGHT := 190.0               # 날아오는 높이(px). 땅에서 휘두르면 130px까지만 닿아요
const BAT_BOB := 14.0                   # 위아래로 흔들리는 폭(px)
const BAT_SPEED := 90.0                 # 땅의 속도에 더해 다가오는 속도(px/초)

# 뭉치(뭉친 몬스터)
const AMMO_DAMAGE := {"orc": 3.0, "slime": 1.0, "bat": 2.0}   # 강적에게 주는 기본 피해
const AMMO_WEAR := {"orc": 2.0, "slime": 1.0, "bat": 1.0}     # 부딪힐 때마다 닳는 자기 체력(0이 되면 터짐)
const SHOT_VX := 2000.0                 # 쳐서 보낸 뭉치의 속도
const SHOT_TIMEOUT := 1.3               # 이 시간 안에 못 맞히면 되돌아와요
const REBOUND_GROGGY := 3.0             # 튕겨 돌아온 뒤 그로기 시간(초)

# 랠리
const RALLY_RANGE := 1250.0             # 강적이 이 안(화면 x)에 들어오면 치는 몬스터가 강적에게 날아가요
const RALLY_LAND := 150.0               # 튕겨 온 뭉치가 떨어지는 자리(선두 앞 px)
const RETURN_TIME := {"normal": 0.55, "fast": 0.38, "lob": 0.85}   # 튕겨 오는 데 걸리는 시간(초)
const STALL_VY := -60.0                 # 체공: 공중에서 공격할 때마다 이 속도로 살짝 떠올라요
const SPIKE_MULT := 1.3                 # 공중에서 차 내린 몬스터의 피해 배율
const SPIKE_SPEED := 1.3                # 차 내린 몬스터의 속도 배율
const LOB_SEND_TIME := 0.6               # 높이 띄워 보낼 때 강적에 닿기까지의 시간(초)
# 겨냥 시험: 치는 순간의 상태에 따라 강적의 어느 높이로 보낼지가 달라져요.
#   땅에서 치면 가운데 / 뛰어오르는 중에 치면 위 / 떨어지는 중에 치면 아래
const AIM_BY_JUMP := true               # false면 예전처럼 몸통 30~70% 중 무작위
# 강적의 약점: 방패로 위·가운데·아래 중 두 곳을 가리고, 가려지지 않은 한 곳이 약점이에요.
const ELITE_STANCE_TIME := 5.0          # 약점이 다른 곳으로 옮겨 가는 간격(초)
const STANCE_WARN := 1.0                # 바뀌기 이만큼(초) 전부터 표시가 깜빡여요
const WEAK_MULT := 1.8                  # 약점에 맞았을 때 피해 배율
const BLOCK_MULT := 0.4                 # 방패에 막혔을 때 피해 배율
const AIM_HEIGHT := {"high": 0.88, "mid": 0.5, "low": 0.12}   # 강적 키에 대한 비율
const HEAT_WEAK := 0.08                 # 약점에 한 마리 맞을 때마다 오르는 열기
const DROP_GRACE := 0.35                # 방금 받아쳤으면 이 시간 안에 떨어진 낙오 몬스터는 봐줘요(초)
const RALLY_GAP := 2.0                  # 이 시간 동안 못 보내면 랠리 횟수가 끊겨요
const HEAT_MAX := 10.0                  # 열기 최대치
const HEAT_PERFECT := 1.0               # 땅에 닿기 전에 받아쳤을 때 오르는 열기
const HEAT_GOOD := 0.3                  # 땅에 닿은 뒤에 쳤을 때
const HEAT_DECAY := 0.5                 # 초당 식는 양
const HEAT_DMG := 0.2                   # 열기 1마다 피해 +20%
const HEAT_SPEED := 0.04                # 열기 1마다 보내는 속도 +4%

# 말풍선(재미용, 규칙과는 무관): 뭉친 몬스터들이 신음을 흘려요.
const BUBBLES := true                   # false면 말풍선을 끔
const BUBBLE_MAX := 4                   # 동시에 뜨는 최대 개수
const BUBBLE_TIME := 1.2                # 한 말풍선이 떠 있는 시간(초)
const BUBBLE_IDLE_MIN := 0.5            # 가만히 튀는 동안 혼잣말이 나오는 간격(초)
const BUBBLE_IDLE_MAX := 1.3

# 강적
const ELITE_HP := 600.0
const ELITE_APPROACH := 110.0           # 화면에서 다가오는 속도(px/초). 선두에 닿으면 패배
const ELITE_FIRST := 12.0               # 첫 강적 등장 시각(초)
const ELITE_INTERVAL := 16.0            # 강적을 잡은 뒤 다음 등장까지(초)
const ELITE_WARN := 3.0                 # 등장 예고 시간(초)
const STAGE_ELITE_HP_GROWTH := 0.4      # 스테이지가 오를 때마다 강적 체력 +40%
const ELITE_ORDER_HP_GROWTH := 0.15     # 같은 스테이지 안에서 다음 강적은 +15%

# 한 판의 구조: 스테이지 5개, 스테이지마다 강적 3번. 마지막 강적을 잡아야 다음으로 넘어가요.
const STAGE_COUNT := 5
const ELITES_PER_STAGE := 3
const SHOP_INPUT_LOCK := 0.5            # 가게가 열린 직후 이 시간 동안은 입력을 받지 않아요(초)
const STAGE_CLEAR_DELAY := 1.8         # 마지막 강적을 잡고 가게가 열리기까지(초)
# 최종 보스(마지막 스테이지의 마지막 강적). 지금은 강적의 강화판이에요.
const BOSS_HP_MULT := 2.5
const BOSS_STANCE_MULT := 0.6           # 약점이 옮겨 가는 간격 배율(작을수록 빨리 바뀜)
const BOSS_SIZE := 1.35
# 맞았을 때: 체력이 깎이는 대신 뭉치가 사방으로 흩어져요(뭉치가 없을 때만 체력이 깎임).
const SCATTER_LOSS := 0.25              # 흩어진 몬스터 중 뒤로 빠져나가 잃는 비율
const JUGGLE_SPAWN_SCALE := 1.6         # 몬스터 무리 간격 배율
const OBSTACLE_INTERVAL_MIN := 1.5     # 장애물(강철벽·낭떠러지) 간격(초). 줄일수록 촘촘해요
const OBSTACLE_INTERVAL_MAX := 2.3
const OBSTACLE_INTERVAL_FLOOR := 1.0    # 아무리 촘촘해져도 이보다 짧아지지 않아요(연속 점프가 가능한 한계)
const OBSTACLE_STOP_BEFORE_ELITE := 2.0 # 강적 등장 이만큼(초) 전부터 장애물을 멈춰요
const OBSTACLE_RESUME_DELAY := 1.2      # 강적을 잡은 뒤 장애물이 다시 나오기까지(초)
const OBSTACLE_PIT_RATIO := 0.4        # 장애물 중 낭떠러지 비율
const STAGE_OBSTACLE_SCALE := 0.88      # 스테이지가 오를 때마다 장애물 간격 x0.88
const STAGE_BANNER_TIME := 1.8         # 스테이지 전환 배너 표시 시간(초)
const ELITE_PUSH := 3.0                 # 한 발 맞을 때마다 밀리는 거리(px)

# --- 화면 버튼 위치 ---
const JUMP_BTN := Vector2(104, 622)
const JUMP_BTN_R := 62.0
const ATTACK_BTN := Vector2(1170, 612)
const ATTACK_BTN_R := 75.0
const PAUSE_BTN := Vector2(1238, 42)
const PAUSE_BTN_R := 22.0

# --- 입력 액션 ---
const INPUTS := {
	"attack": [KEY_D, KEY_RIGHT, KEY_J],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"pick_1": [KEY_1],
	"pick_2": [KEY_2],
	"pick_3": [KEY_3],
	"pick_4": [KEY_4],
	"confirm": [KEY_ENTER, KEY_KP_ENTER],
	"pause": [KEY_ESCAPE, KEY_P],
	"restart": [KEY_R],
	"party": [KEY_T],
	"debug": [KEY_F1],
}


func _enter_tree() -> void:
	for action: String in INPUTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in INPUTS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
