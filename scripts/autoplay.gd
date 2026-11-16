extends Node
# 검증용 자동 플레이. 실행 인자 뒤에 `-- --autoplay`를 붙이면 켜져요.
#   --fast          : 4배속(헤드리스 검증용)
#   --shots=<폴더>  : 주요 장면을 PNG로 저장
#   --nochain       : 그로기 중에는 공격 버튼을 누르지 않음(비교용)
# 게임 로직은 건드리지 않고 game의 입력 함수만 눌러요.

var game
var shots_dir := ""
var taken := {}
var done := false
var use_chain := true
var wait := 0.0
var react := 0.0
var runs: Array = []       # 끊긴 연쇄들의 길이
var last_run := 0
var peak_air := 0
var want_juggle := false
var stop_after_elite := -1.0   # 0 이상이면 첫 강적 격파 후 이 시간(초) 뒤 종료
var elite_wait := 0.0
var pick := ""            # --char= 로 지정한 캐릭터
var bats_hit := 0          # 공중 적을 치려고 휘두른 횟수(프레임 기준, 참고용)
var doubles := 0          # 더블 점프를 쓴 횟수
var air_hits := 0          # 점프 중에 공격을 시도한 프레임 수(참고용)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--juggle":
			want_juggle = true
		elif a == "--fast":
			Engine.time_scale = 4.0
		elif a == "--nochain":
			use_chain = false
		elif a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--stop-after-elite="):
			# 예: --stop-after-elite=2 → 첫 강적을 잡고 2초 뒤에 종료(녹화용)
			stop_after_elite = float(a.trim_prefix("--stop-after-elite="))
		elif a.begins_with("--char="):
			pick = a.trim_prefix("--char=")      # 예: --char=wolf (저글링 모드에서 고를 캐릭터)
		elif a.begins_with("--pattern="):
			# 예: --pattern=orc:0,slime:150,steel:330  → 이 무리만 반복 스폰
			var list: Array = []
			for part in a.trim_prefix("--pattern=").split(","):
				var kv := part.split(":")
				list.append([kv[0], float(kv[1])])
			game.spawner.override = list


