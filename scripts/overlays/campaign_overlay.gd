extends "res://scripts/ui/overlay.gd"
## Campaña electoral por regiones: reparte tus actos de campaña por el mapa.

const Widgets := preload("res://scripts/ui/widgets.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const W := preload("res://scripts/data/world_data.gd")

const MAP_POS := Vector2(60, 210)
const MAP_SIZE := Vector2(1000, 760)

var map: Control
var layer: Control
var panel: VBoxContainer
var sel := 1
var acts_lbl: Label
var _t := 0.0


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.95)
	var head := title_bar("Campaña electoral", "Elecciones en %d días" % maxi(0, GS.term_days - GS.day), "votar")
	head.position = Vector2(60, 112)
	root.add_child(head)
	map = MapView.new()
	map.position = MAP_POS
	map.size = MAP_SIZE
	root.add_child(map)
	map.set_mode(1)
	map.gui_input.connect(_map_click)
	layer = Control.new()
	layer.position = MAP_POS
	layer.size = MAP_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_layer)
	root.add_child(layer)
	var pp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.5), 22)
	pp.position = Vector2(1100, 210)
	pp.custom_minimum_size = Vector2(760, 760)
	root.add_child(pp)
	panel = UI.vbox(12)
	pp.add_child(panel)
	var cb := close_button("Volver al despacho")
	cb.position = Vector2(1100, 990)
	root.add_child(cb)
	if data.get("intro", false):
		GS.toast.emit("¡Arranca la campaña! Tiene %d actos de campaña. Recibirá uno más cada 6 días." % GS.campaign_acts, "info", "votar")
	_color_regions()
	_select(_weakest())


func _weakest() -> int:
	var best := 1
	var bv := 999.0
	for i in range(1, 9):
		var v := GS.region_estimate(i) / maxf(0.01, float(W.REGIONS[i]["pop"])) * 0.1
		if v < bv:
			bv = v
			best = i
	return best


func _color_regions() -> void:
	var own := Color(W.PARTIES[GS.pres["party"]]["color"])
	var base := Color(0.16, 0.18, 0.24)
	for i in range(1, 9):
		var e := GS.region_estimate(i)
		var t := clampf((e - 26.0) / 22.0, 0.0, 1.0)
		map.set_region(i, base.lerp(own, 0.25 + t * 0.75))


