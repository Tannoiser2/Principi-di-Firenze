class_name PFEngine
extends Node
## Motore della partita: 7 round con asta, (asta dei personaggi), fase azioni e miglior opera.
## Le regole immediate stanno in PFState (st); qui si chiedono le decisioni una alla volta:
## l'IA risponde subito, per le persone si emette `decision_requested` e si aspetta `provide_decision()`.
## Online ogni decisione passa dal registro di mosse (OnlineSession): con lo stesso seme ogni
## dispositivo ottiene la stessa partita.

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(results: Array)
signal fx(kind: String, data: Dictionary)

const D = preload("res://scripts/data/pf_data.gd")

var st := PFState.new()
var ai_delay := 0.0
var headless := false
var ais := {}
var log_lines: Array = []
var current := -1
var abort := false
var online = null
var results: Array = []
var game_over := false
## stato dell'asta in corso, per la UI
var auction := {}
var char_bids := {}            # personaggio -> [posto, offerta]
var solo_card := 0
var solo_rolls := {}

var players: Array:
	get:
		return st.players
var n: int:
	get:
		return st.n


func setup(config: Dictionary) -> void:
	st.setup(config)
	ai_delay = float(config.get("ai_delay", 0.0))
	for s in st.n:
		var a := PFAI.new()
		a.level = st.players[s]["level"]
		a.rng.seed = st.seed + 7919 * (s + 1)
		ais[s] = a


func pname(s: int) -> String:
	return st.pname(s)


func any_local_human() -> bool:
	if online != null:
		return true
	for p in st.players:
		if not p["ai"]:
			return true
	return false


func _sync() -> void:
	for t in st.log:
		log_lines.append(t)
		log_added.emit(t)
	st.log.clear()
	changed.emit()


func say(t: String) -> void:
	st.say(t)
	_sync()


# ------------------------------------------------------------------ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	_sync()
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		return await online.decide(self, seat, req)
	if st.players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		return ais[seat].decide(self, seat, req)
	decision_requested.emit(req)
	var r = await decision_provided
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


func _wait(sec: float) -> void:
	if headless or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if ai_delay <= 0.0 and not any_local_human():
		return
	await get_tree().create_timer(sec * maxf(0.4, ai_delay / 0.6)).timeout


# ------------------------------------------------------------------ partita

func run() -> void:
	_sync()
	await _draft()
	for r in range(1, D.ROUNDS + 1):
		if abort:
			return
		st.round = r
		say("— Round %d (opera minima %d). Comincia %s. —" % [r, st.min_work(), pname(st.start)])
		fx.emit("round", {"r": r})
		st.phase = "asta"
		if st.is_solo():
			await _solo_auction()
		else:
			await _auction()
		if st.opts.get("chars", false):
			st.phase = "personaggi"
			await _char_auction()
		st.phase = "azioni"
		await _action_phase()
		_round_end()
		await _wait(0.8)
	await _final()


## Ognuno riceve 4 Mestieri e ne tiene 3.
func _draft() -> void:
	st.phase = "preparazione"
	var deals := {}
	for s in n:
		if st.players[s]["wolf"]:
			continue
		deals[s] = []
		for k in 4:
			deals[s].append(st.prof_deck.pop_front())
	if st.is_solo():
		for k in 3:
			st.players[st.wolf]["row"].append({"c": st.prof_deck.pop_front(), "up": false, "bonus": []})
		for d in st.solo["dummies"]:
			for k in 3:
				d.append({"c": st.prof_deck.pop_front(), "up": false})
	for s in deals:
		var cards: Array = deals[s]
		var r = await decide(s, {"t": "draft", "cards": cards.duplicate()})
		if not (r is int) or not (int(r) in cards):
			r = ais[s].decide(self, s, {"t": "draft", "cards": cards, "seat": s})
		cards.erase(int(r))
		st.players[s]["hand"] = cards
		st.prof_deck.append(int(r))
	st._shuffle(st.prof_deck)
	say("Ognuno tiene 3 carte Mestiere.")


# ================================================================== asta

func _stack_key(obj: String) -> String:
	if st.two_p and obj in D.LANDS:
		return "paesaggio"
	return obj


## L'oggetto c'è ancora (rifornimento e mazzo)?
func object_left(obj: String) -> bool:
	match obj:
		"bosco", "lago", "parco":
			return st.supply["land"][obj] > 0
		"paesaggio":
			for l in D.LANDS:
				if st.supply["land"][l] > 0:
					return true
			return false
		"prestigio":
			return st.prest_deck.size() > 0
		"reclutamento", "giullare", "costruttore":
			return st.supply[obj] > 0
	return false


## Il giocatore può prendere l'oggetto?
func can_take(s: int, obj: String) -> bool:
	if not object_left(obj):
		return false
	var p: Dictionary = st.players[s]
	match obj:
		"costruttore":
			return p["builders"] < 3
		"bosco", "lago", "parco":
			return p["wolf"] or st.any_placement(s, "l", obj)
		"paesaggio":
			for l in D.LANDS:
				if st.supply["land"][l] > 0 and st.any_placement(s, "l", l):
					return true
			return false
	return true


