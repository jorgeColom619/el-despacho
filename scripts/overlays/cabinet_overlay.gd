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
const Gobierno := preload("res://scripts/systems/gobierno.gd")
const FIRE_CP := 6

var grid: GridContainer
var picker: Control
## Cargo que hay que cubrir sí o sí (tras un escándalo o una dimisión): sin cancelar y sin el coste del cese
var forced := ""


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.93)
	var head := title_bar("Consejo de Ministros", "Informe del Gabinete · rasgos y fichajes", "empresarios")
	head.position = Vector2(80, 112)
	root.add_child(head)
	var sub := UI.lbl("La competencia de cada cargo pesa en su área y en lo que usted le delega. Puede cesar a uno (−%d CP, Estabilidad ▼) y elegir sustituto entre tres perfiles." % FIRE_CP, UI.f_sans, 17, UI.DIM)
	sub.position = Vector2(80, 190)
	root.add_child(sub)
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(80, 226)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	_fill()
	var cb := close_button("Levantar la sesión")
	cb.position = Vector2(1640, 1012)
	root.add_child(cb)
	var pk := str(data.get("pick", ""))
	if GS.ministers.has(pk):
		forced = pk
		_open_picker(pk, GS.gen_candidates(pk))


func _fill() -> void:
	for c in grid.get_children():
		c.queue_free()
	for k in W.CABINET:
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


