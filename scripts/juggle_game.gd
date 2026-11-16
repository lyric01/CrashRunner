extends "res://scripts/game.gd"
# 저글링과 랠리의 규칙. 기본 뼈대(game.gd) 위에 얹혀 있어요.
#
# 조작은 점프와 공격 두 개뿐이에요.
#   - 평소: 일반 공격은 피해 없이 몬스터를 살짝 띄워 그로기로 만들어요. 계속 치면 선두 앞에 뭉쳐요.
#   - 강적전(랠리): 강적이 화면에 들어오면, 친 몬스터가 강적에게 날아가 부딪히고
#     선두 앞으로 튕겨 돌아와요. 돌아온 뭉치를 다시 쳐서 보내는 걸 반복해요.
#   - 받아치지 못한 몬스터는 땅에 떨어지며 사방으로 흩어져요. 벌은 없어요.
#     여기저기 튀는 몬스터를 쳐서 강적의 약점으로 보내는 게 이 모드의 핵심이에요.
#   - 약점에 맞힐수록 "열기"가 올라 더 세고 빠르게 날아가요.
#     튕겨 온 몬스터를 땅에 닿기 전에 받아치면 PERFECT로 열기가 더 올라요(덤).
#   - 강적은 가끔 공을 빠르게(빠른 공) 또는 높고 느리게(높은 공) 돌려보내 박자를 바꿔요.
#   - 강적이 캐릭터에 닿으면 패배예요.
#
# 한 판: 스테이지 5개, 스테이지마다 강적 3번. 세 번째 강적을 잡으면 가게가 열리고 다음 스테이지로 넘어가요.
#   - 뭉치는 탄환이면서 화폐예요. 가게에서 뭉치를 내고 강화를 사요.
#   - 마지막 스테이지의 세 번째 강적이 최종 보스예요. 잡으면 승리.
#   - 맞으면 체력 대신 뭉치가 사방으로 흩어져요. 대부분은 다시 모을 수 있고 일부는 뒤로 빠져나가요.

const JUGGLE_GROUPS := [
	[["orc", 0]],
	[["orc", 0], ["orc", 220]],
	[["orc", 0], ["slime", 150], ["slime", 270]],
	[["slime", 0], ["slime", 120], ["slime", 240]],
	[["orc", 0], ["slime", 160]],
	[["orc", 0], ["orc", 180], ["orc", 360]],
	# 공중 적(박쥐): 점프해서 쳐야 잡혀요.
	[["bat", 0]],
	[["bat", 0], ["bat", 170]],
	[["orc", 0], ["bat", 210]],
	[["slime", 0], ["slime", 120], ["bat", 280]],
]
# 장애물(강철벽, 낭떠러지)은 몬스터 무리와 따로, 자기 박자로 나와요(_update_obstacles).
const AIM_HOW := {"high": "뛰어오르며 치기", "mid": "땅에서 치기", "low": "떨어지며 치기"}
# 말풍선 대사. 상황별로 하나를 무작위로 골라요.
const GROANS := {
	"hit": ["아야!", "으악!", "또야?!", "그만...", "살살 좀!", "악!", "왜 나만..."],
	"idle": ["끄응...", "어지러워...", "멀미 나...", "집에 갈래...", "내려 줘...", "우웩...", "언제 끝나..."],
	"send": ["으아아아!", "안 돼애애!", "대장님 피해요!", "날 쏘지 마!", "엄마아아!"],
	"impact": ["죄송합니다!", "쿵!", "일부러 그런 게...", "아이고 대장님", "으깨진다..."],
	"drop": ["철퍼덕!", "어이쿠!", "데굴데굴...", "살았다...?"],
	"elite": ["크윽!", "이 녀석들이!", "배신자들!", "거기는 안 돼!"],
}
const GROANS_BY_KIND := {
	"slime": {"hit": ["뿌잉!", "말랑...", "찌그러져..."], "idle": ["뿌잉...", "흐물흐물..."]},
	"bat": {"hit": ["끼익!", "날개가!"], "idle": ["끼이...", "날 수가 없어..."]},
}
# 말풍선이 뜨는 자리(몬스터 머리 기준). 말풍선마다 서로 다른 자리를 써서 뭉치 여기저기에서 나와요.
const BUBBLE_SLOTS := [
	Vector2(-84, -30), Vector2(78, -46), Vector2(-14, -96), Vector2(118, 6),
	Vector2(-124, 14), Vector2(44, -128), Vector2(-66, -134), Vector2(140, -86),
]
# 가게에서 파는 강화. cost: 첫 구매 값(마리), 살 때마다 +2. max: 최대 단계
const UPGRADES := {
	"wide": {"name": "넓은 휘두르기", "desc": "공격 범위 +25%", "cost": 5, "max": 3},
	"magnet": {"name": "자석", "desc": "흩어진 몬스터가 더 빨리 돌아옴", "cost": 4, "max": 3},
	"swarm": {"name": "몬스터 떼", "desc": "몬스터가 더 자주 나옴", "cost": 6, "max": 3},
	"sturdy": {"name": "튼튼한 뭉치", "desc": "부딪혀도 덜 닳음", "cost": 6, "max": 3},
	"pierce": {"name": "방패 뚫기", "desc": "막혀도 피해가 더 들어감", "cost": 5, "max": 2},
	"focus": {"name": "약점 고정", "desc": "약점이 더 오래 머묾", "cost": 4, "max": 3},
	"power": {"name": "묵직한 타격", "desc": "피해 +30%", "cost": 7, "max": 4},
	"mass": {"name": "덩어리의 힘", "desc": "뭉치가 클수록 피해 증가", "cost": 8, "max": 3},
}
const AIM_NAME := {"high": "위", "mid": "가운데", "low": "아래"}
const AIM_COLOR := {"high": Color("#6FD0FF"), "mid": Color("#FFD23D"), "low": Color("#FF8A4A")}
const RETURN_LABEL := {"fast": ["빠른 공!", Color("#FF7A7A")], "lob": ["높은 공!", Color("#7FD6FF")]}

var elite = null
var elite_timer: float = Config.ELITE_FIRST
var warn_t := 0.0
var elites_spawned := 0
var elites_killed := 0

var juggled := 0           # 지금 뭉쳐 있는 몬스터 수
var heat := 0.0            # 열기(0 ~ HEAT_MAX)
var rally := 0             # 끊기지 않고 보낸 횟수
var best_rally := 0
var rally_gap_t := 0.0
var award_serial := -1     # 이번 휘두르기에 이미 준 판정
var award_q := 0.0
var ret_type := "normal"   # 강적이 이번에 돌려보내는 방식
var since_impact := 9.0
var flash_t := 0.0
var prof: Dictionary = Characters.rally_of("")   # 고른 캐릭터의 랠리 방식
var spike_serial := -1     # 이번 휘두르기에 차 내리기 연출을 이미 했는지
var stance_t := 0.0        # 약점이 바뀌기까지 남은 시간
var weak_hits := 0
var block_hits := 0
var flash_col := Color.WHITE
var verdict_t := 0.0       # 판정 자리에서 퍼지는 고리(판정 색)
var verdict_col := Color.WHITE
var heat_hit_t := 0.0      # 열기가 깎였을 때 열기 바가 붉게 깜빡이는 시간
var award_rank := 0        # 이번 휘두르기에 이미 준 판정의 등급
var since_send := 9.0      # 마지막으로 받아친 뒤 지난 시간
var drop_cd := 0.0
var drops := 0             # 뭉치를 떨어뜨린 횟수
var earlies := 0
var lates := 0
var bubbles: Array = []    # 떠 있는 말풍선 {m, text, t, off}
var bubble_cd := 1.0
var aim_serial := -1       # 이번 휘두르기의 겨냥을 이미 정했는지
var aim_lane := "mid"      # 이번 휘두르기가 보내는 높이(high / mid / low)
var lane_hits := {}        # 높이별 명중 수(통계)
var impact_i := 0          # 부딪힌 순서(묶음 나누기용)
var obstacle_t := 2.5       # 다음 장애물까지 남은 시간
var obstacles_spawned := 0
var banner_t := 0.0       # 스테이지 전환 배너
var stage_elites := 0      # 이번 스테이지에 나온 강적 수
var stage_kills := 0       # 이번 스테이지에 잡은 강적 수
var clear_delay := 0.0     # 스테이지의 마지막 강적을 잡은 뒤 가게·승리까지 남은 시간
var clump_total := 0       # 날아가는 중인 것까지 포함한 뭉치 전체 수
var scatters := 0          # 맞아서 뭉치가 흩어진 횟수
var ups := {}              # 산 강화: id -> 단계
var shop_offers: Array = []    # 가게에 나온 강화 id 셋(산 자리는 "")
var shop_note := ""
var shop_note_t := 0.0
var shop_lock_t := 0.0     # 가게가 열린 직후 입력을 받지 않는 시간

