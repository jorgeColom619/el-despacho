extends "res://scripts/ui/overlay.gd"
## Gabinete de Crisis: despliegue de unidades en tiempo real sobre el mapa de Valdoria.

const Widgets := preload("res://scripts/ui/widgets.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const W := preload("res://scripts/data/world_data.gd")

const DURATION := 60.0
const MAP_POS := Vector2(60, 250)
const MAP_SIZE := Vector2(1000, 760)

var item: Dictionary
var ev: Dictionary
var cr: Dictionary
var map: Control
var layer: Control
var regions := {}
var units := []
var tokens := []
var pings := []
var running := false
var finished := false
var time_left := DURATION
var damage := 0.0
var cost := 0.0
var unit_fx := {}
var spawn_t := 0.0
var calm_t := 0.0
var elapsed := 0.0
var drag_unit := -1
var drag_token = null
var roster: VBoxContainer
var dmg_lbl: Label
var conf_bar: Control
var timer_bar: Control
var right: VBoxContainer
var start_panel: Control
var special_used := {}
var special_cards := {}
var confidence_bonus := 0.0
var _t := 0.0
var fatal_t := 0.0


func build() -> void:
	dim.color = Color(0.01, 0.02, 0.035, 0.96)
	item = data.get("item", {})
	ev = item.get("ev", {})
	cr = W.CRISES[ev.get("crisis", "disturbios")]
	Sfx.music("music_tension", 1.0)
	# fondo técnico
	var grid := Control.new()
	UI.full(grid)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(func():
		for x in range(0, 1920, 48):
			grid.draw_line(Vector2(x, 0), Vector2(x, 1080), Color(0.2, 0.5, 0.7, 0.05), 1.0)
		for y in range(0, 1080, 48):
			grid.draw_line(Vector2(0, y), Vector2(1920, y), Color(0.2, 0.5, 0.7, 0.05), 1.0))
	root.add_child(grid)
	# cabecera
	var head := UI.vbox(2)
	head.position = Vector2(60, 118)
	root.add_child(head)
	var alert := UI.lbl("●  ALERTA · GABINETE DE CRISIS", UI.f_sans_b, 16, UI.RED)
	head.add_child(alert)
	var tw := alert.create_tween().set_loops()
	tw.tween_property(alert, "modulate:a", 0.35, 0.6)
	tw.tween_property(alert, "modulate:a", 1.0, 0.6)
	var hh := UI.hbox(14)
	hh.add_child(UI.icon_rect(cr["icon"], 40, UI.RED.lightened(0.2)))
	hh.add_child(UI.lbl(cr["title"], UI.f_serif_b, 44, UI.CREAM))
	head.add_child(hh)
	var dl := UI.lbl(cr["desc"], UI.f_sans, 18, UI.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(1000, 0)
	head.add_child(dl)
	# mapa
	map = MapView.new()
	map.position = MAP_POS
	map.size = MAP_SIZE
	root.add_child(map)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 4, Color(0.4, 0.8, 1.0, 0.35), 1))
	frame.position = MAP_POS - Vector2(2, 2)
	frame.size = MAP_SIZE + Vector2(4, 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	layer = Control.new()
	layer.position = MAP_POS
	layer.size = MAP_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_layer)
	root.add_child(layer)
	# panel derecho
	right = UI.vbox(12)
	right.position = Vector2(1110, 250)
	right.size = Vector2(760, 760)
	root.add_child(right)
	timer_bar = TimerBar.new()
	timer_bar.custom_minimum_size = Vector2(760, 12)
	right.add_child(UI.spacer(0, 14))
	right.add_child(timer_bar)
	var stats := UI.hbox(30)
	var dv := UI.vbox(0)
	dv.add_child(UI.lbl(String(cr["dmg"]).to_upper(), UI.f_sans_b, 13, UI.DIM))
	dmg_lbl = UI.lbl("0", UI.f_cond_b, 44, UI.RED.lightened(0.2))
	dv.add_child(dmg_lbl)
	stats.add_child(dv)
	var cv := UI.vbox(4)
	cv.add_child(UI.lbl("CONFIANZA EN LA GESTIÓN", UI.f_sans_b, 13, UI.DIM))
	conf_bar = Control.new()
	conf_bar.custom_minimum_size = Vector2(330, 44)
	conf_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conf_bar.draw.connect(func():
		var s := _score()
		conf_bar.draw_rect(Rect2(0, 10, 330, 16), Color(1, 1, 1, 0.08))
		conf_bar.draw_rect(Rect2(0, 10, 330 * s, 16), UI.color_for(s * 100.0))
		conf_bar.draw_string(UI.f_cond_b, Vector2(0, 44), "%d%%" % int(s * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.TEXT))
	cv.add_child(conf_bar)
	stats.add_child(cv)
	right.add_child(stats)
	right.add_child(Widgets.section("Unidades disponibles · arrástrelas al mapa"))
	roster = UI.vbox(8)
	right.add_child(roster)
	for u in cr["units"]:
		var ud: Dictionary = u.duplicate(true)
		ud["left"] = int(u["n"])
		units.append(ud)
	_build_roster()
	right.add_child(Widgets.section("Medidas extraordinarias"))
	var sp := UI.hbox(10)
	right.add_child(sp)
	sp.add_child(_special("emergencia", "Estado de alarma", "alerta", "+1 unidad de cada tipo · Estabilidad ▼"))
	sp.add_child(_special("ayuda", "Ayuda de la Unión", "prestigio", "Refuerzos si la relación lo permite"))
	sp.add_child(_special("comparecer", "Comparecer en TV", "microfono", "Tranquiliza a la población"))
	# regiones
	for i in range(1, 9):
		regions[i] = {"i": 0.0, "hidden": cr.get("hidden", false), "revealed": false, "collapsed": false, "units": 0}
	var hot: Array = cr["hot"].duplicate()
	hot.shuffle()
	for k in mini(int(cr["start"]), hot.size()):
		regions[int(hot[k])]["i"] = randf_range(25, 45)
	# briefing inicial
	_build_start()
	_update_palette()
	if data.get("autostart", false):
		start_panel.queue_free()
		start_panel = null
		running = true
		timer_bar.start(DURATION, "TIEMPO DE OPERACIÓN")
		for k in regions.keys():
			if regions[k]["i"] > 0.0:
				_deploy(0, k)
				_deploy(1, k)


func _build_start() -> void:
	start_panel = UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.RED, 0.7), 30)
	start_panel.position = Vector2(560, 380)
	start_panel.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(16)
	start_panel.add_child(v)
	v.add_child(UI.lbl("SITUACIÓN DE EMERGENCIA", UI.f_sans_b, 15, UI.RED))
	v.add_child(UI.lbl("Asuma el mando de la operación", UI.f_serif_b, 36, UI.CREAM))
	var t := UI.lbl("Arrastre las unidades del panel derecho a las regiones afectadas (en rojo). Cada unidad reduce la intensidad donde se despliega; algunas tienen efectos secundarios en la opinión pública. Puede redistribuir las unidades arrastrándolas de nuevo. Tiene %d segundos." % int(DURATION), UI.f_sans, 19, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(740, 0)
	v.add_child(t)
	var h := UI.hbox(16)
	var go := UI.btn("ASUMIR EL MANDO", "gold", 22)
	go.pressed.connect(func():
		start_panel.queue_free()
		start_panel = null
		running = true
		timer_bar.start(DURATION, "TIEMPO DE OPERACIÓN")
		Sfx.loop_start("siren", "siren", -18.0)
		Sfx.play("alert", -4.0))
	h.add_child(go)
	var del := UI.btn("Delegar en el ministro", "normal", 18)
	del.tooltip_text = "Resultado mediocre garantizado, sin riesgos ni esfuerzo."
	del.pressed.connect(func():
		start_panel.queue_free()
		start_panel = null
		_finish(0.42 + randf() * 0.1, true))
	h.add_child(del)
	v.add_child(h)
	root.add_child(start_panel)
	UI.pop_in(start_panel)


func _build_roster() -> void:
	for c in roster.get_children():
		c.queue_free()
	for i in units.size():
		var u: Dictionary = units[i]
		var h := UI.hbox(14)
		var ic := UI.icon_rect(u["icon"], 34, UI.GOLD_L if u["left"] > 0 else UI.DIM)
		h.add_child(ic)
		var nv := UI.vbox(0)
		nv.add_child(UI.lbl(u["name"], UI.f_sans_b, 19, UI.TEXT if u["left"] > 0 else UI.DIM))
		var extra := ""
		if u.get("reveal", false):
			extra = " · Revela amenazas"
		if u.get("protect", false):
			extra = " · Reduce víctimas"
		var fxs := ""
		for k in u["fx"].keys():
			fxs += "  %s %s" % [GS.label_of(k), "▲" if float(u["fx"][k]) > 0 else "▼"]
		nv.add_child(UI.lbl("Potencia %d · %s por despliegue%s%s" % [int(u["power"]), UI.money(u["cost"]) if u["cost"] > 0 else "sin coste", extra, fxs], UI.f_sans, 14, UI.DIM))
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nv)
		var cnt := UI.lbl("×%d" % u["left"], UI.f_cond_b, 30, UI.GOLD_L if u["left"] > 0 else UI.DIM)
		h.add_child(cnt)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(Color(0.07, 0.11, 0.17, 0.95), 8, Color(1, 1, 1, 0.12), 1, 0, 12))
		card.add_child(h)
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG if u["left"] > 0 else Control.CURSOR_FORBIDDEN
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and running and units[idx]["left"] > 0:
				drag_unit = idx
				Sfx.play("paper2", -8.0, 1.4))
		roster.add_child(card)


