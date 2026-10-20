class_name PFState
extends RefCounted
## Stato della partita e regole immediate (costi, piazzamenti, valore delle opere, punteggi).
## Non chiede niente a nessuno: le decisioni le raccoglie il motore (PFEngine).

const D = preload("res://scripts/data/pf_data.gd")

var rng := RandomNumberGenerator.new()
var seed := 0
var n := 0
var players: Array = []
var round := 1
var start := 0                    # giocatore iniziale del round
var opts := {}                    # chars (personaggi), coop (lato B)
var two_p := false
var supply := {}
var prof_deck: Array = []
var prest_deck: Array = []
var bonus_deck: Array = []
var bonus_out: Array = []         # carte Bonus giocate (fuori dal gioco)
var chars := {}                   # nome -> {owner, up}
var banker_money := 600
var solo := {}                    # partita in solitario contro Wolfgang
var log: Array = []
var phase := ""
var wolf := -1                    # posto di Wolfgang (solo)


# ================================================================== preparazione

func setup(cfg: Dictionary) -> void:
	seed = int(cfg.get("seed", 0))
	if seed == 0:
		rng.randomize()
		seed = int(rng.randi() % 2000000000) + 1
	rng.seed = seed
	opts = cfg.get("opts", {}).duplicate()
	var seats: Array = cfg["seats"]
	n = seats.size()
	two_p = n == 2 and cfg.get("solo", null) == null
	var sd = cfg.get("solo", null)
	if sd is Dictionary:
		opts.erase("chars")
		opts.erase("coop")
	var side := "B" if opts.get("coop", false) else "A"
	for i in n:
		var s: Dictionary = seats[i]
		var b: Dictionary = D.BOARD_B if side == "B" else D.BOARD_A
		var grid := []
		grid.resize(b["w"] * b["h"])
		grid.fill("")
		for c in b["palazzo"]:
			grid[c.y * b["w"] + c.x] = "P"
		players.append({
			"id": i, "color": s.get("color", D.COLORS[i]["id"]), "side": s.get("side", "d"),
			"name": s.get("name", "Giocatore %d" % (i + 1)), "ai": bool(s.get("ai", false)), "level": int(s.get("level", 1)),
			"wolf": bool(s.get("wolf", false)),
			"money": D.START_MONEY_2P if two_p else D.START_MONEY, "fame": 0,
			"board": side, "w": b["w"], "h": b["h"], "grid": grid, "pieces": [],
			"buildings": [], "land": {"bosco": 0, "lago": 0, "parco": 0}, "freedoms": [],
			"builders": 0, "jesters": 0, "hand": [], "recruits": 0, "bonus": [], "prestige": [],
			"table": [], "row": [], "best": -1, "char": "", "char_up": false, "acts": {}, "nacts": 0,
		})
	# rifornimenti
	supply = {"bld": {}, "land": {}, "free": {}, "giullare": D.JESTERS, "costruttore": D.BUILDERS, "reclutamento": D.RECRUITS}
	for bid in D.BUILDINGS:
		supply["bld"][bid] = D.BUILDING_COPIES
	for l in D.LANDS:
		supply["land"][l] = D.LAND_COUNT
	for f in D.FREEDOMS:
		supply["free"][f] = maxi(1, n - 1)
	if two_p:
		for f in D.FREEDOMS:
			supply["free"][f] = 1
		var extra: Array = D.FREEDOMS.duplicate()
		_shuffle(extra)
		supply["free"][extra[0]] += 1
		supply["free"][extra[1]] += 1
	prof_deck = []
	for k in D.PROFS:
		prof_deck.append(int(k))
	_shuffle(prof_deck)
	prest_deck = []
	for k in D.PRESTIGE:
		prest_deck.append(int(k))
	_shuffle(prest_deck)
	bonus_deck = []
	for k in D.BONUS:
		bonus_deck.append(int(k))
	_shuffle(bonus_deck)
	if opts.get("chars", false):
		for c in D.CHARACTERS:
			chars[c] = {"owner": -1, "up": true}
		banker_money = D.BANKER_START
	if sd is Dictionary:
		_setup_solo(sd)
	start = int(cfg.get("start", rng.randi() % n))


