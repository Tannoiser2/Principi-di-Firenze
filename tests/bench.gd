extends SceneTree
## Confronto fra IA: metà dei posti con l'IA nuova (PFAI), metà con la vecchia (tests/ai_old.gd).
## godot --headless --path . --script tests/bench.gd -- [partite] [giocatori] [opzioni]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 40
	var np := int(args[1]) if args.size() > 1 else 4
	var opts := {}
	if "chars" in args:
		opts["chars"] = true
	if "coop" in args:
		opts["coop"] = true
	var tot := {"new": 0.0, "old": 0.0}
	var cnt := {"new": 0, "old": 0}
	var wins := {"new": 0.0, "old": 0.0}
	var works := {"new": 0.0, "old": 0.0}
	var money := {"new": 0.0, "old": 0.0}
	for g in games:
		var seats := []
		for i in np:
			seats.append({"color": ["rosso", "blu", "giallo", "verde", "nero"][i], "ai": true, "name": "S%d" % i, "level": 2})
		var eng := PFEngine.new()
		eng.headless = true
		root.add_child(eng)
		eng.setup({"seats": seats, "opts": opts, "seed": 5000 + g * 31})
		var kind := {}
		var fl := OS.get_environment("PF_FLAGS")
		var kv := OS.get_environment("PF_SET")
		for s1 in np:
			if kv != "":
				for pair in kv.split(","):
					var kvp := pair.split("=")
					eng.ais[s1].flags[kvp[0]] = float(kvp[1])
		for s0 in np:
			if fl != "":
				for f in fl.split(","):
					eng.ais[s0].flags[f] = false
		for s in np:
			var nw := (s + g) % 2 == 0
			kind[s] = "new" if nw else "old"
			if not nw:
				var a = load("res://tests/ai_old.gd").new()
				a.level = 2
				a.rng.seed = eng.ais[s].rng.seed
				eng.ais[s] = a
		await eng.run()
		var best: int = eng.results[0]["score"]
		var nb := 0
		for r in eng.results:
			if r["score"] == best:
				nb += 1
		for r in eng.results:
			var k: String = kind[r["seat"]]
			tot[k] += r["score"]
			cnt[k] += 1
			works[k] += eng.st.works(r["seat"])
			money[k] += r["money"]
			if r["score"] == best:
				wins[k] += 1.0 / nb
		eng.queue_free()
	for k in ["new", "old"]:
		print("%s: media %.1f, vittorie %.1f, opere %.2f, fiorini finali %.0f" % [k, tot[k] / cnt[k], wins[k], works[k] / cnt[k], money[k] / cnt[k]])
	quit()
