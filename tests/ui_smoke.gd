extends SceneTree
## Avvia l'app senza schermo: menu, poi una partita tutta IA che arriva in fondo.
## godot --headless --path . --script tests/ui_smoke.gd -- [opzioni: coop chars solo]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var seats := []
	var n := 4
	for a in args:
		if a.begins_with("n="):
			n = int(a.substr(2))
	for i in n:
		seats.append({"color": ["rosso", "blu", "giallo", "verde", "nero"][i], "side": "d", "ai": true, "name": "IA%d" % i, "level": 1})
	var cfg := {"seats": seats, "ai_delay": 0.0, "opts": {}, "seed": 4242}
	if "coop" in args:
		cfg["opts"]["coop"] = true
	if "chars" in args:
		cfg["opts"]["chars"] = true
	if "solo" in args:
		cfg = {"seats": [seats[0], {"color": "blu", "ai": true, "wolf": true, "name": "Wolfgang"}], "ai_delay": 0.0, "opts": {}, "solo": {"dummies": 2, "diff": 1}, "seed": 4242}
	main.start_game(cfg)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		var g = main.current
		if g != null and g.eng != null and g.eng.game_over:
			print("FINE: ", g.eng.results[0]["name"], " ", g.eng.results[0]["score"])
			break
	await process_frame
	quit()
