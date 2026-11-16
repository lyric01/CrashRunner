extends Node2D
# 선두 캐릭터: 점프와 공격. 화면 x는 고정이고 공격할 때만 앞으로 튀어나갔다 돌아와요.

const STRIKE_TIME := 0.28

var game
var y: float = Config.GROUND_Y
var vy := 0.0
var on_ground := true
var falling := false       # 낭떠러지로 떨어지는 중
var fall_t := 0.0          # 떨어지기 시작한 뒤 지난 시간(코요테 타임 판정)
var air_jumps: int = Config.AIR_JUMPS   # 남은 공중 점프 횟수
var swing_time: float = Config.ATTACK_DURATION     # 휘두르는 시간(캐릭터에 따라 달라질 수 있음)
var cooldown_time: float = Config.ATTACK_COOLDOWN  # 다음 공격까지 걸리는 시간
var air_stall := false      # 공중에서 휘두르는 동안 떨어지지 않음(토끼의 체공)
var reach_mult := 1.0       # 공격 판정 폭 배율(강화 '넓은 휘두르기')
var air_reach_down := false  # 공중 공격 판정을 바닥까지 늘림(저글링 모드)
var swinging := false
var atk_t := 0.0
var atk_cd := 0.0
var serial := 0            # 휘두르기 번호(한 번에 같은 대상을 두 번 치지 않게)
var recoil := 0.0
var phase := 0.0
var strike_t := 0.0        # 연계 타격 연출
var strike_pos := Vector2.ZERO


func char_id() -> String:
	return game.party.lead()


func try_jump() -> void:
	var mult := Config.RABBIT_JUMP_MULT if char_id() == "rabbit" else 1.0
	# 코요테 타임: 낭떠러지로 떨어지기 시작한 직후에는 아직 땅에서 뛴 것으로 쳐 줘요.
	var coyote := falling and fall_t <= Config.COYOTE_TIME
	if (on_ground and not falling) or coyote:
		if coyote:
			y = Config.GROUND_Y
		falling = false
		on_ground = false
		vy = Config.JUMP_VELOCITY * mult
		return
	# 더블 점프: 공중에서 한 번 더. 낭떠러지에 막 빠진 참이면 빠져나올 수도 있어요.
	if air_jumps <= 0:
		return
	if falling and y > Config.GROUND_Y + Config.PIT_RESCUE_DEPTH:
		return
	air_jumps -= 1
	falling = false
	vy = Config.DOUBLE_JUMP_VELOCITY * mult
	game.fx.burst(Vector2(position.x, y - 8.0), Color(1, 1, 1), 5, 0.35)
	game.fx.star(Vector2(position.x, y), 0.6)


func try_attack() -> bool:
	if falling or swinging or atk_cd > 0.0:
		return false
	swinging = true
	atk_t = 0.0
	atk_cd = cooldown_time
	serial += 1
	# 체공: 공중에서 공격하면 떨어지던 속도가 사라지고 살짝 떠올라요.
	if air_stall and not on_ground and not falling:
		vy = minf(vy, Config.STALL_VY)
	return true


func attacking() -> bool:
	return swinging


func bounce_back() -> void:
	swinging = false
	recoil = -70.0


func start_fall() -> void:
	falling = true
	fall_t = 0.0
	on_ground = false
	swinging = false
	vy = 260.0


func respawn() -> void:
	air_jumps = Config.AIR_JUMPS
	falling = false
	on_ground = true
	y = Config.GROUND_Y
	vy = 0.0


# pos 근처로 순간 이동하듯 날아가 치고 돌아와요. offset은 대상 기준으로 서는 자리예요.
func strike_at(pos: Vector2, offset := Vector2(-80, 30)) -> void:
	strike_t = STRIKE_TIME
	strike_pos = pos + offset
	swinging = false


func lunge() -> float:
	if not swinging:
		return 0.0
	return sin(atk_t / swing_time * PI) * Config.ATTACK_LUNGE


func body_rect() -> Rect2:
	return Rect2(position.x - 20, y - 78, 40, 76)


func attack_rect() -> Rect2:
	var top := y - 130.0
	# 저글링 모드: 공중에서 휘두르면 바닥까지 내려쳐서 아래에 있는 몬스터도 맞아요.
	var bottom := Config.GROUND_Y if air_reach_down and not on_ground else y
	return Rect2(position.x - 10, top, Config.ATTACK_REACH * reach_mult, bottom - top)


func update(dt: float) -> void:
	phase += dt * 16.0
	atk_cd -= dt
	strike_t -= dt
	recoil = move_toward(recoil, 0.0, 320.0 * dt)
	if swinging:
		atk_t += dt
		if atk_t >= swing_time:
			swinging = false
	# 점프는 공격과 따로 움직여요. 휘두르는 중에도 바로 뛰어오르고 떨어져요.
	if not on_ground:
		# 체공 중(공중에서 휘두르는 동안)에는 중력이 걸리지 않아요.
		# (점프로 솟구치는 중에는 평소대로 느려져야 하니, 올라가는 속도가 남아 있으면 적용하지 않아요.)
		if not (air_stall and swinging and not falling and vy >= Config.STALL_VY):
			vy += Config.GRAVITY * dt
		y += vy * dt
		if falling:
			fall_t += dt
			if y > Config.GROUND_Y + 190.0:
				game.on_pit_fall()
		elif y >= Config.GROUND_Y and vy >= 0.0:
			y = Config.GROUND_Y
			vy = 0.0
			on_ground = true
			air_jumps = Config.AIR_JUMPS
	position = Vector2(game.party.xpos[char_id()] + lunge() + recoil, y)
	if strike_t > 0.0:
		var k := sin((1.0 - strike_t / STRIKE_TIME) * PI)
		position = position.lerp(strike_pos, k)
	queue_redraw()


func _draw() -> void:
	if game == null or game.party.members.is_empty():
		return
	var alpha := 1.0
	if game.invuln > 0.0 and strike_t <= 0.0 and int(game.invuln * 20.0) % 2 == 0:
		alpha = 0.35
	var fast := swinging or strike_t > 0.0
	if swinging:
		# 제자리 휘두르기: 앞쪽으로 퍼지는 베기 궤적(판정 폭과 같은 거리까지)
		var p := clampf(atk_t / swing_time, 0.0, 1.0)
		var reach: float = Config.ATTACK_REACH * reach_mult - 10.0
		var a := 1.0 - p
		var sweep := lerpf(-0.8, 0.5, p)      # 위에서 앞쪽 아래로 내려 긋기
		for i in 3:
			var r := reach * (0.55 + i * 0.22)
			draw_arc(Vector2(-10, -62), r, sweep - 0.5, sweep + 0.3, 14,
					Color(1.0, 0.62 + i * 0.1, 0.2, (0.85 - i * 0.2) * a), 9.0 - i * 2.0)
	elif strike_t > 0.0:
		for i in 3:
			draw_rect(Rect2(-52 - i * 34, -64 + i * 16, 44 - i * 8, 9),
					Color(1.0, 0.55, 0.15, 0.75 - i * 0.2))
	ChibiDraw.chibi(self, char_id(), Vector2.ZERO, 1.0, {
		"alpha": alpha, "phase": phase if on_ground else 1.2, "dash": fast,
	})
	# 선두 표시
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -128), Vector2(9, -128), Vector2(0, -114)]), Color("#FF8A2A"))