# 통계
var sends := 0
var perfects := 0
var goods := 0
var impacts := 0


func _ready() -> void:
	super()
	player.air_reach_down = true     # 점프 중 공격이 바닥까지 닿아요
	hitstop_gap = Config.HITSTOP_GAP # 여러 마리를 쳐도 화면이 연달아 멈추지 않아요
	spawner.table = JUGGLE_GROUPS
	spawner.interval_scale = Config.JUGGLE_SPAWN_SCALE
	Config.drift_mult = 1.0


func start_stage(ids: Array) -> void:
	super(ids.slice(0, 1))
	prof = Characters.rally_of(party.lead())
	player.swing_time = Config.ATTACK_DURATION * prof["swing"]
	player.cooldown_time = Config.ATTACK_COOLDOWN * prof["swing"]


func _process(delta: float) -> void:
	super(delta)
	flash_t = maxf(0.0, flash_t - delta)
	verdict_t = maxf(0.0, verdict_t - delta)
	heat_hit_t = maxf(0.0, heat_hit_t - delta)
	shop_note_t = maxf(0.0, shop_note_t - delta)
	shop_lock_t = maxf(0.0, shop_lock_t - delta)
	if not paused:
		banner_t = maxf(0.0, banner_t - delta)
	if state == State.SHOP:
		hud.queue_redraw()


# ---------------------------------------------------------------- 한 판의 구조

func lv(id: String) -> int:
	return ups.get(id, 0)


# 스테이지 진행도: 강적 3번을 기준으로 채워져요.
func road_progress() -> float:
	var n := float(Config.ELITES_PER_STAGE)
	var part := 0.0
	if elite_alive():
		part = 0.5 + 0.5 * (1.0 - elite.hp / elite.max_hp)
	elif stage_kills < Config.ELITES_PER_STAGE:
		var total: float = Config.ELITE_FIRST if stage_elites == 0 else Config.ELITE_INTERVAL
		part = 0.5 * clampf(1.0 - elite_timer / total, 0.0, 1.0)
	return clampf((stage_kills + part) / n, 0.0, 1.0)


func stage_label() -> String:
	return "스테이지 %d/%d · 강적 %d/%d" % [stage, Config.STAGE_COUNT, stage_kills, Config.ELITES_PER_STAGE]


func _next_stage() -> void:
	stage += 1
	stage_time = 0.0
	stage_elites = 0
	stage_kills = 0
	elite_timer = Config.ELITE_FIRST
	warn_t = 0.0
	banner_t = Config.STAGE_BANNER_TIME
	spawner.timer = 0.6
	scroller.to_boss = stage % 2 == 0      # 스테이지마다 배경 색을 번갈아 바꿔요
	score += 1000.0 * (stage - 1)
	fx.shake(8.0, 0.25)


# 지금 손에 있는 뭉치(날려 보낸 것은 빼고)
func _ammo() -> Array:
	var list: Array = []
	for m in monsters.get_children():
		if m.alive() and m.is_monster() and not m.shot and (m.state == "fly" or m.state == "groggy"):
			list.append(m)
	return list


# ---------------------------------------------------------------- 가게

func cost_of(id: String) -> int:
	return int(UPGRADES[id]["cost"]) + 2 * lv(id)


func _open_shop() -> void:
	state = State.SHOP
	var pool: Array = []
	for id: String in UPGRADES:
		if lv(id) < int(UPGRADES[id]["max"]):
			pool.append(id)
	pool.shuffle()
	shop_offers = pool.slice(0, 3)
	shop_note = ""
	shop_lock_t = Config.SHOP_INPUT_LOCK


# i번째 강화를 사요. 값만큼 뭉치에서 몬스터가 빠져나가요.
func buy(i: int) -> void:
	if state != State.SHOP or i < 0 or i >= shop_offers.size() or shop_offers[i] == "":
		return
	var id: String = shop_offers[i]
	var cost := cost_of(id)
	var ammo := _ammo()
	if ammo.size() < cost:
		shop_note = "뭉치가 모자라요 (%d마리 필요)" % cost
		shop_note_t = 1.2
		return
	# 값은 약한 몬스터부터 내요.
	ammo.sort_custom(func(a, b) -> bool:
		return Config.AMMO_DAMAGE.get(a.kind, 1.0) < Config.AMMO_DAMAGE.get(b.kind, 1.0))
	for k in cost:
		_remove(ammo[k])
	ups[id] = lv(id) + 1
	shop_offers[i] = ""
	shop_note = "%s 구매!" % UPGRADES[id]["name"]
	shop_note_t = 1.2
	_apply_upgrades()
	_count_juggled()


func _apply_upgrades() -> void:
	player.reach_mult = 1.0 + 0.25 * lv("wide")
	Config.drift_mult = 1.0 + 0.6 * lv("magnet")
	spawner.interval_scale = Config.JUGGLE_SPAWN_SCALE * pow(0.8, lv("swarm"))


func _close_shop() -> void:
	if state != State.SHOP:
		return
	state = State.STAGE
	_next_stage()


func _stance_time() -> float:
	var t: float = Config.ELITE_STANCE_TIME * (1.0 + 0.4 * lv("focus"))
	if elite != null and elite.boss:
		t *= Config.BOSS_STANCE_MULT
	return t


func _block_mult() -> float:
	return minf(1.0, Config.BLOCK_MULT + 0.25 * lv("pierce"))


# 강화로 붙는 피해 배율
func _upgrade_dmg() -> float:
	return (1.0 + 0.3 * lv("power")) * (1.0 + 0.015 * lv("mass") * clump_total)


# ---------------------------------------------------------------- 피격

# 맞으면 체력 대신 뭉치가 사방으로 흩어져요. 뭉치가 없을 때만 체력이 깎여요.
# 대부분은 앞쪽으로 튀어서 다시 모을 수 있고, 일부는 뒤로 빠져나가 잃어요.
func damage(n: int) -> void:
	if invuln > 0.0 or state != State.STAGE:
		return
	var ammo := _ammo()
	if ammo.is_empty():
		super(n)
		return
	scatters += 1
	invuln = Config.INVULN_TIME
	slow_t = Config.HIT_SLOW_TIME
	combo = 0
	fx.shake(13.0, 0.3)
	fx.star(Vector2(player.position.x + 40.0, player.y - 50.0), 1.8)
	fx.text(Vector2(player.position.x + 60.0, player.y - 150.0), "와르르!", Color.WHITE, 34, 0.8)
	for m in ammo:
		var lost: bool = randf() < Config.SCATTER_LOSS
		var svx: float = scroll - randf_range(260.0, 680.0) if lost else scroll + randf_range(120.0, 900.0)
		m.launch(svx, -randf_range(480.0, 980.0))
		m.groggy_t = Config.REBOUND_GROGGY
		m.no_floor_t = 0.7
		m.incoming = false
		m.roll = false
		m.set_meta("ret", false)
		if lost:
			m.hop = false         # 뒤로 빠져나간 몬스터는 돌아오지 않아요
			m.no_floor_t = 9.0
		_say(m, "drop", 0.2)


func spawn(kind: String, x: float) -> Node2D:
	var m := super(kind, x)
	if m.is_monster():
		m.hop = true             # 그로기 동안 계속 통통 튀어요
	return m


func elite_alive() -> bool:
	return elite != null and elite.alive()


