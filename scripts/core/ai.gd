class_name PFAI
extends RefCounted
## Intelligenza artificiale dei principi avversari.
## Ragiona in fiorini: 1 punto di fama vale circa 200 fiorini, 1 punto di valore d'opera circa 100.
## Livelli: 0 = facile (offre poco, sbaglia), 1 = normale, 2 = esperto.

const D = preload("res://scripts/data/pf_data.gd")

var level := 1
var flags := {"draw": true, "prest": false, "pickwork": true, "freeval": true}
var rng := RandomNumberGenerator.new()


var _leveled := false


## I livelli: facile senza pianificazione e con qualche distrazione, normale senza i calcoli
## più fini, esperto con tutto.
func _apply_level() -> void:
	_leveled = true
	if level <= 0:
		for k in ["prepare", "cross", "draw", "sellfame", "needs"]:
			flags[k] = false
		flags["scale"] = 0.85
		flags["tgt"] = 1.2
	elif level == 1:
		for k in ["needs", "draw", "sellfame"]:
			flags[k] = false


func decide(eng: PFEngine, s: int, req: Dictionary):
	if not _leveled:
		_apply_level()
	if level <= 0 and req.get("t", "") == "action" and rng.randf() < 0.3:
		var m: Dictionary = req["menu"]
		var opts := []
		for a in ["prof", "bonus"]:
			if m.has(a) and m.get("left", 0) > 0:
				opts.append({"a": a})
		if m.has("freedom") and m.get("left", 0) > 0:
			opts.append({"a": "freedom", "f": m["freedom"][rng.randi() % m["freedom"].size()]})
		if not opts.is_empty():
			return opts[rng.randi() % opts.size()]
	match req.get("t", ""):
		"draft":
			return _draft(eng, s, req["cards"])
		"auction_open":
			return _open(eng, s, req)
		"bid":
			return _bid(eng, s, req)
		"auction_last":
			return _last(eng, s, req)
		"land_choice":
			return _land_choice(eng, s, req["options"])
		"place":
			return best_place(eng, s, req["kind"], req["id"])
		"pick":
			return _pick(eng, s, req["kind"], req["cards"])
		"recruit":
			return _recruit(eng, s, req)
		"merchant":
			return "free" if req["cost"] >= 200 * req["pp"] else ("pp" if req["cost"] == 0 or eng.st.round >= 6 else "free")
		"professor":
			if req.get("prestige", false) and eng.st.round >= 4:
				return "prestige"
			return "bonus" if req.get("bonus", false) else ("prestige" if req.get("prestige", false) else "no")
		"solo_pick":
			return _solo_pick(eng, s, req)
		"solo_buy":
			return req.get("forced", false) or req["price"] <= int(object_value(eng, s, req["obj"]) * 1.1)
		"char_bid":
			return _char_bid(eng, s, req)
		"action":
			return _action(eng, s, req["menu"])
		"work_pay":
			return _work_pay(eng, s, req)
		"coop_offer":
			return _coop_accept(eng, s, req)
		"banker_end":
			return req["max"]
	return null


# ================================================================== valutazioni

func _rounds_left(eng: PFEngine) -> int:
	return D.ROUNDS - eng.st.round + 1


## Opere che il giocatore farà ancora (stima)
func expected_works(eng: PFEngine, s: int) -> float:
	var r := _rounds_left(eng)
	var cards: int = eng.st.players[s]["hand"].size() + eng.st.players[s]["recruits"]
	return clampf(float(r) * 0.9, 0.0, float(cards) + float(r) * 0.6)


## Potenziale di una Mestiere nel principato (senza Bonus)
func card_potential(eng: PFEngine, s: int, c: int) -> int:
	var p: Dictionary = eng.st.players[s]
	var pr: Dictionary = D.PROFS[c]
	var v: int = 2 * int(p["jesters"]) + eng.st.card_count(s)
	if p["land"][pr["land"]] > 0:
		v += 3
	elif eng.st.supply["land"][pr["land"]] > 0:
		v += 1
	if pr["free"] in p["freedoms"]:
		v += 3
	elif eng.st.supply["free"][pr["free"]] > 0:
		v += 2
	if pr["bld"] in p["buildings"]:
		v += 4
	elif eng.st.supply["bld"][pr["bld"]] > 0:
		v += 2
	return v