func auction_objects() -> Array:
	if st.two_p:
		return ["paesaggio", "prestigio", "reclutamento", "giullare", "costruttore"]
	return D.OBJECTS.duplicate()


func _auction() -> void:
	var avail := []
	for i in n:
		avail.append((st.start + i) % n)
	var taken := {}
	var start_bid := 300 if st.two_p else 200
	auction = {"taken": taken, "avail": avail, "obj": "", "bid": 0, "leader": -1, "passed": {}, "won": {}}
	var opener: int = st.start
	while avail.size() > 1 and not abort:
		var opts := []
		for o in auction_objects():
			if not taken.has(o) and object_left(o):
				opts.append(o)
		var mine := []
		for o in opts:
			if can_take(opener, o) and st.can_pay(opener, start_bid):
				mine.append(o)
		var r = ""
		if not mine.is_empty():
			r = await decide(opener, {"t": "auction_open", "options": mine, "all": opts, "bid": start_bid})
		if not (r is String) or (r != "" and not (r in mine)):
			r = ""
		if r == "":
			say("%s si ritira dalle aste di questo round." % pname(opener))
			var i0 := avail.find(opener)
			avail.erase(opener)
			auction["won"][opener] = ""
			if avail.is_empty():
				break
			opener = avail[i0 % avail.size()]
			continue
		var winner: int = await _run_auction(opener, r, start_bid, avail)
		taken[r] = winner
		var i1 := avail.find(winner)
		avail.erase(winner)
		auction["won"][winner] = r
		if avail.is_empty():
			break
		if winner == opener:
			opener = avail[i1 % avail.size()]
		changed.emit()
	# l'ultimo rimasto può prendere un oggetto per 200 fiorini
	if avail.size() == 1 and not abort:
		var s: int = avail[0]
		var opts2 := []
		for o in auction_objects():
			if not taken.has(o) and can_take(s, o):
				opts2.append(o)
		if not opts2.is_empty() and st.can_pay(s, 200):
			var r2 = await decide(s, {"t": "auction_last", "options": opts2, "price": 200})
			if r2 is String and r2 in opts2:
				say("%s prende %s per 200 fiorini." % [pname(s), D.OBJECT_NAME[r2]])
				await _pay_won(s, 200)
				await _gain_object(s, r2)
				taken[r2] = s
				auction["won"][s] = r2
			else:
				say("%s non prende niente." % pname(s))
	if st.opts.get("chars", false):
		for s in n:
			await _offer_char_free(s, "fine dell'asta")
	auction = {}
	changed.emit()


## Un'asta: si parte dall'offerta iniziale, poi a turno +100 o passo. Restituisce il vincitore.
func _run_auction(opener: int, obj: String, start_bid: int, avail: Array) -> int:
	var bid := start_bid
	var leader := opener
	var passed := {}
	auction["obj"] = obj
	auction["bid"] = bid
	auction["leader"] = leader
	auction["passed"] = passed
	say("%s mette all'asta %s: %d fiorini." % [pname(opener), D.OBJECT_NAME[obj], bid])
	fx.emit("bid", {"seat": opener, "bid": bid})
	var order := []
	var k0 := avail.find(opener)
	for i in avail.size():
		order.append(avail[(k0 + i) % avail.size()])
	var idx := 1
	while true:
		var active := []
		for s in order:
			if s != leader and not passed.has(s):
				active.append(s)
		if active.is_empty():
			break
		var s: int = order[idx % order.size()]
		idx += 1
		if s == leader or passed.has(s):
			continue
		var next := bid + 100
		var raise := false
		if can_take(s, obj) and st.can_pay(s, next):
			var r = await decide(s, {"t": "bid", "obj": obj, "bid": bid, "next": next, "leader": leader})
			raise = r == true
		if raise:
			bid = next
			leader = s
			auction["bid"] = bid
			auction["leader"] = leader
			say("%s offre %d." % [pname(s), bid])
			fx.emit("bid", {"seat": s, "bid": bid})
		else:
			passed[s] = true
			say("%s passa." % pname(s))
		changed.emit()
	say("%s si aggiudica %s per %d fiorini." % [pname(leader), D.OBJECT_NAME[obj], bid])
	fx.emit("won", {"seat": leader, "obj": obj, "bid": bid})
	await _pay_won(leader, bid)
	await _gain_object(leader, obj)
	return leader


## Pagamento dell'oggetto vinto: con il Mercante si può non pagare.
func _pay_won(s: int, cost: int) -> void:
	var p: Dictionary = st.players[s]
	if p["char"] == "mercante" and p["char_up"]:
		var ahead := _ahead(s)
		var r = await decide(s, {"t": "merchant", "cost": cost, "pp": 1 + ahead})
		if r == "free":
			p["char_up"] = false
			say("%s usa il Mercante: l'oggetto è gratis." % pname(s))
			return
		if r == "pp":
			p["char_up"] = false
			st.add_fame(s, 1 + ahead, "Mercante")
	st.pay(s, cost)
	if p["char"] == "professore" and p["char_up"]:
		await _offer_char_free(s, "dopo l'asta vinta")


