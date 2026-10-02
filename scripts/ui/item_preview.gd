extends Control
## Vista previa animada de un objeto de la tienda.

const S := preload("res://scripts/data/shop_data.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")

const BASE_LOOK := {"g": "m", "skin": 1, "hair": "side", "hc": 1, "glasses": 0, "suit": "1b2436", "shirt": "f4f6fa", "tie": "8e2a22", "age": 1, "eyes": "3b2a20"}

var item_id := ""
var _t := 0.0
var _slot := ""
var _data := {}


func setup(id: String) -> void:
	item_id = id
	var it: Dictionary = S.ITEMS[id]
	_slot = it["slot"]
	_data = it["data"]


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match _slot:
		"despacho":
			_tex(OfficeArt.tex("room", 0.3, {"theme": _data["theme"]}), true)
		"madera":
			var tr := _tex(OfficeArt.tex("desk", 0.35, {"wood": _data["wood"]}), true)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		"telefono":
			_tex(OfficeArt.tex("redphone", 1.0, {"phone": _data["phone"]}), false)
		"lampara":
			_tex(OfficeArt.tex("lamp", 1.0, {"lamp": _data["lamp"]}), false)
		"globo":
			var g := ColorRect.new()
			var sz := minf(size.x, size.y) * 0.8
			g.size = Vector2(sz, sz)
			g.position = (size - g.size) * 0.5
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/globe.gdshader")
			m.set_shader_parameter("map_tex", load("res://art/maps/world_ids.png"))
			m.set_shader_parameter("style", 1 if _data["globe"] == "nocturno" else 0)
			g.material = m
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(g)
			set_meta("globe", m)
		"traje", "corbata", "accesorio":
			var look := Perfil.apply_outfit(BASE_LOOK)
			if _data.has("suit"):
				look["suit"] = _data["suit"]
			if _data.has("tie"):
				look["tie"] = _data["tie"]
			if _data.has("acc"):
				look["acc"] = _data["acc"]
			var p := Portrait.new()
			var h := size.y * 1.25
			p.size = Vector2(h * 400.0 / 480.0, h)
			p.position = Vector2((size.x - p.size.x) * 0.5, size.y * 0.02)
			p.track_mouse = false
			add_child(p)
			p.setup(look, size.y > 200)
			p.mood = 0.4


func _tex(t: Texture2D, cover: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not cover:
		tr.size = size * 0.8
		tr.position = size * 0.1
	add_child(tr)
	return tr


func _process(delta: float) -> void:
	_t += delta
	if has_meta("globe"):
		(get_meta("globe") as ShaderMaterial).set_shader_parameter("rot", _t * 0.4)
	if _slot in ["bandera", "tinta", "mascota"]:
		queue_redraw()


func _draw() -> void:
	var bg := Color(0.06, 0.09, 0.15)
	if _slot in ["bandera", "tinta", "mascota", "globo", "telefono", "lampara", "traje", "corbata", "accesorio"]:
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		for i in 6:
			draw_circle(size * 0.5, size.x * (0.6 - i * 0.08), Color(1, 1, 1, 0.012))
	match _slot:
		"bandera":
			var fw := size.x * 0.72
			var fh := fw * 0.62
			var r := Rect2((size - Vector2(fw, fh)) * 0.5 + Vector2(0, sin(_t * 1.5) * 3.0), Vector2(fw, fh))
			draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.4))
			Flags.draw_valdoria(self, r, _data["style"])
			draw_rect(r, Color(1, 1, 1, 0.25), false, 1.5)
		"tinta":
			var ok := Color(_data.get("ok", "2e8b57"))
			var no := Color(_data.get("no", "b3261e"))
			var wax: bool = _data.get("wax", false)
			draw_rect(Rect2(size * 0.08, size * 0.84), Color(0.94, 0.9, 0.82))
			_impression(size * Vector2(0.32, 0.45), "APROBADO", ok, wax, -0.15)
			_impression(size * Vector2(0.68, 0.58), "VETADO", no, wax, 0.12)
		"mascota":
			var kind: String = _data["pet"]
			var rs := PetArt.ref_size(kind)
			var sc := minf(size.x * 0.75 / rs.x, size.y * 0.75 / rs.y)
			var off := (size - rs * sc) * 0.5 + Vector2(rs.x * sc * (0.25 if kind == "loro" else 0.0), 0)
			draw_set_transform(off, 0.0, Vector2(sc, sc))
			PetArt.draw(self, kind, _t, fmod(_t, 4.0) < 1.5, "")
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _impression(c: Vector2, label: String, col: Color, wax: bool, rot: float) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	if wax:
		var rr := size.y * 0.18
		draw_circle(Vector2.ZERO, rr, col)
		draw_arc(Vector2.ZERO, rr * 0.75, 0, TAU, 32, col.lightened(0.3), 2.0, true)
		draw_string(UI.f_cond_b, Vector2(-rr, 5), label.left(3), HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0, int(rr * 0.5), col.lightened(0.5))
	else:
		var fs := int(size.y * 0.12)
		var tw := UI.f_cond_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(-tw / 2.0 - 8, -fs * 0.8, tw + 16, fs * 1.4)
		draw_rect(r, col, false, 3.0)
		draw_string(UI.f_cond_b, Vector2(-tw / 2.0, fs * 0.38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
