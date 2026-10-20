extends SceneTree
## Statistiche delle IA: quante opere per round e, quando manca, perché.
func _init() -> void:
	var games := 30
	var stat := {"tot": 0, "miss": 0, "vuota": 0, "soldi": 0, "basso": 0, "gap": 0, "money": 0}
	for g in games:
		var seats := []
		for i in 4:
			seats.append({"color": ["rosso","blu","giallo","verde"][i], "ai": true, "name": "IA%d" % i, "level": 2})
		var eng := PFEngine.new()
		eng.headless = true
		root.add_child(eng)
		eng.setup({"seats": seats, "opts": {}, "seed": 9000 + g})
		var snap := {}
		var phase := {"p": ""}
		eng.changed.connect(func():
			if eng.st.phase == "azioni" and phase["p"] != "azioni":
				for s in eng.n:
					var p = eng.st.players[s]
					var bestv := 0
					for c in p["hand"]:
						bestv = maxi(bestv, eng.st.work_value(s, c, p["bonus"]))
					snap[s] = {"works": p["table"].size(), "money": p["money"], "hand": p["hand"].size(), "bestv": bestv, "min": eng.st.min_work()}
			if eng.st.phase != "azioni" and phase["p"] == "azioni":
				for s in snap:
					stat["tot"] += 1
					if eng.st.players[s]["table"].size() == snap[s]["works"]:
						stat["miss"] += 1
						if snap[s]["hand"] == 0:
							stat["vuota"] += 1
						elif snap[s]["money"] < 300:
							stat["soldi"] += 1
						else:
							stat["basso"] += 1
							stat["gap"] += snap[s]["min"] - snap[s]["bestv"]
							stat["money"] += snap[s]["money"]
			phase["p"] = eng.st.phase)
		await eng.run()
		eng.queue_free()
	print("turni %d, senza opera %d: mano vuota %d, senza soldi %d, valore basso %d (scarto medio %.1f, fiorini medi %.0f)" % [stat["tot"], stat["miss"], stat["vuota"], stat["soldi"], stat["basso"], float(stat["gap"]) / maxf(1, stat["basso"]), float(stat["money"]) / maxf(1, stat["basso"])])
	quit()
