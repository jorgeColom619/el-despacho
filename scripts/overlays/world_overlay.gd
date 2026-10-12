extends "res://scripts/ui/overlay.gd"
## Mapa diplomático mundial: relaciones, tratados y acciones exteriores.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const W := preload("res://scripts/data/world_data.gd")

const MAP_POS := Vector2(50, 150)
const MAP_SIZE := Vector2(1200, 675)
const REF := Vector2(1600, 900)

var img: Image
var pal_img: Image
var pal_tex: ImageTexture
var mat: ShaderMaterial
var layer: Control
var panel: VBoxContainer
var selected := ""
var hover_id := 0
var id_to_c := {}
var centroids := {}
var _t := 0.0


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.95)
	var head := title_bar("Relaciones internacionales", "Ministerio de Asuntos Exteriores", "prestigio")
	head.position = Vector2(60, 60)
	root.add_child(head)
	var tex: Texture2D = load("res://art/maps/world_ids.png")
	img = tex.get_image()
	if img.is_compressed():
		img.decompress()
	pal_img = Image.create(16, 1, false, Image.FORMAT_RGBA8)
	pal_tex = ImageTexture.create_from_image(pal_img)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/world.gdshader")
	mat.set_shader_parameter("ids", tex)
	mat.set_shader_parameter("pal", pal_tex)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = MAP_POS
	tr.size = MAP_SIZE
	tr.material = mat
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	tr.gui_input.connect(_map_input)
	root.add_child(tr)
	var fr := Panel.new()
	fr.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 4, Color(UI.GOLD, 0.45), 1))
	fr.position = MAP_POS - Vector2(2, 2)
	fr.size = MAP_SIZE + Vector2(4, 4)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fr)
	for c in W.COUNTRIES.keys():
		id_to_c[int(W.COUNTRIES[c]["map"])] = c
	id_to_c[1] = "valdoria"
	var info: Dictionary = DB.world_map_info.get("countries", {})
	for k in info.keys():
		centroids[int(k)] = Vector2(info[k]["x"], info[k]["y"]) / REF * MAP_SIZE
	layer = Control.new()
	layer.position = MAP_POS
	layer.size = MAP_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_layer)
	root.add_child(layer)
	var legend := UI.lbl("Verde: aliados · Gris: neutrales · Rojo: hostiles.  Haga clic en un país.", UI.f_sans, 16, UI.DIM)
	legend.position = MAP_POS + Vector2(0, MAP_SIZE.y + 12)
	root.add_child(legend)
	var close_b := close_button("Volver al despacho")
	close_b.position = Vector2(1640, 1000)
	root.add_child(close_b)
	var pp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.5), 22)
	pp.position = Vector2(1280, 150)
	pp.custom_minimum_size = Vector2(590, 830)
	root.add_child(pp)
	panel = UI.vbox(12)
	pp.add_child(panel)
	_select("norland")
	_update_palette()


func on_escape() -> void:
	close()


func _rel_color(rel: float) -> Color:
	if rel >= 0.0:
		return Color(0.42, 0.45, 0.48).lerp(Color(0.25, 0.62, 0.38), clampf(rel / 70.0, 0.0, 1.0))
	return Color(0.42, 0.45, 0.48).lerp(Color(0.72, 0.22, 0.18), clampf(-rel / 70.0, 0.0, 1.0))


func _update_palette() -> void:
	for i in 16:
		var col := Color(0.28, 0.3, 0.33)
		if id_to_c.has(i):
			var c: String = id_to_c[i]
			if c == "valdoria":
				col = Color(0.85, 0.65, 0.25)
			else:
				col = _rel_color(GS.countries[c]["rel"])
		var hv := 0.0
		if i == hover_id:
			hv = 0.5
		if id_to_c.get(i, "") == selected:
			hv = 0.8
		col.a = hv
		pal_img.set_pixel(i, 0, col)
	pal_tex.update(pal_img)


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var p: Vector2 = event.position / MAP_SIZE * REF
		var id := 0
		if p.x >= 0 and p.y >= 0 and p.x < REF.x and p.y < REF.y:
			id = int(round(img.get_pixel(int(p.x), int(p.y)).r * 255.0 / 16.0))
		if id != hover_id:
			hover_id = id
			_update_palette()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and id_to_c.has(id) and id_to_c[id] != "valdoria":
			Sfx.play("click", -2.0)
			_select(id_to_c[id])


