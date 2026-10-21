class_name Board3D
extends Node3D
## Il tavolo: tabellone con le pile dell'asta, gli edifici, le libertà e la traccia della fama;
## per ogni casata il principato con edifici e paesaggi, la plancia (libertà, costruttori, giullari)
## e le opere completate. In 3D gli edifici sono i modelli dipinti (Meshy) sopra le tessere.
## Trascina per ruotare, rotella per lo zoom, tasto destro (o Maiusc+trascina) per spostare,
## doppio clic per tornare alla vista iniziale.

signal principality_clicked(seat: int)

const D = preload("res://scripts/data/pf_data.gd")
const BW := 24.0                         # larghezza del tabellone
const BH := 24.0 * 3192.0 / 6299.0
const IW := 12.5                         # larghezza della plancia italiana (principato + plancia)
const PW := 9.0                          # larghezza della plancia del principato
const CW := 6.6                          # larghezza della plancia del giocatore
const CH := CW * 723.0 / 1400.0
const TOP := 0.06

var eng: PFEngine
var st: PFState
var cam: Camera3D
var yaw := 0.0
const PITCH0 := 56.0
var dist0 := 34.0
var focus0 := Vector3(0, 0, 5.5)
var pitch := PITCH0
var dist := 34.0
var focus := Vector3(0, 0, 5.5)
var _yaw_t := 0.0
var _pitch_t := PITCH0
var _dist_t := 34.0
var _focus_t := Vector3(0, 0, 5.5)
var flat := false
var show_models := true

var dyn: Node3D
var mats := {}
var meshes := {}
var model_cache := {}
var group_pos := {}                      # posto -> origine del principato (angolo in alto a sinistra)
var plancia_pos := {}                    # posto -> centro della plancia del giocatore
var _drag := false
var _drag_moved := 0.0
var _pan := false
var _touches := {}
var _pinch_d := 0.0
var _last_click := 0


func _ready() -> void:
	st = eng.st
	_build_env()
	_build_table()
	_layout()
	dyn = Node3D.new()
	add_child(dyn)
	reset_view()
	dist = _dist_t
	focus = _focus_t
	_apply_cam()
	refresh()


func _process(delta: float) -> void:
	var k := minf(1.0, delta * 9.0)
	yaw = lerpf(yaw, _yaw_t, k)
	pitch = lerpf(pitch, _pitch_t, k)
	dist = lerpf(dist, _dist_t, k)
	focus = focus.lerp(_focus_t, k)
	_apply_cam()


# ================================================================== scena fissa

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/env/sky.jpg")
	pm.energy_multiplier = 0.85
	sky.sky_material = pm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#e0cfae")
	e.ambient_light_energy = 0.36
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.76
	sun.light_color = Color("#fff0d6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 150, 0)
	fill.light_energy = 0.28
	fill.light_color = Color("#c8d8ff")
	add_child(fill)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true


func _mat(c: Color, rough := 0.6) -> StandardMaterial3D:
	var key := "c" + c.to_html()
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	mats[key] = m
	return m


func _tex_mat(path: String, alpha := false) -> StandardMaterial3D:
	var key := path + str(alpha)
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex(path)
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = m
	return m


func _build_table() -> void:
	var t := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 100)
	t.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/env/table.jpg")
	m.uv1_scale = Vector3(10, 7, 1)
	m.roughness = 0.7
	m.albedo_color = Color(0.92, 0.84, 0.76)
	t.material_override = m
	t.position = Vector3(0, -0.02, 6)
	add_child(t)
	_slab("res://assets/board/tabellone.jpg", BW, BH, Vector3(0, 0, 0), 0.1, self)


## Lastra di cartone con un'immagine sopra (tabellone, plance)
func _slab(path: String, w: float, h: float, pos: Vector3, thick: float, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, thick, h)
	box.mesh = bm
	box.material_override = _mat(Color("#3b2614"))
	box.position.y = thick / 2.0
	root.add_child(box)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	top.mesh = pm
	top.material_override = _tex_mat(path)
	top.position.y = thick + 0.002
	root.add_child(top)
	return root


