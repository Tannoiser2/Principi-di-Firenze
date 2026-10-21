extends Control
## Piazzamento di un edificio o di un paesaggio nel principato.
## La tessera segue il mouse sulla griglia: clic per posarla, R / tasto destro / rotella per ruotarla,
## F per girarla. Verde = posizione valida. Sul lato B si vedono anche i principati vicini:
## un edificio a cavallo del confine si costruisce insieme al vicino, che paga la cifra proposta.

signal done(result)

const D = preload("res://scripts/data/pf_data.gd")

var eng: PFEngine
var st: PFState
var seat := 0
var kind := "b"                # b edificio, l paesaggio
var id := ""
var can_cancel := true
var title_text := ""

var rot := 0
var flip := false
var hover := Vector2i(-99, -99)
var cell := 84.0
var origin := Vector2.ZERO         # angolo in alto a sinistra della griglia del giocatore
var boards := []                   # [{seat, off (in caselle), img}]
var nb := {}
var price := 200
var price_lbl: Label
var price_box: HBoxContainer
var info: Label
var ok_cells := {}                 # piazzamenti legali (chiave "x,y,r,f")
var coop_ok := {}


func _ready() -> void:
	st = eng.st
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p: Dictionary = st.players[seat]
	nb = st.neighbors(seat) if kind == "b" else {}
	var cols: int = p["w"]
	var span := cols
	if nb.has("L"):
		span += st.players[nb["L"]]["w"]
	if nb.has("R"):
		span += st.players[nb["R"]]["w"]
	cell = minf(96.0, minf(1700.0 / float(span), 640.0 / float(p["h"])))
	var total_w := span * cell
	var left_cols: int = st.players[nb["L"]]["w"] if nb.has("L") else 0
	origin = Vector2((1920.0 - total_w) / 2.0 + left_cols * cell, 230.0)
	if nb.has("L"):
		boards.append({"seat": nb["L"], "off": -st.players[nb["L"]]["w"]})
	boards.append({"seat": seat, "off": 0})
	if nb.has("R"):
		boards.append({"seat": nb["R"], "off": cols})
	for pl in st.placements(seat, kind, id):
		ok_cells["%d,%d,%d,%s" % [pl["x"], pl["y"], pl["r"], pl["f"]]] = pl
	if kind == "b":
		for side in nb:
			for pl in st.coop_placements(seat, side, id):
				coop_ok["%d,%d,%d,%s" % [pl["x"], pl["y"], pl["r"], pl["f"]]] = pl
	# prima orientazione che ha almeno un posto
	for o in D.orientations(id):
		var found := false
		for k in ok_cells:
			if k.ends_with(",%d,%s" % [o[0], o[1]]):
				found = true
				break
		if found:
			rot = o[0]
			flip = o[1]
			break
	_build_ui()