## «Competencia 74 · Solvente · Del partido» con una barra
static func skill_row(m: Dictionary, width: float) -> Control:
	var s := float(m.get("skill", Gobierno.MID))
	var lv: Array = Gobierno.level(s)
	var v := UI.vbox(3)
	v.add_child(UI.lbl("Competencia %d · %s · %s" % [int(s), lv[0], Gobierno.origin_label(m)], UI.f_sans_b, 14, lv[1]))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(width, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 0, width, 6), Color(1, 1, 1, 0.1))
		bar.draw_rect(Rect2(0, 0, width * s / 100.0, 6), lv[1]))
	v.add_child(bar)
	return v


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
		pf.custom_minimum_size = Vector2(500, 250)
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
		cv.add_child(skill_row(cand, 500))
		var why := ""
		match str(cand.get("origin", "")):
			"independiente":
				why = "Independiente: muy capaz, pero el partido se queja de que no cuente con los suyos (+%d CP)." % Gobierno.INDEP_CP
			"socio":
				why = "Cuota de %s: menos experiencia, pero afianza la coalición (relación +%d)." % [W.PARTIES[cand["party"]]["name"], int(Gobierno.SOCIO_REL_VICE if k == "vice" else Gobierno.SOCIO_REL)]
			_:
				why = "Del partido: de confianza, sin sorpresas (Estabilidad +2)."
		var wl := UI.lbl(why, UI.f_sans_m, 15, UI.TEXT)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size = Vector2(500, 0)
		cv.add_child(wl)
		cv.add_child(_traits_box(cand["traits"], 500))
		for t in cand["traits"]:
			var d := UI.lbl("· " + W.TRAITS[t]["desc"], UI.f_sans, 15, UI.DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(500, 0)
			cv.add_child(d)
		var c2: Dictionary = cand
		var card := Widgets.click_card(cv, func(): _hire(k, c2), 18)
		h.add_child(card)
	if forced != k:
		var cancel := UI.btn("Cancelar", "ghost", 18)
		cancel.pressed.connect(func():
			picker.queue_free()
			picker = null)
		v.add_child(cancel)
	root.add_child(picker)
	UI.pop_in(v)


## Encargar una reforma al ministro: dos a elegir, con lo que cuestan y lo que se juega
func _open_reforms(k: String) -> void:
	if picker != null:
		picker.queue_free()
	picker = Control.new()
	UI.full(picker)
	var dr := ColorRect.new()
	dr.color = Color(0.01, 0.015, 0.03, 0.97)
	UI.full(dr)
	picker.add_child(dr)
	var v := UI.vbox(16)
	v.position = Vector2(110, 150)
	picker.add_child(v)
	var m: Dictionary = GS.ministers[k]
	v.add_child(UI.lbl("ENCARGO A %s · %s" % [String(m["name"]).to_upper(), String(m["role"]).to_upper()], UI.f_sans_b, 15, UI.GOLD))
	v.add_child(UI.lbl("¿Qué reforma le encarga?", UI.f_serif_b, 40, UI.CREAM))
	var ch: Array = Gobierno.reform_chance(k)
	var ok := int(float(ch[0]) * 100.0)
	var bad := int(float(ch[1]) * 100.0)
	v.add_child(UI.lbl("Con su competencia (%d), sale bien el %d %% de las veces, a medias el %d %% y fracasa el %d %%." % [int(Gobierno.skill(k)), ok, 100 - ok - bad, bad], UI.f_sans_m, 18, UI.TEXT))
	var h := UI.hbox(20)
	v.add_child(h)
	for r in W.REFORMS.get(k, []):
		var cv := UI.vbox(10)
		cv.custom_minimum_size = Vector2(800, 330)
		cv.add_child(UI.lbl(r["name"], UI.f_serif_b, 28, UI.CREAM))
		var d := UI.lbl(r["desc"], UI.f_sans, 17, UI.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(760, 0)
		cv.add_child(d)
		var money := float(r.get("money", 0.0))
		cv.add_child(UI.lbl("Coste: %d CP%s · Tarda %d días" % [int(r["pc"]), (" y " + UI.money(money)) if money > 0.0 else "", int(r["days"])], UI.f_sans_b, 16, UI.GOLD_L))
		cv.add_child(UI.lbl("Si sale bien:", UI.f_sans_b, 14, UI.GREEN))
		cv.add_child(Widgets.effect_chips(GS.preview(_flat(Gobierno._tokens(r["ok"]))), 15, 8))
		if r.has("flag"):
			var fl := UI.lbl("Además: +1 unidad de cada tipo y mejor resultado al delegar en sus crisis.", UI.f_sans, 15, UI.TEXT)
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fl.custom_minimum_size = Vector2(760, 0)
			cv.add_child(fl)
		cv.add_child(UI.lbl("Si fracasa:", UI.f_sans_b, 14, UI.RED))
		cv.add_child(Widgets.effect_chips(GS.preview(_flat(Gobierno._tokens(r["bad"]))), 15, 8))
		var rid: String = r["id"]
		h.add_child(Widgets.click_card(cv, func(): _start_reform(k, rid), 18))
	var cancel := UI.btn("Cancelar", "ghost", 18)
	cancel.pressed.connect(func():
		picker.queue_free()
		picker = null)
	v.add_child(cancel)
	root.add_child(picker)
	UI.pop_in(v)


## Los efectos permanentes («mods») se enseñan como los demás
static func _flat(fx: Dictionary) -> Dictionary:
	var out := fx.duplicate(true)
	if out.has("mods"):
		for mk in out["mods"].keys():
			out[mk] = float(out.get(mk, 0.0)) + float(out["mods"][mk])
		out.erase("mods")
	return out


func _start_reform(k: String, id: String) -> void:
	if not Gobierno.start_reform(k, id):
		GS.toast.emit("No tiene capital político suficiente para este encargo", "warn", "capital")
		return
	Sfx.play("stamp", -2.0)
	if picker != null:
		picker.queue_free()
		picker = null
	_fill()


func _hire(k: String, cand: Dictionary) -> void:
	var cost := (0 if forced == k else FIRE_CP) + Gobierno.hire_cost(cand)
	if GS.pc < cost:
		GS.toast.emit("No tiene capital político suficiente (%d CP)" % cost, "warn", "capital")
		return
	GS.pc -= cost
	GS.apply_fx({"estabilidad": -2}, "Crisis de Gobierno", false)
	GS.hire_minister(k, cand)
	if forced == k:
		forced = ""
	Sfx.play("stamp", -2.0)
	GS.toast.emit("%s es el nuevo nombramiento del Gobierno" % cand["name"], "good", "empresarios")
	if picker != null:
		picker.queue_free()
		picker = null
	_fill()


func _report(k: String) -> Array:
	match k:
		"vice":
			var socio := Gobierno.partner_party()
			var t0 := "Coordino al Gobierno y superviso lo que usted delega. "
			if socio != "":
				t0 += "Nuestro socio más cercano es %s (relación %d)." % [W.PARTIES[socio]["name"], int(GS.parties[socio]["rel"])]
			else:
				t0 += "No tenemos ningún socio fiable en el Congreso: cuidado con las votaciones."
			return [t0, clampf((float(GS.supporting_seats()) - 160.0) / 30.0, -1.0, 1.0)]
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
	card.custom_minimum_size = Vector2(425, 378)
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
	nv.add_child(UI.lbl(m["name"], UI.f_serif_b, 21, UI.TEXT))
	nv.add_child(UI.lbl(m["role"], UI.f_sans_m, 15, UI.GOLD))
	var status := "Situación favorable" if mood > 0.3 else ("Situación delicada" if mood < -0.3 else "Situación estable")
	nv.add_child(UI.lbl(status, UI.f_sans_b, 15, UI.GREEN if mood > 0.3 else (UI.RED if mood < -0.3 else UI.AMBER)))
	h.add_child(nv)
	v.add_child(h)
	v.add_child(skill_row(m, 395))
	v.add_child(_traits_box(m.get("traits", []), 395))
	var t := UI.lbl("«" + text + "»", UI.f_serif, 15, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(395, 0)
	v.add_child(t)
	var rf: Dictionary = GS.reforms.get(key, {})
	if not rf.is_empty():
		var rd := Gobierno.reform_data(key, str(rf["id"]))
		var ch: Array = Gobierno.reform_chance(key)
		var rl := UI.lbl("Encargo en marcha: %s · quedan %d días · éxito ~%d %%" % [rd.get("name", ""), maxi(0, int(rf["end"]) - GS.day), int(float(ch[0]) * 100.0)], UI.f_sans_m, 14, UI.GOLD_L)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(395, 0)
		v.add_child(rl)
	var bh := UI.hbox(8)
	bh.size_flags_vertical = Control.SIZE_SHRINK_END
	v.add_child(bh)
	if rf.is_empty():
		var eb := UI.btn("Encargar reforma", "normal", 14)
		eb.pressed.connect(func(): _open_reforms(key))
		bh.add_child(eb)
	bh.add_child(UI.spacer(0, 0, true))
	var b := UI.btn("Cesar (%d CP)" % FIRE_CP, "ghost", 14)
	b.pressed.connect(func(): _fire(key))
	bh.add_child(b)
	return card


func on_escape() -> void:
	close()