func _map_click(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var id: int = map.id_at(e.position)
		if id >= 1 and id <= 8:
			Sfx.play("click", -2.0)
			_select(id)


func _select(id: int) -> void:
	sel = id
	for c in panel.get_children():
		c.queue_free()
	var r: Dictionary = W.REGIONS[id]
	var ah := UI.hbox(14)
	ah.add_child(UI.icon_rect("microfono", 32, UI.GOLD_L))
	acts_lbl = UI.lbl("Actos de campaña disponibles: %d" % GS.campaign_acts, UI.f_sans_b, 22, UI.GOLD_L if GS.campaign_acts > 0 else UI.RED)
	ah.add_child(acts_lbl)
	panel.add_child(ah)
	panel.add_child(UI.lbl("Recibe un acto nuevo cada 6 días (máximo 5). Actos realizados: %d" % GS.acts_done, UI.f_sans, 15, UI.DIM))
	panel.add_child(Widgets.section("Región seleccionada"))
	panel.add_child(UI.lbl(r["name"], UI.f_serif_b, 38, UI.CREAM))
	panel.add_child(UI.lbl("%s · %d%% de la población" % [r["sub"], int(float(r["pop"]) * 100)], UI.f_sans_m, 17, UI.GOLD))
	var est := GS.region_estimate(id)
	var eh := UI.hbox(14)
	eh.add_child(UI.lbl("Intención de voto:", UI.f_sans_m, 19, UI.TEXT))
	eh.add_child(UI.lbl(UI.pct(est, 1), UI.f_cond_b, 30, UI.color_for(est * 1.8)))
	var bonus := GS.region_boost(id)
	if bonus > 0.0:
		eh.add_child(UI.lbl("(campaña +%s)" % UI.num(bonus, 1), UI.f_sans_m, 16, UI.GREEN))
	panel.add_child(eh)
	var dom := ""
	var dv := 0.0
	for f in r["demo"].keys():
		if float(r["demo"][f]) > dv:
			dv = float(r["demo"][f])
			dom = f
	panel.add_child(UI.lbl("Grupo dominante: %s (%d%%) · satisfacción %d" % [W.FACTION_INFO[dom]["name"], int(dv * 100), int(GS.fac[dom])], UI.f_sans, 16, UI.DIM))
	panel.add_child(Widgets.section("Acciones"))
	var acts := [
		["mitin", "Mitin", "microfono", "1 acto · minijuego de discurso. Mucho efecto si lo hace bien.", 1, 0],
		["visita", "Visita y baño de masas", "aprobacion", "1 acto · +2,5 en la región.", 1, 0],
		["anuncio", "Anuncio de inversión", "dinero", "1 acto · −800 M€ · +4 en la región.", 1, 800],
		["spot", "Spot en la TV nacional", "tv", "2 actos · −1.500 M€ · +1,3 en todas las regiones.", 2, 1500],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for a in acts:
		var v := UI.vbox(4)
		v.custom_minimum_size = Vector2(340, 92)
		var h := UI.hbox(8)
		h.add_child(UI.icon_rect(a[2], 24, UI.GOLD_L))
		h.add_child(UI.lbl(a[1], UI.f_sans_b, 18, UI.TEXT))
		v.add_child(h)
		var d := UI.lbl(a[3], UI.f_sans, 14, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(330, 0)
		v.add_child(d)
		var aid: String = a[0]
		var card := Widgets.click_card(v, func(): _do(aid), 12)
		if GS.campaign_acts < int(a[4]):
			card.set_meta("enabled", false)
			card.modulate.a = 0.4
		grid.add_child(card)
	panel.add_child(UI.spacer(0, 6))
	var nat := 0.0
	for i in range(1, 9):
		nat += GS.region_estimate(i) * float(W.REGIONS[i]["pop"])
	panel.add_child(UI.lbl("Estimación nacional de su partido: %s · Necesita 176 escaños con sus socios." % UI.pct(nat, 1), UI.f_sans_m, 16, UI.TEXT))
	var tip := UI.lbl("Consejo: las regiones más pobladas reparten más escaños. Un mitin bien hecho es el acto más rentable.", UI.f_sans, 15, UI.DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(700, 0)
	panel.add_child(tip)
	layer.queue_redraw()


func _do(aid: String) -> void:
	var r: Dictionary = W.REGIONS[sel]
	match aid:
		"mitin":
			if not GS.use_campaign_act(1):
				return
			close()
			if main != null:
				main.call_deferred("open_overlay", "speech", {"occasion": "campana", "region": sel})
			return
		"visita":
			if not GS.use_campaign_act(1):
				return
			GS.add_region_boost(sel, 2.5)
			GS.push_news("Baño de masas del presidente en %s" % r["name"], 1)
			Sfx.play("cheer", -6.0)
		"anuncio":
			if not GS.use_campaign_act(1):
				return
			GS.apply_fx({"money": -800}, "Campaña")
			GS.add_region_boost(sel, 4.0)
			GS.push_news("El presidente promete una gran inversión en %s" % r["name"], 2)
			Sfx.play("coin", -2.0)
		"spot":
			if not GS.use_campaign_act(2):
				return
			GS.apply_fx({"money": -1500}, "Campaña")
			for i in range(1, 9):
				GS.add_region_boost(i, 1.3)
			GS.push_news("Arranca la campaña de televisión del partido del Gobierno", 1)
			Sfx.play("news", -6.0)
	GS.toast.emit("Acto de campaña realizado en %s" % r["name"] if aid != "spot" else "Spot emitido en todo el país", "good", "votar")
	_color_regions()
	_select(sel)


func _process(delta: float) -> void:
	_t += delta
	layer.queue_redraw()


func _draw_layer() -> void:
	for id in range(1, 9):
		var c: Vector2 = map.centroids.get(id, Vector2.ZERO)
		var est := GS.region_estimate(id)
		layer.draw_string(UI.f_sans_b, c + Vector2(-90, -10), W.REGIONS[id]["name"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color.WHITE)
		layer.draw_string(UI.f_cond_b, c + Vector2(-90, 16), UI.pct(est, 0), HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color.WHITE)
		var b := GS.region_boost(id)
		if b > 0.0:
			layer.draw_string(UI.f_sans_b, c + Vector2(-90, 36), "+" + UI.num(b, 1), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(0.6, 1.0, 0.6))
		if id == sel:
			layer.draw_arc(c + Vector2(0, 6), 46 + sin(_t * 4.0) * 3.0, 0, TAU, 48, UI.GOLD_L, 3.0, true)


func on_escape() -> void:
	close()