func _setup_solo(sd: Dictionary) -> void:
	wolf = 1
	var dummies := int(sd.get("dummies", 2))
	solo = {"dummies": [], "diff": int(sd.get("diff", 1)), "pc": 2 + dummies, "automa": [], "card": 0}
	for f in D.FREEDOMS:
		supply["free"][f] = 2
	players[wolf]["money"] = D.WOLFGANG_MONEY[solo["diff"]]
	players[wolf]["wolf"] = true
	players[wolf]["ai"] = true
	# mazzo dell'Automa: 1-2 sopra, poi 3-4, poi 5-7
	var a := [1, 2, 3, 4, 5, 6]
	var b := [7, 8, 9, 10, 11, 12]
	var c := [13, 14, 15, 16, 17, 18, 19, 20, 21]
	_shuffle(a)
	_shuffle(b)
	_shuffle(c)
	solo["automa"] = a + b + c
	for d in dummies:
		solo["dummies"].append([])


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func say(t: String) -> void:
	log.append(t)


func pname(s: int) -> String:
	if s < 0 or s >= n:
		return "?"
	return players[s]["name"]


func is_solo() -> bool:
	return not solo.is_empty()


func min_work() -> int:
	return D.MIN_WORK[clampi(round, 1, 7)]


# ================================================================== denaro e fama

## La fama si può scambiare con denaro (100 fiorini per punto), ma non con i personaggi.
func can_sell_fame() -> bool:
	return not opts.get("chars", false)


## Denaro che il giocatore può mettere insieme, vendendo anche la fama se è permesso.
func purse(s: int) -> int:
	var p: Dictionary = players[s]
	if p["wolf"]:
		return 999999
	return p["money"] + (p["fame"] * 100 if can_sell_fame() else 0)


func can_pay(s: int, cost: int) -> bool:
	return purse(s) >= cost


## Paga, scendendo sulla traccia della fama se servono fiorini (Wolfgang: 200 fiorini a punto, anche sotto zero).
func pay(s: int, cost: int) -> void:
	if cost <= 0:
		return
	var p: Dictionary = players[s]
	if p["money"] >= cost:
		p["money"] -= cost
		return
	var need := cost - int(p["money"])
	if p["wolf"]:
		var steps := int(ceil(need / 200.0))
		p["money"] = steps * 200 - need
		p["fame"] -= steps
		say("%s scende di %d sulla traccia della fama per pagare." % [pname(s), steps])
		return
	var pts := int(ceil(need / 100.0))
	pts = mini(pts, p["fame"])
	p["fame"] -= pts
	p["money"] = p["money"] + pts * 100 - cost
	if pts > 0:
		say("%s cede %d punti di fama per %d fiorini." % [pname(s), pts, pts * 100])


func sell_fame(s: int, pts: int) -> void:
	var p: Dictionary = players[s]
	pts = clampi(pts, 0, p["fame"])
	p["fame"] -= pts
	p["money"] += pts * 100
	if pts > 0:
		say("%s cede %d punti di fama per %d fiorini." % [pname(s), pts, pts * 100])


func add_fame(s: int, pts: int, why := "") -> void:
	if pts == 0:
		return
	players[s]["fame"] += pts
	if why != "":
		say("%s: +%d punti (%s)." % [pname(s), pts, why])


# ================================================================== principato

func cell(s: int, x: int, y: int) -> String:
	var p: Dictionary = players[s]
	if x < 0 or y < 0 or x >= p["w"] or y >= p["h"]:
		return "#"
	return p["grid"][y * p["w"] + x]


func empty_cells(s: int) -> int:
	var c := 0
	for v in players[s]["grid"]:
		if v == "":
			c += 1
	return c


func build_cost(s: int) -> int:
	var b: int = players[s]["builders"]
	return 0 if b >= 3 else (300 if b >= 1 else 700)