# 랠리 중: 강적이 화면 안에 들어와 있어서, 치는 몬스터가 강적에게 날아가는 상태
func rallying() -> bool:
	return elite_alive() and elite.position.x < Config.RALLY_RANGE


func heat_mult() -> float:
	return 1.0 + heat * Config.HEAT_DMG


# ---------------------------------------------------------------- 진행

func _update_stage(dt: float, rdt: float) -> void:
	_update_bubbles(rdt)
	player.air_stall = prof["stall"] and rallying()      # 체공은 강적전 중에만
	_update_obstacles(dt)
	warn_t -= dt
	since_impact += dt
	since_send += dt
	drop_cd -= dt
	heat = maxf(0.0, heat - prof["decay"] * dt)
	rally_gap_t -= dt
	if rally_gap_t <= 0.0:
		rally = 0
	if clear_delay > 0.0:
		# 스테이지의 마지막 강적을 잡았어요. 잠깐 뒤 가게가 열려요(마지막 스테이지면 승리).
		clear_delay -= rdt
		if clear_delay <= 0.0:
			if stage >= Config.STAGE_COUNT:
				_finish("clear")
				return
			_open_shop()
	elif elite_alive():
		stance_t -= dt
		if stance_t <= 0.0:
			_change_stance()
	elif stage_elites < Config.ELITES_PER_STAGE:
		elite_timer -= dt
		if elite_timer <= Config.ELITE_WARN and elite_timer + dt > Config.ELITE_WARN:
			warn_t = Config.ELITE_WARN
		if elite_timer <= 0.0:
			_spawn_elite()
	super(dt, rdt)


# 장애물을 일정한 간격으로 내보내요. 스테이지가 오를수록 간격이 줄어 더 촘촘해져요.
func _update_obstacles(dt: float) -> void:
	# 강적 페이즈에는 장애물이 나오지 않아요(랠리에만 집중).
	# 강적이 나오기 직전에도 멈춰서, 등장할 때 화면에 남은 장애물이 없게 해요.
	var elite_soon: bool = elite_timer < Config.OBSTACLE_STOP_BEFORE_ELITE \
			and stage_elites < Config.ELITES_PER_STAGE
	if elite_alive() or elite_soon or clear_delay > 0.0:
		obstacle_t = maxf(obstacle_t, Config.OBSTACLE_RESUME_DELAY)
		return
	obstacle_t -= dt
	if obstacle_t > 0.0:
		return
	var tight: float = pow(Config.STAGE_OBSTACLE_SCALE, stage - 1)
	obstacle_t = maxf(Config.OBSTACLE_INTERVAL_FLOOR,
			randf_range(Config.OBSTACLE_INTERVAL_MIN, Config.OBSTACLE_INTERVAL_MAX) * tight)
	super.spawn("pit" if randf() < Config.OBSTACLE_PIT_RATIO else "steel", 1420.0)
	obstacles_spawned += 1


func _update_monsters(dt: float) -> void:
	var flying_in: Array = []      # 이번 프레임이 시작될 때 튕겨 오던 몬스터들
	for m in monsters.get_children():
		if m.dead:
			continue
		if m.incoming and not m.shot:
			flying_in.append(m)
		# 지금 치면 PERFECT인 몬스터에는 흰 고리가 생겨요. 뭉치를 보고 있으면 바로 보여요.
		m.targeted = m.incoming and not m.shot and _in_zone(m)
		# 점프해도 저글링이 끊기지 않게: 선두가 공중에 있는 동안에는 그로기 시간이 줄지 않아요.
		if not player.on_ground and m.groggy_t > 0.0:
			m.groggy_t += dt
		# 보냈는데 맞히지 못한 몬스터는 되돌아와요.
		if m.shot:
			m.shot_t -= dt
			if m.shot_t <= 0.0:
				_return(m, "normal")
		# 굴러온 몬스터가 표시선을 지나치면(놓치면) 평소처럼 튀는 상태로 돌아가요.
		elif m.roll and m.position.x < rally_line() - prof["line_px"] - 10.0:
			m.roll = false
			m.incoming = false
	super(dt)
	# 튕겨 온 몬스터가 받아치지 못한 채 땅에 닿았으면(또는 굴러 지나갔으면) 떨어뜨린 거예요.
	# 방금 받아친 직후에 뒤늦게 떨어진 낙오 몬스터는 세지 않아요.
	if drop_cd <= 0.0 and since_send > Config.DROP_GRACE and rallying():
		var dropped: Array = []
		for m in flying_in:
			if is_instance_valid(m) and m.alive() and not m.incoming and not m.shot:
				dropped.append(m)
		if not dropped.is_empty():
			_on_drop(dropped)


# 받아치지 못한 뭉치가 땅에 닿았을 때. 벌은 없고, 흩어지기만 해요.
func _on_drop(dropped: Array) -> void:
	drop_cd = 0.5
	drops += 1
	fx.burst(Vector2(rally_line(), Config.GROUND_Y - 8.0), Color(0.85, 0.8, 0.7), 8, 0.6)
	fx.shake(4.0, 0.1)
	# 떨어진 뭉치는 사방으로 흩어져요.
	for m in dropped:
		_say(m, "drop", 0.3)
		m.launch(scroll + randf_range(-260.0, 420.0), -randf_range(420.0, 820.0))
		m.groggy_t = Config.REBOUND_GROGGY
		m.no_floor_t = 0.6
		m.set_meta("ret", false)


func _remove(m) -> void:
	if m == elite:
		elite = null
	super(m)


func _count_juggled() -> void:
	clump_total = 0
	for m in monsters.get_children():
		if m.alive() and m.is_monster() and m.state != "walk" and m.state != "down":
			clump_total += 1
	juggled = 0
	for m in monsters.get_children():
		if m.alive() and m.is_monster() and (m.state == "fly" or m.state == "groggy"):
			juggled += 1
	if juggled == 0:
		juggle_run = 0


# ---------------------------------------------------------------- 일반 공격 / 보내기

func _attack_hit(m) -> void:
	if m.kind == "elite":
		fx.star(Vector2(m.rect().position.x, m.center().y), 0.8)
		fx.text(m.center() + Vector2(0, -m.h / 2.0 - 30.0), "몬스터를 쳐서 보내세요!", Color("#B8C4CF"), 22)
		return
	if not m.is_monster():
		super(m)
		return
	if m.shot:
		return
	var data: Dictionary = Characters.DATA[party.lead()]
	var was_juggled: bool = m.state == "fly" or m.state == "groggy"
	fx.shake(5.0, 0.1)
	hitstop(Config.HITSTOP_HIT)
	fx.burst(m.center(), m.color(), 3, 0.6)
	register_hit(m.center(), Config.SCORE_HIT)
	_say(m, "send" if rallying() else "hit", 0.22)
	if was_juggled:
		juggle_run += 1
		max_juggle = maxi(max_juggle, juggle_run)
	if rallying():
		# 강적전: 친 몬스터는 강적에게 날아가요. 튕겨 온 걸 땅에 닿기 전에 쳤으면 PERFECT
		var perfect := _is_perfect(m)
		# 공중 받아치기: 떠 있는 채로 받아치면 높이 띄우지 않고 강적 쪽으로 곧장 날아가요.
		var spike: bool = perfect and prof["air"]
		var verdict: String = "perfect" if perfect else _miss_kind(m)
		_award(verdict)
		# 한 번 휘두를 때 친 몬스터는 모두 같은 높이로 가요(처음 맞는 순간의 상태로 정함).
		if player.serial != aim_serial:
			aim_serial = player.serial
			aim_lane = current_aim()
		_send(m, spike, aim_lane)
	else:
		m.incoming = false
		m.set_meta("ret", false)
		m.roll = false
		m.launch(Config.JUGGLE_VX * data["push"], Config.JUGGLE_VY)
		m.groggy_t = Config.JUGGLE_GROGGY


# 지금 치면 강적의 어느 높이로 날아가는지.
#   땅에 서 있으면 가운데, 뛰어오르는 중이면 위, 떨어지는 중이면 아래
func current_aim() -> String:
	if player.on_ground or player.falling:
		return "mid"
	return "high" if player.vy < 0.0 else "low"