func _process(delta: float) -> void:
	if done:
		return
	var killed = game.get("elites_killed")      # 저글링 모드에만 있는 값
	if stop_after_elite >= 0.0 and killed != null and killed >= 1:
		elite_wait += delta
		if elite_wait >= stop_after_elite:
			done = true
			print("[autoplay] 첫 강적 격파 후 %.1f초, 종료 (게임 시간 %.1f초)" % [elite_wait, game.stage_time])
			get_tree().quit()
			return
	if game.state == game.State.SELECT:
		if want_juggle and game.mode() != "juggle":
			done = true
			game.switch_mode()      # 새 씬이 자동 플레이를 다시 붙여요
			return
		wait += delta
		_shot("select")
		if wait > 0.6:
			if pick != "" and game.party_size() == 1:
				game.select.picks = [pick]
			game.select.confirm()
		return
	if game.state == game.State.RESULT:
		done = true
		print("[autoplay] 결과=%s hp=%d 점수=%d 최대콤보=%d 처치=%d 더블점프=%d 공중적공격=%d" % [
			game.result_reason, game.hp, int(game.score), game.max_combo, game.kills, doubles, bats_hit])
		print("[autoplay] 충돌 %d회(죽으며 %d회) → 그로기 %d회 → 연계기 %d회, 최대 연쇄 x%d" % [
			game.bowl_total, game.dying_bowls, game.groggy_total, game.chain_total, game.max_chain])
		var total := 0
		var long := 0
		for n: int in runs:
			total += n
			if n >= 3:
				long += 1
		print("[stat] 연쇄묶음=%d 평균=%.2f 3회이상=%d 최대=%d 연계기=%d 충돌=%d 처치=%d 잃은체력=%d 동시최대=%d" % [
			runs.size(), float(total) / maxi(1, runs.size()), long, game.max_chain,
			game.chain_total, game.bowl_total, game.kills, Config.PARTY_HP - game.hp, peak_air])
		if game.has_method("bot_report"):
			print(game.bot_report(peak_air))
		await _shot("result")
		get_tree().quit()
		return
	# 통계: 연쇄가 끊길 때마다 길이를 기록, 동시에 떠 있는(날아가거나 그로기인) 몬스터 수
	if game.chain_run == 0 and last_run > 0:
		runs.append(last_run)
	last_run = game.chain_run
	var air := 0
	for m in game.monsters.get_children():
		if m.alive() and (m.state == "fly" or m.state == "groggy"):
			air += 1
	peak_air = maxi(peak_air, air)
	# 저글링 모드: 게이지 연계기가 준비되면 바로 사용
	if game.has_method("bot_step"):
		if game.elite != null:
			_shot("elite")
		var did: String = game.bot_step(use_chain)
		# 타이밍 고리 확인용: 뭉치가 튕겨 오는 도중의 장면
		for mm in game.monsters.get_children():
			if mm.alive() and mm.incoming and mm.lift > 120.0 and mm.vy > 0.0:
				_shot("incoming")
				break
		if did != "":
			_shot(did)
	# 그로기를 보고 0.2초 뒤에 누르는 사람 흉내
	if game.chain_ready():
		react += delta
		_shot("groggy")
		if use_chain and react >= 0.2:
			game.do_attack()
			react = 0.0
			_shot("chain")
	else:
		react = 0.0
	if game.chain_run >= 3:
		_shot("chain3")
	var px: float = game.player.position.x
	for m in game.monsters.get_children():
		if not m.alive():
			continue
		var dx: float = m.position.x - px
		var pl = game.player
		# 내려오는 중인데 발밑에 장애물이 있으면 더블 점프로 한 번 더 넘어요.
		var dropping: bool = not pl.on_ground and not pl.falling and pl.vy > 150.0 \
				and pl.y > Config.GROUND_Y - 150.0 and pl.air_jumps > 0
		if m.kind == "steel":
			if pl.on_ground and dx > 120.0 and dx < 215.0:
				game.do_jump()
			elif dropping and dx > -20.0 and dx < 150.0:
				game.do_jump()
				doubles += 1
				_shot("double")
			continue
		if m.kind == "pit":
			var gap: float = dx - m.w / 2.0
			if pl.on_ground and gap > 0.0 and gap < 70.0:
				game.do_jump()
				_shot("pit")
			elif dropping and gap < 60.0 and gap > -m.w + 30.0:
				game.do_jump()
				doubles += 1
				_shot("double")
			continue
		# 공중 적: 다가오면 뛰어올라서 쳐요.
		if m.kind == "bat" and m.air_h > 0.0:
			var be: float = m.position.x - m.w / 2.0 - px
			if pl.on_ground and be > 80.0 and be < 270.0:
				game.do_jump()
			elif not pl.on_ground and be > -20.0 and be < 200.0:
				game.do_attack()
				bats_hit += 1
				_shot("bat")
			continue
		if m.state == "fly":
			_shot("fly")
			# 저글링 모드에서는 튀고 있는 몬스터도 손 닿는 높이면 다시 쳐요.
			if not (game.mode() == "juggle" and m.lift < 100.0 and m.vx < 400.0):
				continue
		var edge: float = m.position.x - m.w / 2.0 - px
		# 저글링 모드: 점프 중에도 공격해서 흐름을 이어 가요.
		if game.mode() == "juggle" and not game.player.on_ground and edge > -20.0 and edge < 120.0:
			air_hits += 1
		if edge > -20.0 and edge < 170.0 and not (game.chain_ready() and not use_chain):
			game.do_attack()


func _shot(tag: String) -> void:
	if shots_dir == "" or taken.has(tag):
		return
	taken[tag] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(tag + ".png"))
