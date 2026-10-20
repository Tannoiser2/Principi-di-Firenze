class_name UI
extends RefCounted
## Stile dell'interfaccia: pergamena, inchiostro, oro e rosso fiorentino.
## Caratteri: Cinzel (titoli, come le epigrafi rinascimentali), EB Garamond (testo),
## Caveat Brush (numeri a pennello, come sulle monete del gioco).

const D = preload("res://scripts/data/pf_data.gd")

const INK := Color("#3a2614")
const INK2 := Color("#6b4a2b")
const PAPER := Color("#efe3c4")
const GOLD := Color("#c9a24a")
const GOLD_D := Color("#8a6a24")
const RED := Color("#8e1f1f")
const RED_D := Color("#5e1212")
const LAPIS := Color("#24467a")
const WALNUT := Color("#2a1c12")
const SAND := Color("#e9d7a8")
const GREEN := Color("#3d6b2c")

static var font_title: Font
static var font_deco: Font
static var font_body: Font
static var font_italic: Font
static var font_bold: Font
static var font_brush: Font
static var _tex := {}


static func init_fonts() -> void:
	if font_body != null:
		return
	font_title = _var("res://assets/fonts/Cinzel.ttf", 600)
	font_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	font_body = _var("res://assets/fonts/EBGaramond.ttf", 450)
	font_bold = _var("res://assets/fonts/EBGaramond.ttf", 650)
	font_italic = _var("res://assets/fonts/EBGaramond-Italic.ttf", 450)
	font_brush = load("res://assets/fonts/CaveatBrush-Regular.ttf")


static func _var(path: String, w: int) -> Font:
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return fv


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func prof_tex(c: int) -> Texture2D:
	return tex("res://assets/cards/prof%02d.jpg" % c)


static func bonus_tex(b: int) -> Texture2D:
	return tex("res://assets/cards/bonus%02d.jpg" % b)


static func prest_tex(p: int) -> Texture2D:
	return tex("res://assets/cards/prest%02d.jpg" % p)


static func char_tex(c: String) -> Texture2D:
	return tex("res://assets/cards/pers_%s.jpg" % c)


static func tile_tex(id: String) -> Texture2D:
	return tex("res://assets/tiles/%s.png" % id)


static func free_tex(f: String) -> Texture2D:
	return tex("res://assets/tiles/liberta_%s.jpg" % f)


static func pcolor(color_id: String) -> Color:
	for c in D.COLORS:
		if c["id"] == color_id:
			return Color(c["hex"])
	return Color.GRAY


static func pink(color_id: String) -> Color:
	for c in D.COLORS:
		if c["id"] == color_id:
			return Color(c["ink"])
	return Color.WHITE


static func flat(bg: Color, border: Color, bw := 2, radius := 8, margin := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s


static func paper(dark := false, margin := 18.0) -> StyleBox:
	var t := tex("res://assets/ui/parchment_dark.png" if dark else "res://assets/ui/parchment.png")
	if t == null:
		return flat(PAPER, GOLD_D, 2, 6, margin)
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = 40
	s.texture_margin_right = 40
	s.texture_margin_top = 40
	s.texture_margin_bottom = 40
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


static func label(text: String, size := 22, col := INK, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := 40, col := INK) -> Label:
	init_fonts()
	return label(text, size, col, font_title)


static func number(text: String, size := 30, col := INK) -> Label:
	init_fonts()
	return label(text, size, col, font_brush)


static func wrap(text: String, size: int, width: float, col := INK, font: Font = null) -> Label:
	var l := label(text, size, col, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func rich(size := 21, width := 400.0) -> RichTextLabel:
	init_fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = width
	r.add_theme_font_override("normal_font", font_body)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_override("italics_font", font_italic)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", INK)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Gettone rotondo con un numero (giullari, costruttori...)
static func counter(t: Texture2D, n: int, sz := 34.0, col := INK) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_rect(t, Vector2(sz, sz)))
	h.add_child(number(str(n), int(sz * 0.85), col))
	return h


static func button(text: String, w := 200.0, h := 52.0, size := 22) -> Button:
	init_fonts()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_override("font", font_title)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return plain(b)


static func _skin(b: Button, bg: Color, border: Color, fg: Color, hover: Color) -> Button:
	b.add_theme_stylebox_override("normal", flat(bg, border, 2, 7, 12))
	b.add_theme_stylebox_override("hover", flat(hover, GOLD, 2, 7, 12))
	b.add_theme_stylebox_override("pressed", flat(bg.darkened(0.2), GOLD, 2, 7, 12))
	b.add_theme_stylebox_override("disabled", flat(Color(bg, 0.45), Color(border, 0.4), 2, 7, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg.lightened(0.1))
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	return b


static func plain(b: Button) -> Button:
	return _skin(b, Color("#f3e7c9"), GOLD_D, INK, Color("#fbf1d8"))


static func primary(b: Button) -> Button:
	return _skin(b, RED, GOLD, Color("#fff4dc"), Color("#a52a2a"))


static func lapis(b: Button) -> Button:
	return _skin(b, LAPIS, GOLD, Color("#f2ecdc"), Color("#2f5a98"))


static func dark(b: Button) -> Button:
	return _skin(b, Color("#3b2a1b"), GOLD_D, SAND, Color("#4e3824"))


static func selected(b: Button) -> Button:
	return _skin(b, Color("#d9b763"), RED_D, INK, Color("#e6c67a"))


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", paper(false, 14))
	t.set_stylebox("normal", "LineEdit", flat(Color("#fbf3dd"), GOLD_D, 2, 6, 10))
	t.set_stylebox("focus", "LineEdit", flat(Color("#fffaea"), GOLD, 2, 6, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK2, 0.6))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("panel", "TooltipPanel", flat(Color("#fbf1d8"), GOLD_D, 1, 4, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", font_body)
	t.set_font_size("font_size", "TooltipLabel", 19)
	var sb := flat(Color(0.3, 0.2, 0.1, 0.25), Color(0, 0, 0, 0), 0, 4, 0)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(GOLD_D, 0.8), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(GOLD_D, 0.5)
	hs.content_margin_top = 4
	hs.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", hs)
	return t


## Riquadro decorato: cornice dorata su pergamena
static func frame(margin := 16.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper(false, margin))
	return p


## Fiorini in forma leggibile: 3500 -> "3.500"
static func fl(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