func _build_ui() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(0, 40)
	top.size = Vector2(1920, 160)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var name: String = D.BUILDING_NAME.get(id, D.LAND_NAME.get(id, id))
	var t := UI.title(title_text if title_text != "" else "Dove metti %s?" % name, 40, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(t)
	info = UI.label("Clic per posare · R, tasto destro o rotella per ruotare · F per girare la tessera", 22, UI.SAND, UI.font_italic)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(info)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	bar.position = Vector2(0, 950)
	bar.size = Vector2(1920, 70)
	add_child(bar)
	var b_rot := UI.button("Ruota", 170, 56, 24)
	b_rot.pressed.connect(func(): _rotate(1))
	bar.add_child(b_rot)
	var b_flip := UI.button("Gira", 170, 56, 24)
	b_flip.pressed.connect(func(): _flip())
	bar.add_child(b_flip)
	var b_auto := UI.button("Posto consigliato", 300, 56, 24)
	UI.lapis(b_auto)
	b_auto.pressed.connect(func():
		var pl: Dictionary = eng.ais[seat].best_place(eng, seat, kind, id)
		if not pl.is_empty():
			done.emit(pl))
	bar.add_child(b_auto)
	price_box = HBoxContainer.new()
	price_box.add_theme_constant_override("separation", 8)
	price_box.visible = false
	var minus := UI.button("−100", 110, 56, 22)
	minus.pressed.connect(func():
		price = maxi(0, price - 100)
		_paint_price())
	price_box.add_child(minus)
	price_lbl = UI.label("", 24, UI.SAND, UI.font_bold)
	price_box.add_child(price_lbl)
	var plus := UI.button("+100", 110, 56, 22)
	plus.pressed.connect(func():
		price += 100
		_paint_price())
	price_box.add_child(plus)
	bar.add_child(price_box)
	if can_cancel:
		var b_no := UI.button("Annulla", 200, 56, 24)
		UI.dark(b_no)
		b_no.pressed.connect(func(): done.emit(null))
		bar.add_child(b_no)
	_paint_price()


func _paint_price() -> void:
	if price_lbl != null:
		price_lbl.text = "Il vicino ti paga: %s fiorini" % UI.fl(price)


func _rotate(d: int) -> void:
	rot = posmod(rot + d, 4)
	queue_redraw()


func _flip() -> void:
	flip = not flip
	queue_redraw()


## Posizione corrente: {pl, ok, coop}
func _current() -> Dictionary:
	var cells := D.shape_cells(id, rot, flip)
	var mx := 0
	var my := 0
	for c in cells:
		mx = maxi(mx, c.x)
		my = maxi(my, c.y)
	var x := hover.x - mx / 2
	var y := hover.y - my / 2
	var key := "%d,%d,%d,%s" % [x, y, rot, flip]
	if ok_cells.has(key):
		return {"pl": ok_cells[key], "ok": true, "coop": false}
	if coop_ok.has(key):
		return {"pl": coop_ok[key], "ok": true, "coop": true}
	return {"pl": {"x": x, "y": y, "r": rot, "f": flip}, "ok": false, "coop": false}


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var g := ((ev as InputEventMouseMotion).position - origin) / cell
		var h := Vector2i(floori(g.x), floori(g.y))
		if h != hover:
			hover = h
			var cur := _current()
			price_box.visible = cur["coop"]
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var cur := _current()
			if cur["ok"]:
				var pl: Dictionary = cur["pl"].duplicate()
				if cur["coop"]:
					pl["price"] = price
				done.emit(pl)
			else:
				Audio.play("click", -14.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate(-1)


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_R:
			_rotate(1)
		elif ev.keycode == KEY_F:
			_flip()
		elif ev.keycode == KEY_ESCAPE and can_cancel:
			done.emit(null)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.03, 0.82), true)
	for b in boards:
		var s: int = b["seat"]
		var q: Dictionary = st.players[s]
		var bd: Dictionary = D.board_info(q)
		var o := origin + Vector2(b["off"] * cell, 0)
		var k: float = cell / float(bd["cell"])
		var img: Texture2D = UI.tex(bd["img"])
		# solo la parte con la griglia
		var src := Rect2(bd["x0"], bd["y0"], bd["cell"] * q["w"], bd["cell"] * q["h"])
		draw_texture_rect_region(img, Rect2(o, Vector2(q["w"], q["h"]) * cell), src, Color(1, 1, 1, 1.0 if s == seat else 0.72))
		draw_rect(Rect2(o, Vector2(q["w"], q["h"]) * cell), UI.pcolor(q["color"]), false, 4.0)
		draw_string(UI.font_title, o + Vector2(6, -10), q["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.SAND)
		for pc in q["pieces"]:
			if pc.get("ghost", false):
				continue
			_draw_piece(pc, o, 1.0)
	var cur := _current()
	var col := Color(0.3, 0.85, 0.35, 0.55) if cur["ok"] else Color(0.9, 0.2, 0.15, 0.45)
	if cur["coop"]:
		col = Color(0.3, 0.6, 0.95, 0.55)
	if hover.x > -50:
		var pl: Dictionary = cur["pl"]
		_draw_piece({"id": id, "x": pl["x"], "y": pl["y"], "r": rot, "f": flip}, origin, 0.85)
		for c in PFState.placed_cells(id, pl):
			draw_rect(Rect2(origin + Vector2(c) * cell, Vector2(cell, cell)).grow(-3), col, true)
	if cur["coop"]:
		info.text = "Edificio in comune con %s: costa a te %s fiorini, il vicino ti paga la cifra qui sotto (può rifiutare)." % [st.pname(int(nb.get(cur["pl"].get("side", "R"), 0))), UI.fl(st.build_cost(seat))]
	elif hover.x > -50:
		info.text = "Clic per posare · R, tasto destro o rotella per ruotare · F per girare la tessera"


func _draw_piece(pc: Dictionary, o: Vector2, alpha: float) -> void:
	var pid: String = pc["id"]
	var mp := Board3D.shape_map(pid, int(pc["r"]), bool(pc["f"]))
	var tex: Texture2D = UI.tile_tex(pid)
	if tex == null:
		return
	var center: Vector2 = o + (Vector2(float(pc["x"]), float(pc["y"])) + mp["center"]) * cell
	var xf := Transform2D(PI / 2.0 * posmod(int(pc["r"]), 4), center)
	if pc["f"]:
		xf = xf * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	draw_set_transform_matrix(xf)
	var w: float = mp["w0"] * cell
	var h: float = mp["h0"] * cell
	draw_texture_rect(tex, Rect2(-w / 2.0, -h / 2.0, w, h), false, Color(1, 1, 1, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)
