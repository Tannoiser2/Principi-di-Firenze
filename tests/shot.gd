extends SceneTree
## Fotografie della partita per controllare l'aspetto (serve uno schermo, anche virtuale: xvfb-run).
## godot --path . --script tests/shot.gd -- <cartella> [coop] [chars] [solo]

var main
var out := "/tmp/shots"
var g


func snap(name: String) -> void:
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await snap("01_menu")
	var seats := [{"color": "rosso", "side": "d", "ai": false, "name": "Lucrezia", "level": 1}]
	var n := 4
	for i in range(1, n):
		seats.append({"color": ["rosso", "blu", "giallo", "verde", "nero"][i], "side": "u", "ai": true, "name": ["", "Lorenzo", "Giuliano", "Piero", "Federico"][i], "level": 1})
	var cfg := {"seats": seats, "ai_delay": 0.0, "opts": {}, "seed": 99}
	if "coop" in args:
		cfg["opts"]["coop"] = true
	if "chars" in args:
		cfg["opts"]["chars"] = true
	if "solo" in args:
		cfg = {"seats": [seats[0], {"color": "blu", "ai": true, "wolf": true, "name": "Wolfgang"}], "ai_delay": 0.0, "opts": {}, "solo": {"dummies": 2, "diff": 1}, "seed": 99}
	main.start_game(cfg)
	await process_frame
	g = main.current
	var shot := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await process_frame
		if g.eng.game_over:
			await snap("90_fine")
			break
		if g.req.is_empty():
			continue
		var r: Dictionary = g.req
		var t: String = r["t"]
		var key := "%s_%d" % [t, g.eng.st.round]
		if t == "draft" and not shot.has("draft"):
			shot["draft"] = true
			await snap("02_draft")
		elif t == "auction_open" and not shot.has("open"):
			shot["open"] = true
			await snap("03_asta")
		elif t == "action" and g.eng.st.round >= 3 and not shot.has("act"):
			shot["act"] = true
			await snap("04_azioni_3d")
			g.board.set_flat(true)
			await snap("05_azioni_2d")
			g.board.set_flat(false)
			g.board.focus_seat(0)
			await process_frame
			for i in 30:
				await process_frame
			await snap("06_principato")
			g.board.reset_view()
			var m: Dictionary = r["menu"]
			if m.has("build"):
				g._ui_build(r)
				await snap("07_scegli_edificio")
				g._close_modal()
				g._ui_place({"seat": 0, "kind": "b", "id": m["build"][0]}, true, func(pl): pass)
				g._place.hover = Vector2i(2, 2)
				g._place.queue_redraw()
				await snap("08_piazzamento")
				g._place.queue_free()
			if m.has("work"):
				g._ui_work(r)
				await snap("09_opera")
				g._close_modal()
		elif t == "char_bid" and not shot.has("chars"):
			shot["chars"] = true
			await snap("10_personaggi")
		elif t == "solo_pick" and not shot.has("solo"):
			shot["solo"] = true
			await snap("11_solitario")
		elif t == "work_pay" and not shot.has("pay"):
			shot["pay"] = true
			await snap("12_pagamento")
		if g.req.is_empty():
			continue
		var v = g.eng.ais[r["seat"]].decide(g.eng, r["seat"], r)
		g._reply(v)
	quit()
