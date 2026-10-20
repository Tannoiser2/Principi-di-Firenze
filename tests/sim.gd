extends SceneTree
## Partite simulate fra IA: controlla che il motore arrivi in fondo senza errori.
## godot --headless --path . --script tests/sim.gd -- [partite]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 6
	var configs := [
		{"name": "2 giocatori", "n": 2, "opts": {}},
		{"name": "3 giocatori", "n": 3, "opts": {}},
		{"name": "4 giocatori", "n": 4, "opts": {}},
		{"name": "5 giocatori", "n": 5, "opts": {}},
		{"name": "4 + personaggi", "n": 4, "opts": {"chars": true}},
		{"name": "3 + cooperazione", "n": 3, "opts": {"coop": true}},
		{"name": "5 + tutto", "n": 5, "opts": {"chars": true, "coop": true}},
		{"name": "2 + cooperazione", "n": 2, "opts": {"coop": true}},
		{"name": "solitario 4", "n": 2, "opts": {}, "solo": {"dummies": 2, "diff": 1}},
		{"name": "solitario 5", "n": 2, "opts": {}, "solo": {"dummies": 3, "diff": 2}},
	]
	var t0 := Time.get_ticks_msec()
	for cfg in configs:
		var tot := 0
		var mx := 0
		var mn := 999
		for g in games:
			var seats := []
			for i in cfg["n"]:
				seats.append({"color": ["rosso", "blu", "giallo", "verde", "nero"][i], "ai": true, "name": "IA%d" % i, "level": [1, 2, 0, 1, 2][i]})
			if cfg.has("solo"):
				seats[1]["wolf"] = true
				seats[1]["name"] = "Wolfgang"
			var eng := PFEngine.new()
			eng.headless = true
			root.add_child(eng)
			var c := {"seats": seats, "opts": cfg["opts"], "seed": 1000 + g * 17 + cfg["n"]}
			if cfg.has("solo"):
				c["solo"] = cfg["solo"]
			eng.setup(c)
			await eng.run()
			if not eng.game_over:
				push_error("partita non finita: " + cfg["name"])
			var best: int = eng.results[0]["score"]
			tot += best
			mx = maxi(mx, best)
			for r in eng.results:
				mn = mini(mn, r["score"])
			if g == 0:
				var line := []
				for r in eng.results:
					line.append("%s %d (%d op., %d ed.)" % [r["name"], r["score"], eng.st.works(r["seat"]), eng.st.n_buildings(r["seat"])])
				print("  ", cfg["name"], ": ", ", ".join(line))
			eng.queue_free()
		print("%s: vincitore medio %.1f, max %d, min %d" % [cfg["name"], float(tot) / games, mx, mn])
	print("tempo %d ms" % (Time.get_ticks_msec() - t0))
	quit()