## Quante carte in mano vogliono questa cosa (paesaggio, libertà o edificio) e non l'hanno
func _need(eng: PFEngine, s: int, key: String, what: String) -> int:
	var p: Dictionary = eng.st.players[s]
	var c := 0
	for card in p["hand"]:
		if D.PROFS[card][key] == what:
			c += 1
	return c


## Valore in fiorini di un oggetto dell'asta
func object_value(eng: PFEngine, s: int, obj: String) -> float:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var r := _rounds_left(eng)
	var e := expected_works(eng, s)
	var v := 0.0
	match obj:
		"giullare":
			v = e * 175.0 + (80.0 if st.round <= 3 else 0.0)
		"costruttore":
			match int(p["builders"]):
				0: v = 400.0 * minf(2.5, float(r) * 0.5) + 50.0
				1: v = 600.0 + 250.0 + (150.0 if r > 3 else 0.0)
				2: v = 600.0 + 300.0 * minf(2.0, float(r) * 0.4)
				_: v = 0.0
		"bosco", "lago", "parco":
			if p["land"][obj] > 0:
				v = 520.0 + 60.0 * _need(eng, s, "land", obj)
			else:
				var need := _need(eng, s, "land", obj)
				var share: float = float({"bosco": 9.0, "lago": 7.0, "parco": 5.0}[obj]) / 21.0
				v = need * 260.0 + e * share * 250.0 + 100.0
			if 4 in p["prestige"] and p["land"][obj] == 0:
				v += 500.0
			if (obj == "bosco" and 6 in p["prestige"]) or (obj == "lago" and 7 in p["prestige"]) or (obj == "parco" and 12 in p["prestige"]):
				v += 300.0
			if 5 in p["prestige"]:
				v += 200.0
		"paesaggio":
			for l in D.LANDS:
				if st.supply["land"][l] > 0:
					v = maxf(v, object_value(eng, s, l))
		"prestigio" when not flags.get("prest", false):
			v = 500.0 + 30.0 * r
		"prestigio":
			var hopes := []
			for pid in st.prest_deck:
				hopes.append(_prestige_hope(eng, s, pid))
			hopes.sort()
			hopes.reverse()
			var top := 0.0
			for i in mini(3, hopes.size()):
				top += hopes[i]
			top /= maxf(1.0, float(mini(3, hopes.size())))
			v = top * 170.0 + 60.0
		"reclutamento":
			var targets := eng.recruit_targets(s)
			v = e * 100.0 + (450.0 if not targets.is_empty() else 150.0)
	v *= float(flags.get("scale", 0.6))
	if flags.get("cross", true) and obj in ["bosco", "lago", "parco", "giullare", "reclutamento"]:
		v += _cross_bonus(eng, s, obj)
	if level == 0:
		v *= 0.75
	elif level == 2:
		v *= 1.05
	return v


## Se l'oggetto fa arrivare una carta in mano al minimo del round, vale molto di più
func _cross_bonus(eng: PFEngine, s: int, obj: String) -> float:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var mn := st.min_work()
	var before := -99
	var after := -99
	for c in p["hand"]:
		var v := st.work_value(s, c, p["bonus"])
		before = maxi(before, v)
		var w := v
		if obj in D.LANDS and D.PROFS[c]["land"] == obj and p["land"][obj] == 0:
			w += 3
		elif obj == "giullare":
			w += 2
		elif obj == "reclutamento":
			w += 1
		after = maxi(after, w)
	# con un'azione di miglioramento (libertà o edificio) si guadagnano ancora 3-4 punti
	if before + 4 < mn and after + 4 >= mn:
		return 650.0
	if before < mn and after >= mn:
		return 800.0
	return 0.0