func has_building(s: int, bid: String) -> bool:
	return bid in players[s]["buildings"]


func neighbors(s: int) -> Dictionary:
	## vicini sul tabellone condiviso (lato B): L a sinistra, R a destra
	var out := {}
	if not opts.get("coop", false) or n < 2:
		return out
	if n == 2:
		if s == 0:
			out["R"] = 1
		else:
			out["L"] = 0
		return out
	out["R"] = (s + 1) % n
	out["L"] = (s - 1 + n) % n
	return out


func _is_bld(v: String) -> bool:
	return v == "P" or v.begins_with("b:")


## Controlla un edificio nelle caselle (già nel principato s). adj_ok: adiacenze permesse.
func _bld_ok_in(s: int, cells: Array, bid: String) -> bool:
	var p: Dictionary = players[s]
	if bid in p["buildings"] and not p["wolf"]:
		return false
	var adj_ok: bool = p["builders"] >= 2 or p["wolf"]
	var set := {}
	for c in cells:
		set[c] = true
	for c in cells:
		if cell(s, c.x, c.y) != "":
			return false
	if adj_ok:
		return true
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if set.has(q):
				continue
			if _is_bld(cell(s, q.x, q.y)):
				return false
	return true


## Piazzamento legale di un pezzo (edificio o paesaggio) nel solo principato del giocatore.
func can_place(s: int, kind: String, id: String, pl: Dictionary) -> bool:
	var cells := placed_cells(id, pl)
	var p: Dictionary = players[s]
	for c in cells:
		if c.x < 0 or c.y < 0 or c.x >= p["w"] or c.y >= p["h"]:
			return false
	if kind == "l":
		for c in cells:
			if cell(s, c.x, c.y) != "":
				return false
		return true
	if not _bld_ok_in(s, cells, id):
		return false
	# lato B: un edificio costruito da soli può toccare il confine con un vicino solo con i costruttori
	var nb := neighbors(s)
	if not nb.is_empty() and not p["wolf"]:
		for side in nb:
			var edge: int = 0 if side == "L" else p["w"] - 1
			var other_edge: int = players[nb[side]]["w"] - 1 if side == "L" else 0
			for c in cells:
				if c.x != edge:
					continue
				if p["builders"] == 0:
					return false
				if p["builders"] == 1 and cell(nb[side], other_edge, c.y) != "":
					return false
	return true


static func placed_cells(id: String, pl: Dictionary) -> Array:
	var base := D.shape_cells(id, int(pl.get("r", 0)), bool(pl.get("f", false)))
	var out := []
	var o := Vector2i(int(pl.get("x", 0)), int(pl.get("y", 0)))
	for c in base:
		out.append(c + o)
	return out


## Tutti i piazzamenti legali (solo nel proprio principato).
func placements(s: int, kind: String, id: String) -> Array:
	var out := []
	var p: Dictionary = players[s]
	for o in D.orientations(id):
		var cells: Array = o[2]
		var mx := 0
		var my := 0
		for c in cells:
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		for y in range(0, p["h"] - my):
			for x in range(0, p["w"] - mx):
				var pl := {"x": x, "y": y, "r": o[0], "f": o[1]}
				if can_place(s, kind, id, pl):
					out.append(pl)
	return out


func any_placement(s: int, kind: String, id: String) -> bool:
	var p: Dictionary = players[s]
	for o in D.orientations(id):
		var cells: Array = o[2]
		var mx := 0
		var my := 0
		for c in cells:
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		for y in range(0, p["h"] - my):
			for x in range(0, p["w"] - mx):
				if can_place(s, kind, id, {"x": x, "y": y, "r": o[0], "f": o[1]}):
					return true
	return false


