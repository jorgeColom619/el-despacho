extends "res://scripts/ui/overlay.gd"
## Informe del Gabinete: cada ministro resume la situación de su área y da un consejo.

const Portrait := preload("res://scripts/ui/portrait.gd")
const W := preload("res://scripts/data/world_data.gd")

const FIXES := {
	"trabajadores": "subir el gasto en vivienda y servicios sociales, o bajar el IVA",
	"empresarios": "bajar el Impuesto de Sociedades o invertir en infraestructuras",
	"clase_media": "bajar el IRPF y reforzar la seguridad",
	"jovenes": "invertir en educación, vivienda y medio ambiente",
	"jubilados": "revalorizar las pensiones y mejorar la sanidad",
	"militares": "aumentar el presupuesto de Defensa",
}


const Widgets := preload("res://scripts/ui/widgets.gd")
const FIRE_CP := 6

var grid: GridContainer
var picker: Control


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.93)
	var head := title_bar("Consejo de Ministros", "Informe del Gabinete · rasgos y fichajes", "empresarios")
	head.position = Vector2(80, 112)
	root.add_child(head)
	var sub := UI.lbl("Cada ministro tiene rasgos que afectan al país. Puede cesar a uno (−%d CP, Estabilidad ▼) y fichar a un sustituto entre tres candidatos." % FIRE_CP, UI.f_sans, 17, UI.DIM)
	sub.position = Vector2(80, 190)
	root.add_child(sub)
	grid = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(80, 226)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	_fill()
	var cb := close_button("Levantar la sesión")
	cb.position = Vector2(1640, 1012)
	root.add_child(cb)


func _fill() -> void:
	for c in grid.get_children():
		c.queue_free()
	for k in ["jefa", "economia", "interior", "exteriores", "defensa", "sanidad"]:
		var r := _report(k)
		grid.add_child(_card(GS.ministers[k], r[0], r[1], k))


func _traits_box(traits: Array, width: float) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.custom_minimum_size = Vector2(width, 0)
	for t in traits:
		var td: Dictionary = W.TRAITS.get(t, {})
		if td.is_empty():
			continue
		var c := Widgets.chip("capital" if td.get("good", true) else "alerta", td["name"], UI.GREEN if td.get("good", true) else UI.RED, 14)
		c.tooltip_text = td["desc"]
		flow.add_child(c)
	return flow


func _fire(k: String) -> void:
	if GS.pc < FIRE_CP:
		GS.toast.emit("No tiene capital político suficiente (%d CP)" % FIRE_CP, "warn", "capital")
		return
	_open_picker(k, GS.gen_candidates(k))