## Fiorini da tenere da parte per la fase azioni
func _reserve(eng: PFEngine, s: int) -> int:
	var st: PFState = eng.st
	var r := _rounds_left(eng)
	return 300 + (st.build_cost(s) if r > 1 else 0) + (300 if r > 2 else 0)


func _budget(eng: PFEngine, s: int) -> int:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var fame_ok: int = (mini(p["fame"], 6) * 100) if (st.can_sell_fame() and st.round >= 5) else 0
	return p["money"] + fame_ok - _reserve(eng, s)


func _open(eng: PFEngine, s: int, req: Dictionary):
	var best := ""
	var bv := -99999.0
	for o in req["options"]:
		var v := object_value(eng, s, o) - float(req["bid"]) + rng.randf_range(0.0, 60.0 if level < 2 else 10.0)
		if v > bv:
			bv = v
			best = o
	if bv < -100.0 or _budget(eng, s) < int(req["bid"]):
		# meglio aspettare: l'ultimo prende per 200
		return "" if eng.auction.get("avail", []).size() > 2 else best
	return best


func _bid(eng: PFEngine, s: int, req: Dictionary) -> bool:
	var v := object_value(eng, s, req["obj"])
	var cap := float(eng.st.players[s]["money"]) * (0.4 if eng.st.round <= 5 else 0.6)
	if eng.st.round == D.ROUNDS:
		cap = float(eng.st.players[s]["money"]) - 300.0
	var lim := minf(minf(v * (0.8 if level == 0 else 0.92), float(_budget(eng, s))), cap)
	if level == 0:
		lim -= rng.randf_range(0.0, 200.0)
	return float(req["next"]) <= lim


func _last(eng: PFEngine, s: int, req: Dictionary):
	var best := ""
	var bv := 150.0
	for o in req["options"]:
		var v := object_value(eng, s, o)
		if v > bv:
			bv = v
			best = o
	return best


func _land_choice(eng: PFEngine, s: int, opts: Array) -> String:
	var best: String = opts[0]
	var bv := -1.0
	for l in opts:
		var v := object_value(eng, s, l)
		if v > bv:
			bv = v
			best = l
	return best


func _solo_pick(eng: PFEngine, s: int, req: Dictionary) -> String:
	var best := ""
	var bv := 0.0
	for o in req["options"]:
		var v := object_value(eng, s, o)
		if v > bv:
			bv = v
			best = o
	return best


# ================================================================== carte

func _draft(eng: PFEngine, s: int, cards: Array) -> int:
	# si restituisce la carta con meno affinità con le altre (paesaggi e libertà in comune)
	var worst: int = cards[0]
	var wv := 9999.0
	for c in cards:
		var v := 0.0
		for o in cards:
			if o == c:
				continue
			if D.PROFS[o]["land"] == D.PROFS[c]["land"]:
				v += 1.0
			if D.PROFS[o]["free"] == D.PROFS[c]["free"]:
				v += 1.0
			if D.PROFS[o]["bld"] == D.PROFS[c]["bld"]:
				v += 1.5
		v += {"bosco": 0.6, "lago": 0.3, "parco": 0.0}[D.PROFS[c]["land"]]
		v += rng.randf_range(0.0, 0.3)
		if v < wv:
			wv = v
			worst = c
	return worst


func _pick(eng: PFEngine, s: int, kind: String, cards: Array) -> int:
	var st: PFState = eng.st
	var best: int = cards[0]
	var bv := -9999.0
	for c in cards:
		var v := 0.0
		match kind:
			"prestigio":
				v = _prestige_hope(eng, s, c)
			"bonus":
				v = st.bonus_value(s, c, true) + 0.1 * rng.randf()
			_:
				v = card_potential(eng, s, c) + 0.1 * rng.randf()
				var now := st.work_value(s, c, st.players[s]["bonus"]) + 1
				if flags["pickwork"] and eng.st.phase == "azioni" and now >= st.min_work():
					v += 6.0 + 0.5 * now
		if v > bv:
			bv = v
			best = c
	return best


