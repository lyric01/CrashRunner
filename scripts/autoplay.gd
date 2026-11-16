extends Node
# 검증용 자동 플레이. 실행 인자 뒤에 `-- --autoplay`를 붙이면 켜져요.
#   --fast                  : 4배속(헤드리스 검증용)
#   --char=<id>             : 고를 캐릭터(bear / wolf / cow / rabbit)
#   --shots=<폴더>          : 주요 장면을 PNG로 저장
#   --pattern=orc:0,bat:200 : 이 무리만 반복 스폰(패턴 실험용)
#   --stop-after-elite=2    : 첫 강적을 잡고 2초 뒤에 종료(녹화용)
#   --hit-at=8              : 게임 시간 8초에 일부러 한 대 맞음(뭉치 흩어짐 확인용)
# 게임 로직은 건드리지 않고 game의 입력 함수만 눌러요. 최종 보스를 잡거나 지면 끝나요.

var game
var shots_dir := ""
var taken := {}
var done := false
var wait := 0.0
var runs: Array = []       # 끊긴 저글들의 길이
var last_run := 0
var peak_air := 0          # 동시에 떠 있던 몬스터의 최대 수
var stop_after_elite := -1.0   # 0 이상이면 첫 강적 격파 후 이 시간(초) 뒤 종료
var elite_wait := 0.0
var hit_at := -1.0         # 0 이상이면 이 시각에 일부러 한 대 맞음
var hit_done := false
var pick := ""             # --char= 로 지정한 캐릭터
var bats_hit := 0          # 공중 적을 치려고 휘두른 횟수(프레임 기준, 참고용)
var doubles := 0           # 더블 점프를 쓴 횟수


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--fast":
			Engine.time_scale = 4.0
		elif a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--stop-after-elite="):
			stop_after_elite = float(a.trim_prefix("--stop-after-elite="))
		elif a.begins_with("--hit-at="):
			hit_at = float(a.trim_prefix("--hit-at="))
		elif a.begins_with("--char="):
			pick = a.trim_prefix("--char=")
		elif a.begins_with("--pattern="):
			var list: Array = []
			for part in a.trim_prefix("--pattern=").split(","):
				var kv := part.split(":")
				list.append([kv[0], float(kv[1])])
			game.spawner.override = list


func _process(delta: float) -> void:
	if done:
		return
	if stop_after_elite >= 0.0 and game.elites_killed >= 1:
		elite_wait += delta
		if elite_wait >= stop_after_elite:
			done = true
			print("[autoplay] 첫 강적 격파 후 %.1f초, 종료 (게임 시간 %.1f초)" % [elite_wait, game.stage_time])
			get_tree().quit()
			return
	if game.state == game.State.SELECT:
		wait += delta
		_shot("select")
		if wait > 0.6:
			wait = 0.0
			if pick != "":
				game.select.picks = [pick]
			game.select.confirm()
		return
	if game.state == game.State.SHOP:
		_shot("shop")
		wait += delta
		if wait > 0.4:
			wait = 0.0
			game.bot_shop()
		return
	if game.state == game.State.RESULT:
		done = true
		var total := 0
		for n: int in runs:
			total += n
		print("[autoplay] 결과=%s hp=%d 점수=%d 최대콤보=%d 처치=%d 더블점프=%d 공중적공격=%d" % [
			game.result_reason, game.hp, int(game.score), game.max_combo, game.kills, doubles, bats_hit])
		print("[autoplay] 저글 묶음 %d개(평균 %.1f회, 최대 x%d) · 동시에 뜬 몬스터 최대 %d마리" % [
			runs.size(), float(total) / maxi(1, runs.size()), game.max_juggle, peak_air])
		print(game.bot_report(peak_air))
		await _shot("result")
		get_tree().quit()
		return

	if hit_at >= 0.0 and not hit_done and game.stage_time >= hit_at:
		hit_done = true
		var before: int = game._ammo().size()
		var hp0: int = game.hp
		game.invuln = 0.0
		game.damage(1)
		print("[autoplay] 일부러 맞음: 뭉치 %d마리, 체력 %d → %d, 흩어짐 %d회" % [before, hp0, game.hp, game.scatters])
	if hit_done and game.stage_time >= hit_at + 0.35:
		_shot("scatter")
	# 통계: 저글이 끊길 때마다 길이를 기록, 동시에 떠 있는 몬스터 수
	if game.juggle_run == 0 and last_run > 0:
		runs.append(last_run)
	last_run = game.juggle_run
	var air := 0
	for m in game.monsters.get_children():
		if m.alive() and (m.state == "fly" or m.state == "groggy"):
			air += 1
	peak_air = maxi(peak_air, air)

	# 강적전의 판단(약점에 맞춰 점프 등)은 게임 쪽 bot_step에 맡겨요.
	if game.elite != null:
		_shot("elite")
	var did: String = game.bot_step(true)
	if did != "":
		_shot(did)
	for mm in game.monsters.get_children():
		if mm.alive() and mm.incoming and mm.lift > 120.0 and mm.vy > 0.0:
			_shot("incoming")
			break
	if game.juggle_run >= 3:
		_shot("juggle")

	var pl = game.player
	var px: float = pl.position.x
	for m in game.monsters.get_children():
		if not m.alive():
			continue
		var dx: float = m.position.x - px
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
		# 튀고 있는 몬스터는 손 닿는 높이로 내려왔을 때 다시 쳐요.
		if m.state == "fly":
			_shot("fly")
			if not (m.lift < 100.0 and m.vx < 400.0):
				continue
		var edge: float = m.position.x - m.w / 2.0 - px
		if edge > -20.0 and edge < 170.0:
			game.do_attack()


func _shot(tag: String) -> void:
	if shots_dir == "" or taken.has(tag):
		return
	taken[tag] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(tag + ".png"))