# from에서 lane 높이로 보낼 때 처음 날아가는 방향(화면 기준). 실제 보내기와 같은 식이에요.
func _aim_dir(from: Vector2, lane: String, ax: float) -> Vector2:
	var gy := Config.GROUND_Y
	var to := Vector2(ax - 16.0, gy - elite.h * Config.AIM_HEIGHT[lane])
	var svx: float = Config.SHOT_VX * prof["send"] * (1.0 + heat * Config.HEAT_SPEED)
	var ft: float = maxf(0.05, (to.x - from.x) / (svx - (scroll - elite.approach)))
	var v0: float = ((gy - to.y) - (gy - from.y) + 0.5 * Config.GRAVITY * ft * ft) / ft
	return Vector2((to.x - from.x) / ft, -v0).normalized()


# 겨냥이 적용되는 캐릭터인지(굴리기·높이 띄우기 방식은 궤적이 정해져 있어서 제외)
func aiming() -> bool:
	return Config.AIM_BY_JUMP and not prof["roll"] and not prof["lob"]


# 튕겨 온 몬스터를 제때 받아쳤는지. 기준은 캐릭터마다 달라요.
func _is_perfect(m) -> bool:
	if not m.incoming or m.state != "fly":
		return false
	if prof["roll"]:
		# 땅볼: 표시선 근처를 지날 때
		return absf(m.position.x - rally_line()) <= prof["line_px"]
	if prof["air"] and player.on_ground:
		# 공중 받아치기: 점프한 상태여야 해요
		return false
	# 캐릭터에 따라 더 낮은 높이에서, 즉 더 늦게 정확히 쳐야 할 수도 있어요.
	return m.lift <= prof["lift_max"]


# 튕겨 오는 몬스터가 지금 PERFECT 구간 안에 있는지(화면 표시용)
func _in_zone(m) -> bool:
	if prof["roll"]:
		return absf(m.position.x - rally_line()) <= prof["line_px"]
	return m.vy > 0.0 and m.lift <= minf(prof["lift_max"], 130.0)


# PERFECT가 아닐 때 왜 아닌지: early(너무 일찍) / late(땅에 닿은 뒤) / join(처음 합류하는 몬스터)
func _miss_kind(m) -> String:
	if m.incoming:
		return "early"
	if m.get_meta("ret", false):
		return "late"
	return "join"


# 튕겨 온 뭉치가 도착하는 자리(화면 x)
func rally_line() -> float:
	return player.position.x + Config.RALLY_LAND


# 받아치기 판정. 한 번 휘두를 때 여러 마리를 쳐도 판정과 열기는 한 번만 줘요(가장 좋은 것으로).
func _award(verdict: String) -> void:
	var perfect := verdict == "perfect"
	var q := 0.0
	if perfect:
		q = prof["perfect"]
	elif verdict != "join":
		q = prof["good"]
	if player.serial != award_serial:
		award_serial = player.serial
		award_q = 0.0
		award_rank = 0
		since_send = 0.0
		sends += 1
		rally += 1
		best_rally = maxi(best_rally, rally)
		rally_gap_t = Config.RALLY_GAP
	var rank: int = {"join": 1, "early": 2, "late": 2, "perfect": 3}[verdict]
	if rank <= award_rank:
		return
	var prev_rank := award_rank
	award_rank = rank
	if q > award_q:
		heat = minf(Config.HEAT_MAX, heat + q - award_q)
		award_q = q
	# 글자는 캐릭터 머리 위가 아니라, 시선이 가 있는 판정 자리에 크게 띄워요.
	var at := Vector2(rally_line() + 10.0, Config.GROUND_Y - 175.0)
	var spot := Vector2(rally_line(), Config.GROUND_Y - 45.0)
	match verdict:
		"perfect":
			perfects += 1
			if prev_rank == 2:
				goods -= 1
			fx.text(at, "PERFECT", ChibiDraw.GOLD, 46, 0.7)
			flash_t = 0.1
			flash_col = Color.WHITE
			verdict_t = 0.3
			verdict_col = ChibiDraw.GOLD
			fx.star(spot, 2.2)
			fx.burst(spot, ChibiDraw.GOLD, 10, 1.0)
			fx.shake(11.0, 0.18)
		"early":
			goods += 1
			earlies += 1
		"late":
			goods += 1
			lates += 1


# 몬스터 하나를 강적 쪽으로 쳐 보내요. 열기가 높을수록 빨라요.
# spike: 공중에서 차 내린 경우. 높이 띄우지 않고 곧장, 더 빠르고 세게 날아가요.
func _send(m, spike := false, lane := "mid") -> void:
	var dist: float = maxf(60.0, elite.position.x - elite.w / 2.0 - m.position.x)
	var closing: float = scroll - elite.approach
	var spread: float = 0.03 * prof["jitter"]
	var svx: float = Config.SHOT_VX * prof["send"] * (1.0 + heat * Config.HEAT_SPEED) \
			* randf_range(1.0 - spread, 1.0 + spread)
	if spike:
		svx *= Config.SPIKE_SPEED
	m.set_meta("spike", spike)
	var svy := 0.0
	if prof["roll"]:
		pass       # 바닥으로 굴려 보내기: 위로 뜨지 않아요
	elif prof["lob"] and not spike:
		# 높이 띄워서 강적 머리 위로 떨어뜨리기
		var lt: float = Config.LOB_SEND_TIME * randf_range(1.0 - spread, 1.0 + spread)
		svx = dist / lt + closing
		svy = -(elite.h + 10.0 - m.lift + 0.5 * Config.GRAVITY * lt * lt) / lt
	else:
		var t: float = dist / (svx - closing)
		var want: float = elite.h * randf_range(0.3, 0.7)
		if aiming():
			want = elite.h * (Config.AIM_HEIGHT[lane] + randf_range(-0.05, 0.05))
		svy = -(want - m.lift + 0.5 * Config.GRAVITY * t * t) / t
	m.launch(svx, svy)
	m.lane = lane
	m.roll = prof["roll"]
	m.shot = true
	m.incoming = false
	m.set_meta("ret", false)
	m.shot_t = Config.SHOT_TIMEOUT
	m.groggy_t = Config.REBOUND_GROGGY


# 강적에 부딪힌(또는 빗나간) 몬스터가 선두 앞 정해진 자리로 튕겨 돌아와요.
# how: normal / fast(빠르게) / lob(높고 느리게) → 도착까지 걸리는 시간이 달라요.
# wave: 몇 번째 묶음으로 돌아올지(묶음마다 조금씩 늦게 도착)
func _return(m, how: String, wave := 0) -> void:
	var jit: float = prof["jitter"]
	var t: float = Config.RETURN_TIME[how] * prof["ret"] * randf_range(1.0 - 0.04 * jit, 1.0 + 0.04 * jit) \
			+ wave * prof["wave_gap"]
	var target: float = player.position.x + Config.RALLY_LAND + randf_range(-22.0, 22.0) * jit
	var screen_vx: float = (target - m.position.x) / t
	var rvy: float = -(0.5 * Config.GRAVITY * t * t - m.lift) / t
	if prof["roll"]:
		rvy = 0.0      # 바닥으로 굴러서 돌아와요
	var g_scale := 1.0
	var hang := 0.15
	if prof["air"]:
		# 공중 받아치기: 바닥이 아니라 선두 위 공중(apex 높이)에서 정점을 찍고 천천히 떠 있어요.
		var rise: float = maxf(30.0, prof["apex"] - m.lift)
		# 부딪힌 높이가 달라도 모두 같은 시간(t)에 같은 높이에 모이도록, 몬스터마다 중력을 맞춰요.
		g_scale = minf(1.0, 2.0 * rise / (t * t) / Config.GRAVITY)
		screen_vx = (target - m.position.x) / t
		rvy = -Config.GRAVITY * g_scale * t
		hang = 1.0
	m.shot = false
	m.launch(screen_vx + scroll, rvy)
	m.grav = g_scale
	m.roll = prof["roll"]
	m.incoming = true
	m.set_meta("ret", true)
	m.groggy_t = Config.REBOUND_GROGGY
	m.no_floor_t = t + hang


