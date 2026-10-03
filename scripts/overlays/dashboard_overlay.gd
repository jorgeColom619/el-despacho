extends "res://scripts/ui/overlay.gd"
## SIGEP: el ordenador del despacho. Datos, sociedad, agenda legislativa, Congreso, agenda y gabinete.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const W := preload("res://scripts/data/world_data.gd")

const SCREEN := Rect2(110, 118, 1700, 900)

var content: Control
var tabs := {}
var current := ""


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.9)
	var scr := Panel.new()
	scr.add_theme_stylebox_override("panel", UI.sb(Color("0a1424"), 14, Color("2a3b55"), 2, 30))
	scr.position = SCREEN.position
	scr.size = SCREEN.size
	scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scr)
	var top := Control.new()
	top.position = SCREEN.position
	top.size = Vector2(SCREEN.size.x, 56)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.draw.connect(func():
		top.draw_rect(Rect2(2, 2, top.size.x - 4, 54), Color("13294a"))
		top.draw_string(UI.f_sans_b, Vector2(26, 37), "SIGEP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.GOLD_L)
		top.draw_string(UI.f_sans, Vector2(110, 36), "Sistema Integrado de Gestión Presidencial  ·  Acceso: Presidente de la República", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.65))
		top.draw_string(UI.f_mono, Vector2(0, 36), UI.date_short(GS.day), HORIZONTAL_ALIGNMENT_RIGHT, top.size.x - 80, 16, Color(0.6, 1.0, 0.75, 0.8)))
	root.add_child(top)
	var x := UI.btn("✕", "ghost", 22)
	x.position = SCREEN.position + Vector2(SCREEN.size.x - 64, 6)
	x.pressed.connect(func(): close())
	root.add_child(x)
	var nav := UI.vbox(6)
	nav.position = SCREEN.position + Vector2(20, 80)
	nav.size = Vector2(230, 700)
	root.add_child(nav)
	for spec in [["resumen", "Resumen", "grafico"], ["sociedad", "Sociedad", "aprobacion"], ["leyes", "Agenda legislativa", "ley"], ["congreso", "Congreso", "mazo"], ["agenda", "Agenda y registro", "calendario"], ["gabinete", "Gabinete", "empresarios"]]:
		var b := UI.btn("  " + spec[1], "ghost", 19)
		b.icon = UI.icon(spec[2], 36)
		b.add_theme_constant_override("icon_max_width", 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(230, 48)
		var id: String = spec[0]
		b.pressed.connect(func(): _show(id))
		nav.add_child(b)
		tabs[id] = b
	content = Control.new()
	content.position = SCREEN.position + Vector2(280, 80)
	content.size = Vector2(1390, 800)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	_show(data.get("tab", "resumen"))


func on_escape() -> void:
	close()


func _show(id: String) -> void:
	current = id
	for k in tabs.keys():
		var b: Button = tabs[k]
		b.add_theme_color_override("font_color", UI.GOLD_L if k == id else UI.TEXT)
		b.add_theme_stylebox_override("normal", UI.sb(Color(UI.GOLD, 0.14), 6, Color(UI.GOLD, 0.4), 1) if k == id else StyleBoxEmpty.new())
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = content.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var v := UI.vbox(16)
	v.custom_minimum_size = Vector2(1360, 0)
	scroll.add_child(v)
	match id:
		"resumen":
			_resumen(v)
		"sociedad":
			_sociedad(v)
		"leyes":
			_leyes(v)
		"congreso":
			_congreso(v)
		"agenda":
			_agenda(v)
		"gabinete":
			_gabinete(v)


func _card(w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("0f1d33"), 10, Color("24344d"), 1, 0, 18))
	p.custom_minimum_size = Vector2(w, h)
	return p


# ------------------------------------------------------------------ pestañas