func _ahead(s: int) -> int:
	var c := 0
	for o in n:
		if o != s and st.players[o]["fame"] > st.players[s]["fame"]:
			c += 1
	return c


## Personaggi che si possono usare fuori dalle azioni (Mercante per i punti, Professore).
func _offer_char_free(s: int, when: String) -> void:
	var p: Dictionary = st.players[s]
	if not p["char_up"] or st.players[s]["wolf"]:
		return
	if p["char"] == "professore":
		var r = await decide(s, {"t": "professor", "when": when, "bonus": st.bonus_deck.size() > 0, "prestige": st.prest_deck.size() > 0})
		if r == "bonus" and st.bonus_deck.size() > 0:
			p["char_up"] = false
			say("%s usa il Professore: carta Bonus gratis." % pname(s))
			await _pick_card(s, "bonus")
		elif r == "prestige" and st.prest_deck.size() > 0:
			p["char_up"] = false
			say("%s usa il Professore: carta Prestigio gratis." % pname(s))
			await _pick_card(s, "prestigio")
	elif p["char"] == "mercante" and when == "fine dell'asta":
		var ahead := _ahead(s)
		var r2 = await decide(s, {"t": "merchant", "cost": 0, "pp": 1 + ahead})
		if r2 == "pp":
			p["char_up"] = false
			st.add_fame(s, 1 + ahead, "Mercante")


## L'oggetto passa al giocatore.
func _gain_object(s: int, obj: String) -> void:
	var p: Dictionary = st.players[s]
	match obj:
		"paesaggio":
			var opts := []
			for l in D.LANDS:
				if st.supply["land"][l] > 0 and st.any_placement(s, "l", l):
					opts.append(l)
			var r = await decide(s, {"t": "land_choice", "options": opts})
			if not (r is String) or not (r in opts):
				r = opts[0]
			await _gain_object(s, r)
		"bosco", "lago", "parco":
			await _place_land(s, obj)
		"prestigio":
			await _pick_card(s, "prestigio")
		"reclutamento":
			st.supply["reclutamento"] -= 1
			p["recruits"] += 1
			if not p["wolf"]:
				await _offer_recruit(s, true)
		"giullare":
			st.supply["giullare"] -= 1
			p["jesters"] += 1
			fx.emit("jester", {"seat": s})
		"costruttore":
			st.supply["costruttore"] -= 1
			p["builders"] += 1
			if p["builders"] >= 2:
				st.add_fame(s, 3, "%d° costruttore" % p["builders"])
	changed.emit()


func _place_land(s: int, lid: String) -> void:
	var p: Dictionary = st.players[s]
	var pl := {}
	if p["wolf"]:
		pl = st.wolf_spot(s, "l", lid)
	else:
		var r = await decide(s, {"t": "place", "kind": "l", "id": lid})
		if r is Dictionary and st.can_place(s, "l", lid, r):
			pl = r
		else:
			pl = ais[s].best_place(self, s, "l", lid)
	st.place_land(s, lid, pl)
	say("%s mette %s nel principato." % [pname(s), ("una foresta" if lid == "bosco" else "un " + D.LAND_NAME[lid].to_lower())])
	fx.emit("placed", {"seat": s, "id": lid})
	_sync()


## Pesca fino a 5 carte (Prestigio, Bonus, Mestiere), ne tiene una, le altre vanno in fondo.
func _pick_card(s: int, kind: String) -> void:
	var deck: Array = st.prest_deck if kind == "prestigio" else (st.bonus_deck if kind == "bonus" else st.prof_deck)
	var drawn := []
	for k in mini(5, deck.size()):
		drawn.append(deck.pop_front())
	if drawn.is_empty():
		return
	var r = await decide(s, {"t": "pick", "kind": kind, "cards": drawn.duplicate()})
	if not (r is int) or not (int(r) in drawn):
		r = ais[s].decide(self, s, {"t": "pick", "kind": kind, "cards": drawn, "seat": s})
	drawn.erase(int(r))
	deck.append_array(drawn)
	var p: Dictionary = st.players[s]
	match kind:
		"prestigio":
			p["prestige"].append(int(r))
			say("%s prende una carta Prestigio." % pname(s))
		"bonus":
			p["bonus"].append(int(r))
			say("%s prende una carta Bonus." % pname(s))
		_:
			p["hand"].append(int(r))
			say("%s prende una carta Mestiere." % pname(s))
	_sync()


## Bersagli possibili per una carta Attrazione: [[posto, indice, professione], ...]
func recruit_targets(s: int) -> Array:
	var out := []
	for o in n:
		if o == s:
			continue
		var p: Dictionary = st.players[o]
		if p["wolf"]:
			for i in p["row"].size():
				var e: Dictionary = p["row"][i]
				if e["up"] and e["c"] > 0:
					out.append([o, i, e["c"]])
		else:
			for i in p["table"].size():
				if p["table"][i] > 0:
					out.append([o, i, p["table"][i]])
	if st.is_solo():
		var ds: Array = st.solo["dummies"]
		for d in ds.size():
			for i in ds[d].size():
				var e2: Dictionary = ds[d][i]
				if e2["up"]:
					out.append([-1 - d, i, e2["c"]])
	return out