## Punti che una carta Prestigio può ragionevolmente dare a fine partita
func _prestige_hope(eng: PFEngine, s: int, pid: int) -> float:
	var st: PFState = eng.st
	var now := float(st.prestige_points(s, pid))
	var info: Dictionary = D.PRESTIGE[pid]
	var p: Dictionary = st.players[s]
	var hope := now
	match pid:
		2: hope = maxf(now, 5.0 * (0.8 if st.n_size(s, "G") >= 1 else 0.4))
		3: hope = maxf(now, 3.0)
		4: hope = maxf(now, 8.0 * (st.land_types(s) / 3.0) * 0.8)
		8: hope = maxf(now, 8.0 * (p["freedoms"].size() / 3.0) * 0.8)
		9: hope = maxf(now, 3.0)
		13: hope = maxf(now, 7.0 * (0.9 if p["builders"] + p["jesters"] >= 1 else 0.5))
		_:
			hope = maxf(now, float(info["tie"]) * 0.8)
	return hope + rng.randf() * 0.2


func _recruit(eng: PFEngine, s: int, req: Dictionary):
	var best = null
	var bv := 0
	for t in req["targets"]:
		var v := card_potential(eng, s, int(t[2]))
		if v > bv:
			bv = v
			best = t
	if best == null:
		return null
	# subito se serve, altrimenti si tiene la carta (vale +1 a ogni opera)
	if req.get("now", false) and eng.st.players[s]["hand"].size() >= _rounds_left(eng) and bv < eng.st.min_work() + 2:
		return null
	return [best[0], best[1]]


# ================================================================== piazzamenti

func best_place(eng: PFEngine, s: int, kind: String, id: String) -> Dictionary:
	var st: PFState = eng.st
	var pls := st.placements(s, kind, id)
	if pls.is_empty():
		return {}
	var best: Dictionary = pls[0]
	var bv := -99999.0
	var p: Dictionary = st.players[s]
	for pl in pls:
		var cells := PFState.placed_cells(id, pl)
		var set := {}
		for c in cells:
			set[c] = true
		var contact := 0
		for c in cells:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + d
				if set.has(q):
					continue
				var v := st.cell(s, q.x, q.y)
				if v != "":
					contact += 2 if (v == "#" or v.begins_with("l:")) else 1
		# spazio libero rimasto in blocchi utili
		var holes := _holes_after(st, s, set)
		var score := float(contact) * 1.0 - float(holes) * 2.2 + rng.randf() * 0.3
		if kind == "b" and p["builders"] < 2:
			# lascia spazio per gli edifici futuri: meglio i bordi
			for c in cells:
				if c.x == 0 or c.y == 0 or c.x == p["w"] - 1 or c.y == p["h"] - 1:
					score += 0.4
		if score > bv:
			bv = score
			best = pl
	return best


## Caselle vuote isolate o in piccoli gruppi (1-2) dopo il piazzamento
func _holes_after(st: PFState, s: int, extra: Dictionary) -> int:
	var p: Dictionary = st.players[s]
	var seen := {}
	var holes := 0
	for y in p["h"]:
		for x in p["w"]:
			var c := Vector2i(x, y)
			if seen.has(c) or extra.has(c) or st.cell(s, x, y) != "":
				continue
			var stack := [c]
			var size := 0
			seen[c] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				size += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var r: Vector2i = q + d
					if seen.has(r) or extra.has(r) or st.cell(s, r.x, r.y) != "":
						continue
					seen[r] = true
					stack.append(r)
			if size <= 2:
				holes += size
	return holes


# ================================================================== personaggi