func board_point(f: Vector2) -> Vector3:
	return Vector3((f.x - 0.5) * BW, 0.1, (f.y - 0.5) * BH)


## Larghezza e altezza della plancia del principato del giocatore
func pw(s: int) -> float:
	return PW if st.players[s]["board"] == "B" else IW


func ph(s: int) -> float:
	var b: Dictionary = D.board_info(st.players[s])
	return pw(s) * float(b["img_h"]) / float(b["img_w"])


## Posizioni sul tavolo (fuori dal tabellone): edifici a sinistra, libertà e mazzi a destra
var table_pos := {}


func _table_layout() -> void:
	var i := 0
	for b in D.BUILDINGS:
		table_pos[b] = Vector3(-BW / 2.0 - 2.2 - (i % 3) * 2.7, 0, -4.6 + (i / 3) * 3.1)
		i += 1
	var j := 0
	for f in D.FREEDOMS:
		table_pos[f] = Vector3(BW / 2.0 + 5.4, 0, -3.5 + j * 1.4)
		j += 1
	table_pos["bonus"] = Vector3(BW / 2.0 + 2.2, 0, -2.6)
	table_pos["professioni"] = Vector3(BW / 2.0 + 2.2, 0, 1.6)


## Disposizione delle casate attorno al tabellone
func _layout() -> void:
	_table_layout()
	var n := st.n
	var coop: bool = st.opts.get("coop", false)
	if coop:
		var bh := PW * 1635.0 / 2048.0
		var total := n * PW
		for s in n:
			var x := -total / 2.0 + s * PW
			group_pos[s] = Vector3(x, 0, BH / 2.0 + 1.6)
			plancia_pos[s] = Vector3(x + PW / 2.0 - 0.9, 0, BH / 2.0 + 1.6 + bh + CH / 2.0 + 0.5)
		dist0 = maxf(36.0, total * 0.95)
		focus0 = Vector3(0, 0, 7.0)
	else:
		var bottom := []
		var topr := []
		for s in n:
			if s < int(ceil(n / 2.0)) or n <= 2:
				bottom.append(s)
			else:
				topr.append(s)
		var gw := IW + 1.6
		for i in bottom.size():
			var s: int = bottom[i]
			var x := (i - (bottom.size() - 1) / 2.0) * gw - IW / 2.0
			group_pos[s] = Vector3(x, 0, BH / 2.0 + 1.5)
		for i in topr.size():
			var s: int = topr[i]
			var x := (i - (topr.size() - 1) / 2.0) * gw - IW / 2.0
			group_pos[s] = Vector3(x, 0, -BH / 2.0 - 1.5 - ph(s))
		dist0 = 40.0 if topr.is_empty() else 52.0
		focus0 = Vector3(0, 0, 7.0 if topr.is_empty() else 2.0)
	for s in n:
		var p: Dictionary = st.players[s]
		var b: Dictionary = D.board_info(p)
		var w := pw(s)
		var hh := ph(s)
		_slab(b["img"], w, hh, group_pos[s] + Vector3(w / 2.0, 0, hh / 2.0), 0.08, self)
		if coop:
			_slab("res://assets/board/plancia_%s_%s.jpg" % [p["color"], p["side"]], CW, CH, plancia_pos[s], 0.06, self)
		var lab := Label3D.new()
		lab.text = p["name"]
		lab.font = UI.font_title
		lab.font_size = 96
		lab.pixel_size = 0.006
		lab.modulate = UI.pcolor(p["color"]).lightened(0.25)
		lab.outline_size = 18
		lab.outline_modulate = Color(0.1, 0.06, 0.03)
		lab.rotation_degrees.x = -90
		var above: bool = group_pos[s].z > 0
		lab.position = group_pos[s] + Vector3(w / 2.0, 0.12, -0.45 if above else hh + 0.45)
		add_child(lab)