func _offer_recruit(s: int, just_got: bool) -> void:
	var t := recruit_targets(s)
	if t.is_empty() or st.players[s]["recruits"] <= 0:
		return
	var r = await decide(s, {"t": "recruit", "targets": t, "now": just_got})
	if r is Array and r.size() >= 2:
		use_recruit(s, int(r[0]), int(r[1]))


func use_recruit(s: int, o: int, idx: int) -> bool:
	var p: Dictionary = st.players[s]
	if p["recruits"] <= 0:
		return false
	var c := 0
	if o <= -1:
		var col: Array = st.solo["dummies"][-1 - o]
		if idx < 0 or idx >= col.size() or not col[idx]["up"]:
			return false
		c = col[idx]["c"]
		col.remove_at(idx)
	else:
		var q: Dictionary = st.players[o]
		if q["wolf"]:
			if idx < 0 or idx >= q["row"].size() or not q["row"][idx]["up"] or q["row"][idx]["c"] <= 0:
				return false
			c = q["row"][idx]["c"]
			q["row"].remove_at(idx)
			q["row"].append({"c": 0, "up": false, "bonus": []})
		else:
			if idx < 0 or idx >= q["table"].size() or q["table"][idx] <= 0:
				return false
			c = q["table"][idx]
			q["table"][idx] = 0
	p["recruits"] -= 1
	p["hand"].append(c)
	say("%s usa una carta Attrazione e prende %s%s." % [pname(s), D.PROFS[c]["name"], (" da " + pname(o)) if o >= 0 else ""])
	fx.emit("recruit", {"seat": s, "from": o})
	_sync()
	return true


# ================================================================== asta in solitario

func automa_mod(code: String) -> int:
	var card: Dictionary = D.AUTOMA[solo_card]
	return int(card["m"][code][clampi(st.solo["pc"] - 4, 0, 1)])


func automa_code(obj: String) -> String:
	if obj in D.LANDS:
		return "L"
	for k in D.AUTOMA_OBJ:
		if D.AUTOMA_OBJ[k] == obj:
			return k
	return ""


## I due oggetti con il modificatore più alto (non acquistabili nell'ultima asta)
func automa_top2() -> Array:
	var card: Dictionary = D.AUTOMA[solo_card]
	var codes: Array = card["o"].duplicate()
	codes.sort_custom(func(a, b): return automa_mod(a) > automa_mod(b) or (automa_mod(a) == automa_mod(b) and card["o"].find(a) < card["o"].find(b)))
	return [codes[0], codes[1]]


func _roll() -> int:
	return st.rng.randi_range(1, 6)


func _next_automa() -> int:
	if st.solo["automa"].is_empty():
		var all := []
		for k in range(13, 22):
			all.append(k)
		st._shuffle(all)
		st.solo["automa"] = all
	solo_card = st.solo["automa"].pop_front()
	st.solo["card"] = solo_card
	changed.emit()
	return solo_card


func _solo_auction() -> void:
	var me := 0
	var w := st.wolf
	_next_automa()
	var pc: int = st.solo["pc"]
	var chosen := []
	solo_rolls = {}
	var bought := ""
	auction = {"solo": true, "chosen": chosen, "rolls": solo_rolls, "obj": "", "bid": 0, "leader": -1, "won": {}}
	var top2 := automa_top2()
	var k := 0
	while k < pc and bought == "" and not abort:
		var final := k == pc - 1
		var opts := []
		for o in D.OBJECTS:
			if o in chosen or not can_take(me, o):
				continue
			if final and automa_code(o) in top2:
				continue
			opts.append(o)
		if opts.is_empty():
			break
		var r = await decide(me, {"t": "solo_pick", "options": opts, "final": final, "card": solo_card})
		if not (r is String) or not (r in opts):
			say("%s si ritira dalle aste." % pname(me))
			break
		chosen.append(r)
		k += 1
		auction["obj"] = r
		var price := 200
		var forced := false
		var roll := 0
		var mod := 0
		if not final:
			roll = _roll()
			mod = automa_mod(automa_code(r))
			price = (roll + mod) * 100 + 100
			solo_rolls[r] = (roll + mod) * 100
			forced = mod == 0 and roll <= 2
			say("%s: dado %d%s, ultima offerta %d → prezzo %d." % [D.OBJECT_NAME[r], roll, (" + %d" % mod) if mod > 0 else "", (roll + mod) * 100, price])
			fx.emit("die", {"roll": roll})
		auction["bid"] = price
		changed.emit()
		var buy = forced
		if st.can_pay(me, price):
			var r2 = await decide(me, {"t": "solo_buy", "obj": r, "price": price, "forced": forced, "roll": roll, "mod": mod, "final": final})
			buy = forced or r2 == true
		else:
			buy = false
		if buy and st.can_pay(me, price):
			say("%s compra %s per %d fiorini." % [pname(me), D.OBJECT_NAME[r], price])
			st.pay(me, price)
			await _gain_object(me, r)
			bought = r
			auction["won"][me] = r
		elif final:
			break
	# Wolfgang compra
	await _wolf_buys(bought)
	if bought != "reclutamento" and auction["won"].get(w, "") != "reclutamento" and st.supply["reclutamento"] > 0:
		st.supply["reclutamento"] -= 1
		say("Si scarta una carta Attrazione.")
	if bought != "costruttore" and auction["won"].get(w, "") != "costruttore" and st.supply["costruttore"] > 0:
		st.supply["costruttore"] -= 1
		say("Si scarta un costruttore.")
	auction = {}
	changed.emit()