func _char_bid(eng: PFEngine, s: int, req: Dictionary):
	var st: PFState = eng.st
	var best = null
	var bv := 0.0
	for c in req["options"]:
		var lo: int = req["options"][c][0]
		var hi: int = req["options"][c][1]
		var val := 0.0
		match c:
			"banchiere":
				val = float(req["banker"]) - 100.0
			"cardinale":
				val = 450.0
			"musa":
				val = float(st.round) * 140.0 * (1.5 if st.players[s]["hand"].size() >= 2 else 0.8)
			"mercante":
				val = 450.0
			"professore":
				val = 500.0
			"principessa":
				var v := st.work_value(s, -1, [], 0)
				val = float(v) * 90.0 if v >= st.min_work() else 100.0
		var cost := float(lo * 100)
		var gain := val - cost
		if gain > bv and cost <= float(st.players[s]["money"] - 600):
			bv = gain
			var bidv := lo
			if level >= 1 and val - float((lo + 1) * 100) > 150.0 and lo + 1 <= hi:
				bidv = lo + 1
			best = {"c": c, "v": bidv}
	return best


# ================================================================== fase azioni

func _action(eng: PFEngine, s: int, m: Dictionary) -> Dictionary:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var left: int = m.get("left", 0)
	var r := _rounds_left(eng)
	var worked: int = p["acts"].get("work", 0)
	if m.has("recruit") and (p["hand"].size() <= 1 or r <= 2):
		var t = _recruit(eng, s, {"targets": m["recruit"], "now": false})
		if t != null:
			return {"a": "recruit", "o": t[0], "i": t[1]}
	if m.has("cardinal") and left > 0:
		return {"a": "cardinal"}
	if m.has("professor"):
		return {"a": "professor", "k": "prestige" if st.prest_deck.size() > 0 and st.round >= 3 else "bonus"}
	if m.has("merchant") and (m["merchant"] >= 3 or r == 1):
		return {"a": "merchant"}
	if left <= 0:
		return {"a": "end"}
	var cards_left: int = p["hand"].size() + p["recruits"]
	var want_work: bool = (worked == 0 or cards_left > r - 1 or r == 1 or bool(flags.get("greedy", true))) and worked < 2
	if want_work:
		var plan := _work_plan(eng, s, m, left)
		if not plan.is_empty():
			if plan["steps"].is_empty():
				return plan["work"]
			return plan["steps"][0]
		# nessuna carta basta: si pesca sperando in una carta adatta, se poi resta un'azione per l'opera
		if flags["draw"] and m.has("prof") and left >= 2 and p["money"] >= 300 and _draw_chance(eng, s) >= 0.45:
			return {"a": "prof"}
	# niente opera possibile: carte e miglioramenti per i round futuri
	if m.has("prof") and p["hand"].size() < r + (1 if worked == 0 else 0) + (1 if flags.get("moreprof", false) else 0) and (r > 1 or left >= 2):
		return {"a": "prof"}
	if flags.get("prepare", true) and r >= 2:
		var prep := _prepare(eng, s, m)
		if not prep.is_empty():
			return prep
	var imp := _improvement(eng, s, m, false)
	if not imp.is_empty():
		return imp
	if m.has("prof") and p["hand"].size() <= r and r >= 2 and p["money"] >= 700:
		return {"a": "prof"}
	# ultimo round: i fiorini non servono più, un edificio vale 3 punti
	if r == 1 and m.has("build") and flags.get("lastbuild", true):
		for b in m["build"]:
			var pl := best_place(eng, s, "b", b)
			if not pl.is_empty():
				return {"a": "build", "b": b, "pl": pl, "price": 0}
	if m.has("bonus") and p["money"] >= 900 and r >= 2 and p["bonus"].size() < 2:
		return {"a": "bonus"}
	return {"a": "end"}