## Geometria della griglia del principato
func grid_info(s: int) -> Dictionary:
	var p: Dictionary = st.players[s]
	var b: Dictionary = D.board_info(p)
	var k := pw(s) / float(b["img_w"])
	return {"o": group_pos[s] + Vector3(b["x0"] * k, 0.08, b["y0"] * k), "c": b["cell"] * k}


## Punto della plancia italiana (coordinate dell'immagine originale 3296 px di larghezza)
func it_point(s: int, x: float, y: float) -> Vector3:
	var k := pw(s) / 3296.0
	return group_pos[s] + Vector3(x * k, 0.08, y * k)


# ================================================================== telecamera

func _apply_cam() -> void:
	if cam == null:
		return
	if flat:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.v_offset = -0.1 * dist
		cam.size = dist * 0.75
		cam.position = focus + Vector3(0, 80, 0)
		cam.look_at(focus, Vector3(0, 0, -1))
		return
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.v_offset = -0.12 * dist
	var pr := deg_to_rad(pitch)
	var yw := deg_to_rad(yaw)
	cam.position = focus + Vector3(sin(yw) * cos(pr), sin(pr), cos(yw) * cos(pr)) * dist
	if pitch > 88.5:
		cam.look_at(focus, Vector3(-sin(yw), 0, -cos(yw)))
	else:
		cam.look_at(focus, Vector3.UP)


func set_flat(on: bool) -> void:
	flat = on
	show_models = not on
	refresh()


func reset_view() -> void:
	_yaw_t = _near_yaw(0.0)
	_pitch_t = PITCH0
	_dist_t = dist0
	_focus_t = focus0


func focus_seat(s: int) -> void:
	var info := grid_info(s)
	var p: Dictionary = st.players[s]
	_focus_t = info["o"] + Vector3(p["w"] * info["c"] / 2.0, 0, p["h"] * info["c"] / 2.0 + 1.5)
	_focus_t.y = 0
	_dist_t = 17.0


func focus_board() -> void:
	_focus_t = Vector3(0, 0, 0)
	_dist_t = 26.0


func _near_yaw(a: float) -> float:
	while a - _yaw_t > 180.0:
		a -= 360.0
	while _yaw_t - a > 180.0:
		a += 360.0
	return a


func zoom(f: float) -> void:
	_dist_t = clampf(_dist_t * f, 6.0, 90.0)


func _pan_by(rel: Vector2) -> void:
	var yw := 0.0 if flat else deg_to_rad(yaw)
	var right := Vector3(cos(yw), 0, -sin(yw))
	var fwd := Vector3(-sin(yw), 0, -cos(yw))
	var f := dist * (0.0012 if flat else 0.0016)
	_focus_t += (-right * rel.x + fwd * rel.y) * f
	_focus_t.x = clampf(_focus_t.x, -40, 40)
	_focus_t.z = clampf(_focus_t.z, -30, 34)