func _body_hit(m) -> void:
	if player.strike_t > 0.0 and m.kind != "elite":
		return       # 차 내리러 날아간 동안에는 부딪히지 않아요
	if m.kind == "elite":
		# 강적을 막지 못함 → 패배
		fx.shake(24.0, 0.5)
		_finish("elite")
		return
	super(m)


# 몬스터의 체력을 깎고, 0이 되면 터뜨려요.
func _wear(m, amount: float) -> void:
	m.hp -= amount
	m.flash = 0.12
	if m.hp <= 0.0:
		kills += 1
		fx.burst(m.center(), m.color(), 12, 1.1)
		_remove(m)


# ---------------------------------------------------------------- 강적

func _spawn_elite() -> void:
	elite_timer = Config.ELITE_INTERVAL
	elites_spawned += 1
	elite = super.spawn("elite", 1400.0)
	stage_elites += 1
	elite.max_hp = Config.ELITE_HP * (1.0 + Config.STAGE_ELITE_HP_GROWTH * (stage - 1)) \
			* (1.0 + Config.ELITE_ORDER_HP_GROWTH * (stage_elites - 1))
	if next_is_boss_now():
		# 최종 보스: 지금은 강적의 강화판(더 크고, 더 단단하고, 약점이 더 빨리 움직임)
		elite.boss = true
		elite.max_hp *= Config.BOSS_HP_MULT
		elite.w *= Config.BOSS_SIZE
		elite.h *= Config.BOSS_SIZE
	elite.hp = elite.max_hp
	elite.approach = Config.ELITE_APPROACH
	fx.shake(10.0, 0.3)
	_change_stance()


# 방금 나온(또는 곧 나올) 강적이 최종 보스인지
func next_is_boss_now() -> bool:
	return stage >= Config.STAGE_COUNT and stage_elites >= Config.ELITES_PER_STAGE


func next_is_boss() -> bool:
	return stage >= Config.STAGE_COUNT and stage_elites == Config.ELITES_PER_STAGE - 1


# 약점을 다른 곳으로 옮겨요(같은 곳이 연달아 나오지 않음).
func _change_stance() -> void:
	var lanes := ["high", "mid", "low"]
	var next: String = lanes.pick_random()
	while next == elite.weak:
		next = lanes.pick_random()
	elite.weak = next
	elite.squash = Vector2(1.15, 0.88)
	stance_t = _stance_time()
	# 판정 자리 근처에서 바로 보이게 알려요.
	if aiming():
		fx.text(Vector2(player.position.x + Config.RALLY_LAND - 40.0, Config.GROUND_Y - 210.0),
				"약점: %s" % AIM_NAME[next], AIM_COLOR[next], 34, 0.9)


func _collide() -> void:
	super()
	# 보낸 몬스터와 강적의 충돌
	if not elite_alive():
		return
	var er: Rect2 = elite.rect().grow(8.0)
	var total := 0.0
	var hit_at := Vector2.ZERO
	var last_lane := ""
	var last_weak := false
	for m in monsters.get_children():
		if m.dead or not m.shot or not m.alive():
			continue
		if not er.intersects(m.rect()):
			continue
		impacts += 1
		last_lane = m.lane
		lane_hits[m.lane] = lane_hits.get(m.lane, 0) + 1
		# 한 묶음이 부딪힐 때마다 강적이 돌려보내는 방식을 정해요.
		if since_impact > 0.35:
			_pick_return()
		since_impact = 0.0
		var dmg: float = Config.AMMO_DAMAGE.get(m.kind, 1.0) * heat_mult() * prof["dmg"] * _upgrade_dmg()
		if m.get_meta("spike", false):
			dmg *= Config.SPIKE_MULT
		# 약점에 맞으면 피해가 크고, 방패에 맞으면 크게 줄어요(겨냥이 없는 캐릭터는 그대로).
		var weak_hit: bool = aiming() and m.lane == elite.weak
		if aiming():
			dmg *= Config.WEAK_MULT if weak_hit else _block_mult()
			if weak_hit:
				weak_hits += 1
				_say(elite, "elite", 0.05)
				heat = minf(Config.HEAT_MAX, heat + Config.HEAT_WEAK)
			else:
				block_hits += 1
		last_weak = weak_hit
		total += dmg
		hit_at = m.center()
		elite.hp -= dmg
		if weak_hit or not aiming():
			elite.position.x = minf(elite.position.x + Config.ELITE_PUSH * prof["push"], Config.WALL_X)
		register_hit(hit_at, Config.SCORE_HIT)
		# 몬스터는 사라지지 않고, 체력이 닳은 채 튕겨 돌아와요.
		impact_i += 1
		_say(m, "impact", 0.15)
		_return(m, ret_type, impact_i % int(prof["waves"]))
		_wear(m, Config.AMMO_WEAR.get(m.kind, 1.0) * pow(0.65, lv("sturdy")))
	if total > 0.0:
		if aiming() and AIM_NAME.has(last_lane):
			fx.text(Vector2(elite.position.x - elite.w / 2.0 - 70.0,
					Config.GROUND_Y - elite.h * Config.AIM_HEIGHT[last_lane] + 8.0),
					"약점!" if last_weak else "막힘",
					AIM_COLOR[last_lane] if last_weak else Color("#B8C4CF"), 28 if last_weak else 20, 0.5)
		fx.star(hit_at, 1.2 + heat * 0.1)
		fx.text(hit_at + Vector2(randf_range(-24, 24), -50), str(int(round(total))),
				ChibiDraw.GOLD if heat >= 3.0 else Color.WHITE, 28 + int(heat), 0.5)
		fx.shake(6.0 + heat, 0.14)
		hitstop(Config.HITSTOP_IMPACT)
		elite.flash = 0.12
		elite.squash = Config.HIT_SQUASH
		if elite.hp <= 0.0:
			_kill_elite()


# 강적이 공을 어떻게 돌려보낼지: 랠리 초반은 보통, 이어질수록 빠른 공·높은 공이 섞여요.
func _pick_return() -> void:
	ret_type = "normal"
	if rally >= 3:
		var r := randf()
		if r < 0.25:
			ret_type = "fast"
		elif r < 0.5:
			ret_type = "lob"
	if RETURN_LABEL.has(ret_type):
		var info: Array = RETURN_LABEL[ret_type]
		fx.text(elite.center() + Vector2(-90, -elite.h / 2.0 - 30.0), info[0], info[1], 30, 0.7)
		elite.squash = Vector2(1.2, 0.85)


func _kill_elite() -> void:
	var e = elite
	elite = null
	for m in monsters.get_children():
		if not m.dead:
			m.set_meta("ret", false)
	elites_killed += 1
	score += 2000.0
	stage_kills += 1
	if stage_kills >= Config.ELITES_PER_STAGE:
		clear_delay = Config.STAGE_CLEAR_DELAY
	e.hp = 0.0
	e.state = "dying"
	e.launch(Config.BLAST_VX, Config.BLAST_VY)
	fx.star(e.center(), 2.4)
	fx.burst(e.center(), e.color(), 20, 1.3)
	fx.shake(22.0, 0.5)
	hitstop_t = Config.HITSTOP_BURST
	fx.text(e.center() + Vector2(0, -130), "최종 보스 격파!" if e.boss else "강적 격파!", ChibiDraw.GOLD, 52, 1.1)


func result_data() -> Dictionary:
	var d := super()
	d["elites"] = elites_killed
	var bought := 0
	for id: String in ups:
		bought += int(ups[id])
	d["upgrades"] = bought
	return d


func debug_rows() -> Array:
	var rows := super()
	rows.append("뭉친 몬스터 %d마리 · 열기 %.1f (피해 x%.1f) · 랠리 x%d" % [juggled, heat, heat_mult(), rally])
	rows.append("약점 명중 %d · 막힘 %d · PERFECT %d · 강적 %d/%d" % [
		weak_hits, block_hits, perfects, elites_killed, elites_spawned])
	return rows