## Edificio in cooperazione (lato B): pl in coordinate del giocatore s, con le caselle del vicino
## a destra (x >= w) o a sinistra (x < 0). Restituisce {ok, mine, theirs}.
func coop_split(s: int, side: String, id: String, pl: Dictionary) -> Dictionary:
	var nb := neighbors(s)
	if not nb.has(side):
		return {"ok": false}
	var o: int = nb[side]
	var p: Dictionary = players[s]
	var q: Dictionary = players[o]
	var mine := []
	var theirs := []
	for c in placed_cells(id, pl):
		if c.y < 0 or c.y >= p["h"]:
			return {"ok": false}
		if c.x >= 0 and c.x < p["w"]:
			mine.append(c)
		elif side == "R" and c.x >= p["w"] and c.x < p["w"] + q["w"]:
			theirs.append(Vector2i(c.x - p["w"], c.y))
		elif side == "L" and c.x < 0 and c.x >= -q["w"]:
			theirs.append(Vector2i(c.x + q["w"], c.y))
		else:
			return {"ok": false}
	if mine.is_empty() or theirs.is_empty():
		return {"ok": false}
	if not _bld_ok_in(s, mine, id) or not _bld_ok_in(o, theirs, id):
		return {"ok": false}
	return {"ok": true, "mine": mine, "theirs": theirs, "other": o}


func coop_placements(s: int, side: String, id: String) -> Array:
	var out := []
	var nb := neighbors(s)
	if not nb.has(side):
		return out
	var p: Dictionary = players[s]
	for o in D.orientations(id):
		var cells: Array = o[2]
		var mx := 0
		var my := 0
		for c in cells:
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		var xs := range(p["w"] - mx, p["w"]) if side == "R" else range(-mx, 0)
		for y in range(0, p["h"] - my):
			for x in xs:
				var pl := {"x": x, "y": y, "r": o[0], "f": o[1], "side": side}
				if coop_split(s, side, id, pl).get("ok", false):
					out.append(pl)
	return out


func _put(s: int, cells: Array, val: String) -> void:
	var p: Dictionary = players[s]
	for c in cells:
		p["grid"][c.y * p["w"] + c.x] = val


## Mette un paesaggio (già pagato) nel principato. Restituisce i punti guadagnati.
func place_land(s: int, lid: String, pl: Dictionary) -> int:
	var p: Dictionary = players[s]
	var cells := placed_cells(lid, pl)
	if not p["wolf"] or can_place(s, "l", lid, pl):
		_put(s, cells, "l:" + lid)
		p["pieces"].append({"k": "l", "id": lid, "x": pl.get("x", 0), "y": pl.get("y", 0), "r": pl.get("r", 0), "f": pl.get("f", false)})
	var pts := 3 if p["land"][lid] > 0 else 0
	p["land"][lid] += 1
	supply["land"][lid] -= 1
	if pts > 0:
		add_fame(s, pts, "un altro %s" % D.LAND_NAME[lid].to_lower())
	return pts


func place_building(s: int, bid: String, pl: Dictionary) -> void:
	var p: Dictionary = players[s]
	if pl.has("side"):
		var sp := coop_split(s, pl["side"], bid, pl)
		var o: int = sp["other"]
		_put(s, sp["mine"], "b:" + bid)
		_put(o, sp["theirs"], "b:" + bid)
		p["pieces"].append({"k": "b", "id": bid, "x": pl["x"], "y": pl["y"], "r": pl.get("r", 0), "f": pl.get("f", false), "with": o})
		var q: Dictionary = players[o]
		var dx: int = -p["w"] if pl["side"] == "R" else q["w"]
		q["pieces"].append({"k": "b", "id": bid, "x": int(pl["x"]) + dx, "y": pl["y"], "r": pl.get("r", 0), "f": pl.get("f", false), "with": s, "ghost": true})
		p["buildings"].append(bid)
		q["buildings"].append(bid)
	else:
		if not p["wolf"] or (pl.has("x") and can_place(s, "b", bid, pl)):
			_put(s, placed_cells(bid, pl), "b:" + bid)
			p["pieces"].append({"k": "b", "id": bid, "x": pl.get("x", 0), "y": pl.get("y", 0), "r": pl.get("r", 0), "f": pl.get("f", false)})
		p["buildings"].append(bid)
	supply["bld"][bid] -= 1