func _seat_at(pos: Vector2) -> int:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	if absf(dir.y) < 0.001:
		return -1
	var t := (0.1 - from.y) / dir.y
	var hit := from + dir * t
	for s in group_pos:
		var o: Vector3 = group_pos[s]
		if hit.x >= o.x and hit.x <= o.x + PW and hit.z >= o.z and hit.z <= o.z + PW * 0.8:
			return s
	return -1


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				var s := _seat_at(mb.position)
				if s >= 0:
					focus_seat(s)
				else:
					reset_view()
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				if _drag and _drag_moved < 6.0:
					var s2 := _seat_at(mb.position)
					if s2 >= 0:
						principality_clicked.emit(s2)
				_drag = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = mb.pressed
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _touches.size() >= 2:
			return
		if _drag and not mm.shift_pressed and not flat:
			_drag_moved += mm.relative.length()
			_yaw_t -= mm.relative.x * 0.3
			_pitch_t = clampf(_pitch_t + mm.relative.y * 0.25, 15.0, 89.5)
		elif _pan or (_drag and (mm.shift_pressed or flat)):
			_drag_moved += mm.relative.length()
			_pan_by(mm.relative)
	elif ev is InputEventScreenTouch:
		var stt := ev as InputEventScreenTouch
		if stt.pressed:
			_touches[stt.index] = stt.position
		else:
			_touches.erase(stt.index)
		_pinch_d = 0.0
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var ks := _touches.keys()
			var d2: float = (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]])
			if _pinch_d > 0.0:
				_dist_t = clampf(_dist_t * _pinch_d / maxf(1.0, d2), 6.0, 90.0)
			_pinch_d = d2
			_drag_moved = 99.0
	elif ev is InputEventMagnifyGesture:
		zoom(1.0 / (ev as InputEventMagnifyGesture).factor)
	elif ev is InputEventPanGesture:
		_pan_by((ev as InputEventPanGesture).delta * 12.0)


# ================================================================== pezzi

func _quad(path: String, w: float, h: float, pos: Vector3, alpha := false, rot_y := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	q.mesh = pm
	q.material_override = _tex_mat(path, alpha)
	q.position = pos
	q.rotation.y = rot_y
	(parent if parent != null else dyn).add_child(q)
	return q


## Pila di tessere/carte: un parallelepipedo sottile con l'immagine sopra e il numero accanto
func _stack(path: String, w: float, h: float, pos: Vector3, count: int, thick := 0.02, alpha := false, label := true) -> void:
	if count <= 0:
		return
	var hgt := thick * count
	if not alpha:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 0.98, hgt, h * 0.98)
		box.mesh = bm
		box.material_override = _mat(Color("#e8dcc0"))
		box.position = pos + Vector3(0, hgt / 2.0, 0)
		dyn.add_child(box)
	_quad(path, w, h, pos + Vector3(0, hgt + 0.003, 0), alpha)
	if label and count > 1:
		_label("×%d" % count, pos + Vector3(w / 2.0 + 0.05, hgt + 0.05, h / 2.0 - 0.15), 64)


func _label(text: String, pos: Vector3, size := 64, col := Color("#fff2c0")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UI.font_brush
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0.12, 0.07, 0.03)
	l.rotation_degrees.x = -90
	l.position = pos
	l.no_depth_test = false
	dyn.add_child(l)
	return l