# ---------------------------------------------------------------- 가게 화면과 입력

func shop_card_rect(i: int) -> Rect2:
	return Rect2(205 + i * 300, 210, 270, 270)


func shop_next_rect() -> Rect2:
	return Rect2(490, 548, 300, 64)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.SHOP:
		# 가게에서는 1 / 2 / 3(구매)과 Enter(다음 스테이지)만 받아요.
		# 공격·점프 등 다른 키는 눌러도 아무 일도 일어나지 않아요(연타하다가 가게를 지나치지 않게).
		# 열린 직후 잠깐은 그 키들도 받지 않아요.
		if shop_lock_t > 0.0:
			return
		if event is InputEventScreenTouch:
			if event.pressed:
				if shop_next_rect().has_point(event.position):
					_close_shop()
				for i in 3:
					if shop_card_rect(i).has_point(event.position):
						buy(i)
		elif event is InputEventKey and not event.echo:
			if event.is_action_pressed("confirm"):
				_close_shop()
			else:
				for i in 3:
					if event.is_action_pressed("pick_%d" % (i + 1)):
						buy(i)
		return
	super(event)


func _draw_shop(ci: CanvasItem) -> void:
	var have := _ammo().size()
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.06, 0.1, 0.78))
	ChibiDraw.text(ci, Vector2(640, 92), "스테이지 %d 클리어" % stage, 48, ChibiDraw.GOLD, 1, true)
	ChibiDraw.text(ci, Vector2(640, 136), "뭉치를 내고 강화를 사세요. 남긴 뭉치는 다음 스테이지로 가져가요.", 20,
			Color(1, 1, 1, 0.8), 1)
	ChibiDraw.text(ci, Vector2(640, 180), "가진 뭉치: %d마리" % have, 28, Color.WHITE, 1, true)
	for i in shop_offers.size():
		var r := shop_card_rect(i)
		var id: String = shop_offers[i]
		if id == "":
			ChibiDraw.panel(ci, r, Color(0.1, 0.11, 0.15, 0.9), 14, Color(1, 1, 1, 0.12), 2)
			ChibiDraw.text(ci, r.get_center() + Vector2(0, 8), "구매 완료", 24, Color(1, 1, 1, 0.4), 1, true)
			continue
		var u: Dictionary = UPGRADES[id]
		var cost := cost_of(id)
		var ok := have >= cost
		ChibiDraw.panel(ci, r, Color(0.16, 0.18, 0.25) if ok else Color(0.11, 0.12, 0.17), 14,
				ChibiDraw.GOLD if ok else Color(1, 1, 1, 0.18), 4 if ok else 2)
		ChibiDraw.text(ci, Vector2(r.get_center().x, r.position.y + 62), u["name"], 28,
				Color.WHITE if ok else Color(1, 1, 1, 0.55), 1, true)
		ChibiDraw.text(ci, Vector2(r.get_center().x, r.position.y + 104), u["desc"], 17, Color(1, 1, 1, 0.8), 1)
		ChibiDraw.text(ci, Vector2(r.get_center().x, r.position.y + 138), "단계 %d → %d (최대 %d)" % [
			lv(id), lv(id) + 1, int(u["max"])], 15, Color(1, 1, 1, 0.55), 1)
		ChibiDraw.panel(ci, Rect2(r.position.x + 55, r.position.y + 178, 160, 46),
				ChibiDraw.ORANGE if ok else Color(0.25, 0.26, 0.3), 12)
		ChibiDraw.text(ci, Vector2(r.get_center().x, r.position.y + 210), "%d마리" % cost, 24,
				Color.WHITE if ok else Color(1, 1, 1, 0.5), 1, true)
		ChibiDraw.text(ci, r.end + Vector2(-14, -12), "[%d]" % (i + 1), 15, Color(1, 1, 1, 0.5), 2)
	if shop_note_t > 0.0:
		ChibiDraw.text(ci, Vector2(640, 520), shop_note, 22, ChibiDraw.GOLD, 1, true, 6)
	var b := shop_next_rect()
	ChibiDraw.panel(ci, b, ChibiDraw.ORANGE, 14)
	ChibiDraw.text(ci, b.get_center() + Vector2(0, 10), "다음 스테이지 (Enter)", 24, Color.WHITE, 1, true)
	# 지금까지 산 강화
	var owned: Array = []
	for id: String in ups:
		owned.append("%s %d" % [UPGRADES[id]["name"], ups[id]])
	if not owned.is_empty():
		ChibiDraw.text(ci, Vector2(640, 650), "보유: " + " · ".join(owned), 15, Color(1, 1, 1, 0.6), 1)


# 검증용 자동 플레이의 가게 판단: 뭉치를 6마리는 남기면서 살 수 있는 것을 사고 넘어가요.
func bot_shop() -> void:
	for i in shop_offers.size():
		var id: String = shop_offers[i]
		if id != "" and _ammo().size() - cost_of(id) >= 6:
			buy(i)
			return
	_close_shop()


# ---------------------------------------------------------------- 말풍선(재미용)

# 몬스터 m이 상황(what)에 맞는 대사를 말해요. chance는 말할 확률이에요.
func _say(m, what: String, chance := 1.0) -> void:
	if not Config.BUBBLES or bubbles.size() >= Config.BUBBLE_MAX or randf() > chance:
		return
	for b: Dictionary in bubbles:
		if b.m == m:
			return       # 이미 말하는 중
	var lines: Array = GROANS[what]
	var own: Dictionary = GROANS_BY_KIND.get(m.kind, {})
	if own.has(what) and randf() < 0.6:
		lines = own[what]
	# 지금 떠 있는 말풍선이 쓰지 않는 자리 중 하나를 골라요.
	var free: Array = []
	for i in BUBBLE_SLOTS.size():
		var used := false
		for b: Dictionary in bubbles:
			if b.slot == i:
				used = true
		if not used:
			free.append(i)
	var slot: int = free.pick_random() if not free.is_empty() else randi() % BUBBLE_SLOTS.size()
	bubbles.append({"m": m, "text": lines.pick_random(), "t": 0.0, "slot": slot,
			"jit": Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))})


func _update_bubbles(rdt: float) -> void:
	for b: Dictionary in bubbles:
		b.t += rdt
	bubbles = bubbles.filter(func(b: Dictionary) -> bool:
		return b.t < Config.BUBBLE_TIME and is_instance_valid(b.m) and not b.m.dead)
	# 가만히 튀고 있는 몬스터가 가끔 혼잣말을 해요.
	bubble_cd -= rdt
	if bubble_cd <= 0.0:
		bubble_cd = randf_range(Config.BUBBLE_IDLE_MIN, Config.BUBBLE_IDLE_MAX)
		var pool: Array = []
		for m in monsters.get_children():
			if m.alive() and m.is_monster() and not m.shot and (m.state == "fly" or m.state == "groggy"):
				pool.append(m)
		if not pool.is_empty():
			_say(pool.pick_random(), "idle")


