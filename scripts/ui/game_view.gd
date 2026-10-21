extends Control
## La partita: tavolo 3D (o 2D dall'alto) dietro, e sopra le casate, la cronaca, la mano
## e le richieste del motore (aste, azioni, piazzamenti, scelte di carte).

const D = preload("res://scripts/data/pf_data.gd")
const PlaceDialog = preload("res://scripts/ui/place_dialog.gd")

var main
var config := {}
var eng: PFEngine
var board: Board3D
var me := 0                       # casata di cui si mostra la mano
var req := {}                     # richiesta in attesa
var online = null

var top_lbl: Label
var phase_lbl: Label
var players_box: VBoxContainer
var log_text: RichTextLabel
var log_lines: Array = []
var hand_box: HBoxContainer
var hand_title: Label
var prompt: PanelContainer
var prompt_lbl: RichTextLabel
var prompt_body: VBoxContainer
var overlay: Control
var status_lbl: Label
var b_view: Button
var auction_lbl: RichTextLabel
var _place: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	eng = PFEngine.new()
	add_child(eng)
	online = config.get("online", null)
	var cfg := config.duplicate()
	cfg.erase("online")
	eng.setup(cfg)
	if online != null:
		add_child(online)
		online.view = self
		eng.online = online
		me = online.seat
	else:
		me = _first_human()
	board = Board3D.new()
	board.eng = eng
	add_child(board)
	board.principality_clicked.connect(func(s): board.focus_seat(s))
	_build_hud()
	eng.changed.connect(_refresh)
	eng.log_added.connect(_on_log)
	eng.decision_requested.connect(_on_decision)
	eng.game_ended.connect(_on_end)
	eng.fx.connect(_on_fx)
	_refresh()
	if online != null and online.role != "host":
		online.heartbeat_loop()
	elif online != null:
		online.heartbeat_loop()
	await get_tree().process_frame
	eng.run()


func _exit_tree() -> void:
	if eng != null:
		eng.abort = true
		eng.provide_decision(null)


func _first_human() -> int:
	for s in eng.n:
		if not eng.players[s]["ai"]:
			return s
	return 0


# ================================================================== interfaccia fissa

func _build_hud() -> void:
	# barra in alto
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.flat(Color(0.16, 0.1, 0.06, 0.92), UI.GOLD_D, 0, 0, 10))
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 58)
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	bar.add_child(hb)
	var g := UI.icon_rect(UI.tex("res://assets/tokens/giglio.png"), Vector2(34, 40))
	hb.add_child(g)
	var t := UI.label("I Principi di Firenze", 26, UI.GOLD, UI.font_deco)
	hb.add_child(t)
	top_lbl = UI.label("", 22, UI.SAND, UI.font_title)
	top_lbl.custom_minimum_size.x = 400
	hb.add_child(top_lbl)
	phase_lbl = UI.label("", 21, UI.SAND, UI.font_italic)
	phase_lbl.clip_text = true
	phase_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(phase_lbl)
	b_view = UI.button("Vista 2D", 130, 42, 17)
	UI.dark(b_view)
	b_view.pressed.connect(func():
		board.set_flat(not board.flat)
		b_view.text = "Vista 3D" if board.flat else "Vista 2D")
	hb.add_child(b_view)
	var b_reset := UI.button("Inquadra", 120, 42, 17)
	UI.dark(b_reset)
	b_reset.pressed.connect(func(): board.reset_view())
	hb.add_child(b_reset)
	var b_mine := UI.button("Il mio principato", 200, 42, 17)
	UI.dark(b_mine)
	b_mine.pressed.connect(func(): board.focus_seat(me))
	hb.add_child(b_mine)
	var b_rules := UI.button("Regole", 100, 42, 17)
	UI.dark(b_rules)
	b_rules.pressed.connect(_show_rules)
	hb.add_child(b_rules)
	var b_menu := UI.button("Menu", 90, 42, 17)
	UI.dark(b_menu)
	b_menu.pressed.connect(_ask_menu)
	hb.add_child(b_menu)

	# casate a sinistra
	players_box = VBoxContainer.new()
	players_box.position = Vector2(8, 66)
	players_box.custom_minimum_size = Vector2(330, 0)
	players_box.add_theme_constant_override("separation", 6)
	add_child(players_box)

	# colonna destra: cronaca, stato dell'asta, richiesta corrente
	var col := VBoxContainer.new()
	col.position = Vector2(1548, 64)
	col.custom_minimum_size = Vector2(366, 0)
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.paper(false, 12))
	lp.custom_minimum_size = Vector2(366, 250)
	col.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(UI.title("Cronaca", 22))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(336, 190)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	log_text = UI.rich(17, 322)
	sc.add_child(log_text)
	log_text.resized.connect(func(): sc.scroll_vertical = int(log_text.size.y))
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", UI.paper(false, 12))
	ap.custom_minimum_size = Vector2(366, 0)
	col.add_child(ap)
	auction_lbl = UI.rich(17, 336)
	ap.add_child(auction_lbl)
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.paper(false, 14))
	prompt.custom_minimum_size = Vector2(366, 0)
	prompt.visible = false
	col.add_child(prompt)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	prompt.add_child(pv)
	prompt_lbl = UI.rich(20, 336)
	pv.add_child(prompt_lbl)
	prompt_body = VBoxContainer.new()
	prompt_body.add_theme_constant_override("separation", 6)
	pv.add_child(prompt_body)

	# mano in basso
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UI.flat(Color(0.16, 0.1, 0.06, 0.88), UI.GOLD_D, 2, 10, 10))
	hp.position = Vector2(346, 862)
	hp.size = Vector2(1194, 210)
	hp.custom_minimum_size = Vector2(1194, 210)
	add_child(hp)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hp.add_child(hv)
	hand_title = UI.label("", 20, UI.SAND, UI.font_title)
	hv.add_child(hand_title)
	var hs := ScrollContainer.new()
	hs.custom_minimum_size = Vector2(1170, 172)
	hs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hv.add_child(hs)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 8)
	hs.add_child(hand_box)

	status_lbl = UI.label("", 21, UI.SAND, UI.font_italic)
	status_lbl.position = Vector2(350, 66)
	add_child(status_lbl)