func _disc(pos: Vector3, c: Color, r := 0.22, h := 0.1, path := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 24
	m.mesh = cm
	m.material_override = _mat(c, 0.45)
	m.position = pos + Vector3(0, h / 2.0, 0)
	dyn.add_child(m)
	if path != "":
		_quad(path, r * 2.0, r * 2.0, pos + Vector3(0, h + 0.003, 0), true)
	return m


## Pedina del giocatore (asta e opera del round)
func _pawn(pos: Vector3, c: Color) -> void:
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.24
	cm.height = 0.55
	body.mesh = cm
	body.material_override = _mat(c, 0.4)
	body.position = pos + Vector3(0, 0.275, 0)
	dyn.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	head.mesh = sm
	head.material_override = _mat(c, 0.4)
	head.position = pos + Vector3(0, 0.66, 0)
	dyn.add_child(head)


## Trasformazione di una sagoma: da coordinate della tessera (in caselle, r=0) a coordinate piazzate
static func shape_map(id: String, r: int, f: bool) -> Dictionary:
	var rows: Array = D.SHAPES[id]
	var w0 := float(rows[0].length())
	var h0 := float(rows.size())
	var corners := [Vector2(0, 0), Vector2(w0, 0), Vector2(0, h0), Vector2(w0, h0)]
	var tf := func(p: Vector2) -> Vector2:
		var q := Vector2(w0 - p.x, p.y) if f else p
		for _k in posmod(r, 4):
			q = Vector2(-q.y, q.x)
		return q
	var mn := Vector2(INF, INF)
	for c in corners:
		var q: Vector2 = tf.call(c)
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
	var center: Vector2 = tf.call(Vector2(w0 / 2.0, h0 / 2.0)) - mn
	return {"w0": w0, "h0": h0, "center": center, "rot": -PI / 2.0 * posmod(r, 4), "flip": f}


const THICK := 0.075                    # spessore delle tessere (cartoncino di 2-3 mm)
const SUPPLY_CELL := 0.825                # casella delle sagome stampate sul tabellone


## Tessera di cartone con lo spessore: una colonnina per casella e l'illustrazione sopra.
## parent ha l'origine al centro del riquadro della sagoma (orientamento della tessera, r=0).
func _cardboard(id: String, c: float, count: int, parent: Node3D, with_model := false) -> void:
	var rows: Array = D.SHAPES[id]
	var w0 := float(rows[0].length())
	var h0 := float(rows.size())
	var hgt := THICK * maxi(1, count)
	var key := "box%.3f_%.3f" % [c, hgt]
	if not meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3(c * 0.97, hgt, c * 0.97)
		meshes[key] = bm
	var side := _mat(Color("#9c8463"), 0.9)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var b := MeshInstance3D.new()
			b.mesh = meshes[key]
			b.material_override = side
			b.position = Vector3((x + 0.5 - w0 / 2.0) * c, hgt / 2.0, (y + 0.5 - h0 / 2.0) * c)
			parent.add_child(b)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w0 * c, h0 * c)
	q.mesh = pm
	q.material_override = _tex_mat("res://assets/tiles/%s.png" % id, true)
	q.position.y = hgt + 0.002
	parent.add_child(q)
	if with_model and show_models:
		var model := _model(id)
		if model != null:
			model.scale = Vector3(c, c, c)
			model.position.y = hgt + 0.003
			parent.add_child(model)


func _piece(s: int, pc: Dictionary) -> void:
	var info := grid_info(s)
	var c: float = info["c"]
	var o: Vector3 = info["o"]
	var id: String = pc["id"]
	var mp := shape_map(id, int(pc["r"]), bool(pc["f"]))
	var center := Vector3(o.x + (float(pc["x"]) + mp["center"].x) * c, o.y + 0.002, o.z + (float(pc["y"]) + mp["center"].y) * c)
	var holder := Node3D.new()
	holder.position = center
	holder.rotation.y = mp["rot"]
	dyn.add_child(holder)
	var inner := Node3D.new()
	if mp["flip"]:
		inner.scale = Vector3(-1, 1, 1)
	holder.add_child(inner)
	_cardboard(id, c, 1, inner, true)