## Preparazione del prossimo round: l'azione che avvicina di più una carta in mano al minimo
## del round successivo (libertà, edificio, carta Bonus), tenendo conto del costo.
func _prepare(eng: PFEngine, s: int, m: Dictionary) -> Dictionary:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	if p["hand"].is_empty():
		return {}
	var nmin: int = D.MIN_WORK[mini(st.round + 1, 7)]
	var base := {}
	var before := -99
	for c in p["hand"]:
		base[c] = st.work_value(s, c, p["bonus"]) + 1
		before = maxi(before, base[c])
	var cands := []
	if m.has("freedom"):
		for f in m["freedom"]:
			cands.append({"act": {"a": "freedom", "f": f}, "cost": 300, "intr": 0.0, "free": f})
	if m.has("build"):
		for b in m["build"]:
			if st.build_cost(s) > 300 and _need(eng, s, "bld", b) == 0:
				continue
			cands.append({"act": {"a": "build", "b": b}, "cost": st.build_cost(s), "intr": 600.0, "bld": b})
	if m.has("bonus") and st.bonus_deck.size() > 0:
		var vals := []
		for b in st.bonus_deck:
			vals.append(st.bonus_value(s, b, true))
		vals.sort()
		vals.reverse()
		var exp := 0.0
		for i in mini(3, vals.size()):
			exp += vals[i]
		exp /= maxf(1.0, float(mini(3, vals.size())))
		cands.append({"act": {"a": "bonus"}, "cost": 300, "intr": 0.0, "plus": int(round(exp))})
	var best := {}
	var bv := 0.0
	var money: int = p["money"]
	for cd in cands:
		if cd["cost"] > money - 300:
			continue
		var after := -99
		for c in p["hand"]:
			var v: int = base[c]
			var pr: Dictionary = D.PROFS[c]
			if cd.has("free") and pr["free"] == cd["free"]:
				v += 3
			if cd.has("bld") and pr["bld"] == cd["bld"]:
				v += 4
			v += int(cd.get("plus", 0))
			after = maxi(after, v)
		var score := float(cd["intr"]) - float(cd["cost"])
		if after >= nmin and before < nmin:
			score += 900.0 + float(after) * 50.0
		else:
			score += float(after - before) * 60.0
		if cd.has("free"):
			score += maxf(0.0, expected_works(eng, s) - float(p["hand"].size())) / 3.0 * 300.0
		if score > bv:
			bv = score
			best = cd["act"]
	if best.get("a", "") == "build":
		var pl := best_place(eng, s, "b", best["b"])
		if pl.is_empty():
			pl = _coop_place(eng, s, best["b"])
		if pl.is_empty():
			return {}
		best["pl"] = pl
		best["price"] = 200 if pl.has("side") else 0
	return best


## Probabilità che pescando 5 Mestieri ne esca una che si può giocare subito
func _draw_chance(eng: PFEngine, s: int) -> float:
	var st: PFState = eng.st
	var deck: Array = st.prof_deck
	if deck.is_empty():
		return 0.0
	var p: Dictionary = st.players[s]
	var muse: int = st.round if p["char"] == "musa" else 0
	var ok := 0
	for c in deck:
		if st.work_value(s, c, p["bonus"], muse) + 1 >= st.min_work():
			ok += 1
	var q := float(ok) / float(deck.size())
	return 1.0 - pow(1.0 - q, float(mini(5, deck.size())))