# ================================================================== aggiornamento

var _dirty := false


func _refresh() -> void:
	_dirty = true


func _process(_d: float) -> void:
	if _dirty:
		_dirty = false
		_do_refresh()


func _do_refresh() -> void:
	var st := eng.st
	top_lbl.text = "Round %d di 7 · Opera minima %d" % [st.round, st.min_work()]
	var ph := {"preparazione": "Preparazione", "asta": "Asta", "personaggi": "Asta dei personaggi", "azioni": "Azioni", "fine": "Fine della partita"}
	var who := ""
	if eng.current >= 0 and st.phase != "fine":
		who = " · tocca a %s" % eng.pname(eng.current)
	phase_lbl.text = "Fase: %s%s" % [ph.get(st.phase, st.phase), who]
	_refresh_players()
	_refresh_hand()
	_refresh_auction()
	if board != null:
		board.refresh()


func _refresh_players() -> void:
	UI.clear(players_box)
	var st := eng.st
	for s in st.n:
		players_box.add_child(_player_card(s))


func _player_card(s: int) -> Control:
	var st := eng.st
	var p: Dictionary = st.players[s]
	var pc := PanelContainer.new()
	var active := eng.current == s and st.phase != "fine"
	var sb := UI.flat(Color("#f3e7c9") if not active else Color("#fbe7a8"), UI.pcolor(p["color"]), 4 if active else 2, 8, 8)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(330, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.tooltip_text = _player_tip(s)
	pc.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			board.focus_seat(s))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	h.add_child(UI.icon_rect(UI.tex("res://assets/tokens/ritratto_%s_%s.jpg" % [p["color"], p["side"]]), Vector2(64, 82)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := UI.label(p["name"], 22, UI.pcolor(p["color"]).darkened(0.25), UI.font_title)
	nm.custom_minimum_size.x = 150
	nm.clip_text = true
	top.add_child(nm)
	top.add_child(UI.number("%d" % p["fame"], 30, UI.RED))
	top.add_child(UI.label(" punti", 17, UI.INK2))
	v.add_child(top)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var money := "%s fiorini" % UI.fl(p["money"]) if (s == me or p["wolf"] or st.phase == "fine") else "fiorini nascosti"
	mid.add_child(UI.label(money, 18, UI.INK2, UI.font_italic))
	if p["char"] != "":
		mid.add_child(UI.label("· " + D.CHAR_NAME[p["char"]] + ("" if p["char_up"] else " (usato)"), 18, UI.LAPIS, UI.font_bold))
	v.add_child(mid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.counter(UI.tex("res://assets/tokens/giullare.jpg"), p["jesters"], 24))
	row.add_child(UI.counter(UI.tex("res://assets/tokens/costruttore.jpg"), p["builders"], 24))
	for f in p["freedoms"]:
		row.add_child(UI.icon_rect(UI.free_tex(f), Vector2(40, 18)))
	v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand_n: int = p["hand"].size() if not p["wolf"] else st.wolf_down(s).size()
	row2.add_child(UI.label("Opere %d · Mano %d%s · Bonus %d · Prestigio %d" % [st.works(s), hand_n,
		("+%dR" % p["recruits"]) if p["recruits"] > 0 else "", p["bonus"].size() if not p["wolf"] else 0, p["prestige"].size()], 16, UI.INK2))
	v.add_child(row2)
	if p["best"] > 0:
		v.add_child(UI.label("Opera del round: %d" % p["best"], 16, UI.RED, UI.font_bold))
	if st.phase == "asta" and eng.auction.has("won") and eng.auction["won"].has(s):
		var w: String = eng.auction["won"][s]
		v.add_child(UI.label("Asta: " + (D.OBJECT_NAME[w] if w != "" else "ritirato"), 16, UI.LAPIS, UI.font_italic))
	return pc


func _player_tip(s: int) -> String:
	var st := eng.st
	var p: Dictionary = st.players[s]
	var parts := []
	parts.append("Edifici: " + (", ".join(p["buildings"].map(func(b): return D.BUILDING_NAME[b])) if p["buildings"].size() > 0 else "nessuno"))
	parts.append("Paesaggi: bosco %d, lago %d, parco %d" % [p["land"]["bosco"], p["land"]["lago"], p["land"]["parco"]])
	parts.append("Caselle vuote: %d" % st.empty_cells(s))
	if p["wolf"]:
		parts.append("Carte coperte: %d" % st.wolf_down(s).size())
	else:
		var t := []
		for c in p["table"]:
			t.append(D.PROFS[c]["name"] if c > 0 else "Attrazione")
		parts.append("Opere: " + (", ".join(t) if t.size() > 0 else "nessuna"))
	parts.append("(clic: inquadra il principato)")
	return "\n".join(parts)


func _card_btn(t: Texture2D, w: float, tip: String, cb: Callable = Callable(), badge := "", dim := false) -> Control:
	var h := w * 1.39
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.tooltip_text = tip
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var r := UI.icon_rect(t, Vector2(w, h))
	if dim:
		r.modulate = Color(0.6, 0.6, 0.6)
	c.add_child(r)
	if badge != "":
		var b := PanelContainer.new()
		b.add_theme_stylebox_override("panel", UI.flat(UI.RED, UI.GOLD, 2, 14, 6))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(UI.number(badge, 22, Color("#fff4dc")))
		b.position = Vector2(w - 46, h - 40)
		c.add_child(b)
	if cb.is_valid():
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				cb.call())
		c.mouse_entered.connect(func(): r.modulate = Color(1.15, 1.1, 0.95))
		c.mouse_exited.connect(func(): r.modulate = Color(0.6, 0.6, 0.6) if dim else Color(1, 1, 1))
	return c


func _refresh_hand() -> void:
	UI.clear(hand_box)
	var st := eng.st
	if me < 0 or me >= st.n:
		return
	var p: Dictionary = st.players[me]
	hand_title.text = "La mano di %s · %s fiorini" % [p["name"], UI.fl(p["money"])]
	if p["wolf"]:
		return
	var muse: int = st.round if p["char"] == "musa" else 0
	for c in p["hand"]:
		var v := st.work_value(me, c, [], muse)
		var pr: Dictionary = D.PROFS[c]
		var tip := "%s (%s)\nVuole: %s, %s, %s\nValore dell'opera ora: %d (minimo %d)" % [pr["name"], pr["en"], D.LAND_NAME[pr["land"]], D.FREEDOM_SHORT[pr["free"]], D.BUILDING_NAME[pr["bld"]], v, st.min_work()]
		hand_box.add_child(_card_btn(UI.prof_tex(c), 118, tip, Callable(), str(v), v < st.min_work()))
	for i in p["recruits"]:
		hand_box.add_child(_card_btn(UI.tex("res://assets/cards/reclutamento.jpg"), 118, "Carta Attrazione: si scambia con una carta Mestiere giocata da un avversario. Conta +1 per ogni opera."))
	if p["bonus"].size() > 0:
		hand_box.add_child(VSeparator.new())
	for b in p["bonus"]:
		hand_box.add_child(_card_btn(UI.bonus_tex(b), 104, "Bonus B%d: %s\nOra vale +%d" % [b, D.BONUS[b], st.bonus_value(me, b, true)], Callable(), "+%d" % st.bonus_value(me, b, true)))
	if p["prestige"].size() > 0:
		hand_box.add_child(VSeparator.new())
	for pid in p["prestige"]:
		var pts := st.prestige_points(me, pid)
		var info: Dictionary = D.PRESTIGE[pid]
		hand_box.add_child(_card_btn(UI.prest_tex(pid), 104, "Prestigio P%d: %s → %d punti%s\nOra varrebbe %d" % [pid, info["text"], info["pts"], (" (%d in pareggio)" % info["tie"]) if info["tie"] > 0 else "", pts], Callable(), str(pts)))
	if p["char"] != "":
		hand_box.add_child(VSeparator.new())
		hand_box.add_child(_card_btn(UI.char_tex(p["char"]), 100, "%s: %s" % [D.CHAR_NAME[p["char"]], D.CHAR_TEXT[p["char"]]], Callable(), "", not p["char_up"]))


func _refresh_auction() -> void:
	var st := eng.st
	var lines := []
	var au: Dictionary = eng.auction
	if st.phase == "asta" and au.has("obj") and au["obj"] != "":
		if au.get("solo", false):
			lines.append("[b]Asta contro l'Automa[/b]")
			lines.append("Oggetto: %s · prezzo %s" % [D.OBJECT_NAME[au["obj"]], UI.fl(au["bid"])])
			if not au["chosen"].is_empty():
				lines.append("Già scelti: " + ", ".join(au["chosen"].map(func(o): return D.OBJECT_NAME[o])))
		else:
			lines.append("[b]All'asta: %s[/b]" % D.OBJECT_NAME[au["obj"]])
			lines.append("Offerta: [b]%s[/b] fiorini di %s" % [UI.fl(au["bid"]), eng.pname(au["leader"])])
			var ps := []
			for s in au.get("passed", {}):
				ps.append(eng.pname(s))
			if not ps.is_empty():
				lines.append("Hanno passato: " + ", ".join(ps))
	elif st.phase == "personaggi":
		lines.append("[b]Asta dei personaggi[/b]")
		for c in eng.char_bids:
			lines.append("%s: %s offre %d" % [D.CHAR_NAME[c], eng.pname(eng.char_bids[c][0]), eng.char_bids[c][1] * 100])
		lines.append("Banchiere: %s fiorini sopra" % UI.fl(st.banker_money))
	else:
		lines.append("[b]Rifornimenti[/b]")
		lines.append("Foreste %d · Laghi %d · Parchi %d" % [st.supply["land"]["bosco"], st.supply["land"]["lago"], st.supply["land"]["parco"]])
		lines.append("Giullari %d · Costruttori %d · Attrazione %d" % [st.supply["giullare"], st.supply["costruttore"], st.supply["reclutamento"]])
		lines.append("Mazzi: Mestieri %d · Bonus %d · Prestigio %d" % [st.prof_deck.size(), st.bonus_deck.size(), st.prest_deck.size()])
		var fr := []
		for f in D.FREEDOMS:
			fr.append("%s %d" % [D.FREEDOM_SHORT[f], st.supply["free"][f]])
		lines.append("Libertà: " + ", ".join(fr))
	auction_lbl.text = "\n".join(lines)


func _on_log(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 220:
		log_lines = log_lines.slice(log_lines.size() - 200)
	var out := []
	for l in log_lines:
		if l.begins_with("—"):
			out.append("[color=#8e1f1f][b]%s[/b][/color]" % l)
		else:
			out.append(l)
	log_text.text = "\n".join(out)


func _on_fx(kind: String, data: Dictionary) -> void:
	match kind:
		"bid":
			Audio.play("coin", -6.0)
		"won":
			Audio.play("market", -8.0)
		"work":
			Audio.play("card", -2.0)
		"placed":
			Audio.play("pawn", -2.0)
		"round":
			Audio.play("turn", -6.0)
		"best":
			Audio.play("bell", -8.0)
		"freedom", "char", "recruit", "jester":
			Audio.play("card", -6.0)


# ================================================================== richieste

func _clear_prompt() -> void:
	UI.clear(prompt_body)
	prompt.visible = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _reply(v) -> void:
	_clear_prompt()
	req = {}
	eng.provide_decision(v)


func _ask(text: String) -> VBoxContainer:
	UI.clear(prompt_body)
	prompt_lbl.text = text
	prompt.visible = true
	Audio.play("turn", -14.0)
	return prompt_body


func _row() -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	h.add_theme_constant_override("v_separation", 6)
	h.custom_minimum_size.x = 336
	prompt_body.add_child(h)
	return h


func _btn(parent: Control, text: String, cb: Callable, style := "plain", w := 0.0, tip := "") -> Button:
	var b := UI.button(text, w, 46, 17)
	if w <= 0.0:
		b.custom_minimum_size.x = clampf(10.0 * text.length() + 30.0, 100.0, 336.0)
	match style:
		"primary":
			UI.primary(b)
		"lapis":
			UI.lapis(b)
		"dark":
			UI.dark(b)
	b.tooltip_text = tip
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_decision(r: Dictionary) -> void:
	req = r
	if online == null:
		me = int(r["seat"])
	_refresh()
	var who := "[color=%s][b]%s[/b][/color]: " % [UI.pcolor(eng.players[r["seat"]]["color"]).darkened(0.2).to_html(false), eng.pname(r["seat"])]
	match r["t"]:
		"draft":
			_ui_draft(r)
		"auction_open":
			_ui_open(who, r)
		"bid":
			_ui_bid(who, r)
		"auction_last":
			_ui_last(who, r)
		"land_choice":
			var b := _ask(who + "quale paesaggio prendi?")
			var h := _row()
			for l in r["options"]:
				_btn(h, D.LAND_NAME[l], func(): _reply(l))
		"place":
			_ui_place(r, false)
		"pick":
			_ui_pick(who, r)
		"recruit":
			_ui_recruit(who, r)
		"merchant":
			_ask(who + "hai il [b]Mercante[/b]." + ((" Non paghi i %s fiorini dell'oggetto, oppure" % UI.fl(r["cost"])) if r["cost"] > 0 else "") + " guadagni %d punti?" % r["pp"])
			var h2 := _row()
			if r["cost"] > 0:
				_btn(h2, "Oggetto gratis", func(): _reply("free"), "primary")
			_btn(h2, "+%d punti" % r["pp"], func(): _reply("pp"), "lapis")
			_btn(h2, "Non ora", func(): _reply("no"), "dark")
		"professor":
			_ask(who + "vuoi usare il [b]Professore[/b] (%s)?" % r["when"])
			var h3 := _row()
			if r.get("bonus", false):
				_btn(h3, "Carta Bonus gratis", func(): _reply("bonus"), "primary")
			if r.get("prestige", false):
				_btn(h3, "Carta Prestigio gratis", func(): _reply("prestige"), "lapis")
			_btn(h3, "Non ora", func(): _reply("no"), "dark")
		"solo_pick":
			_ui_solo_pick(who, r)
		"solo_buy":
			_ui_solo_buy(who, r)
		"char_bid":
			_ui_char_bid(who, r)
		"action":
			_ui_action(who, r)
		"work_pay":
			_ui_work_pay(who, r)
		"coop_offer":
			_ask(who + "%s ti propone di costruire insieme il [b]%s[/b] a cavallo del confine: tu paghi %s fiorini, e l'edificio vale anche per te (+3 punti)." % [eng.pname(r["from"]), D.BUILDING_NAME[r["b"]], UI.fl(r["price"])])
			var h4 := _row()
			_btn(h4, "Accetto", func(): _reply(true), "primary")
			_btn(h4, "Rifiuto", func(): _reply(false), "dark")
		"banker_end":
			_ui_slider(who + "il [b]Banchiere[/b]: quanti fiorini trasformi in punti (200 fiorini = 1 punto)?", 0, r["max"], r["max"], func(v): return "%d punti (%s fiorini)" % [v, UI.fl(v * 200)], func(v): _reply(v))
		_:
			_reply(null)


func _ui_draft(r: Dictionary) -> void:
	_modal("Le tue prime carte Mestiere", "Tieni 3 carte: scegli quella da rimettere nel mazzo.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.get_meta("body").add_child(h)
	for c in r["cards"]:
		var pr: Dictionary = D.PROFS[c]
		var v := VBoxContainer.new()
		v.add_child(_card_btn(UI.prof_tex(c), 230, "%s: vuole %s, %s, %s" % [pr["name"], D.LAND_NAME[pr["land"]], D.FREEDOM_SHORT[pr["free"]], D.BUILDING_NAME[pr["bld"]]], func(): _reply(c)))
		var l := UI.label(pr["name"], 22, UI.INK, UI.font_title)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var b := UI.button("Scarta", 230, 44, 19)
		UI.dark(b)
		b.pressed.connect(func(): _reply(c))
		v.add_child(b)
		h.add_child(v)


func _obj_icon(o: String) -> Texture2D:
	match o:
		"bosco", "lago", "parco":
			return UI.tile_tex(o)
		"paesaggio":
			return UI.tile_tex("bosco")
		"prestigio":
			return UI.tex("res://assets/cards/dorso_prestigio.jpg")
		"reclutamento":
			return UI.tex("res://assets/cards/reclutamento.jpg")
		"giullare":
			return UI.tex("res://assets/tokens/giullare.jpg")
		"costruttore":
			return UI.tex("res://assets/tokens/costruttore.jpg")
	return null


func _obj_tip(o: String) -> String:
	match o:
		"bosco", "lago", "parco":
			return "%s: +3 al valore delle opere di chi lo vuole; dal secondo dello stesso tipo +3 punti." % D.LAND_NAME[o]
		"paesaggio":
			return "Un paesaggio a scelta (bosco, lago o parco)."
		"prestigio":
			return "Peschi 5 carte Prestigio e ne tieni una: punti a fine partita."
		"reclutamento":
			return "Si scambia con una Mestiere giocata da un avversario; conta +1 in ogni opera."
		"giullare":
			return "+2 al valore di ogni tua opera."
		"costruttore":
			return "1° costruttore: edifici a 300. 2°: +3 punti, edifici adiacenti. 3°: +3 punti, edifici gratis."
	return ""


func _obj_button(parent: Control, o: String, label: String, cb: Callable, style := "plain") -> void:
	var b := UI.button(label, 0, 54, 17)
	b.icon = _obj_icon(o)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.custom_minimum_size.x = 165
	b.tooltip_text = _obj_tip(o)
	if style == "primary":
		UI.primary(b)
	b.pressed.connect(cb)
	parent.add_child(b)


func _ui_open(who: String, r: Dictionary) -> void:
	_ask(who + "apri un'asta. Scegli l'oggetto: offerta iniziale [b]%s[/b] fiorini (ne hai %s)." % [UI.fl(r["bid"]), UI.fl(eng.players[r["seat"]]["money"])])
	var h := _row()
	for o in r["options"]:
		_obj_button(h, o, D.OBJECT_NAME[o].replace("Carta ", ""), func(): _reply(o))
	var h2 := _row()
	_btn(h2, "Mi ritiro dalle aste di questo round", func(): _reply(""), "dark")


func _ui_bid(who: String, r: Dictionary) -> void:
	var p: Dictionary = eng.players[r["seat"]]
	var txt := who + "[b]%s[/b]: %s offre %s fiorini. Hai %s fiorini." % [D.OBJECT_NAME[r["obj"]], eng.pname(r["leader"]), UI.fl(r["bid"]), UI.fl(p["money"])]
	if r["next"] > p["money"]:
		txt += " [i]Rilanciando cederai punti di fama (100 fiorini l'uno).[/i]"
	_ask(txt)
	var h := _row()
	_btn(h, "Offro %s" % UI.fl(r["next"]), func(): _reply(true), "primary")
	_btn(h, "Passo", func(): _reply(false), "dark")


func _ui_last(who: String, r: Dictionary) -> void:
	_ask(who + "sei rimasto solo all'asta: puoi prendere un oggetto per [b]%s[/b] fiorini." % UI.fl(r["price"]))
	var h := _row()
	for o in r["options"]:
		_obj_button(h, o, D.OBJECT_NAME[o].replace("Carta ", ""), func(): _reply(o))
	_btn(_row(), "Non prendo niente", func(): _reply(""), "dark")


func _ui_place(r: Dictionary, cancel: bool, cb: Callable = Callable(), title := "") -> void:
	if is_instance_valid(_place):
		_place.queue_free()
	var d := PlaceDialog.new()
	d.eng = eng
	d.seat = r["seat"]
	d.kind = r["kind"]
	d.id = r["id"]
	d.can_cancel = cancel
	d.title_text = title
	add_child(d)
	_place = d
	d.done.connect(func(pl):
		d.queue_free()
		if cb.is_valid():
			cb.call(pl)
		else:
			_reply(pl))


func _ui_pick(who: String, r: Dictionary) -> void:
	var st := eng.st
	var s: int = r["seat"]
	var names := {"prestigio": "Prestigio", "bonus": "Bonus", "prof": "Mestiere"}
	_modal("Scegli una carta %s" % names.get(r["kind"], ""), "Le altre tornano in fondo al mazzo.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.get_meta("body").add_child(h)
	for c in r["cards"]:
		var tex: Texture2D
		var tip := ""
		var badge := ""
		match r["kind"]:
			"prestigio":
				tex = UI.prest_tex(c)
				tip = "%s: %d punti" % [D.PRESTIGE[c]["text"], D.PRESTIGE[c]["pts"]]
				badge = str(st.prestige_points(s, c))
			"bonus":
				tex = UI.bonus_tex(c)
				tip = D.BONUS[c]
				badge = "+%d" % st.bonus_value(s, c, true)
			_:
				tex = UI.prof_tex(c)
				var pr: Dictionary = D.PROFS[c]
				tip = "%s: vuole %s, %s, %s" % [pr["name"], D.LAND_NAME[pr["land"]], D.FREEDOM_SHORT[pr["free"]], D.BUILDING_NAME[pr["bld"]]]
				badge = str(st.work_value(s, c))
		h.add_child(_card_btn(tex, 200, tip + "\n(il numero: quanto vale ora per te)", func(): _reply(c), badge))


func _ui_recruit(who: String, r: Dictionary) -> void:
	_modal("Carta Attrazione", "Prendi una carta Mestiere giocata da un avversario (al suo posto resta la carta Attrazione), oppure tienila per dopo.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.get_meta("body").add_child(h)
	var s: int = r["seat"]
	for t in r["targets"]:
		var v := VBoxContainer.new()
		var c: int = t[2]
		var owner := eng.pname(t[0]) if int(t[0]) >= 0 else "casata fantasma %d" % (-int(t[0]))
		v.add_child(_card_btn(UI.prof_tex(c), 150, "%s di %s\nValore per te: %d" % [D.PROFS[c]["name"], owner, eng.st.work_value(s, c)], func(): _reply([t[0], t[1]]), str(eng.st.work_value(s, c))))
		var l := UI.label(owner, 18, UI.INK2, UI.font_italic)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		h.add_child(v)
	var b := UI.button("Tengo la carta per dopo", 360, 54, 22)
	UI.dark(b)
	b.pressed.connect(func(): _reply(null))
	overlay.get_meta("body").add_child(b)


func _ui_solo_pick(who: String, r: Dictionary) -> void:
	var t := who + "scegli l'oggetto da mettere all'asta contro l'Automa (carta A%d)." % r["card"]
	if r["final"]:
		t += " È l'ultima asta: costa [b]200[/b] fiorini (non per i due oggetti con il modificatore più alto)."
	else:
		t += " Si tira il dado: prezzo = (dado + modificatore) × 100 + 100."
	_ask(t)
	var h := _row()
	var tr := TextureRect.new()
	tr.texture = UI.tex("res://assets/cards/automa%02d.jpg" % r["card"])
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(330, 150)
	h.add_child(tr)
	var h1 := _row()
	for o in r["options"]:
		var code := eng.automa_code(o)
		var mod := eng.automa_mod(code)
		_obj_button(h1, o, "%s%s" % [D.OBJECT_NAME[o].replace("Carta ", ""), (" (+%d)" % mod) if mod > 0 else ""], func(): _reply(o))
	_btn(_row(), "Mi ritiro dalle aste", func(): _reply(""), "dark")


func _ui_solo_buy(who: String, r: Dictionary) -> void:
	var t := who + "[b]%s[/b]: " % D.OBJECT_NAME[r["obj"]]
	if r["final"]:
		t += "ultima asta, prezzo [b]%s[/b] fiorini." % UI.fl(r["price"])
	else:
		t += "dado [b]%d[/b]%s → prezzo [b]%s[/b] fiorini." % [r["roll"], (" + %d" % r["mod"]) if r["mod"] > 0 else "", UI.fl(r["price"])]
	if r["forced"]:
		t += " Con 1 o 2 e nessun modificatore [b]devi comprarlo[/b]."
	_ask(t)
	var h := _row()
	_btn(h, "Compro per %s" % UI.fl(r["price"]), func(): _reply(true), "primary")
	if not r["forced"]:
		_btn(h, "Rinuncio", func(): _reply(false), "dark")


func _ui_char_bid(who: String, r: Dictionary) -> void:
	_modal("Asta dei personaggi", "Metti la pedina su un personaggio (offerta = numero × 100 fiorini). Se tocca di nuovo a te e la tua pedina è ancora lì, è tuo.")
	var body: VBoxContainer = overlay.get_meta("body")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	var sel := {"c": ""}
	var val := {"v": 0}
	var info := UI.label("", 22, UI.INK, UI.font_bold)
	var spin := HBoxContainer.new()
	spin.alignment = BoxContainer.ALIGNMENT_CENTER
	spin.add_theme_constant_override("separation", 10)
	var paint := func():
		if sel["c"] == "":
			info.text = "Scegli un personaggio."
		else:
			info.text = "%s: offri %s fiorini" % [D.CHAR_NAME[sel["c"]], UI.fl(val["v"] * 100)]
	for c in D.CHARACTERS:
		var v := VBoxContainer.new()
		var avail: bool = r["options"].has(c)
		var cur := ""
		if r["bids"].has(c):
			cur = "%s: %d" % [eng.pname(r["bids"][c][0]), r["bids"][c][1] * 100]
		elif eng.st.chars[c]["owner"] >= 0:
			cur = "preso"
		var tip := "%s\n%s" % [D.CHAR_NAME[c], D.CHAR_TEXT[c]]
		if c == "banchiere":
			tip += "\nSopra ci sono %s fiorini." % UI.fl(r["banker"])
		v.add_child(_card_btn(UI.char_tex(c), 150, tip, func():
			if avail:
				sel["c"] = c
				val["v"] = r["options"][c][0]
				paint.call(), "", not avail))
		var l := UI.label(cur if cur != "" else ("da %d" % (r["options"][c][0] * 100) if avail else ""), 17, UI.INK2, UI.font_italic)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		h.add_child(v)
	body.add_child(info)
	var minus := UI.button("−100", 110, 50, 20)
	minus.pressed.connect(func():
		if sel["c"] != "":
			val["v"] = maxi(r["options"][sel["c"]][0], val["v"] - 1)
			paint.call())
	spin.add_child(minus)
	var plus := UI.button("+100", 110, 50, 20)
	plus.pressed.connect(func():
		if sel["c"] != "":
			val["v"] = mini(r["options"][sel["c"]][1], val["v"] + 1)
			paint.call())
	spin.add_child(plus)
	var ok := UI.button("Offro", 200, 50, 22)
	UI.primary(ok)
	ok.pressed.connect(func():
		if sel["c"] != "":
			_reply({"c": sel["c"], "v": val["v"]}))
	spin.add_child(ok)
	var no := UI.button("Passo", 160, 50, 22)
	UI.dark(no)
	no.pressed.connect(func(): _reply(null))
	spin.add_child(no)
	body.add_child(spin)
	paint.call()


# ------------------------------------------------------------------ fase azioni

func _ui_action(who: String, r: Dictionary) -> void:
	var m: Dictionary = r["menu"]
	var s: int = r["seat"]
	var p: Dictionary = eng.players[s]
	var left: int = m.get("left", 0)
	_ask(who + "fase azioni: %s. Hai %s fiorini." % [("ti restano [b]%d[/b] azioni" % left) if left > 1 else ("ti resta [b]1[/b] azione" if left == 1 else "azioni finite"), UI.fl(p["money"])])
	var h := _row()
	var a_work := _btn(h, "Completa un'opera", func(): _ui_work(r), "primary", 0, "Gioca una carta Mestiere dalla mano (valore almeno %d)" % eng.st.min_work())
	a_work.disabled = not m.has("work")
	var a_build := _btn(h, "Costruisci (%s)" % UI.fl(eng.st.build_cost(s)), func(): _ui_build(r), "lapis", 0, "Un edificio nel principato: +3 punti, +4 alle opere che lo vogliono")
	a_build.disabled = not m.has("build")
	var a_free := _btn(h, "Libertà (300)", func(): _ui_freedom(r), "lapis", 0, "Introduci una libertà: +3 alle opere che la vogliono")
	a_free.disabled = not m.has("freedom")
	var h2 := _row()
	var a_prof := _btn(h2, "Carta Mestiere (300)", func(): _reply({"a": "prof"}), "plain", 0, "Peschi 5 carte Mestiere e ne tieni una (una volta per round)")
	a_prof.disabled = not m.has("prof")
	var a_bonus := _btn(h2, "Carta Bonus (300)", func(): _reply({"a": "bonus"}), "plain", 0, "Peschi 5 carte Bonus e ne tieni una")
	a_bonus.disabled = not m.has("bonus")
	_btn(h2, "Fine turno", func(): _reply({"a": "end"}), "dark")
	var h3 := _row()
	if m.has("recruit"):
		_btn(h3, "Usa Attrazione", func(): _ui_recruit_free(r), "plain", 0, "Azione gratuita")
	if m.has("sell"):
		_btn(h3, "Cedi fama per fiorini", func(): _ui_sell(r), "plain", 0, "Ogni punto di fama vale 100 fiorini (azione gratuita)")
	if m.has("cardinal"):
		_btn(h3, "Cardinale: 3ª azione", func(): _reply({"a": "cardinal"}), "lapis")
	if m.has("merchant"):
		_btn(h3, "Mercante: +%d punti" % m["merchant"], func(): _reply({"a": "merchant"}), "lapis")
	if m.has("professor"):
		_btn(h3, "Professore: Bonus gratis", func(): _reply({"a": "professor", "k": "bonus"}), "lapis")
		_btn(h3, "Professore: Prestigio gratis", func(): _reply({"a": "professor", "k": "prestige"}), "lapis")
	if h3.get_child_count() == 0:
		h3.queue_free()


func _ui_work(r: Dictionary) -> void:
	var s: int = r["seat"]
	var st := eng.st
	var p: Dictionary = st.players[s]
	var muse: int = st.round if p["char"] == "musa" else 0
	_modal("Completa un'opera", "Scegli l'artista o il sapiente e le carte Bonus da aggiungere. Valore minimo nel round %d: %d." % [st.round, st.min_work()])
	var body: VBoxContainer = overlay.get_meta("body")
	var sel := {"c": -99, "b": []}
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	var det := UI.rich(21, 900)
	var ok := UI.button("Completa l'opera", 320, 56, 24)
	UI.primary(ok)
	var paint := func():
		if sel["c"] == -99:
			det.text = "[i]Scegli una carta.[/i]"
			ok.disabled = true
			return
		var v := st.work_value(s, sel["c"], sel["b"], muse)
		var parts := []
		for x in st.work_breakdown(s, sel["c"], sel["b"], muse):
			if x[1] != 0:
				parts.append("%s +%d" % [x[0], x[1]])
		det.text = "[b]Valore %d[/b] = %s%s" % [v, " · ".join(parts), "" if v >= st.min_work() else "  [color=#8e1f1f](sotto il minimo %d)[/color]" % st.min_work()]
		ok.disabled = v < st.min_work()
	for c in p["hand"]:
		var v0 := st.work_value(s, c, [], muse)
		h.add_child(_card_btn(UI.prof_tex(c), 150, D.PROFS[c]["name"], func():
			sel["c"] = c
			paint.call(), str(v0)))
	if p["char"] == "principessa" and p["char_up"]:
		h.add_child(_card_btn(UI.char_tex("principessa"), 150, "Opera con la Principessa (niente Bonus)", func():
			sel["c"] = -1
			sel["b"] = []
			paint.call(), str(st.work_value(s, -1, [], muse))))
	if p["bonus"].size() > 0:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 10)
		body.add_child(UI.label("Carte Bonus (clic per aggiungerle o toglierle):", 20, UI.INK2, UI.font_italic))
		body.add_child(hb)
		for b in p["bonus"]:
			var holder := VBoxContainer.new()
			var mark := UI.label("", 18, UI.RED, UI.font_bold)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			holder.add_child(_card_btn(UI.bonus_tex(b), 110, D.BONUS[b], func():
				if sel["c"] == -1:
					return
				if b in sel["b"]:
					sel["b"].erase(b)
					mark.text = ""
				else:
					sel["b"].append(b)
					mark.text = "aggiunta"
				paint.call(), "+%d" % st.bonus_value(s, b, true)))
			holder.add_child(mark)
			hb.add_child(holder)
	body.add_child(det)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	ok.pressed.connect(func(): _reply({"a": "work", "card": sel["c"], "bonus": sel["b"]}))
	row.add_child(ok)
	var no := UI.button("Indietro", 200, 56, 22)
	UI.dark(no)
	no.pressed.connect(func():
		_close_modal()
		_ui_action("", r))
	row.add_child(no)
	body.add_child(row)
	paint.call()


func _ui_build(r: Dictionary) -> void:
	var s: int = r["seat"]
	var st := eng.st
	var p: Dictionary = st.players[s]
	_modal("Costruisci un edificio", "Costo: %s fiorini (%d costruttori). Ogni edificio dà subito 3 punti e +4 alle opere degli artisti che lo vogliono." % [UI.fl(st.build_cost(s)), p["builders"]])
	var body: VBoxContainer = overlay.get_meta("body")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for b in D.BUILDINGS:
		var ok: bool = b in r["menu"]["build"]
		var v := VBoxContainer.new()
		var want := []
		for c in p["hand"]:
			if D.PROFS[c]["bld"] == b:
				want.append(D.PROFS[c]["name"])
		var btn := Button.new()
		btn.icon = UI.tile_tex(b)
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(180, 140)
		btn.disabled = not ok
		btn.tooltip_text = "%s (%s, %d rimasti)%s" % [D.BUILDING_NAME[b], D.SIZE_NAME[D.BUILDING_SIZE[b]], st.supply["bld"][b], ("\nLo vogliono: " + ", ".join(want)) if want.size() > 0 else ""]
		UI.plain(btn)
		btn.pressed.connect(func():
			_close_modal()
			_ui_place({"seat": s, "kind": "b", "id": b}, true, func(pl):
				if pl == null:
					_ui_action("", r)
					return
				var plc: Dictionary = pl
				var price := int(plc.get("price", 0))
				plc.erase("price")
				_reply({"a": "build", "b": b, "pl": plc, "price": price})))
		v.add_child(btn)
		var l := UI.label("%s%s" % [D.BUILDING_NAME[b], (" ★%d" % want.size()) if want.size() > 0 else ""], 18, UI.INK if ok else UI.INK2, UI.font_bold if ok else UI.font_body)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		grid.add_child(v)
	var no := UI.button("Indietro", 200, 52, 22)
	UI.dark(no)
	no.pressed.connect(func():
		_close_modal()
		_ui_action("", r))
	body.add_child(no)


func _ui_freedom(r: Dictionary) -> void:
	var s: int = r["seat"]
	_ask("Quale libertà introduci (300 fiorini)?")
	var h := _row()
	for f in r["menu"]["freedom"]:
		var want := 0
		for c in eng.players[s]["hand"]:
			if D.PROFS[c]["free"] == f:
				want += 1
		var b := UI.button(D.FREEDOM_SHORT[f] + ((" ★%d" % want) if want > 0 else ""), 330, 54, 18)
		b.icon = UI.free_tex(f)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 80)
		UI.lapis(b)
		b.pressed.connect(func(): _reply({"a": "freedom", "f": f}))
		h.add_child(b)
	_btn(_row(), "Indietro", func(): _ui_action("", r), "dark")


func _ui_recruit_free(r: Dictionary) -> void:
	_modal("Carta Attrazione", "Prendi una carta Mestiere giocata da un avversario.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.get_meta("body").add_child(h)
	var s: int = r["seat"]
	for t in r["menu"]["recruit"]:
		var c: int = t[2]
		var owner := eng.pname(t[0]) if int(t[0]) >= 0 else "casata fantasma %d" % (-int(t[0]))
		var v := VBoxContainer.new()
		v.add_child(_card_btn(UI.prof_tex(c), 150, "%s di %s" % [D.PROFS[c]["name"], owner], func(): _reply({"a": "recruit", "o": t[0], "i": t[1]}), str(eng.st.work_value(s, c))))
		var l := UI.label(owner, 18, UI.INK2, UI.font_italic)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		h.add_child(v)
	var b := UI.button("Indietro", 200, 52, 22)
	UI.dark(b)
	b.pressed.connect(func():
		_close_modal()
		_ui_action("", r))
	overlay.get_meta("body").add_child(b)


func _ui_sell(r: Dictionary) -> void:
	var mx: int = r["menu"]["sell"]
	_ui_slider("Quanti punti di fama cedi? Ogni punto vale 100 fiorini.", 0, mx, 1, func(v): return "%d punti → %s fiorini" % [v, UI.fl(v * 100)], func(v):
		if v <= 0:
			_ui_action("", r)
		else:
			_reply({"a": "sell", "n": v}))


func _ui_work_pay(who: String, r: Dictionary) -> void:
	var v: int = r["value"]
	_ui_slider(who + "opera di valore [b]%d[/b]: la banca paga %s fiorini. Quanti ne trasformi in punti (200 fiorini = 1 punto)?" % [v, UI.fl(v * 100)], 0, r["max"], eng.ais[r["seat"]]._work_pay(eng, r["seat"], r),
		func(k): return "%d punti e %s fiorini" % [k, UI.fl(v * 100 - k * 200)], func(k): _reply(k))


func _ui_slider(text: String, lo: int, hi: int, start: int, fmt: Callable, cb: Callable) -> void:
	_ask(text)
	var val := {"v": clampi(start, lo, hi)}
	var h := _row()
	var lbl := UI.label("", 21, UI.INK, UI.font_bold)
	lbl.custom_minimum_size.x = 180
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var paint := func(): lbl.text = fmt.call(val["v"])
	_btn(h, "−", func():
		val["v"] = maxi(lo, val["v"] - 1)
		paint.call(), "plain", 70)
	h.add_child(lbl)
	_btn(h, "+", func():
		val["v"] = mini(hi, val["v"] + 1)
		paint.call(), "plain", 70)
	var h2 := _row()
	_btn(h2, "Nessuno", func():
		val["v"] = lo
		paint.call(), "plain", 160)
	_btn(h2, "Tutti", func():
		val["v"] = hi
		paint.call(), "plain", 160)
	_btn(h2, "Conferma", func(): cb.call(val["v"]), "primary", 330)
	paint.call()


# ------------------------------------------------------------------ finestre

func _modal(title: String, sub: String) -> void:
	_close_modal()
	prompt.visible = false
	overlay = Control.new()
	overlay.size = Vector2(1920, 1080)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.05, 0.03, 0.72)
	shade.size = overlay.size
	overlay.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.paper(false, 30))
	overlay.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var t := UI.title(title, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sl := UI.wrap(sub, 21, 1100, UI.INK2, UI.font_italic)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	overlay.set_meta("body", v)
	box.resized.connect(func(): box.position = (Vector2(1920, 1080) - box.size) / 2.0 - Vector2(0, 30))


func _close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _show_rules() -> void:
	var r := preload("res://scripts/ui/rules_view.gd").new()
	r.overlay = true
	add_child(r)


func _ask_menu() -> void:
	_modal("Tornare al menu?", "La partita in corso si interrompe." if online == null else "Esci dalla stanza: al tuo posto giocherà l'IA finché non rientri.")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	overlay.get_meta("body").add_child(h)
	var yes := UI.button("Sì, al menu", 260, 56, 22)
	UI.primary(yes)
	yes.pressed.connect(func():
		eng.abort = true
		if online != null:
			online.alive = false
		main.show_menu())
	h.add_child(yes)
	var no := UI.button("Continua a giocare", 300, 56, 22)
	no.pressed.connect(func():
		_close_modal()
		if not req.is_empty():
			_on_decision(req))
	h.add_child(no)


func _on_end(results: Array) -> void:
	_clear_prompt()
	Audio.play("win", -4.0)
	me = me
	_refresh()
	_modal("Fine della partita", "Vince %s!" % results[0]["name"])
	var body: VBoxContainer = overlay.get_meta("body")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	for hdr in ["Casata", "Fama", "Prestigio", "Totale", "Fiorini"]:
		grid.add_child(UI.label(hdr, 22, UI.INK2, UI.font_title))
	for r in results:
		var p: Dictionary = eng.players[r["seat"]]
		grid.add_child(UI.label(r["name"], 26, UI.pcolor(p["color"]).darkened(0.2), UI.font_title))
		grid.add_child(UI.number(str(r["fame"]), 30))
		var ex := []
		var tot := 0
		for d in r["prestige"]:
			ex.append("P%d %d" % [d[0], d[1]])
			tot += d[1]
		var pl := UI.label("%d" % tot, 24)
		pl.tooltip_text = ", ".join(ex)
		pl.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(pl)
		grid.add_child(UI.number(str(r["score"]), 34, UI.RED))
		grid.add_child(UI.label(UI.fl(r["money"]), 22))
	body.add_child(grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var b := UI.button("Torna al menu", 300, 60, 24)
	UI.primary(b)
	b.pressed.connect(func(): main.show_menu())
	row.add_child(b)
	var b2 := UI.button("Guarda il tavolo", 300, 60, 24)
	b2.pressed.connect(func(): _close_modal())
	row.add_child(b2)
	body.add_child(row)


# ------------------------------------------------------------------ online

func online_caught_up() -> void:
	status_lbl.text = ""


func online_status(t: String) -> void:
	status_lbl.text = t


func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		status_lbl.text = ""
	else:
		status_lbl.text = "Aspetto %s…%s" % [eng.pname(s), " (ci mette un po')" if slow else ""]


func online_cancel_decision(t: String) -> void:
	_clear_prompt()
	if is_instance_valid(_place):
		_place.queue_free()
	status_lbl.text = t
