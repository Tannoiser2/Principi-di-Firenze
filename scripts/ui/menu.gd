extends Control
## Menu principale: il tabellone sullo sfondo, le casate su una pergamena (Umano / IA / Assente),
## livello e velocità dell'IA, espansioni, solitario contro Wolfgang, gioco online.

const MODES := ["Umano", "IA", "Assente"]
const D = preload("res://scripts/data/pf_data.gd")

var main
var seat_mode := [0, 1, 1, 1, 2]      # 0 umano, 1 IA, 2 assente
var sides := ["d", "u", "d", "u", "d"]
var level := 1
var speed := 1
var mods := {}
var solo_dummies := 2
var solo_diff := 1
var msg: Label
var rows_box: VBoxContainer
var mods_box: VBoxContainer

const MOD_LIST := [
	["chars", "La Musa e la Principessa", "Sei personaggi all'asta dopo l'asta normale: Banchiere, Cardinale, Mercante, Musa, Professore, Principessa. Niente vendita della fama."],
	["coop", "Costruzioni in comune (lato B)", "Plance del principato sul lato B, una accanto all'altra: gli edifici si possono costruire a cavallo del confine con un vicino, che paga la sua parte."],
]


func _ready() -> void:
	size = Vector2(1920, 1080)
	if main.menu_state.has("seat_mode"):
		seat_mode = main.menu_state["seat_mode"].duplicate()
		sides = main.menu_state["sides"].duplicate()
		level = main.menu_state["level"]
		speed = main.menu_state["speed"]
		mods = main.menu_state.get("mods", {}).duplicate()
		solo_dummies = main.menu_state.get("dummies", 2)
		solo_diff = main.menu_state.get("diff", 1)
	# il tabellone dietro
	var art := TextureRect.new()
	art.texture = UI.tex("res://assets/board/tabellone.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = Vector2(1920, 1080)
	art.modulate = Color(0.75, 0.68, 0.6)
	add_child(art)
	var fade := TextureRect.new()
	var fg := GradientTexture2D.new()
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.12, 0.07, 0.04, 0.97))
	g2.set_color(1, Color(0.12, 0.07, 0.04, 0.35))
	fg.gradient = g2
	fg.fill_to = Vector2(1, 0)
	fade.texture = fg
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.size = Vector2(1920, 1080)
	add_child(fade)

	var giglio := UI.icon_rect(UI.tex("res://assets/tokens/giglio.png"), Vector2(110, 130))
	giglio.position = Vector2(44, 22)
	add_child(giglio)
	var t1 := UI.label("I Principi", 76, UI.GOLD, UI.font_deco)
	t1.position = Vector2(170, 6)
	add_child(t1)
	var t2 := UI.label("di Firenze", 52, UI.SAND, UI.font_deco)
	t2.position = Vector2(176, 88)
	add_child(t2)
	var tag := UI.label("Mecenati, artisti e sapienti nel Rinascimento fiorentino", 26, UI.SAND, UI.font_italic)
	tag.position = Vector2(46, 160)
	add_child(tag)

	# pergamena delle casate
	var scroll := PanelContainer.new()
	scroll.add_theme_stylebox_override("panel", UI.paper(false, 26))
	scroll.position = Vector2(40, 206)
	scroll.custom_minimum_size = Vector2(880, 0)
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	var hh := HBoxContainer.new()
	hh.add_child(UI.title("Le casate", 40))
	var sub := UI.label("   da 2 a 5 principi", 22, UI.INK2, UI.font_italic)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	hh.add_child(sub)
	vb.add_child(hh)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	vb.add_child(rows_box)
	_refresh_rows()
	vb.add_child(HSeparator.new())
	vb.add_child(_segmented("Avversari IA", ["Facili", "Normali", "Esperti"], level, func(i): level = i))
	vb.add_child(_segmented("Velocità IA", ["Lenta", "Media", "Veloce", "Subito"], speed, func(i): speed = i))
	mods_box = VBoxContainer.new()
	vb.add_child(mods_box)
	_refresh_mods()

	# colonna destra: solitario e pulsanti
	var right := VBoxContainer.new()
	right.position = Vector2(960, 230)
	right.add_theme_constant_override("separation", 16)
	add_child(right)
	var b_play := _big("Si gioca!", 420, true)
	b_play.pressed.connect(_on_start)
	right.add_child(b_play)
	var solo_box := PanelContainer.new()
	solo_box.add_theme_stylebox_override("panel", UI.paper(false, 20))
	solo_box.custom_minimum_size = Vector2(560, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	solo_box.add_child(sv)
	sv.add_child(UI.title("Solitario contro Wolfgang", 30))
	sv.add_child(UI.wrap("Tu contro Wolfgang, l'Automa: lui gioca con le sue carte e i dadi, con 2 o 3 casate fantasma che tengono solo carte Mestiere. Senza espansioni.", 20, 520, UI.INK2))
	sv.add_child(_segmented("Casate fantasma", ["2 (4 giocatori)", "3 (5 giocatori)"], solo_dummies - 2, func(i): solo_dummies = i + 2))
	sv.add_child(_segmented("Wolfgang", ["Facile", "Standard", "Difficile"], solo_diff, func(i): solo_diff = i))
	var b_solo := _big("Sfida Wolfgang", 400)
	UI.lapis(b_solo)
	b_solo.pressed.connect(_on_solo)
	sv.add_child(b_solo)
	right.add_child(solo_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var b_online := _big("Gioca online", 300)
	b_online.pressed.connect(_online_panel)
	row.add_child(b_online)
	var b_rules := _big("Regole", 240)
	b_rules.pressed.connect(func():
		_store()
		main.show_rules())
	row.add_child(b_rules)
	right.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.add_child(Audio.toggle_button("music", 180))
	row2.add_child(Audio.toggle_button("sfx", 180))
	right.add_child(row2)
	msg = UI.wrap("", 22, 560, UI.SAND, UI.font_italic)
	right.add_child(msg)
	var credit := UI.label("Gioco di Wolfgang Kramer, Richard Ulrich e Jens Christopher Ulrich · illustrazioni di Lukas Siegmon · versione digitale per uso personale", 17, Color(UI.SAND, 0.7), UI.font_italic)
	credit.position = Vector2(40, 1044)
	add_child(credit)
	if str(main.get_net().load_session().get("room", "")) != "":
		msg.text = "Avevi una partita online in corso: apri «Gioca online» per rientrare."


func _store() -> void:
	main.menu_state = {"seat_mode": seat_mode.duplicate(), "sides": sides.duplicate(), "level": level, "speed": speed,
		"mods": mods.duplicate(), "dummies": solo_dummies, "diff": solo_diff}


func _refresh_rows() -> void:
	UI.clear(rows_box)
	for i in D.COLORS.size():
		rows_box.add_child(_house_row(i))


func _house_row(i: int) -> Control:
	var c: Dictionary = D.COLORS[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var port := UI.icon_rect(UI.tex("res://assets/tokens/ritratto_it_%s.jpg" % c["id"]), Vector2(52, 66))
	port.mouse_filter = Control.MOUSE_FILTER_STOP
	port.tooltip_text = "Clic: cambia principe / principessa"
	port.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			sides[i] = "u" if sides[i] == "d" else "d"
			_refresh_rows())
	h.add_child(port)
	var sw := ColorRect.new()
	sw.color = Color(c["hex"])
	sw.custom_minimum_size = Vector2(10, 60)
	h.add_child(sw)
	var nm := UI.label("%s · %s" % [D.PRINCES[c["id"]][0 if sides[i] == "d" else 1], c["name"]], 25)
	nm.custom_minimum_size = Vector2(300, 0)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	for m in 3:
		var b := UI.button(MODES[m], 140, 46, 20)
		if seat_mode[i] == m:
			if m == 0:
				UI.primary(b)
			else:
				UI.selected(b)
		b.pressed.connect(func():
			seat_mode[i] = m
			_refresh_rows())
		h.add_child(b)
	return h


func _refresh_mods() -> void:
	UI.clear(mods_box)
	mods_box.add_child(UI.label("Espansioni", 24, UI.INK, UI.font_title))
	for m in MOD_LIST:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var on: bool = mods.get(m[0], false)
		var b := UI.button("Sì" if on else "No", 80, 42, 20)
		if on:
			UI.selected(b)
		b.pressed.connect(func():
			mods[m[0]] = not mods.get(m[0], false)
			_refresh_mods())
		h.add_child(b)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(UI.label(m[1], 22, UI.INK, UI.font_bold))
		vb.add_child(UI.wrap(m[2], 18, 700, UI.INK2))
		h.add_child(vb)
		mods_box.add_child(h)


func _segmented(label_text: String, items: Array, cur: int, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := UI.label(label_text, 22)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var btns := []
	for i in items.size():
		var b := UI.button(items[i], 0, 42, 19)
		b.custom_minimum_size.x = maxf(110.0, 13.0 * items[i].length())
		btns.append(b)
		h.add_child(b)
	var paint := func(sel: int):
		for j in btns.size():
			if j == sel:
				UI.selected(btns[j])
			else:
				UI.plain(btns[j])
	for i in btns.size():
		btns[i].pressed.connect(func():
			cb.call(i)
			paint.call(i))
	paint.call(cur)
	return h


func _big(text: String, w: float, primary := false) -> Button:
	var b := UI.button(text, w, 72, 32)
	if primary:
		UI.primary(b)
	return b


## Configurazione scelta nel menu (anche quella che, online, viaggia agli altri).
func _config() -> Dictionary:
	var seats := []
	for i in D.COLORS.size():
		var m: int = seat_mode[i]
		if m == 2:
			continue
		var c: Dictionary = D.COLORS[i]
		seats.append({"color": c["id"], "side": sides[i], "ai": m == 1, "name": D.PRINCES[c["id"]][0 if sides[i] == "d" else 1], "level": level})
	var speeds := [1.2, 0.6, 0.25, 0.0]
	var o := {}
	for k in ["chars", "coop"]:
		if mods.get(k, false):
			o[k] = true
	return {"seats": seats, "ai_delay": speeds[speed], "opts": o}


func _on_start() -> void:
	var cfg := _config()
	if cfg["seats"].size() < 2:
		msg.text = "Si gioca da 2 a 5: metti in gioco almeno 2 casate (oppure prova il solitario contro Wolfgang)."
		return
	_store()
	main.start_game(cfg)


func _on_solo() -> void:
	# la prima casata su Umano è la tua; Wolfgang prende un altro colore
	var mine := -1
	for i in D.COLORS.size():
		if seat_mode[i] == 0:
			mine = i
			break
	if mine < 0:
		mine = 0
	var wc := (mine + 1) % D.COLORS.size()
	var c: Dictionary = D.COLORS[mine]
	var seats := [
		{"color": c["id"], "side": sides[mine], "ai": false, "name": D.PRINCES[c["id"]][0 if sides[mine] == "d" else 1], "level": level},
		{"color": D.COLORS[wc]["id"], "side": "u", "ai": true, "wolf": true, "name": "Wolfgang", "level": 2},
	]
	var speeds := [1.2, 0.6, 0.25, 0.0]
	_store()
	main.start_game({"seats": seats, "ai_delay": speeds[speed], "opts": {}, "solo": {"dummies": solo_dummies, "diff": solo_diff}, "start": randi() % 2})


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _online_panel() -> void:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.size = Vector2(1920, 1080)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.05, 0.02, 0.82)
	shade.size = on_panel.size
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.paper(false, 34))
	box.position = Vector2(560, 130)
	box.custom_minimum_size = Vector2(800, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	vb.add_child(UI.title("Gioca online", 46))
	vb.add_child(UI.wrap("Chi crea la stanza sceglie prima nel menu casate, espansioni e livello dell'IA: le casate su Umano diventano i posti per gli amici (la prima è la sua). Gli amici entrano con il codice. I posti rimasti liberi li gioca l'IA.", 21, 740, UI.INK2))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := UI.button("Crea una stanza", 0, 60, 26)
	UI.lapis(b_create)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 60, 26)
	UI.lapis(b_join)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.wrap("", 22, 740)
	on_lbl.custom_minimum_size.y = 120
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = _big("Si comincia!", 360, true)
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := _big("Indietro", 260)
	b_close.pressed.connect(func():
		on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 60)
	le.add_theme_font_size_override("font_size", 28)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_list() -> Array:
	return _config()["seats"]


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var list := _seat_list()
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		var cname: String = list[int(idx)]["name"] if int(idx) < list.size() else "posto %d" % (int(idx) + 1)
		parts.append("%s: %s" % [cname, who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := []
	var list := _seat_list()
	for i in list.size():
		if not list[i]["ai"]:
			seats.append(i)
	if list.size() < 2 or seats.size() < 2:
		_say("Servono almeno 2 casate in gioco, di cui almeno due su Umano: la prima è la tua, le altre sono i posti per gli amici.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi Si comincia!: i posti liberi li gioca l'IA." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (posto %d).\nPosti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1, _seats_text(room)])
		await get_tree().create_timer(2.0).timeout


## Chi ha creato la stanza avvia: casate, espansioni e seme valgono per tutti.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	var my_seat := int(main.lobby["seat"])
	if my_seat >= cfg["seats"].size() or not seats_db.has(str(my_seat)) or cfg["seats"][my_seat]["ai"]:
		_say("Hai cambiato le casate dopo aver creato la stanza: creane una nuova.")
		return
	for i in cfg["seats"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["seats"][i]["ai"]:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", cfg["seats"][i]["name"]))
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	cfg["start"] = randi() % cfg["seats"].size()
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


## Avvio (o rientro) della partita online.
func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)