## Il miglior piano per completare un'opera in questo turno: eventuali miglioramenti (libertà, edificio)
## e poi l'opera. Restituisce {work, steps, value} oppure {}.
func _work_plan(eng: PFEngine, s: int, m: Dictionary, left: int) -> Dictionary:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var muse: int = st.round if p["char"] == "musa" else 0
	var mn := st.min_work()
	var r := _rounds_left(eng)
	var best := {}
	var bv := -1.0
	var bonuses: Array = p["bonus"].duplicate()
	bonuses.sort_custom(func(a, b): return st.bonus_value(s, a) > st.bonus_value(s, b))
	var money: int = p["money"]
	for c in p["hand"]:
		var pr: Dictionary = D.PROFS[c]
		var base := st.work_value(s, c, [], muse)
		var opts := [[]]
		var free_ok: bool = m.has("freedom") and pr["free"] in m["freedom"]
		var bld_ok: bool = m.has("build") and pr["bld"] in m["build"]
		var prof_ok: bool = m.has("prof")
		if left >= 2:
			if free_ok:
				opts.append(["f"])
			if bld_ok:
				opts.append(["b"])
			if prof_ok:
				opts.append(["p"])
		if left >= 3 and free_ok and bld_ok:
			opts.append(["f", "b"])
		for o in opts:
			var v: int = base
			var cost := 0
			if "f" in o:
				v += 3
				cost += 300
			if "b" in o:
				v += 4
				cost += st.build_cost(s)
			if "p" in o:
				v += 1
				cost += 300
			if cost > money:
				# si può scendere sulla traccia della fama, se l'opera ripaga
				if not (flags.get("sellfame", true) and st.can_sell_fame() and (cost - money + 99) / 100 <= p["fame"] and (cost - money + 99) / 100 <= v / 2 - 2):
					continue
			var use := []
			for b in bonuses:
				var bvv := st.bonus_value(s, b, true)
				if bvv <= 0:
					continue
				if v < mn or r <= 1 or (r <= 3 and bvv >= 4):
					use.append(b)
					v += bvv
			if v < mn:
				continue
			var score: float = float(v) - 0.3 * o.size() + (2.0 if "b" in o else 0.0) - 0.5 * use.size() - (1.5 if "p" in o else 0.0)
			if score > bv:
				bv = score
				var steps := []
				if "b" in o:
					var pl := best_place(eng, s, "b", pr["bld"])
					if pl.is_empty():
						pl = _coop_place(eng, s, pr["bld"])
					if pl.is_empty():
						continue
					steps.append({"a": "build", "b": pr["bld"], "pl": pl, "price": 200 if pl.has("side") else 0})
				if "f" in o:
					steps.append({"a": "freedom", "f": pr["free"]})
				if "p" in o:
					steps.append({"a": "prof"})
				best = {"work": {"a": "work", "card": c, "bonus": use}, "steps": steps, "value": v}
	if p["char"] == "principessa" and p["char_up"]:
		var vp := st.work_value(s, -1, [], muse)
		if vp >= mn and float(vp) > bv:
			best = {"work": {"a": "work", "card": -1}, "steps": [], "value": vp}
	return best


## L'opera migliore possibile ora, con i Bonus che servono
func _best_work(eng: PFEngine, s: int) -> Dictionary:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var muse: int = st.round if p["char"] == "musa" else 0
	var r := _rounds_left(eng)
	var best := {}
	var bv := -1
	var mn := st.min_work()
	for c in p["hand"]:
		var base := st.work_value(s, c, [], muse)
		var use := []
		var v := base
		var bonuses: Array = p["bonus"].duplicate()
		bonuses.sort_custom(func(a, b): return st.bonus_value(s, a) > st.bonus_value(s, b))
		for b in bonuses:
			var bvv := st.bonus_value(s, b, true)
			if bvv <= 0:
				continue
			if v < mn or r <= 2 or (bvv >= 4 and r <= 4):
				use.append(b)
				v += bvv
		if v >= mn and v > bv:
			bv = v
			best = {"a": "work", "card": c, "bonus": use}
	if p["char"] == "principessa" and p["char_up"]:
		var vp := st.work_value(s, -1, [], muse)
		if vp >= mn and vp > bv:
			best = {"a": "work", "card": -1}
	return best