func _special(id: String, title: String, icon_name: String, desc: String) -> Control:
	var v := UI.vbox(4)
	v.custom_minimum_size = Vector2(230, 80)
	var h := UI.hbox(8)
	h.add_child(UI.icon_rect(icon_name, 22, UI.GOLD_L))
	h.add_child(UI.lbl(title, UI.f_sans_b, 16, UI.TEXT))
	v.add_child(h)
	var d := UI.lbl(desc, UI.f_sans, 13, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(220, 0)
	v.add_child(d)
	var card := Widgets.click_card(v, func():
		if not running or special_used.has(id):
			return
		special_used[id] = true
		special_cards[id].set_meta("enabled", false)
		special_cards[id].modulate.a = 0.4
		_use_special(id), 10)
	special_cards[id] = card
	return card


func _use_special(id: String) -> void:
	match id:
		"emergencia":
			for u in units:
				u["left"] += 1
			unit_fx["estabilidad"] = unit_fx.get("estabilidad", 0.0) - 3.0
			GS.toast.emit("Estado de alarma declarado: refuerzos en camino", "warn", "alerta")
		"ayuda":
			if GS.countries["union"]["rel"] > 10.0:
				units.append({"id": "ue", "name": "Ayuda de la Unión", "icon": "prestigio", "n": 2, "left": 2, "cost": 0, "power": 5.5, "fx": {}})
				unit_fx["prestigio"] = unit_fx.get("prestigio", 0.0) - 1.0
				GS.toast.emit("La Unión Continental envía refuerzos", "good", "prestigio")
			else:
				GS.toast.emit("La Unión declina ayudar: nuestras relaciones son demasiado frías", "bad", "prestigio")
		"comparecer":
			confidence_bonus += 0.06
			unit_fx["estabilidad"] = unit_fx.get("estabilidad", 0.0) + 1.0
			GS.toast.emit("Su comparecencia transmite calma a la población", "good", "microfono")
	_build_roster()
	Sfx.play("notify", -4.0)


# ------------------------------------------------------------------ simulación

func _process(delta: float) -> void:
	_t += delta
	if running and not finished:
		elapsed += delta
		time_left = timer_bar.left
		_simulate(delta)
		if time_left <= 0.0:
			_finish(_score(), false)
	for p in pings:
		p["t"] += delta
	pings = pings.filter(func(p): return p["t"] < 1.2)
	for tk in tokens:
		if tk["travel"] < 1.0:
			tk["travel"] = minf(1.0, tk["travel"] + delta * 1.4)
	_update_palette()
	layer.queue_redraw()
	conf_bar.queue_redraw()
	dmg_lbl.text = UI.num(damage, 0)


func _simulate(dt: float) -> void:
	var mult: float = [0.85, 1.0, 1.15][GS.difficulty]
	var power := {}
	var protect := {}
	var reveal := {}
	for tk in tokens:
		if tk["travel"] < 1.0:
			continue
		var r: int = tk["region"]
		var u: Dictionary = units[tk["unit"]]
		power[r] = power.get(r, 0.0) + float(u["power"])
		if u.get("protect", false):
			protect[r] = true
		if u.get("reveal", false):
			reveal[r] = true
			for n in map.adjacency.get(r, []):
				reveal[n] = true
	var active := 0
	for id in regions.keys():
		var rg: Dictionary = regions[id]
		if reveal.has(id) and rg["hidden"] and not rg["revealed"]:
			rg["revealed"] = true
			if rg["i"] > 1.0:
				pings.append({"id": id, "t": 0.0})
				Sfx.play("alert", -10.0, 1.3)
		if rg["i"] <= 0.0:
			continue
		active += 1
		var hot_n := 0
		for n in map.adjacency.get(id, []):
			if regions[n]["i"] > 50.0:
				hot_n += 1
		var growth := float(cr["growth"]) * mult * (1.0 + 0.2 * hot_n)
		var red: float = power.get(id, 0.0)
		rg["i"] = clampf(rg["i"] + (growth - red) * dt, 0.0, 100.0)
		if rg["i"] <= 0.0:
			pings.append({"id": id, "t": 0.0, "good": true})
			Sfx.play("success", -12.0, 1.2)
		var dmg_rate: float = rg["i"] / 10.0 * float(cr["dmg_k"]) * dt
		if protect.has(id):
			dmg_rate *= 0.45
		if rg["i"] >= 100.0:
			dmg_rate *= 1.8
			if not rg["collapsed"]:
				rg["collapsed"] = true
				Sfx.play("fail", -6.0)
				if rg["hidden"] and not rg["revealed"]:
					rg["revealed"] = true
					damage += float(cr["dmg_k"]) * 40.0
					GS.toast.emit("¡Atentado en %s!" % W.REGIONS[id]["name"], "bad", "alerta")
		else:
			rg["collapsed"] = false
		damage += dmg_rate
		if cr.get("spread", false) and rg["i"] > 65.0:
			for n in map.adjacency.get(id, []):
				if regions[n]["i"] <= 0.0 and randf() < dt * 0.12:
					regions[n]["i"] = 14.0
					pings.append({"id": n, "t": 0.0})
	spawn_t += dt
	if spawn_t > float(cr["spawn"]) and time_left > 8.0:
		spawn_t = 0.0
		var cands := []
		for h in cr["hot"]:
			if regions[int(h)]["i"] <= 1.0:
				cands.append(int(h))
		if cands.size() > 0:
			var nid: int = cands.pick_random()
			regions[nid]["i"] = randf_range(18, 30)
			pings.append({"id": nid, "t": 0.0})
			if not regions[nid]["hidden"] or regions[nid]["revealed"]:
				Sfx.play("alert", -12.0)
	# fin anticipado
	if active == 0 and elapsed > 8.0:
		calm_t += dt
		if calm_t > 2.5:
			confidence_bonus += 0.08
			_finish(_score(), false)
	else:
		calm_t = 0.0
	# golpe: si cae la capital
	if cr.get("fatal", false):
		if regions[1]["collapsed"]:
			fatal_t += dt
			if fatal_t > 6.0:
				_finish(0.0, false)
		else:
			fatal_t = 0.0


func _score() -> float:
	var ref := float(cr["dmg_k"]) * 10.0 * DURATION * 1.1
	var avg := 0.0
	for id in regions.keys():
		avg += regions[id]["i"]
	avg /= 8.0
	var s := clampf(1.0 - damage / ref, 0.0, 1.0) * 0.65 + clampf(1.0 - avg / 40.0, 0.0, 1.0) * 0.35
	return clampf(s + confidence_bonus, 0.0, 1.0)


func _update_palette() -> void:
	for id in regions.keys():
		var rg: Dictionary = regions[id]
		var vis: bool = not rg["hidden"] or rg["revealed"]
		var inten: float = rg["i"] / 100.0 if vis else 0.0
		map.set_region(id, Color(inten, 0.6 if (rg["hidden"] and rg["revealed"]) else 0.0, 0, 0))


# ------------------------------------------------------------------ interacción

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_mouse_position() - MAP_POS
		if event.pressed:
			if running and drag_unit < 0:
				for tk in tokens:
					if tk["travel"] >= 1.0 and _token_pos(tk).distance_to(local) < 24.0:
						drag_token = tk
						Sfx.play("paper2", -8.0, 1.5)
						get_viewport().set_input_as_handled()
						break
		else:
			if drag_unit >= 0:
				var id: int = map.id_at(local)
				if id >= 1 and id <= 8:
					_deploy(drag_unit, id)
				drag_unit = -1
			elif drag_token != null:
				var id2: int = map.id_at(local)
				if id2 >= 1 and id2 <= 8 and id2 != drag_token["region"]:
					drag_token["from"] = _token_pos(drag_token)
					drag_token["region"] = id2
					drag_token["travel"] = 0.0
					Sfx.play("click", -4.0)
				drag_token = null
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and running:
		var local2: Vector2 = get_global_mouse_position() - MAP_POS
		for tk in tokens:
			if _token_pos(tk).distance_to(local2) < 24.0:
				units[tk["unit"]]["left"] += 1
				tokens.erase(tk)
				_build_roster()
				Sfx.play("close", -6.0)
				break


func _deploy(ui: int, region: int) -> void:
	var u: Dictionary = units[ui]
	if u["left"] <= 0:
		return
	u["left"] -= 1
	cost += float(u["cost"])
	for k in u["fx"].keys():
		unit_fx[k] = unit_fx.get(k, 0.0) + float(u["fx"][k])
	var from := get_global_mouse_position() - MAP_POS
	tokens.append({"unit": ui, "region": region, "travel": 0.0, "from": from, "slot": tokens.size()})
	Sfx.play("click", -2.0, 0.9)
	_build_roster()


func _token_pos(tk: Dictionary) -> Vector2:
	var c: Vector2 = map.centroids.get(tk["region"], Vector2(500, 380))
	var n := 0
	var idx := 0
	for t2 in tokens:
		if t2["region"] == tk["region"]:
			if t2 == tk:
				idx = n
			n += 1
	var ang := TAU * idx / maxf(1.0, n) - PI / 2.0
	var target := c + (Vector2(cos(ang), sin(ang)) * (34.0 + n * 3.0) if n > 1 else Vector2(0, 34))
	var t: float = tk["travel"]
	var e := 1.0 - pow(1.0 - t, 3.0)
	return (tk["from"] as Vector2).lerp(target, e)


func _draw_layer() -> void:
	# etiquetas de regiones
	for id in range(1, 9):
		var c: Vector2 = map.centroids.get(id, Vector2.ZERO)
		var rg: Dictionary = regions[id]
		var vis: bool = not rg["hidden"] or rg["revealed"]
		var name: String = W.REGIONS[id]["name"]
		layer.draw_string(UI.f_sans_b, c + Vector2(-80, -16), name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(1, 1, 1, 0.85))
		if vis and rg["i"] > 0.0:
			var col := UI.RED.lightened(0.3) if rg["i"] > 60 else UI.AMBER
			layer.draw_string(UI.f_cond_b, c + Vector2(-60, 6), "%d%%" % int(rg["i"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)
			layer.draw_rect(Rect2(c + Vector2(-30, 12), Vector2(60, 4)), Color(0, 0, 0, 0.5))
			layer.draw_rect(Rect2(c + Vector2(-30, 12), Vector2(60 * rg["i"] / 100.0, 4)), col)
			if rg["collapsed"]:
				layer.draw_string(UI.f_sans_b, c + Vector2(-80, 34), "¡DESBORDADO!", HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(1, 0.3, 0.2, 0.6 + 0.4 * sin(_t * 8.0)))
			var ic := UI.icon(cr["icon"], 48)
			layer.draw_texture_rect(ic, Rect2(c + Vector2(-12, -52), Vector2(24, 24)), false, Color(1, 0.8, 0.6, 0.6 + 0.4 * sin(_t * 5.0)))
		elif rg["hidden"] and not rg["revealed"]:
			layer.draw_string(UI.f_sans_m, c + Vector2(-60, 6), "? ? ?", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.6, 0.8, 1.0, 0.4))
	# avisos
	for p in pings:
		var c2: Vector2 = map.centroids.get(p["id"], Vector2.ZERO)
		var tt: float = p["t"]
		var pc := Color(0.3, 1.0, 0.5) if p.get("good", false) else Color(1, 0.3, 0.2)
		layer.draw_arc(c2, 20 + tt * 90.0, 0, TAU, 48, Color(pc, 1.0 - tt / 1.2), 3.0, true)
	# fichas
	for tk in tokens:
		if tk == drag_token:
			continue
		_draw_token(_token_pos(tk), units[tk["unit"]], tk["travel"] < 1.0)
	var local: Vector2 = get_global_mouse_position() - MAP_POS
	if drag_unit >= 0:
		_draw_token(local, units[drag_unit], true)
		var hid: int = map.id_at(local)
		if hid >= 1 and hid <= 8:
			layer.draw_arc(map.centroids.get(hid, local), 50, 0, TAU, 48, Color(UI.GOLD_L, 0.8), 2.0, true)
	elif drag_token != null:
		_draw_token(local, units[drag_token["unit"]], true)


func _draw_token(p: Vector2, u: Dictionary, moving: bool) -> void:
	layer.draw_circle(p + Vector2(2, 3), 19, Color(0, 0, 0, 0.5))
	layer.draw_circle(p, 18, Color("0d1b2a"))
	layer.draw_arc(p, 18, 0, TAU, 32, UI.GOLD if not moving else Color(1, 1, 1, 0.6), 2.5, true)
	layer.draw_texture_rect(UI.icon(u["icon"], 48), Rect2(p - Vector2(11, 11), Vector2(22, 22)), false, UI.GOLD_L)


# ------------------------------------------------------------------ final

func _finish(score: float, delegated: bool) -> void:
	if finished:
		return
	finished = true
	running = false
	timer_bar.stop()
	Sfx.loop_stop("siren")
	if delegated:
		cost = 300.0
		unit_fx = {}
	var out := GS.resolve_crisis(item, score, unit_fx, cost)
	if GS.game_ended:
		return
	var panel := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	panel.position = Vector2(520, 300)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UI.vbox(14)
	panel.add_child(v)
	var verdict := "CRISIS CONTROLADA"
	var vc := UI.GREEN
	if score < 0.38:
		verdict = "DESASTRE"
		vc = UI.RED
	elif score < 0.62:
		verdict = "GESTIÓN IRREGULAR"
		vc = UI.AMBER
	if delegated:
		verdict = "GESTIONADO POR EL MINISTRO"
		vc = UI.AMBER
	var vl := UI.lbl(verdict, UI.f_cond_b, 56, vc)
	vl.rotation = deg_to_rad(-2.0)
	v.add_child(vl)
	v.add_child(UI.lbl("%s: %s   ·   Coste de la operación: %s   ·   Eficacia: %d%%" % [cr["dmg"], UI.num(damage, 0), UI.money(cost), int(score * 100)], UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 10)
	chips.custom_minimum_size = Vector2(820, 0)
	v.add_child(chips)
	var b := UI.btn("Volver al despacho", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	root.add_child(panel)
	UI.pop_in(panel)
	Sfx.play("success" if score >= 0.62 else "fail", -2.0)


func close(result = null) -> void:
	Sfx.loop_stop("siren")
	Sfx.music("music_campaign" if GS.campaign else "music_office", 1.5)
	super.close(result)


func on_escape() -> void:
	if finished:
		close()