func _model(id: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % id
	if not model_cache.has(path):
		model_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var ps = model_cache[path]
	if ps == null:
		return null
	return (ps as PackedScene).instantiate()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		out = a
		first = false
	for ch in n.get_children():
		var b := _aabb(ch, t)
		if b.size == Vector3.ZERO:
			continue
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


# ================================================================== aggiornamento

func refresh() -> void:
	if dyn == null:
		return
	for c in dyn.get_children():
		c.queue_free()
	_refresh_supply()
	_refresh_track()
	for s in st.n:
		_refresh_player(s)
	_refresh_extra()


func _bp(key: String) -> Vector3:
	if table_pos.has(key):
		return table_pos[key]
	return board_point(D.BOARD_POS[key])


## Pila sul tabellone: tessere di cartone sulla sagoma stampata (con il modello in cima in 3D)
func _supply_stack(id: String, count: int) -> void:
	if count <= 0:
		return
	var holder := Node3D.new()
	holder.position = _bp(id)
	holder.rotation.y = -PI / 2.0 * int(D.BOARD_ROT.get(id, 0)) if D.BOARD_POS.has(id) else 0.0
	dyn.add_child(holder)
	_cardboard(id, SUPPLY_CELL, count, holder, true)
	if count > 1:
		var rows: Array = D.SHAPES[id]
		var lab := _label("×%d" % count, Vector3.ZERO, 64)
		lab.reparent(holder, false)
		lab.position = Vector3(rows[0].length() * SUPPLY_CELL / 2.0 + 0.05, THICK * count + 0.05, rows.size() * SUPPLY_CELL / 2.0 - 0.2)


## Pila di tessere rettangolari (libertà) o di carte, appoggiata sul tabellone
func _flat_stack(path: String, w: float, h: float, pos: Vector3, count: int, thick: float, edge := Color("#e8dcc0")) -> void:
	if count <= 0:
		return
	var hgt := thick * count
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w * 0.99, hgt, h * 0.99)
	box.mesh = bm
	box.material_override = _mat(edge)
	box.position = pos + Vector3(0, hgt / 2.0, 0)
	dyn.add_child(box)
	_quad(path, w, h, pos + Vector3(0, hgt + 0.002, 0))
	if count > 1:
		_label("×%d" % count, pos + Vector3(w / 2.0 + 0.05, hgt + 0.05, h / 2.0 - 0.15), 64)


## Gettone quadrato di cartone (costruttore)
func _square_token(path: String, pos: Vector3, size: float, count := 1) -> void:
	_flat_stack(path, size, size, pos, count, THICK, Color("#9c8463"))


func _refresh_supply() -> void:
	for l in D.LANDS:
		_supply_stack(l, st.supply["land"][l])
	for b in D.BUILDINGS:
		_supply_stack(b, st.supply["bld"][b])
	for f in D.FREEDOMS:
		_flat_stack("res://assets/tiles/liberta_%s.jpg" % f, 2.0, 0.85, _bp(f), st.supply["free"][f], THICK, Color("#9c8463"))
	_flat_stack("res://assets/cards/dorso_prestigio.jpg", 2.75, 3.84, _bp("prestigio"), st.prest_deck.size(), 0.012)
	_flat_stack("res://assets/cards/dorso_reclutamento.jpg", 2.75, 3.84, _bp("reclutamento"), st.supply["reclutamento"], 0.012)
	_flat_stack("res://assets/cards/dorso_bonus.jpg", 2.6, 3.65, _bp("bonus"), st.bonus_deck.size(), 0.01)
	_flat_stack("res://assets/cards/dorso_professioni.jpg", 2.6, 3.65, _bp("professioni"), st.prof_deck.size(), 0.01)
	_square_token("res://assets/tokens/costruttore_it.jpg", _bp("costruttore"), 1.3, st.supply["costruttore"])
	for i in st.supply["giullare"]:
		_disc(_bp("giullare") + Vector3(0, i * THICK, 0), Color("#9c8463"), 0.78, THICK, "res://assets/tokens/giullare_tondo.png" if i == st.supply["giullare"] - 1 else "")
	# pedine dell'asta sulle pile già assegnate
	var au: Dictionary = eng.auction
	if au.has("won"):
		for s in au["won"]:
			var obj: String = au["won"][s]
			if obj == "":
				continue
			var key: String = "bosco" if obj == "paesaggio" else obj
			if D.BOARD_POS.has(key):
				_pawn(_bp(key) + Vector3(0.7, 0.2, -0.6), UI.pcolor(st.players[s]["color"]))