func _wolf_buys(bought: String) -> void:
	var w := st.wolf
	var p: Dictionary = st.players[w]
	var card: Dictionary = D.AUTOMA[solo_card]
	for code in card["o"]:
		var obj: String = D.AUTOMA_OBJ[code]
		if code == "L":
			var i := st.wolf_down_prof(w)
			if i < 0:
				continue
			obj = D.PROFS[p["row"][i]["c"]]["land"]
		if obj == bought or not object_left(obj):
			continue
		if obj == "costruttore" and p["builders"] >= 3:
			continue
		var cost := 0
		if solo_rolls.has(obj):
			cost = solo_rolls[obj]
		else:
			var roll := _roll()
			cost = (roll + automa_mod(code)) * 100
		say("Wolfgang compra %s per %d fiorini." % [D.OBJECT_NAME[obj], cost])
		st.pay(w, cost)
		auction["won"][w] = obj
		if obj == "prestigio":
			_wolf_pick(w, "prestigio")
		elif obj == "reclutamento":
			st.supply["reclutamento"] -= 1
			p["row"].append({"c": 0, "up": false, "bonus": []})
		else:
			await _gain_object(w, obj)
		return


## Wolfgang sceglie fra 5 carte quella che gli rende di più.
func _wolf_pick(w: int, kind: String) -> void:
	var deck: Array = st.prest_deck if kind == "prestigio" else st.bonus_deck
	var drawn := []
	for k in mini(5, deck.size()):
		drawn.append(deck.pop_front())
	if drawn.is_empty():
		return
	var best := -1
	var cand := []
	for c in drawn:
		var v := st.prestige_points(w, c) if kind == "prestigio" else st.bonus_value(w, c, true)
		if v > best:
			best = v
			cand = [c]
		elif v == best:
			cand.append(c)
	var pick: int = cand[st.rng.randi() % cand.size()]
	drawn.erase(pick)
	deck.append_array(drawn)
	var p: Dictionary = st.players[w]
	if kind == "prestigio":
		p["prestige"].append(pick)
		say("Wolfgang prende una carta Prestigio.")
	else:
		var i := -1
		for j in p["row"].size():
			if not p["row"][j]["up"]:
				i = j
				break
		if i >= 0:
			p["row"][i]["bonus"].append(pick)
		say("Wolfgang prende una carta Bonus.")
	_sync()


# ================================================================== asta dei personaggi

func char_range(c: String) -> Array:
	return D.CHAR_BIDS.get(c, D.CHAR_BIDS_DEFAULT)


func _char_auction() -> void:
	for s in n:
		var p: Dictionary = st.players[s]
		if p["char"] != "":
			st.chars[p["char"]]["owner"] = -1
			if p["char"] == "banchiere":
				st.banker_money = D.BANKER_START
			p["char"] = ""
			p["char_up"] = false
	char_bids = {}
	var done := {}
	var i := 0
	var guard := 0
	while done.size() < n and not abort and guard < 400:
		guard += 1
		var s: int = (st.start + i) % n
		i += 1
		if done.has(s):
			continue
		var mine := ""
		for c in char_bids:
			if char_bids[c][0] == s:
				mine = c
		if mine != "":
			var amt: int = char_bids[mine][1] * 100
			char_bids.erase(mine)
			_take_char(s, mine, amt)
			done[s] = true
			continue
		var opts := {}
		for c in D.CHARACTERS:
			if st.chars[c]["owner"] >= 0:
				continue
			var rg := char_range(c)
			var lo: int = rg[0]
			if char_bids.has(c):
				lo = char_bids[c][1] + 1
			if lo <= rg[1] and lo * 100 <= st.players[s]["money"]:
				opts[c] = [lo, mini(rg[1], st.players[s]["money"] / 100)]
		var r = null
		if not opts.is_empty():
			r = await decide(s, {"t": "char_bid", "options": opts, "bids": char_bids.duplicate(true), "banker": st.banker_money})
		if r is Dictionary and opts.has(r.get("c", "")) and int(r.get("v", -1)) >= opts[r["c"]][0] and int(r.get("v", -1)) <= opts[r["c"]][1]:
			var c2: String = r["c"]
			if char_bids.has(c2):
				say("%s supera %s sul %s: %d." % [pname(s), pname(char_bids[c2][0]), D.CHAR_NAME[c2], int(r["v"]) * 100])
			else:
				say("%s offre %d per il %s." % [pname(s), int(r["v"]) * 100, D.CHAR_NAME[c2]])
			char_bids[c2] = [s, int(r["v"])]
		else:
			say("%s passa." % pname(s))
			done[s] = true
		changed.emit()
	if st.chars["banchiere"]["owner"] < 0:
		st.banker_money += 100
	char_bids = {}
	changed.emit()


