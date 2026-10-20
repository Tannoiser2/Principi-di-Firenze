extends SceneTree
## Media dei punti per livello dell'IA (facile, normale, esperto) in partite a 3, posti a rotazione.
func _init() -> void:
	var tot := [0.0, 0.0, 0.0]
	var wins := [0.0, 0.0, 0.0]
	var games := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 60
	for g in games:
		var seats := []
		for i in 3:
			seats.append({"color": ["rosso","blu","giallo"][i], "ai": true, "name": "S%d" % i, "level": (i + g) % 3})
		var np := int(OS.get_environment("PF_NP")) if OS.get_environment("PF_NP") != "" else 3
		for i in range(3, np):
			seats.append({"color": ["verde", "nero"][i - 3], "ai": true, "name": "X%d" % i, "level": 1})
		var eng := PFEngine.new()
		eng.headless = true
		root.add_child(eng)
		eng.setup({"seats": seats, "opts": {}, "seed": 300 + g})
		await eng.run()
		for r in eng.results:
			tot[(r["seat"] + g) % 3] += r["score"]
		wins[(eng.results[0]["seat"] + g) % 3] += 1
		eng.queue_free()
	for l in 3:
		print(["facile", "normale", "esperto"][l], ": media %.1f, vittorie %d" % [tot[l] / games, wins[l]])
	quit()