func _refresh_track() -> void:
	# segnapunti sulla traccia della fama
	var at := {}
	for s in st.n:
		var p: Dictionary = st.players[s]
		var sp := posmod(int(p["fame"]), 50)
		var k: int = at.get(sp, 0)
		at[sp] = k + 1
		var pos := board_point(D.fame_pos(sp))
		_disc(pos + Vector3(0, k * 0.09, 0), UI.pcolor(p["color"]), 0.2, 0.09)
		# opera del round: la pedina sulla traccia
		if p["best"] > 0:
			_pawn(board_point(D.fame_pos(p["best"])) + Vector3(0.12 * k, 0, 0.25), UI.pcolor(p["color"]))
	# segnalino del round
	var rp := board_point(D.round_pos(st.round))
	_quad("res://assets/tokens/giglio.png", 0.62, 0.74, rp + Vector3(0, 0.02, 0), true)


## Il palazzo stampato sulla plancia, in 3D
func _palazzo(s: int) -> void:
	if not show_models:
		return
	var model := _model("palazzo")
	if model == null:
		return
	var p: Dictionary = st.players[s]
	var b: Dictionary = D.board_info(p)
	var mn := Vector2i(99, 99)
	for cl in b["palazzo"]:
		mn = Vector2i(mini(mn.x, cl.x), mini(mn.y, cl.y))
	var info := grid_info(s)
	var c: float = info["c"]
	var o: Vector3 = info["o"]
	model.scale = Vector3(c, c, c)
	model.position = o + Vector3((mn.x + 1.5) * c, 0.004, (mn.y + 1.0) * c)
	dyn.add_child(model)


func _refresh_player(s: int) -> void:
	var p: Dictionary = st.players[s]
	_palazzo(s)
	var coop: bool = st.opts.get("coop", false)
	for pc in p["pieces"]:
		if pc.get("ghost", false):
			# l'edificio in comune si vede già dal principato accanto, tranne che fra l'ultimo e il primo
			var o: int = pc["with"]
			if coop and absi(o - s) == 1:
				continue
		_piece(s, pc)
	if p["board"] == "B":
		_tokens_side_b(s)
	else:
		_tokens_it(s)
	# personaggio, disco 50/100 e opere completate accanto alla plancia
	var right: Vector3 = group_pos[s] + Vector3(pw(s) + 0.9, TOP, 0.9)
	var laps := int(p["fame"]) / 50
	if laps >= 1:
		_disc(group_pos[s] + Vector3(-0.7, 0, 0.7), UI.pcolor(p["color"]), 0.4, 0.06, "res://assets/tokens/disco%s_%s.jpg" % ["100" if laps >= 2 else "50", p["color"]])
	var cards := []
	if p["wolf"]:
		for e in p["row"]:
			cards.append(("res://assets/cards/prof%02d.jpg" % e["c"]) if (e["up"] and e["c"] > 0) else ("res://assets/cards/reclutamento.jpg" if e["up"] else "res://assets/cards/dorso_professioni.jpg"))
	else:
		for c in p["table"]:
			cards.append(("res://assets/cards/prof%02d.jpg" % c) if c > 0 else "res://assets/cards/reclutamento.jpg")
	for i in cards.size():
		_quad(cards[i], 1.2, 1.68, right + Vector3((i % 2) * 1.3, 0.01 * i, (i / 2) * 0.7), false)
	if p["char"] != "":
		var q := _quad("res://assets/cards/pers_%s.jpg" % p["char"], 1.2, 1.68, group_pos[s] + Vector3(-0.9, TOP, ph(s) - 1.2), false)
		if not p["char_up"]:
			q.transparency = 0.5


## Libertà, costruttori e giullari sulla plancia italiana (caselle misurate sulla scansione)
func _tokens_it(s: int) -> void:
	var p: Dictionary = st.players[s]
	var k := pw(s) / 3296.0
	var fy := {"viaggio": 1557.0, "religione": 1814.0, "opinione": 2068.0}
	var used := {}
	for f in p["freedoms"]:
		var n: int = used.get(f, 0)
		used[f] = n + 1
		_flat_stack("res://assets/tiles/liberta_%s.jpg" % f, 500.0 * k, 200.0 * k, it_point(s, 418.0 + n * 40.0, fy[f]) + Vector3(0, n * THICK, 0), 1, THICK, Color("#9c8463"))
	var bx := [943.0, 1485.0, 2023.0]
	for i in mini(3, int(p["builders"])):
		_square_token("res://assets/tokens/costruttore_it.jpg", it_point(s, bx[i], 2048.0), 220.0 * k)
	for i in int(p["jesters"]):
		_disc(it_point(s, 250.0 + (i % 3) * 190.0, 1180.0 - (i / 3) * 190.0), Color("#9c8463"), 85.0 * k, THICK, "res://assets/tokens/giullare_tondo.png")