func _draw_bubbles(ci: CanvasItem) -> void:
	var gy := Config.GROUND_Y
	var f := ChibiDraw.font()
	var placed: Array = []      # 이미 그린 말풍선의 자리(겹침 방지용)
	for b: Dictionary in bubbles:
		var m = b.m
		if not is_instance_valid(m) or m.dead:
			continue
		var a: float = clampf(minf(b.t / 0.1, (Config.BUBBLE_TIME - b.t) / 0.25), 0.0, 1.0)
		var pop: float = 1.0 + maxf(0.0, 0.12 - b.t) * 2.5
		var size := int(17 * pop)
		var tw: float = f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var bw: float = tw + 20.0
		# 말하는 몬스터의 머리에서, 이 말풍선의 자리만큼 떨어진 곳
		var head := Vector2(m.position.x, gy - m.lift - m.h * 0.7)
		var slot: Vector2 = BUBBLE_SLOTS[b.slot]
		var c: Vector2 = head + slot + b.jit + Vector2(0, -b.t * 8.0)
		c.x = clampf(c.x, bw / 2.0 + 12.0, 1280.0 - bw / 2.0 - 12.0)
		c.y = clampf(c.y, 44.0, gy - 30.0)
		var box := Rect2(c.x - bw / 2.0, c.y - 14.0, bw, 28.0)
		# 다른 말풍선과 겹치면 위로 밀어 올려요.
		for _i in 6:
			var hit := false
			for other: Rect2 in placed:
				if box.grow(4.0).intersects(other):
					box.position.y = other.position.y - box.size.y - 6.0
					hit = true
			if not hit:
				break
		box.position.y = maxf(box.position.y, 30.0)
		placed.append(box)
		var bc := box.get_center()
		# 꼬리: 말풍선 가장자리에서 말하는 몬스터 쪽으로
		var edge := Vector2(clampf(head.x, box.position.x + 12.0, box.end.x - 12.0),
				clampf(head.y, box.position.y, box.end.y))
		var to_m := head - edge
		if to_m.length() > 6.0:
			var dir := to_m.normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := edge + dir * minf(18.0, to_m.length() * 0.5)
			var root := edge.lerp(bc, 0.25)
			ci.draw_colored_polygon(PackedVector2Array([root + side * 7.0, root - side * 7.0, tip]),
					Color(1, 1, 1, 0.95 * a))
		ChibiDraw.panel(ci, box, Color(1, 1, 1, 0.95 * a), 11, Color(0.15, 0.15, 0.22, 0.85 * a), 2)
		ChibiDraw.text(ci, Vector2(bc.x, bc.y + 6.0), b.text, size, Color(0.12, 0.12, 0.2, a), 1)


# ---------------------------------------------------------------- 자동 플레이용

func bot_step(_use_skills: bool) -> String:
	# 약점이 위·아래일 때는 뭉치가 돌아오는 박자에 맞춰 미리 뛰어요.
	if aiming() and rallying() and player.on_ground and elite.weak != "mid":
		for m in monsters.get_children():
			if not (m.alive() and m.incoming):
				continue
			# 위: 맞히기 직전에 뛰어서 올라가는 중에 침 / 아래: 정점 무렵에 뛰어서 떨어지며 침
			var go: bool = (m.vy > 0.0 and m.lift < 270.0) if elite.weak == "high" else (m.vy > -120.0)
			if go:
				do_jump()
				break
	# 공중 받아치기 캐릭터: 뭉치가 내려오기 시작하면 미리 뛰어올라요.
	if prof["air"] and rallying():
		var hy: float = Config.GROUND_Y - player.y
		for m in monsters.get_children():
			if not (m.alive() and m.incoming):
				continue
			var dx: float = m.position.x - player.position.x
			if player.on_ground:
				if dx < 480.0:
					do_jump()
					break
			elif dx - m.w / 2.0 < 200.0 and m.lift < hy + 110.0:
				do_attack()
				break
		# 떠 있는 동안에는 계속 휘둘러서 높이를 유지해요.
		if not player.on_ground and hy > 60.0:
			do_attack()
	return "rally" if rally >= 3 else ""


func bot_report(peak: int) -> String:
	return "[juggle] %s(%s) · 스테이지 %d · 흩어짐 %d회 · 강화 %s · 장애물 %d개 · 강적 %d/%d 격파 ·보내기 %d회(PERFECT %d, GOOD %d) · 최대 랠리 %d · 명중 %d · 최대 동시 %d마리" % [
		Characters.name_of(party.lead()), prof["name"], stage, scatters, str(ups), obstacles_spawned, elites_killed, elites_spawned, sends, perfects, goods, best_rally, impacts, peak] + (" · 겨냥 위 %d / 가운데 %d / 아래 %d · 약점 %d / 막힘 %d" % [
		lane_hits.get("high", 0), lane_hits.get("mid", 0), lane_hits.get("low", 0), weak_hits, block_hits]) \
			+ (" · 빠름 %d / 늦음 %d / 놓침 %d" % [earlies, lates, drops])


# ---------------------------------------------------------------- HUD