func _take_char(s: int, c: String, amt: int) -> void:
	var p: Dictionary = st.players[s]
	st.pay(s, amt)
	st.chars[c]["owner"] = s
	p["char"] = c
	p["char_up"] = true
	say("%s prende il %s per %d fiorini." % [pname(s), D.CHAR_NAME[c], amt])
	if c == "banchiere":
		p["money"] += st.banker_money
		say("%s incassa %d fiorini dal Banchiere." % [pname(s), st.banker_money])
		st.banker_money = 0
	fx.emit("char", {"seat": s, "c": c})


# ================================================================== azioni

const LIMITS := {"work": 2, "build": 2, "bonus": 2, "prof": 1, "freedom": 1}


func _action_phase() -> void:
	for s in n:
		var p: Dictionary = st.players[s]
		p["acts"] = {}
		p["nacts"] = 0
		p["best"] = -1
	for i in n:
		var s: int = (st.start + i) % n
		if abort:
			return
		if st.players[s]["wolf"]:
			await _wolf_turn(s)
		else:
			await _turn(s)
		await _wait(0.4)


func max_actions(s: int) -> int:
	return 3 if st.players[s].get("cardinal", false) else 2


## Opere possibili: [[carta, valore massimo con tutti i Bonus], ...]
func work_options(s: int) -> Array:
	var out := []
	var p: Dictionary = st.players[s]
	var muse: int = st.round if p["char"] == "musa" else 0
	for c in p["hand"]:
		var v := st.work_value(s, c, p["bonus"], muse)
		if v >= st.min_work():
			out.append([c, v])
	if p["char"] == "principessa" and p["char_up"]:
		var v2 := st.work_value(s, -1, [], muse)
		if v2 >= st.min_work():
			out.append([-1, v2])
	return out


func build_options(s: int) -> Array:
	var out := []
	var p: Dictionary = st.players[s]
	if not st.can_pay(s, st.build_cost(s)):
		return out
	for b in D.BUILDINGS:
		if st.supply["bld"][b] <= 0 or b in p["buildings"]:
			continue
		var ok := st.any_placement(s, "b", b)
		if not ok:
			for side in st.neighbors(s):
				if not st.coop_placements(s, side, b).is_empty():
					ok = true
					break
		if ok:
			out.append(b)
	return out


func freedom_options(s: int) -> Array:
	var out := []
	if not st.can_pay(s, 300):
		return out
	for f in D.FREEDOMS:
		if st.supply["free"][f] > 0 and not (f in st.players[s]["freedoms"]):
			out.append(f)
	return out


## Azioni disponibili ora per il giocatore
func action_menu(s: int) -> Dictionary:
	var p: Dictionary = st.players[s]
	var acts: Dictionary = p["acts"]
	var left: int = max_actions(s) - p["nacts"]
	var m := {}
	if left > 0:
		if acts.get("work", 0) < 2:
			var w := work_options(s)
			if not w.is_empty():
				m["work"] = w
		if acts.get("build", 0) < 2:
			var b := build_options(s)
			if not b.is_empty():
				m["build"] = b
		if acts.get("prof", 0) < 1 and st.prof_deck.size() > 0 and st.can_pay(s, 300):
			m["prof"] = true
		if acts.get("freedom", 0) < 1:
			var f := freedom_options(s)
			if not f.is_empty():
				m["freedom"] = f
		if acts.get("bonus", 0) < 2 and st.bonus_deck.size() > 0 and st.can_pay(s, 300):
			m["bonus"] = true
	if p["recruits"] > 0 and not recruit_targets(s).is_empty():
		m["recruit"] = recruit_targets(s)
	if st.can_sell_fame() and p["fame"] > 0:
		m["sell"] = p["fame"]
	if p["char_up"]:
		if p["char"] == "cardinale" and not p.get("cardinal", false):
			m["cardinal"] = true
		if p["char"] == "mercante":
			m["merchant"] = 1 + _ahead(s)
		if p["char"] == "professore":
			m["professor"] = true
	m["left"] = left
	return m


func _turn(s: int) -> void:
	var p: Dictionary = st.players[s]
	var guard := 0
	while not abort and guard < 40:
		guard += 1
		var menu := action_menu(s)
		var r = await decide(s, {"t": "action", "menu": menu})
		if not (r is Dictionary) or r.get("a", "end") == "end":
			break
		var a: String = r["a"]
		if a in ["work", "build", "prof", "freedom", "bonus"] and not menu.has(a):
			continue
		match a:
			"work":
				if await _do_work(s, r):
					_count(s, "work")
			"build":
				if await _do_build(s, r):
					_count(s, "build")
			"prof":
				st.pay(s, 300)
				await _pick_card(s, "prof")
				_count(s, "prof")
			"freedom":
				var f: String = r.get("f", "")
				if f in menu["freedom"]:
					st.pay(s, 300)
					st.supply["free"][f] -= 1
					p["freedoms"].append(f)
					say("%s introduce la %s." % [pname(s), D.FREEDOM_NAME[f]])
					fx.emit("freedom", {"seat": s, "f": f})
					_count(s, "freedom")
			"bonus":
				st.pay(s, 300)
				await _pick_card(s, "bonus")
				_count(s, "bonus")
			"recruit":
				if menu.has("recruit"):
					use_recruit(s, int(r.get("o", 0)), int(r.get("i", -1)))
			"sell":
				if menu.has("sell"):
					st.sell_fame(s, int(r.get("n", 0)))
			"cardinal":
				if menu.has("cardinal"):
					p["cardinal"] = true
					p["char_up"] = false
					say("%s usa il Cardinale: una terza azione." % pname(s))
			"merchant":
				if menu.has("merchant"):
					p["char_up"] = false
					st.add_fame(s, menu["merchant"], "Mercante")
			"professor":
				if menu.has("professor"):
					var k: String = r.get("k", "bonus")
					if k == "prestige" and st.prest_deck.size() > 0:
						p["char_up"] = false
						await _pick_card(s, "prestigio")
					elif st.bonus_deck.size() > 0:
						p["char_up"] = false
						await _pick_card(s, "bonus")
		_sync()
	p["cardinal"] = false