## Plancia del giocatore separata (lato B, costruzioni in comune)
func _tokens_side_b(s: int) -> void:
	var p: Dictionary = st.players[s]
	var cp: Vector3 = plancia_pos[s]
	var ox := cp.x - CW / 2.0
	var oz := cp.z - CH / 2.0
	var rows := [0.14, 0.378, 0.606]
	var fslot := {"viaggio": 0, "opinione": 1, "religione": 2}
	var used := {}
	for f in p["freedoms"]:
		var r: int = fslot[f]
		var k: int = used.get(r, 0)
		used[r] = k + 1
		_flat_stack("res://assets/tiles/liberta_%s.jpg" % f, CW * 0.2286, CH * 0.186, Vector3(ox + CW * 0.585 + k * 0.12, TOP + k * THICK, oz + CH * rows[r]), 1, THICK, Color("#9c8463"))
	for i in mini(3, int(p["builders"])):
		_square_token("res://assets/tokens/costruttore_it.jpg", Vector3(ox + CW * 0.798, TOP, oz + CH * [0.139, 0.371, 0.603][i]), CW * 0.095)
	for i in int(p["jesters"]):
		_disc(Vector3(ox + CW * (0.5 + 0.075 * i), TOP, oz + CH * 0.86), Color("#9c8463"), 0.27, THICK, "res://assets/tokens/giullare_tondo.png")


func _refresh_extra() -> void:
	# personaggi all'asta (espansione): pedina e offerta sul ritratto stampato
	if not st.chars.is_empty():
		for c in D.CHARACTERS:
			var at := board_point(D.CHAR_POS[c])
			if st.chars[c]["owner"] >= 0:
				var who: Dictionary = st.players[st.chars[c]["owner"]]
				_disc(at + Vector3(0.6, 0, 0.6), UI.pcolor(who["color"]), 0.25, 0.08)
				continue
			if eng.char_bids.has(c):
				var b: Array = eng.char_bids[c]
				_pawn(at + Vector3(0.7, 0.02, 0.3), UI.pcolor(st.players[b[0]]["color"]))
				_label(str(b[1] * 100), at + Vector3(0.7, 0.9, 0.9), 72)
			if c == "banchiere" and st.banker_money > 0:
				_label("%d" % st.banker_money, at + Vector3(-0.2, 0.15, 1.1), 64, UI.GOLD)
	# solitario: carta dell'Automa e casate fantasma
	if st.is_solo():
		if st.solo.get("card", 0) > 0:
			_quad("res://assets/cards/automa%02d.jpg" % st.solo["card"], 2.6, 3.6, Vector3(BW / 2.0 + 9.0, 0.01, -1.0))
		var ds: Array = st.solo["dummies"]
		for d in ds.size():
			var col: Array = ds[d]
			var x2 := -BW / 2.0 - 10.6 - d * 1.5
			_label("Casata %d" % (d + 1), Vector3(x2, 0.05, -BH / 2.0 + 0.5), 48)
			for j in col.size():
				var e: Dictionary = col[j]
				var path: String = ("res://assets/cards/prof%02d.jpg" % e["c"]) if e["up"] else "res://assets/cards/dorso_professioni.jpg"
				_quad(path, 1.2, 1.67, Vector3(x2, 0.01 + j * 0.01, -BH / 2.0 + 1.6 + j * 0.65))