func draw_hud_extra(ci: CanvasItem, pulse: float) -> void:
	var glow := 0.5 + 0.5 * sin(pulse * 14.0)
	var gy := Config.GROUND_Y
	var on := rallying()

	# 튕겨 온 뭉치가 떨어지는 자리
	if on:
		var lx: float = player.position.x + Config.RALLY_LAND
		if prof["air"]:
			# 뭉치가 떠 있을 자리(공중)
			var ap := Vector2(lx, gy - float(prof["apex"]) - 20.0)
			ci.draw_arc(ap, 58.0 + glow * 4.0, 0.0, TAU, 36, Color(1.0, 0.85, 0.3, 0.4 + glow * 0.3), 4.0)
			ci.draw_dashed_line(ap + Vector2(0, 62), Vector2(lx, gy), Color(1.0, 0.85, 0.3, 0.25), 2.0, 8.0)
		var ring: Color = AIM_COLOR[current_aim()] if aiming() else Color(1.0, 0.85, 0.3)
		ci.draw_arc(Vector2(lx, gy + 6.0), 46.0, PI, TAU, 24, Color(ring.r, ring.g, ring.b, 0.45 + glow * 0.3), 5.0)
		ci.draw_line(Vector2(lx - 46, gy + 6), Vector2(lx + 46, gy + 6), Color(ring.r, ring.g, ring.b, 0.6), 3.0)
		if prof["roll"]:
			# 땅볼 판정 구간과 표시선
			var half: float = prof["line_px"]
			ci.draw_rect(Rect2(lx - half, gy - 70, half * 2.0, 76), Color(1.0, 0.85, 0.3, 0.14 + glow * 0.1))
			ci.draw_line(Vector2(lx, gy - 80), Vector2(lx, gy + 8), Color(1.0, 0.85, 0.3, 0.9), 4.0)

	# 겨냥 표시. 시선이 머무는 판정 자리에서 바로 읽히도록 세 가지를 그려요.
	#   1) 떨어지는 자리 위의 큰 화살표(지금 치면 날아갈 방향, 높이별 색)
	#   2) 거기서 강적까지의 예상 궤적(점선)
	#   3) 강적 앞의 위·가운데·아래 표시(지금 겨냥이 밝게)
	if on and aiming():
		var now_aim := current_aim()
		var acol: Color = AIM_COLOR[now_aim]
		var ax: float = elite.position.x - elite.w / 2.0 - 34.0
		var from := Vector2(player.position.x + Config.RALLY_LAND, gy - 50.0)
		var to := Vector2(ax - 16.0, gy - elite.h * Config.AIM_HEIGHT[now_aim])

		# 2) 예상 궤적: 실제로 보낼 때와 같은 식으로 계산해요.
		var svx: float = Config.SHOT_VX * prof["send"] * (1.0 + heat * Config.HEAT_SPEED)
		var ft: float = maxf(0.05, (to.x - from.x) / (svx - (scroll - elite.approach)))
		var l0: float = gy - from.y
		var l1: float = gy - to.y
		var v0: float = (l1 - l0 + 0.5 * Config.GRAVITY * ft * ft) / ft
		var prev := from
		var steps := 14
		for i in range(1, steps + 1):
			var k := float(i) / steps
			var tt := ft * k
			var pt := Vector2(lerpf(from.x, to.x, k), gy - (l0 + v0 * tt - 0.5 * Config.GRAVITY * tt * tt))
			if i % 2 == 1:
				ci.draw_line(prev, pt, Color(acol.r, acol.g, acol.b, 0.45), 3.0)
			prev = pt

		# 1) 판정 자리의 방향 화살표
		var first := Vector2(lerpf(from.x, to.x, 1.0 / steps), gy - (l0 + v0 * ft / steps
				- 0.5 * Config.GRAVITY * pow(ft / steps, 2.0)))
		var dir := (first - from).normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := from + dir * 78.0
		var neck := from + dir * 44.0
		ci.draw_line(from - dir * 6.0, neck, Color(0, 0, 0, 0.45), 18.0)
		ci.draw_line(from - dir * 6.0, neck, acol, 12.0)
		ci.draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, neck + side * 27.0, neck - side * 27.0]),
				Color(0, 0, 0, 0.45))
		ci.draw_colored_polygon(PackedVector2Array([tip, neck + side * 22.0, neck - side * 22.0]), acol)
		ChibiDraw.text(ci, from + Vector2(0, -34.0) - side * 0.0, AIM_NAME[now_aim], 22, acol, 1, true, 7)

		# 4) 약점 표시(판정 자리 바로 옆). 강적을 보지 않아도 약점이 어디인지 알 수 있어요.
		#    세 칸(위·가운데·아래) 중 약점 칸이 그 색으로 빛나고, 흰 테두리가 지금 내 겨냥이에요.
		var weak: String = elite.weak
		if AIM_COLOR.has(weak):
			var wcol: Color = AIM_COLOR[weak]
			var hit_now: bool = weak == now_aim
			var blink := 1.0
			if stance_t < Config.STANCE_WARN:
				blink = 0.35 + 0.65 * absf(sin(pulse * 22.0))      # 곧 바뀐다는 신호
			# 판정 자리에 약점 방향의 빈 화살표(틀)를 그려요. 내 화살표가 이 틀에 들어맞으면 약점이에요.
			var gdir := _aim_dir(from, weak, ax)
			var gside := Vector2(-gdir.y, gdir.x)
			var gneck := from + gdir * 44.0
			var gtip := from + gdir * 86.0
			var gback := from - gdir * 8.0
			var frame := PackedVector2Array([gtip, gneck + gside * 28.0, gneck + gside * 10.0,
				gback + gside * 10.0, gback - gside * 10.0, gneck - gside * 10.0, gneck - gside * 28.0, gtip])
			ci.draw_polyline(frame, Color(0, 0, 0, 0.5 * blink), 8.0)
			ci.draw_polyline(frame, Color(wcol.r, wcol.g, wcol.b, blink), 4.0)
			var bx: float = player.position.x - 88.0     # 캐릭터 바로 뒤(아무것도 지나가지 않는 자리)
			ChibiDraw.panel(ci, Rect2(bx - 30.0, gy - 206.0, 60.0, 168.0), Color(0.08, 0.1, 0.15, 0.7), 12)
			var order := ["high", "mid", "low"]
			for i in order.size():
				var lane2: String = order[i]
				var pc := Vector2(bx, gy - 174.0 + i * 50.0)
				var lc2: Color = AIM_COLOR[lane2]
				if lane2 == weak:
					ci.draw_circle(pc, 20.0 + glow * 3.0, Color(lc2.r, lc2.g, lc2.b, 0.35 * blink))
					ci.draw_circle(pc, 16.0, Color(lc2.r, lc2.g, lc2.b, blink))
					ci.draw_line(pc + Vector2(-8, 0), pc + Vector2(8, 0), Color(0, 0, 0, 0.7), 3.0)
					ci.draw_line(pc + Vector2(0, -8), pc + Vector2(0, 8), Color(0, 0, 0, 0.7), 3.0)
				else:
					ci.draw_circle(pc, 9.0, Color(lc2.r, lc2.g, lc2.b, 0.25))
				if lane2 == now_aim:
					ci.draw_arc(pc, 23.0, 0.0, TAU, 28, Color.WHITE, 3.0)
			if hit_now:
				ChibiDraw.text(ci, Vector2(bx, gy - 214.0), "약점!", 22, wcol, 1, true, 7)
				ci.draw_arc(from, 40.0 + glow * 6.0, 0.0, TAU, 28, Color(wcol.r, wcol.g, wcol.b, 0.7), 4.0)
			else:
				ChibiDraw.text(ci, Vector2(bx, gy - 214.0), AIM_HOW[weak], 15, wcol, 1, true, 6)

		# 3) 강적 앞 표시
		for lane: String in ["high", "mid", "low"]:
			var ay: float = gy - elite.h * Config.AIM_HEIGHT[lane]
			var sel: bool = lane == now_aim
			var lc: Color = AIM_COLOR[lane]
			var col := lc if sel else Color(lc.r, lc.g, lc.b, 0.3)
			var sz := 16.0 if sel else 9.0
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(ax - sz, ay - sz * 0.7), Vector2(ax + sz * 0.6, ay), Vector2(ax - sz, ay + sz * 0.7)]), col)
			if sel:
				ci.draw_arc(Vector2(ax + 20.0, ay), 22.0 + glow * 4.0, 0.0, TAU, 24, col, 4.0)
	# 강적 체력
	if elite_alive():
		ChibiDraw.panel(ci, Rect2(410, 80, 460, 66), Color(0.3, 0.08, 0.1, 0.85))
		ChibiDraw.text(ci, Vector2(426, 100), "최종 보스" if elite.boss else "강적", 15, Color.WHITE, 0, true)
		var left: float = maxf(0.0, elite.position.x - elite.w / 2.0 - player.position.x)
		ChibiDraw.text(ci, Vector2(854, 100), "거리 %dm" % int(left / Config.PX_PER_METER), 15, Color.WHITE, 2)
		ChibiDraw.bar(ci, Rect2(426, 106, 428, 12), elite.hp / elite.max_hp, Color("#FF5A5A"))
		var hint: String = prof["hint"]
		if aiming() and AIM_NAME.has(elite.weak):
			hint = "약점: %s · %s (%.1f초 뒤 바뀜)" % [AIM_NAME[elite.weak], AIM_HOW[elite.weak], maxf(0.0, stance_t)]
		ChibiDraw.text(ci, Vector2(640, 138), hint, 15,
				Color.WHITE, 1, true)
	elif warn_t > 0.0:
		ChibiDraw.panel(ci, Rect2(340, 150, 600, 64), Color(0.75, 0.1, 0.12, 0.6 + glow * 0.3), 10)
		ChibiDraw.text(ci, Vector2(640, 192),
				"최종 보스 접근! 몬스터를 뭉치세요" if next_is_boss() else "강적 접근! 몬스터를 뭉치세요",
				30, Color.WHITE, 1, true)

	# 열기
	var ratio := heat / Config.HEAT_MAX
	var bar := Rect2(410, 590, 460, 18)
	var hot := Color("#7FA8FF").lerp(Color("#FF5A2A"), ratio)
	ChibiDraw.panel(ci, bar.grow(5.0), ChibiDraw.PANEL, 8)
	var bar_col: Color = hot.lightened(glow * 0.25 * ratio)
	ChibiDraw.bar(ci, bar, ratio, bar_col)
	ChibiDraw.text(ci, bar.get_center() + Vector2(0, 6), "%s · 열기 · 피해 x%.1f" % [prof["name"], heat_mult()], 14,
			Color.WHITE, 1, true, 4)

	if rally >= 2:
		ChibiDraw.text(ci, Vector2(1190, 250), "랠리 x%d" % rally, 30, ChibiDraw.GOLD, 2, true, 8)
	if juggled > 0:
		ChibiDraw.text(ci, Vector2(1190, 280), "뭉친 몬스터 %d마리" % juggled, 16, Color.WHITE, 2, false, 6)
	_draw_bubbles(ci)
	if verdict_t > 0.0:
		var vk := 1.0 - verdict_t / 0.3
		ci.draw_arc(Vector2(rally_line(), gy - 45.0), 46.0 + vk * 120.0, 0.0, TAU, 44,
				Color(verdict_col.r, verdict_col.g, verdict_col.b, 1.0 - vk), 4.0 + 12.0 * (1.0 - vk))
	if flash_t > 0.0:
		ci.draw_rect(Rect2(0, 0, 1280, 720),
				Color(flash_col.r, flash_col.g, flash_col.b, 0.28 * minf(1.0, flash_t / 0.1)))
	if state == State.SHOP:
		_draw_shop(ci)
	if banner_t > 0.0:
		var k := clampf((Config.STAGE_BANNER_TIME - banner_t) / 0.15, 0.0, 1.0) * clampf(banner_t / 0.25, 0.0, 1.0)
		ci.draw_rect(Rect2(0, 262, 1280, 96.0 * k), Color(0.1, 0.12, 0.2, 0.8))
		if k > 0.85:
			ChibiDraw.text(ci, Vector2(640, 332), "STAGE %d" % stage, 64, ChibiDraw.GOLD, 1, true, 10)
