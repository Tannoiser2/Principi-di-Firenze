extends SceneTree
## Prova del gioco online: due istanze (chi crea la stanza e un amico) giocano una partita intera
## sul finto Firebase (tests/firebase_mock.py), con una terza casata IA. Le persone sono simulate
## dall'IA. PF_ROLE=host|guest, PF_CODEFILE=file per il codice, PF_MODS=chars,coop.
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ai := PFAI.new()

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("PF_ROLE")
	var cf := OS.get_environment("PF_CODEFILE")
	var menu = main.current
	menu.seat_mode = [0, 0, 1, 2, 2]
	if OS.get_environment("PF_MODS") != "":
		for k in OS.get_environment("PF_MODS").split(","):
			menu.mods[k] = true
	menu.speed = 3
	menu._online_panel()
	menu.on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("PFTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_join()
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 1500000:
			print("PFTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("eng" in view) or view.eng == null:
			continue
		var e: PFEngine = view.eng
		var req: Dictionary = view.req
		if not req.is_empty() and view.online != null and view.online._mine_pending:
			view._reply(ai.decide(e, req["seat"], req))
		if e.game_over:
			await _wait(0.5)
			print("PFTEST impronta ", view.online.n, " | ", e.fingerprint())
			quit(0)
			return