## Costruire, introdurre una libertà: restituisce l'azione, o {} se non conviene.
## for_work: solo se migliora una carta che si sta per giocare.
func _improvement(eng: PFEngine, s: int, m: Dictionary, for_work: bool) -> Dictionary:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var r := _rounds_left(eng)
	var best := {}
	var bv := 0.0
	var spare: int = p["money"] - (0 if r <= 1 else 200)
	if m.has("build") and st.build_cost(s) <= spare:
		for b in m["build"]:
			var need := _need(eng, s, "bld", b)
			if for_work and need == 0:
				continue
			if flags.get("no700", true) and st.build_cost(s) >= 700 and need == 0 and _rounds_left(eng) > 1:
				continue
			var gain := 600.0 + need * 400.0 * minf(1.0, float(r) / 2.0) - float(st.build_cost(s))
			if 1 in p["prestige"] or 9 in p["prestige"]:
				gain += 250.0
			if 2 in p["prestige"] and D.BUILDING_SIZE[b] == "G":
				gain += 400.0
			if D.BUILDING_SIZE[b] == "G":
				gain += 60.0
			if gain > bv:
				var pl := best_place(eng, s, "b", b)
				if pl.is_empty():
					pl = _coop_place(eng, s, b)
				if pl.is_empty():
					continue
				bv = gain
				best = {"a": "build", "b": b, "pl": pl, "price": 200 if pl.has("side") else 0}
	if m.has("freedom") and 300 <= spare:
		for f in m["freedom"]:
			var need2 := _need(eng, s, "free", f)
			if for_work and need2 == 0:
				continue
			var gain2 := need2 * 300.0 * minf(1.0, float(r) / 2.0) + float(r) * 30.0 - 300.0
			if flags.get("freeval", false):
				# vale anche per le carte che arriveranno: un terzo degli artisti vuole questa libertà
				gain2 = (float(need2) + maxf(0.0, expected_works(eng, s) - float(p["hand"].size())) / 3.0) * 300.0 - 300.0
			if 8 in p["prestige"]:
				gain2 += 350.0
			if gain2 > bv:
				bv = gain2
				best = {"a": "freedom", "f": f}
	if for_work and not best.is_empty():
		# conviene solo se dopo resta un'opera giocabile
		return best if (not _best_work(eng, s).is_empty() or _would_enable_work(eng, s, best)) else {}
	return best


func _would_enable_work(eng: PFEngine, s: int, act: Dictionary) -> bool:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	for c in p["hand"]:
		var v := st.work_value(s, c, p["bonus"])
		var pr: Dictionary = D.PROFS[c]
		if act["a"] == "build" and pr["bld"] == act["b"]:
			v += 4
		if act["a"] == "freedom" and pr["free"] == act["f"]:
			v += 3
		if v >= st.min_work():
			return true
	return false


func _coop_place(eng: PFEngine, s: int, b: String) -> Dictionary:
	for side in eng.st.neighbors(s):
		var pls := eng.st.coop_placements(s, side, b)
		if not pls.is_empty():
			return pls[rng.randi() % pls.size()]
	return {}


func _coop_accept(eng: PFEngine, s: int, req: Dictionary) -> bool:
	var st: PFState = eng.st
	var need := _need(eng, s, "bld", req["b"])
	var val := 600.0 + need * 350.0
	return float(req["price"]) <= val and req["price"] <= st.players[s]["money"] - 200


func _work_pay(eng: PFEngine, s: int, req: Dictionary) -> int:
	var st: PFState = eng.st
	var p: Dictionary = st.players[s]
	var v: int = req["value"]
	var mx: int = req["max"]
	var r := _rounds_left(eng)
	if r <= 1 and st.round == D.ROUNDS:
		# ultimo round: i fiorini servono solo per le azioni rimaste
		var keep := 300 if int(p.get("nacts", 0)) == 0 else 0
		return clampi((v * 100 + p["money"] - keep) / 200, 0, mx)
	var target := 1300 if r >= 3 else 1000
	if r == 2:
		target = 1100
	if flags.get("needs", true) and r >= 2:
		# quanto servirà per migliorare le carte in mano (libertà, edifici mancanti)
		var need_cash := 300
		var seen := {}
		for c in p["hand"]:
			var pr: Dictionary = D.PROFS[c]
			if not (pr["free"] in p["freedoms"]) and not seen.has(pr["free"]):
				seen[pr["free"]] = true
				need_cash += 300
			if not (pr["bld"] in p["buildings"]) and not seen.has(pr["bld"]):
				seen[pr["bld"]] = true
				need_cash += st.build_cost(s)
		target = maxi(target, mini(2200 if r >= 3 else 1400, 700 + need_cash))
	if level == 0:
		target = 900
	target = int(float(target) * float(flags.get("tgt", 0.7)))
	var spare := v * 100 + int(p["money"]) - target
	return clampi(spare / 200, 0, mx)