func _open_picker(k: String, cands: Array) -> void:
	if picker != null:
		picker.queue_free()
	picker = Control.new()
	UI.full(picker)
	var dr := ColorRect.new()
	dr.color = Color(0.01, 0.015, 0.03, 0.97)
	UI.full(dr)
	picker.add_child(dr)
	var v := UI.vbox(16)
	v.position = Vector2(110, 140)
	picker.add_child(v)
	v.add_child(UI.lbl("CESE DE %s · ELIJA SUSTITUTO" % String(GS.ministers[k]["name"]).to_upper(), UI.f_sans_b, 15, UI.GOLD))
	v.add_child(UI.lbl("Nombramiento: %s" % GS.ministers[k]["role"], UI.f_serif_b, 40, UI.CREAM))
	var h := UI.hbox(20)
	v.add_child(h)
	for cand in cands:
		var cv := UI.vbox(10)
		cv.custom_minimum_size = Vector2(540, 470)
		var pf := Control.new()
		pf.custom_minimum_size = Vector2(500, 300)
		pf.clip_contents = true
		pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := Portrait.new()
		p.position = Vector2(110, 10)
		p.size = Vector2(280, 336)
		pf.add_child(p)
		p.setup(cand["look"], true)
		p.mood = 0.3
		cv.add_child(pf)
		cv.add_child(UI.lbl(cand["name"], UI.f_serif_b, 28, UI.CREAM))
		cv.add_child(UI.lbl(cand["role"], UI.f_sans_m, 16, UI.GOLD))
		cv.add_child(_traits_box(cand["traits"], 500))
		for t in cand["traits"]:
			var d := UI.lbl("· " + W.TRAITS[t]["desc"], UI.f_sans, 15, UI.DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(500, 0)
			cv.add_child(d)
		var c2: Dictionary = cand
		var card := Widgets.click_card(cv, func(): _hire(k, c2), 18)
		h.add_child(card)
	var cancel := UI.btn("Cancelar", "ghost", 18)
	cancel.pressed.connect(func():
		picker.queue_free()
		picker = null)
	v.add_child(cancel)
	root.add_child(picker)
	UI.pop_in(v)


func _hire(k: String, cand: Dictionary) -> void:
	GS.pc -= FIRE_CP
	GS.apply_fx({"estabilidad": -2}, "Crisis de Gobierno", false)
	GS.hire_minister(k, cand)
	Sfx.play("stamp", -2.0)
	GS.toast.emit("%s es el nuevo nombramiento del Gobierno" % cand["name"], "good", "empresarios")
	if picker != null:
		picker.queue_free()
		picker = null
	_fill()


func _report(k: String) -> Array:
	match k:
		"jefa":
			var worst := "trabajadores"
			for f in GS.FACTIONS:
				if f != "militares" and GS.fac[f] < GS.fac[worst]:
					worst = f
			var t := "La aprobación está en el %s%%. " % UI.num(GS.approval, 0)
			t += "Los más descontentos son %s (%s). Le sugiero %s." % [W.FACTION_INFO[worst]["name"].to_lower(), UI.num(GS.fac[worst], 0), FIXES[worst]]
			if GS.term_days - GS.day < 120:
				t += " Quedan %d días para las elecciones." % (GS.term_days - GS.day)
			return [t, clampf((GS.approval - 45.0) / 20.0, -1.0, 1.0)]
		"economia":
			var bal := GS.monthly_balance()
			var t2 := "La deuda está en el %s%% del PIB y perdemos %s al mes. " % [UI.num(GS.debt_ratio(), 1), UI.money(-bal)] if bal < 0 else "Tenemos superávit de %s al mes. " % UI.money(bal)
			if GS.debt_ratio() > 115:
				t2 += "Los mercados empiezan a ponerse nerviosos: hay que ajustar ya."
			elif bal < -3000:
				t2 += "Deberíamos recortar gasto o subir algún impuesto en los Presupuestos."
			else:
				t2 += "La economía crece un %s%%. Prudencia." % UI.num(GS.growth(), 1)
			return [t2, clampf((110.0 - GS.debt_ratio()) / 20.0, -1.0, 1.0)]
		"interior":
			var s: float = GS.meters["seguridad"]
			var t3 := "Seguridad en %s/100. " % UI.num(s, 0)
			t3 += "Necesito más presupuesto para la policía." if s < 48 else "Las calles están tranquilas."
			if GS.approval < 35:
				t3 += " Cuidado: el malestar social puede acabar en disturbios."
			return [t3, clampf((s - 45.0) / 20.0, -1.0, 1.0)]
		"exteriores":
			var worst_c := "norland"
			var best_c := "norland"
			for c in GS.countries.keys():
				if GS.countries[c]["rel"] < GS.countries[worst_c]["rel"]:
					worst_c = c
				if GS.countries[c]["rel"] > GS.countries[best_c]["rel"]:
					best_c = c
			var t4 := "Nuestro mejor socio es %s (%s). La relación más tensa, con %s (%s). " % [W.COUNTRIES[best_c]["name"], UI.signed(GS.countries[best_c]["rel"], 0), W.COUNTRIES[worst_c]["name"], UI.signed(GS.countries[worst_c]["rel"], 0)]
			t4 += "Los acuerdos comerciales impulsarían la economía: use el globo." if GS.treaty_count() < 2 else "Tenemos %d tratados en vigor." % GS.treaty_count()
			return [t4, clampf((GS.meters["prestigio"] - 45.0) / 20.0, -1.0, 1.0)]
		"defensa":
			var m: float = GS.fac["militares"]
			var t5 := "La moral de las Fuerzas Armadas está en %s/100. " % UI.num(m, 0)
			if m < 25:
				t5 += "Presidente, hay rumores muy preocupantes en los cuarteles. No los ignore."
			elif m < 40:
				t5 += "Hay descontento por la falta de medios."
			else:
				t5 += "Los ejércitos son leales y están preparados."
			return [t5, clampf((m - 40.0) / 20.0, -1.0, 1.0)]
		"sanidad":
			var b: float = GS.meters["bienestar"]
			var t6 := "El bienestar social está en %s/100. " % UI.num(b, 0)
			t6 += "Los hospitales están al límite; una huelga es cuestión de tiempo." if b < 42 else ("El sistema aguanta, pero necesita inversión." if b < 55 else "Los servicios públicos funcionan bien.")
			return [t6, clampf((b - 45.0) / 20.0, -1.0, 1.0)]
	return ["", 0.0]


func _card(m: Dictionary, text: String, mood: float, key: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.08, 0.13, 0.96), 10, Color(1, 1, 1, 0.1), 1, 0, 14))
	card.custom_minimum_size = Vector2(570, 380)
	var v := UI.vbox(8)
	card.add_child(v)
	var h := UI.hbox(14)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(120, 130)
	pf.clip_contents = true
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Portrait.new()
	p.position = Vector2(-10, 0)
	p.size = Vector2(140, 168)
	p.track_mouse = false
	pf.add_child(p)
	p.setup(m["look"], false)
	p.mood = mood * 0.7
	p.anger = clampf(-mood, 0.0, 1.0) * 0.4
	h.add_child(pf)
	var nv := UI.vbox(2)
	nv.add_child(UI.lbl(m["name"], UI.f_serif_b, 24, UI.TEXT))
	nv.add_child(UI.lbl(m["role"], UI.f_sans_m, 15, UI.GOLD))
	var status := "Situación favorable" if mood > 0.3 else ("Situación delicada" if mood < -0.3 else "Situación estable")
	nv.add_child(UI.lbl(status, UI.f_sans_b, 15, UI.GREEN if mood > 0.3 else (UI.RED if mood < -0.3 else UI.AMBER)))
	h.add_child(nv)
	v.add_child(h)
	v.add_child(_traits_box(m.get("traits", []), 530))
	var t := UI.lbl("«" + text + "»", UI.f_serif, 18, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(530, 0)
	v.add_child(t)
	var b := UI.btn("Cesar y fichar sustituto (%d CP)" % FIRE_CP, "ghost", 15)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): _fire(key))
	v.add_child(b)
	return card


func on_escape() -> void:
	close()