func _resumen(v: VBoxContainer) -> void:
	var row := UI.hbox(16)
	v.add_child(row)
	var ac := _card(860, 330)
	row.add_child(ac)
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(820, 290)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(func():
		chart.draw_string(UI.f_sans_b, Vector2(0, 16), "APROBACIÓN DEL GOBIERNO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.DIM)
		chart.draw_string(UI.f_cond_b, Vector2(0, 66), UI.num(GS.approval, 0) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, UI.color_for(GS.approval))
		var r := Rect2(150, 30, 660, 240)
		for i in 5:
			var y := r.position.y + r.size.y * i / 4.0
			chart.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.06), 1.0)
			chart.draw_string(UI.f_sans, Vector2(r.position.x - 40, y + 5), str(100 - i * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		var s: Array = GS.stat_hist["approval"].duplicate()
		s.append(GS.approval)
		if s.size() < 2:
			s.insert(0, s[0])
		Widgets.draw_line_chart(chart, r, s, UI.GOLD, 0.0, 100.0, 3.0)
		chart.draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.5), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Color(1, 1, 1, 0.25), 1.0)
		chart.draw_string(UI.f_sans, Vector2(r.position.x, r.end.y + 18), "Evolución mensual", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM))
	ac.add_child(chart)
	var ec := _card(480, 330)
	row.add_child(ec)
	var ev := UI.vbox(8)
	ec.add_child(ev)
	ev.add_child(UI.lbl("ECONOMÍA Y HACIENDA", UI.f_sans_b, 14, UI.DIM))
	for spec in [["PIB", UI.money(GS.gdp)], ["Crecimiento anual", UI.pct(GS.growth())], ["Paro", UI.pct(GS.unemployment())], ["Deuda pública", UI.pct(GS.debt_ratio()) + " del PIB"], ["Ingresos mensuales", UI.money(GS.revenue())], ["Gasto mensual", UI.money(GS.spending())], ["Intereses de la deuda", UI.money(GS.interest()) + "/mes"], ["Saldo mensual", UI.money(GS.monthly_balance(), true)]]:
		var h := UI.hbox(0)
		var l := UI.lbl(spec[0], UI.f_sans, 18, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var col := UI.TEXT
		if spec[0] == "Saldo mensual":
			col = UI.GREEN if GS.monthly_balance() >= 0 else UI.RED
		h.add_child(UI.lbl(spec[1], UI.f_cond_b, 20, col))
		ev.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for m in GS.METERS:
		var c := _card(440, 150)
		var ch := Control.new()
		ch.custom_minimum_size = Vector2(400, 110)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mm: String = m
		ch.draw.connect(func():
			var val: float = GS.meters[mm]
			var tg: float = GS.mtarget.get(mm, val)
			ch.draw_texture_rect(UI.icon(W.METER_INFO[mm]["icon"], 48), Rect2(0, 0, 26, 26), false, UI.color_for(val))
			ch.draw_string(UI.f_sans_b, Vector2(36, 20), W.METER_INFO[mm]["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.TEXT)
			ch.draw_string(UI.f_cond_b, Vector2(0, 80), UI.num(val, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UI.color_for(val))
			var trend := "estable"
			if tg > val + 2:
				trend = "▲ mejorando hacia %d" % int(tg)
			elif tg < val - 2:
				trend = "▼ empeorando hacia %d" % int(tg)
			ch.draw_string(UI.f_sans, Vector2(0, 104), trend, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
			var s: Array = GS.stat_hist[mm].duplicate()
			s.append(val)
			if s.size() < 2:
				s.insert(0, s[0])
			Widgets.draw_line_chart(ch, Rect2(130, 34, 260, 60), s, UI.color_for(val), 0.0, 100.0, 2.0))
		c.add_child(ch)
		grid.add_child(c)


func _sociedad(v: VBoxContainer) -> void:
	var wants := {
		"trabajadores": "Más gasto social y sanitario, IVA bajo, empleo.",
		"empresarios": "Impuesto de Sociedades bajo, crecimiento, estabilidad.",
		"clase_media": "IRPF moderado, seguridad, buena economía y servicios.",
		"jovenes": "Educación, vivienda asequible, medio ambiente y empleo.",
		"jubilados": "Pensiones, sanidad y seguridad. IVA bajo.",
		"militares": "Presupuesto de Defensa y prestigio internacional.",
	}
	v.add_child(UI.lbl("La aprobación es la media ponderada de la satisfacción de los grupos sociales. La línea blanca indica hacia dónde evoluciona cada grupo.", UI.f_sans, 17, UI.DIM))
	for f in GS.FACTIONS:
		var c := _card(1340, 96)
		var h := UI.hbox(20)
		c.add_child(h)
		h.add_child(UI.icon_rect(W.FACTION_INFO[f]["icon"], 40, UI.color_for(GS.fac[f])))
		var nv := UI.vbox(2)
		nv.custom_minimum_size = Vector2(340, 0)
		nv.add_child(UI.lbl(W.FACTION_INFO[f]["name"], UI.f_sans_b, 22, UI.TEXT))
		var wt: float = W.FACTION_INFO[f]["w"]
		nv.add_child(UI.lbl("Peso electoral: %d%%" % int(wt * 100) if wt > 0 else "Sin peso electoral · riesgo de golpe si < 18", UI.f_sans, 14, UI.DIM))
		h.add_child(nv)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(420, 40)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ff: String = f
		bar.draw.connect(func():
			var val: float = GS.fac[ff]
			var tg: float = GS.ftarget.get(ff, val)
			bar.draw_rect(Rect2(0, 12, 400, 16), Color(1, 1, 1, 0.08))
			bar.draw_rect(Rect2(0, 12, 4.0 * val, 16), UI.color_for(val))
			bar.draw_rect(Rect2(4.0 * clampf(tg, 0, 100) - 1, 6, 3, 28), Color.WHITE))
		h.add_child(bar)
		h.add_child(UI.lbl(UI.num(GS.fac[f], 0), UI.f_cond_b, 32, UI.color_for(GS.fac[f])))
		var wl := UI.lbl(wants[f], UI.f_sans, 15, UI.DIM)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size = Vector2(380, 0)
		h.add_child(wl)
		v.add_child(c)


func _leyes(v: VBoxContainer) -> void:
	v.add_child(UI.lbl("Presente proyectos de ley al Congreso. Cuestan capital político y necesitan mayoría. Una vez aprobados, sus efectos son permanentes. Cada ley aprobada encarece la siguiente.  Capital político disponible: %d" % int(GS.pc), UI.f_sans, 17, UI.DIM))
	if GS.policies.size() > 0:
		v.add_child(Widgets.section("Leyes en vigor"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for p in GS.policies:
			flow.add_child(Widgets.chip(W.LAWS[p]["icon"], W.LAWS[p]["name"], UI.GOLD_L, 16))
		v.add_child(flow)
	v.add_child(Widgets.section("Proyectos disponibles"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	for id in W.LAWS.keys():
		if id in GS.policies:
			continue
		var law: Dictionary = W.LAWS[id]
		var c := _card(668, 200)
		var cv := UI.vbox(8)
		c.add_child(cv)
		var h := UI.hbox(12)
		h.add_child(UI.icon_rect(law["icon"], 30, UI.GOLD_L))
		var t := UI.lbl(law["name"], UI.f_sans_b, 20, UI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(380, 0)
		h.add_child(t)
		var ideo: float = law["ideo"]
		var itxt := "Izquierda" if ideo < -35 else ("Centro-izq." if ideo < -10 else ("Centro" if ideo <= 10 else ("Centro-der." if ideo <= 35 else "Derecha")))
		h.add_child(UI.lbl(itxt, UI.f_sans_m, 14, UI.DIM))
		cv.add_child(h)
		var d := UI.lbl(law["desc"], UI.f_sans, 15, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(620, 0)
		cv.add_child(d)
		var fx: Dictionary = law.get("mods", {}).duplicate()
		if law.has("monthly"):
			fx["monthly"] = law["monthly"]
		if law.get("fx", {}).has("money"):
			fx["money"] = law["fx"]["money"]
		var chips := Widgets.effect_chips(GS.preview(fx), 14, 8)
		chips.custom_minimum_size = Vector2(620, 0)
		cv.add_child(chips)
		var bh := UI.hbox(10)
		var yes := int(_quick_forecast(law))
		var need := 234 if law.get("super", false) else 176
		bh.add_child(UI.lbl("Previsión: ≈%d votos (necesita %d)" % [yes, need], UI.f_sans_m, 14, UI.GREEN if yes >= need else UI.RED))
		bh.add_child(UI.spacer(0, 0, true))
		var cost := GS.law_cost(id)
		var b := UI.btn("Presentar (%d CP)" % cost, "gold", 16)
		b.disabled = GS.pc < float(cost) or GS.flags.has("law_pending_" + id)
		var lid: String = id
		b.pressed.connect(func(): _propose(lid))
		bh.add_child(b)
		cv.add_child(bh)
		grid.add_child(c)


func _quick_forecast(law: Dictionary) -> float:
	var pr := GS.vote_forecast(law, {})
	var e := 0.0
	for p in pr.keys():
		var a := pow(pr[p], 2.2)
		var b := pow(1.0 - pr[p], 2.2)
		e += float(GS.parties[p]["seats"]) * a / (a + b)
	return e


func _propose(id: String) -> void:
	var cost := float(GS.law_cost(id))
	if GS.pc < cost:
		return
	GS.pc -= cost
	GS.flags["law_pending_" + id] = GS.day
	GS.stats_changed.emit()
	Sfx.play("paper", -2.0)
	close()
	if main != null:
		main.call_deferred("open_overlay", "vote", {"law": id})


func _congreso(v: VBoxContainer) -> void:
	var sup := GS.supporting_seats()
	v.add_child(UI.lbl("Apoyo parlamentario estimado: %d de 350 escaños (mayoría absoluta: 176)" % sup, UI.f_sans_b, 20, UI.GREEN if sup >= 176 else UI.AMBER))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(1340, 60)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var x := 0.0
		for p in W.PARTY_ORDER:
			var w2 := 1340.0 * float(GS.parties[p]["seats"]) / 350.0
			bar.draw_rect(Rect2(x, 10, w2 - 2, 36), Color(W.PARTIES[p]["color"]))
			if w2 > 40:
				bar.draw_string(UI.f_sans_b, Vector2(x, 34), W.PARTIES[p]["short"], HORIZONTAL_ALIGNMENT_CENTER, w2, 14, Color.WHITE)
			x += w2
		bar.draw_line(Vector2(1340.0 * 176.0 / 350.0, 0), Vector2(1340.0 * 176.0 / 350.0, 56), Color.WHITE, 2.0))
	v.add_child(bar)
	for p in W.PARTY_ORDER:
		var pd: Dictionary = W.PARTIES[p]
		var c := _card(1340, 80)
		var h := UI.hbox(18)
		c.add_child(h)
		var sw := ColorRect.new()
		sw.color = Color(pd["color"])
		sw.custom_minimum_size = Vector2(10, 44)
		h.add_child(sw)
		var nv := UI.vbox(0)
		nv.custom_minimum_size = Vector2(420, 0)
		nv.add_child(UI.lbl(pd["name"] + (" · su partido" if p == GS.pres["party"] else ""), UI.f_sans_b, 20, UI.TEXT))
		nv.add_child(UI.lbl("Líder: %s · %d escaños" % [pd["leader"], int(GS.parties[p]["seats"])], UI.f_sans, 14, UI.DIM))
		h.add_child(nv)
		var rel: float = GS.parties[p]["rel"]
		h.add_child(UI.lbl("Relación con el Gobierno", UI.f_sans, 15, UI.DIM))
		h.add_child(Widgets.bar(rel, 300, 12, UI.color_for(rel)))
		h.add_child(UI.lbl(UI.num(rel, 0), UI.f_cond_b, 24, UI.color_for(rel)))
		var status := "Socio" if rel >= 55 or p == GS.pres["party"] else ("Neutral" if rel >= 35 else "Oposición")
		var sl := UI.lbl(status, UI.f_sans_b, 16, UI.GREEN if status == "Socio" else (UI.AMBER if status == "Neutral" else UI.RED))
		sl.custom_minimum_size = Vector2(90, 0)
		h.add_child(sl)
		if p != GS.pres["party"]:
			var cd := int(GS.cooldowns.get("meet_" + p, 0)) - GS.day
			var b := UI.btn("Reunirse (6 CP)" if cd <= 0 else "En %d días" % cd, "normal", 15)
			b.tooltip_text = "Reunión con la dirección del grupo: mejora la relación. Clave para formar mayorías y ganar las elecciones (socios con relación ≥ 60)."
			b.disabled = cd > 0 or GS.pc < 6
			var pp: String = p
			b.pressed.connect(func():
				GS.pc -= 6
				GS.cooldowns["meet_" + pp] = GS.day + 45
				GS.apply_fx({"party": {pp: randf_range(5.0, 9.0)}}, "Reunión")
				Sfx.play("paper2", -4.0)
				_show("congreso"))
			h.add_child(b)
		v.add_child(c)
	v.add_child(UI.lbl("Tras las elecciones, solo los partidos con relación ≥ 60 y afinidad ideológica apoyarán su investidura.", UI.f_sans, 15, UI.DIM))


func _agenda(v: VBoxContainer) -> void:
	var left := GS.term_days - GS.day
	v.add_child(UI.lbl("Elecciones generales en %d días (%s)" % [left, UI.date_mid(GS.term_days)], UI.f_serif_b, 30, UI.GOLD_L))
	var info := []
	info.append("Documentos pendientes: %d" % GS.inbox.size())
	info.append("Visitas esperando: %d" % GS.visitors.size())
	info.append("Alertas de crisis: %d" % GS.alerts.size())
	var sp := GS.speech_until - GS.day
	info.append("Discurso a la nación: " + ("disponible" if sp <= 0 else "en %d días" % sp))
	if GS.flags.has("presupuesto_pendiente"):
		info.append("¡Presupuestos del año pendientes de presentar!")
	if GS.campaign:
		info.append("CAMPAÑA ELECTORAL EN CURSO")
	for s in info:
		v.add_child(UI.lbl("•  " + s, UI.f_sans_m, 19, UI.TEXT))
	for it in GS.inbox:
		var d := int(it.get("deadline", GS.day)) - GS.day
		v.add_child(UI.lbl("      ›  %s — vence en %d días" % [GS.fmt(it["ev"]["title"]), d], UI.f_sans, 16, UI.RED if d < 3 else UI.DIM))
	v.add_child(Widgets.section("Registro de decisiones"))
	for hrow in GS.history.slice(0, 40):
		var h := UI.hbox(14)
		var dl := UI.lbl(UI.date_short(int(hrow["day"])), UI.f_mono, 15, UI.DIM)
		dl.custom_minimum_size = Vector2(130, 0)
		h.add_child(dl)
		var tl := UI.lbl(GS.fmt(hrow["title"]), UI.f_sans_b, 16, UI.TEXT)
		tl.custom_minimum_size = Vector2(520, 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(tl)
		var cl := UI.lbl(GS.fmt(hrow["choice"]), UI.f_sans, 15, UI.DIM)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(640, 0)
		h.add_child(cl)
		v.add_child(h)


func _gabinete(v: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for k in ["jefa", "economia", "interior", "exteriores", "defensa", "sanidad"]:
		var m: Dictionary = GS.ministers[k]
		var c := _card(440, 330)
		var cv := UI.vbox(6)
		c.add_child(cv)
		var pf := Control.new()
		pf.custom_minimum_size = Vector2(400, 180)
		pf.clip_contents = true
		pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := Portrait.new()
		p.position = Vector2(125, 6)
		p.size = Vector2(150, 180)
		pf.add_child(p)
		p.setup(m["look"], false)
		cv.add_child(pf)
		cv.add_child(UI.lbl(m["name"], UI.f_serif_b, 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.lbl(m["role"], UI.f_sans_m, 15, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for t in m.get("traits", []):
			var td: Dictionary = W.TRAITS.get(t, {})
			if td.is_empty():
				continue
			var good: bool = td.get("good", true)
			var chip := Widgets.chip("capital" if good else "alerta", td["name"], UI.GREEN if good else UI.RED, 14)
			chip.tooltip_text = td["desc"]
			flow.add_child(chip)
		cv.add_child(flow)
		grid.add_child(c)
	var b := UI.btn("Reunir al Consejo de Ministros (fichajes y ceses)", "normal", 17)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		close()
		if main != null:
			main.call_deferred("open_overlay", "cabinet", {}))
	v.add_child(b)