func _count(s: int, a: String) -> void:
	var p: Dictionary = st.players[s]
	p["acts"][a] = p["acts"].get(a, 0) + 1
	p["nacts"] += 1
	changed.emit()


func _do_work(s: int, r: Dictionary) -> bool:
	var p: Dictionary = st.players[s]
	var card := int(r.get("card", 0))
	var bon := []
	var muse: int = st.round if p["char"] == "musa" else 0
	if card == -1:
		if not (p["char"] == "principessa" and p["char_up"]):
			return false
	else:
		if not (card in p["hand"]):
			return false
		for b in r.get("bonus", []):
			if int(b) in p["bonus"] and not (int(b) in bon):
				bon.append(int(b))
	var v := st.work_value(s, card, bon, muse)
	if v < st.min_work():
		return false
	if card == -1:
		p["char_up"] = false
		say("%s completa un'opera con la Principessa: valore %d." % [pname(s), v])
	else:
		p["hand"].erase(card)
		p["table"].append(card)
		for b in bon:
			p["bonus"].erase(b)
			st.bonus_out.append(b)
		say("%s completa un'opera: %s, valore %d." % [pname(s), D.PROFS[card]["name"], v])
	p["best"] = maxi(p["best"], v)
	fx.emit("work", {"seat": s, "card": card, "value": v})
	_sync()
	var maxpp := v / 2
	var pp = await decide(s, {"t": "work_pay", "value": v, "max": maxpp})
	pp = clampi(int(pp) if (pp is int or pp is float) else 0, 0, maxpp)
	p["money"] += v * 100 - pp * 200
	if pp > 0:
		st.add_fame(s, pp)
	say("%s incassa %d fiorini%s." % [pname(s), v * 100 - pp * 200, (" e %d punti" % pp) if pp > 0 else ""])
	_sync()
	return true


func _do_build(s: int, r: Dictionary) -> bool:
	var p: Dictionary = st.players[s]
	var b: String = r.get("b", "")
	if not (b in D.BUILDINGS) or st.supply["bld"].get(b, 0) <= 0 or b in p["buildings"]:
		return false
	var pl: Dictionary = r.get("pl", {})
	var cost := st.build_cost(s)
	if not st.can_pay(s, cost):
		return false
	if pl.has("side"):
		var sp := st.coop_split(s, pl["side"], b, pl)
		if not sp.get("ok", false):
			return false
		var o: int = sp["other"]
		var price := maxi(0, int(r.get("price", 0)))
		if not st.can_pay(o, price):
			return false
		var ok = await decide(o, {"t": "coop_offer", "from": s, "b": b, "price": price, "pl": pl})
		if ok != true:
			say("%s rifiuta di costruire insieme a %s il %s." % [pname(o), pname(s), D.BUILDING_NAME[b]])
			return false
		st.pay(s, cost)
		st.pay(o, price)
		p["money"] += price
		st.place_building(s, b, pl)
		st.add_fame(s, 3, "edificio")
		st.add_fame(o, 3, "edificio in comune")
		say("%s e %s costruiscono insieme: %s (%s paga %d)." % [pname(s), pname(o), D.BUILDING_NAME[b], pname(o), price])
	else:
		if not st.can_place(s, "b", b, pl):
			return false
		st.pay(s, cost)
		st.place_building(s, b, pl)
		st.add_fame(s, 3, "edificio")
		say("%s costruisce: %s (%d fiorini)." % [pname(s), D.BUILDING_NAME[b], cost])
	fx.emit("placed", {"seat": s, "id": b})
	_sync()
	return true


# ================================================================== Wolfgang (solitario)

func _wolf_can(w: int, a: String) -> bool:
	var p: Dictionary = st.players[w]
	match a:
		"work":
			return not st.wolf_down(w).is_empty()
		"build":
			var i := st.wolf_down_prof(w)
			return i >= 0 and st.supply["bld"][D.PROFS[p["row"][i]["c"]]["bld"]] > 0
		"prof":
			return st.prof_deck.size() > 0
		"freedom":
			var i2 := st.wolf_down_prof(w)
			return i2 >= 0 and st.supply["free"][D.PROFS[p["row"][i2]["c"]]["free"]] > 0
		"bonus":
			return st.bonus_deck.size() > 0
	return false