## Wolfgang non segue le regole di piazzamento: si cerca comunque un posto libero per mostrarlo.
func wolf_spot(s: int, kind: String, id: String) -> Dictionary:
	var pls := placements(s, kind, id)
	if pls.is_empty():
		return {}
	return pls[0]


# ================================================================== conteggi

func n_buildings(s: int) -> int:
	return players[s]["buildings"].size()


func n_lands(s: int) -> int:
	var t := 0
	for l in D.LANDS:
		t += players[s]["land"][l]
	return t


func land_types(s: int) -> int:
	var t := 0
	for l in D.LANDS:
		if players[s]["land"][l] > 0:
			t += 1
	return t


func n_size(s: int, sz: String) -> int:
	var t := 0
	for b in players[s]["buildings"]:
		if D.BUILDING_SIZE[b] == sz:
			t += 1
	return t


func works(s: int) -> int:
	var p: Dictionary = players[s]
	if p["wolf"]:
		var t := 0
		for e in p["row"]:
			if e["up"]:
				t += 1
		return t
	return p["table"].size()


## Carte Professione e Reclutamento in mano e sul tavolo (per il valore dell'opera)
func card_count(s: int) -> int:
	var p: Dictionary = players[s]
	return p["hand"].size() + p["recruits"] + p["table"].size()


func n_freedoms(s: int) -> int:
	return players[s]["freedoms"].size()


## Valore di una carta Bonus giocata con l'opera (played = una Professione appena giocata)
func bonus_value(s: int, b: int, played := true) -> int:
	var p: Dictionary = players[s]
	match b:
		1: return n_buildings(s)
		2: return 2 * n_size(s, "G")
		3: return n_size(s, "M") + p["land"]["bosco"]
		4: return n_size(s, "P") + n_lands(s)
		5:
			var t := 0
			for sz in ["G", "M", "P"]:
				if n_size(s, sz) > 0:
					t += 2
			return t
		6: return n_lands(s)
		7: return 2 * p["land"]["bosco"]
		8: return 2 * p["land"]["lago"]
		9: return 2 * p["land"]["parco"]
		10: return 2 * n_freedoms(s)
		11: return 2 * p["jesters"]
		12: return p["jesters"] + n_freedoms(s)
		13: return 2 * p["builders"]
		14: return p["builders"] + p["land"]["lago"]
		15: return 2 * p["prestige"].size()
		16: return p["prestige"].size() + n_freedoms(s)
		17: return 2 * land_types(s)
		18:
			var t := 0
			for l in D.LANDS:
				if p["land"][l] > 0:
					t += 1
			for k in ["jesters", "builders"]:
				if p[k] > 0:
					t += 1
			if p["prestige"].size() > 0:
				t += 1
			if n_freedoms(s) > 0:
				t += 1
			return t
		19:
			if p["wolf"]:
				return maxi(0, wolf_down(s).size() - 1)
			return maxi(0, p["hand"].size() - (1 if played else 0)) + p["recruits"]
		20:
			if p["wolf"]:
				return works(s) + 1
			return p["table"].size() + (1 if played else 0)
	return 0


## Valore dell'opera con la Professione card (o con la Principessa se card == -1).
func work_value(s: int, card: int, bonuses: Array = [], muse_round := 0) -> int:
	var p: Dictionary = players[s]
	var v := 0
	if card == -1:
		v += 3 * n_lands(s) + 2 * n_buildings(s) + 2 * p["builders"] + card_count(s)
	else:
		var pr: Dictionary = D.PROFS[card]
		if p["land"][pr["land"]] > 0:
			v += 3
		if pr["free"] in p["freedoms"]:
			v += 3
		if pr["bld"] in p["buildings"]:
			v += 4
		v += 2 * p["jesters"]
		v += card_count(s)
		for b in bonuses:
			v += bonus_value(s, int(b), true)
	v += muse_round
	return v