func _process(delta: float) -> void:
	_t += delta
	layer.queue_redraw()


func _draw_layer() -> void:
	var home: Vector2 = centroids.get(1, Vector2.ZERO)
	for t in GS.treaties:
		var c: String = t["c"]
		var cid := int(W.COUNTRIES[c]["map"])
		if not centroids.has(cid):
			continue
		var to: Vector2 = centroids[cid]
		var n := 24
		for i in n:
			if (i + int(_t * 8.0)) % 3 == 0:
				continue
			var a := home.lerp(to, float(i) / n)
			var b := home.lerp(to, float(i + 1) / n)
			var arc := Vector2(0, -sin(PI * (float(i) + 0.5) / n) * 40.0)
			layer.draw_line(a + Vector2(0, -sin(PI * float(i) / n) * 40.0), b + Vector2(0, -sin(PI * float(i + 1) / n) * 40.0), Color(UI.GOLD_L, 0.8), 2.0, true)
	for id in centroids.keys():
		if not id_to_c.has(id):
			continue
		var c2: String = id_to_c[id]
		var p: Vector2 = centroids[id]
		var nm: String = "VALDORIA" if c2 == "valdoria" else W.COUNTRIES[c2]["name"].to_upper()
		layer.draw_string(UI.f_sans_b, p + Vector2(-100, 0), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(1, 1, 1, 0.9))
		if c2 != "valdoria":
			var rel: float = GS.countries[c2]["rel"]
			layer.draw_string(UI.f_cond_b, p + Vector2(-100, 20), UI.signed(rel, 0), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, _rel_color(rel).lightened(0.4))
		else:
			layer.draw_circle(p + Vector2(0, 10), 5 + sin(_t * 3.0) * 1.5, UI.GOLD_L)