func _wolf_turn(w: int) -> void:
	for k in 2:
		if abort:
			return
		var card := _next_automa()
		var panel: Array = D.AUTOMA[card]["a1" if k == 0 else "a2"]
		var act := ""
		if st.wolf_down(w).size() >= D.ROUNDS - st.round + 1 and _wolf_can(w, "work"):
			act = "work"
		else:
			for a in panel:
				if _wolf_can(w, a):
					act = a
					break
			if act == "":
				for a in ["prof", "build", "bonus", "freedom"]:
					if _wolf_can(w, a):
						act = a
						break
		await _wait(0.6)
		if act == "":
			say("Wolfgang non può fare nulla.")
			continue
		_wolf_do(w, act)
		changed.emit()


func _wolf_do(w: int, act: String) -> void:
	var p: Dictionary = st.players[w]
	match act:
		"work":
			var idx: int = st.wolf_down(w)[0]
			var v := st.wolf_work_value(w, idx)
			var e: Dictionary = p["row"][idx]
			e["up"] = true
			for b in e.get("bonus", []):
				st.bonus_out.append(b)
			e["bonus"] = []
			p["best"] = maxi(p["best"], v)
			var pp := v / 2
			st.add_fame(w, pp)
			p["money"] += (v % 2) * 100
			say("Wolfgang completa un'opera%s: valore %d, %d punti." % [(" (" + D.PROFS[e["c"]]["name"] + ")") if e["c"] > 0 else "", v, pp])
			fx.emit("work", {"seat": w, "card": e["c"], "value": v})
			for col in st.solo["dummies"]:
				for c in col:
					if not c["up"]:
						c["up"] = true
						break
		"build":
			var i := st.wolf_down_prof(w)
			var b: String = D.PROFS[p["row"][i]["c"]]["bld"]
			st.pay(w, st.build_cost(w))
			st.place_building(w, b, st.wolf_spot(w, "b", b))
			st.add_fame(w, 3, "edificio")
			say("Wolfgang costruisce: %s." % D.BUILDING_NAME[b])
			fx.emit("placed", {"seat": w, "id": b})
		"prof":
			st.pay(w, 300)
			p["row"].append({"c": st.prof_deck.pop_front(), "up": false, "bonus": []})
			for col in st.solo["dummies"]:
				if st.prof_deck.size() > 0:
					col.append({"c": st.prof_deck.pop_front(), "up": false})
			say("Wolfgang prende una carta Mestiere.")
		"freedom":
			var i2 := st.wolf_down_prof(w)
			var f: String = D.PROFS[p["row"][i2]["c"]]["free"]
			st.pay(w, 300)
			st.supply["free"][f] -= 1
			p["freedoms"].append(f)
			say("Wolfgang introduce la %s." % D.FREEDOM_NAME[f])
		"bonus":
			st.pay(w, 300)
			_wolf_pick(w, "bonus")
	_sync()


# ================================================================== fine round e partita

func _round_end() -> void:
	var best := -1
	for s in n:
		best = maxi(best, st.players[s]["best"])
	if best > 0:
		var who := []
		for s in n:
			if st.players[s]["best"] == best:
				who.append(s)
				st.add_fame(s, 3, "miglior opera del round (%d)" % best)
		fx.emit("best", {"seats": who, "value": best})
	else:
		say("Nessuna opera in questo round.")
	for s in n:
		st.players[s]["best"] = -1
	st.start = (st.start + 1) % n
	_sync()


func _final() -> void:
	st.phase = "fine"
	# Banchiere preso nell'ultimo round: fiorini in punti
	for s in n:
		var p: Dictionary = st.players[s]
		if p["char"] == "banchiere" and p["money"] >= 200:
			var r = await decide(s, {"t": "banker_end", "max": p["money"] / 200})
			var k := clampi(int(r) if (r is int or r is float) else 0, 0, p["money"] / 200)
			if k > 0:
				p["money"] -= k * 200
				st.add_fame(s, k, "Banchiere")
	results = []
	for s in n:
		var det := []
		for pid in st.players[s]["prestige"]:
			det.append([pid, st.prestige_points(s, pid)])
		results.append({"seat": s, "name": pname(s), "fame": st.players[s]["fame"], "prestige": det,
			"score": st.final_score(s), "money": st.players[s]["money"]})
	results.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["money"] > b["money"]))
	for r in results:
		var extra := 0
		for d in r["prestige"]:
			extra += d[1]
		say("%s: %d punti (%d di fama + %d dalle carte Prestigio), %d fiorini." % [r["name"], r["score"], r["fame"], extra, r["money"]])
	say("Vince %s!" % results[0]["name"])
	game_over = true
	if online != null:
		online.finish()
	_sync()
	game_ended.emit(results)


## Impronta dello stato (per controllare che online tutti abbiano la stessa partita)
func fingerprint() -> String:
	var parts := []
	for p in st.players:
		parts.append("%d/%d/%d/%d" % [p["money"], p["fame"], p["hand"].size(), p["buildings"].size()])
	return "r%d:" % st.round + ",".join(parts)