## Dettaglio del valore (per la UI)
func work_breakdown(s: int, card: int, bonuses: Array = [], muse_round := 0) -> Array:
	var p: Dictionary = players[s]
	var out := []
	if card == -1:
		out.append(["Paesaggi ×3", 3 * n_lands(s)])
		out.append(["Edifici ×2", 2 * n_buildings(s)])
		out.append(["Costruttori ×2", 2 * p["builders"]])
		out.append(["Carte Professione/Reclutamento", card_count(s)])
	else:
		var pr: Dictionary = D.PROFS[card]
		out.append([D.LAND_NAME[pr["land"]], 3 if p["land"][pr["land"]] > 0 else 0])
		out.append([D.FREEDOM_SHORT[pr["free"]], 3 if pr["free"] in p["freedoms"] else 0])
		out.append([D.BUILDING_NAME[pr["bld"]], 4 if pr["bld"] in p["buildings"] else 0])
		out.append(["Giullari ×2", 2 * p["jesters"]])
		out.append(["Carte Professione/Reclutamento", card_count(s)])
		for b in bonuses:
			out.append(["Bonus B%d" % int(b), bonus_value(s, int(b), true)])
	if muse_round > 0:
		out.append(["Musa", muse_round])
	return out


# ================================================================== carte Prestigio

func _count_for(s: int, pid: int) -> int:
	var p: Dictionary = players[s]
	match pid:
		1: return n_buildings(s)
		3: return -empty_cells(s)
		5: return n_lands(s)
		6: return p["land"]["bosco"]
		7: return p["land"]["lago"]
		10: return p["jesters"]
		11: return p["builders"]
		12: return p["land"]["parco"]
		14: return works(s)
	return 0


## Giocatori che contano nei confronti «più di tutti» (in solitario: tu e Wolfgang)
func rivals() -> Array:
	var out := []
	for i in n:
		out.append(i)
	return out


func prestige_points(s: int, pid: int) -> int:
	var p: Dictionary = players[s]
	var info: Dictionary = D.PRESTIGE[pid]
	match pid:
		2: return info["pts"] if n_size(s, "G") >= 2 else 0
		4: return info["pts"] if land_types(s) >= 3 else 0
		8:
			var kinds := {}
			for f in p["freedoms"]:
				kinds[f] = true
			return info["pts"] if kinds.size() >= 3 else 0
		9: return info["pts"] if n_buildings(s) >= 4 and n_freedoms(s) >= 2 and works(s) >= 4 else 0
		13: return info["pts"] if p["builders"] >= 1 and p["jesters"] >= 1 and n_lands(s) >= 2 else 0
	var mine := _count_for(s, pid)
	if pid != 3 and mine <= 0:
		return 0
	var tie := false
	for o in rivals():
		if o == s:
			continue
		var v := _count_for(o, pid)
		if v > mine:
			return 0
		if v == mine:
			tie = true
	return info["tie"] if tie else info["pts"]


## Punteggio finale: fama + carte Prestigio
func final_score(s: int) -> int:
	var t: int = players[s]["fame"]
	for pid in players[s]["prestige"]:
		t += prestige_points(s, int(pid))
	return t


func fame_track(s: int) -> int:
	return posmod(players[s]["fame"], 50)


# ================================================================== Wolfgang

## Carte coperte nella fila di Wolfgang (Professioni e Reclutamento)
func wolf_down(s: int) -> Array:
	var out := []
	var row: Array = players[s]["row"]
	for i in row.size():
		if not row[i]["up"]:
			out.append(i)
	return out


func wolf_down_prof(s: int) -> int:
	var row: Array = players[s]["row"]
	for i in row.size():
		if not row[i]["up"] and row[i]["c"] > 0:
			return i
	return -1


## Valore dell'opera di Wolfgang: minimo del round + giullari + carte Reclutamento + Bonus sulla carta
func wolf_work_value(s: int, idx: int) -> int:
	var p: Dictionary = players[s]
	var v: int = min_work() + 2 * int(p["jesters"])
	for e in p["row"]:
		if e["c"] == 0:
			v += 1
	for b in p["row"][idx].get("bonus", []):
		v += bonus_value(s, int(b), true)
	return v