func _select(c: String) -> void:
	selected = c
	_update_palette()
	for ch in panel.get_children():
		ch.queue_free()
	var cd: Dictionary = W.COUNTRIES[c]
	var top := UI.hbox(16)
	var fl := Control.new()
	fl.custom_minimum_size = Vector2(150, 96)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.draw.connect(func():
		Flags.draw_flag(fl, c, Rect2(0, 0, 150, 96))
		fl.draw_rect(Rect2(0, 0, 150, 96), Color(1, 1, 1, 0.3), false, 1.0))
	top.add_child(fl)
	var tv := UI.vbox(2)
	tv.add_child(UI.lbl(cd["full"], UI.f_serif_b, 26, UI.CREAM))
	tv.add_child(UI.lbl("%s %s" % [cd["title"], cd["leader"]], UI.f_sans_m, 17, UI.GOLD))
	var pers: Dictionary = W.PERSONALITIES[GS.country_pers(c)]
	tv.add_child(UI.lbl("Carácter: %s · Poder: %d" % [pers["name"], int(cd["power"])], UI.f_sans, 15, UI.DIM))
	top.add_child(tv)
	panel.add_child(top)
	var d := UI.lbl(cd["desc"], UI.f_sans, 16, UI.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(540, 0)
	panel.add_child(d)
	var rel: float = GS.countries[c]["rel"]
	var rh := UI.hbox(10)
	rh.add_child(UI.lbl("Relación", UI.f_sans_b, 16, UI.DIM))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(360, 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 4, 360, 12), Color(1, 1, 1, 0.08))
		var mid := 180.0
		var w2 := rel / 100.0 * 180.0
		bar.draw_rect(Rect2(mid + minf(0.0, w2), 4, absf(w2), 12), _rel_color(rel).lightened(0.2))
		bar.draw_line(Vector2(mid, 0), Vector2(mid, 20), Color(1, 1, 1, 0.5), 1.0))
	rh.add_child(bar)
	rh.add_child(UI.lbl(UI.signed(rel, 0), UI.f_cond_b, 22, _rel_color(rel).lightened(0.4)))
	panel.add_child(rh)
	var tl := []
	for t in GS.treaties:
		if t["c"] == c:
			tl.append({"comercio": "Tratado comercial", "defensa": "Acuerdo de defensa", "energia": "Contrato energético", "inversion": "Acuerdo de inversión"}.get(t["type"], t["type"]))
	if tl.size() > 0:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		for tt in tl:
			flow.add_child(Widgets.chip("acuerdo", tt, UI.GOLD_L, 14))
		panel.add_child(flow)
	panel.add_child(Widgets.section("Negociar por teléfono"))
	var topics: Array = W.TOPICS.get(c, [])
	for t2 in topics:
		var cdn: int = int(GS.countries[c]["cd"].get(t2["id"], 0)) - GS.day
		var b := UI.btn("  " + t2["name"] + ("" if cdn <= 0 else "  (en %d días)" % cdn), "normal", 17)
		b.icon = UI.icon("telefono", 32)
		b.add_theme_constant_override("icon_max_width", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = cdn > 0
		var tid: String = t2["id"]
		b.pressed.connect(func():
			close()
			if main != null:
				main.call_deferred("open_overlay", "nego", {"who": c, "topic": tid}))
		panel.add_child(b)
	panel.add_child(Widgets.section("Acciones diplomáticas"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(grid)
	for a in [["visita", "Visita de Estado", "−80 M€ · −5 CP · Relación ▲"], ["ayuda", "Ayuda al desarrollo", "−600 M€ · Relación ▲▲"], ["sanciones", "Sanciones económicas", "Relación ▼▼▼ · Economía ▼"], ["embajador", "Expulsar al embajador", "Relación ▼▼ · Firmeza"]]:
		var ad: String = a[0]
		var cdl: int = int(GS.countries[c]["cd"].get(ad, 0)) - GS.day
		var v := UI.vbox(2)
		v.custom_minimum_size = Vector2(250, 60)
		v.add_child(UI.lbl(a[1], UI.f_sans_b, 16, UI.TEXT if cdl <= 0 else UI.DIM))
		v.add_child(UI.lbl(a[2] if cdl <= 0 else "Disponible en %d días" % cdl, UI.f_sans, 13, UI.DIM))
		var card := Widgets.click_card(v, func(): _action(c, ad), 10)
		if cdl > 0:
			card.set_meta("enabled", false)
			card.modulate.a = 0.5
		grid.add_child(card)


func _action(c: String, a: String) -> void:
	var nm: String = W.COUNTRIES[c]["name"]
	var fx := {}
	match a:
		"visita":
			if GS.pc < 5:
				GS.toast.emit("No tiene capital político suficiente", "warn", "capital")
				return
			fx = {"money": -80, "pc": -5, "rel": {c: 8}, "prestigio": 1}
			GS.push_news("El presidente realiza una visita de Estado a %s" % nm, 2)
		"ayuda":
			fx = {"money": -600, "rel": {c: 11}, "prestigio": 1}
			GS.push_news("Valdoria aprueba un paquete de ayuda para %s" % nm, 1)
		"sanciones":
			var p: String = GS.country_pers(c)
			fx = {"rel": {c: -25}, "economia": -1.5, "prestigio": 2 if p in ["agresivo", "volatil"] else -1}
			if c == "kharovia":
				fx["rel"]["union"] = 5
				fx["rel"]["norland"] = 4
			GS.push_news("Valdoria impone sanciones económicas a %s" % nm, 3)
		"embajador":
			fx = {"rel": {c: -15}, "militares": 1, "clase_media": 1}
			GS.push_news("Valdoria expulsa al embajador de %s" % nm, 2)
	GS.countries[c]["cd"][a] = GS.day + (120 if a == "visita" else 180)
	GS.apply_fx(fx, "Diplomacia")
	GS.remember(a, {"who": c})
	GS.log_history("Diplomacia: " + nm, {"visita": "Visita de Estado", "ayuda": "Ayuda al desarrollo", "sanciones": "Sanciones", "embajador": "Expulsión del embajador"}[a])
	Sfx.play("stamp", -6.0)
	_select(c)
