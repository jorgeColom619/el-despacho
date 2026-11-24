extends "res://scripts/ui/overlay.gd"
## Comercio y recursos: qué produce el país, cuánto, cómo y con qué capacidad (producción); los precios del
## mundo y quién vende y compra cada cosa (mercado mundial); y los contratos y las mesas de negociación abiertas.
## Ver systems/mercado.gd y systems/negociacion.gd.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Mercado := preload("res://scripts/systems/mercado.gd")
const N := preload("res://scripts/systems/negociacion.gd")
const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")

var tab := "produccion"
var tab_btns := {}
var body: VBoxContainer
var aviso: Label


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.95)
	tab = String(data.get("tab", "produccion"))
	var head := title_bar("Comercio y recursos", "Ministerio de Economía · %s" % W.COUNTRY_NAME, "fabrica")
	head.position = Vector2(60, 36)
	root.add_child(head)
	var tabs := UI.hbox(8)
	tabs.position = Vector2(620, 58)
	root.add_child(tabs)
	for t in [["produccion", "Producción"], ["mercado", "Mercado mundial"], ["contratos", "Contratos y negociaciones"]]:
		var b := UI.btn(t[1], "normal", 17)
		var id: String = t[0]
		b.pressed.connect(func():
			tab = id
			_show())
		tabs.add_child(b)
		tab_btns[id] = b
	var close_b := close_button("Volver al despacho")
	close_b.position = Vector2(1640, 44)
	root.add_child(close_b)
	aviso = UI.lbl("", UI.f_sans_b, 16, UI.AMBER)
	aviso.position = Vector2(620, 124)
	root.add_child(aviso)
	var pp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.45), 20)
	pp.position = Vector2(60, 180)
	pp.custom_minimum_size = Vector2(1800, 860)
	pp.size = Vector2(1800, 860)
	root.add_child(pp)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1760, 820)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pp.add_child(sc)
	body = UI.vbox(10)
	body.custom_minimum_size = Vector2(1730, 0)
	sc.add_child(body)
	_show()


func on_escape() -> void:
	close()


func _show() -> void:
	for k in tab_btns.keys():
		var b: Button = tab_btns[k]
		b.add_theme_color_override("font_color", UI.GOLD_L if k == tab else UI.DIM)
	for ch in body.get_children():
		ch.queue_free()
	match tab:
		"produccion":
			_produccion()
		"mercado":
			_mercado()
		"contratos":
			_contratos()


func _avisar(t: String) -> void:
	aviso.text = t
	if t != "":
		Sfx.play("fail", -10.0)
		var a := aviso
		get_tree().create_timer(5.0).timeout.connect(func():
			if is_instance_valid(a) and a.text == t:
				a.text = "")


# ------------------------------------------------------------------ producción

const COLS := [190, 250, 250, 110, 200, 380, 150]


func _produccion() -> void:
	var intro := UI.lbl("Decida cuánto produce de cada cosa y cómo. Lo que sobra se vende fuera y lo que falta se compra, al precio del mercado o con los contratos que firme. Subir la producción va poco a poco (un punto al mes) y la capacidad se amplía con obras que tardan meses; no hay gas donde no hay yacimientos.", UI.f_sans, 16, UI.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(1700, 0)
	body.add_child(intro)
	var hh := UI.hbox(12)
	var heads := ["Recurso", "Capacidad", "Producción", "Consumo", "Balanza", "Cómo se produce", "Al mes"]
	for i in heads.size():
		var l := UI.lbl(heads[i].to_upper(), UI.f_sans_b, 13, UI.GOLD)
		l.custom_minimum_size = Vector2(COLS[i], 0)
		hh.add_child(l)
	body.add_child(hh)
	for r in R.RECURSOS.keys():
		body.add_child(_fila(r))
	_resumen_prod()


func _fila(r: String) -> Control:
	var pd := Mercado.prod(r)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.035), 8, Color(1, 1, 1, 0.08), 1, 0, 10))
	var h := UI.hbox(12)
	pc.add_child(h)
	# recurso
	var c0 := UI.vbox(0)
	c0.custom_minimum_size = Vector2(COLS[0], 0)
	var rn := UI.lbl(String(R.RECURSOS[r]["name"]), UI.f_sans_b, 19, UI.CREAM)
	rn.tooltip_text = String(R.RECURSOS[r]["desc"])
	rn.mouse_filter = Control.MOUSE_FILTER_PASS
	c0.add_child(rn)
	c0.add_child(UI.lbl("Precio %d" % int(roundf(N.precio_mercado(r))), UI.f_sans, 14, UI.DIM))
	h.add_child(c0)
	# capacidad y obras
	var c1 := UI.vbox(2)
	c1.custom_minimum_size = Vector2(COLS[1], 0)
	var t := Mercado.techo(GS.pais, r, String(pd["met"]))
	c1.add_child(UI.lbl("%s de %s posibles" % [UI.num(float(pd["cap"]), 1), UI.num(t, 1)], UI.f_sans_m, 16, UI.TEXT))
	var ob: Dictionary = pd.get("obra", {})
	if not ob.is_empty():
		var tot := maxf(1.0, float(int(ob["fin"]) - int(ob.get("ini", GS.day))))
		var hecho := clampf(float(GS.day - int(ob.get("ini", GS.day))) / tot, 0.0, 1.0)
		c1.add_child(Widgets.bar(hecho * 100.0, 200, 8, UI.GOLD))
		c1.add_child(UI.lbl("Obras: +%s el %s" % [UI.num(float(ob["cap"]), 1), UI.date_short(int(ob["fin"]))], UI.f_sans, 13, UI.GOLD_L))
	elif t - float(pd["cap"]) >= 0.25:
		var cost: Array = R.OBRAS[r]
		var ab := UI.btn("Ampliar: %s · %d meses" % [UI.money(float(cost[0])), int(cost[1])], "ghost", 13)
		ab.tooltip_text = "Una unidad más de capacidad. Se paga ahora y tarda en estar lista."
		ab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ab.pressed.connect(func():
			var e := Mercado.ampliar(r)
			if e != "":
				_avisar(e)
			_show())
		c1.add_child(ab)
	else:
		c1.add_child(UI.lbl("Al máximo con este método", UI.f_sans, 13, UI.DIM))
	h.add_child(c1)
	# producción: lo de ahora y adónde va
	var c2 := UI.vbox(2)
	c2.custom_minimum_size = Vector2(COLS[2], 0)
	var row := UI.hbox(4)
	var menos := UI.btn("−", "normal", 16)
	menos.custom_minimum_size = Vector2(40, 36)
	var mas := UI.btn("+", "normal", 16)
	mas.custom_minimum_size = Vector2(40, 36)
	var obj := float(pd["obj"])
	var nv := Mercado.nivel(r)
	var vl := UI.lbl(UI.num(obj, 1), UI.f_cond_b, 24, UI.CREAM)
	vl.custom_minimum_size = Vector2(64, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.pressed.connect(func():
		var e := Mercado.fijar_objetivo(r, obj - 0.5)
		if e != "":
			_avisar(e)
		_show())
	mas.pressed.connect(func():
		var e := Mercado.fijar_objetivo(r, obj + 0.5)
		if e != "":
			_avisar(e)
		_show())
	row.add_child(menos)
	row.add_child(vl)
	row.add_child(mas)
	c2.add_child(row)
	var estado := "Ahora: %s" % UI.num(nv, 1)
	if absf(obj - float(pd["nivel"])) > 0.01:
		estado += "  →  %s" % UI.num(obj, 1)
	var tp: Dictionary = pd.get("tope", {})
	if not tp.is_empty():
		estado += "  ·  pactado con %s" % N.nombre(String(tp.get("con", "")))
	c2.add_child(UI.lbl(estado, UI.f_sans, 13, UI.DIM if tp.is_empty() else UI.GOLD_L))
	h.add_child(c2)
	# consumo
	var c3 := UI.lbl(UI.num(Mercado.consumo(r), 1), UI.f_sans_m, 18, UI.TEXT)
	c3.custom_minimum_size = Vector2(COLS[3], 0)
	h.add_child(c3)
	# balanza
	var c4 := UI.vbox(0)
	c4.custom_minimum_size = Vector2(COLS[4], 0)
	var p := Mercado.perfil(r)
	c4.add_child(UI.lbl(("Exporta %s" % UI.num(p, 1)) if p > 0.05 else (("Importa %s" % UI.num(-p, 1)) if p < -0.05 else "Autosuficiente"), UI.f_sans_b, 16, Color(0.55, 0.8, 0.55) if p > 0.05 else (Color(0.9, 0.6, 0.45) if p < -0.05 else UI.DIM)))
	var cn := Mercado.contratado(r)
	if absf(cn) > 0.01:
		c4.add_child(UI.lbl("%s %s por contrato" % ["vende" if cn > 0.0 else "compra", UI.num(absf(cn), 1)], UI.f_sans, 13, UI.GOLD_L))
	if GS.mercado.get("cortes", {}).has(r) and p < 0.0:
		c4.add_child(UI.lbl("⚠ corte de suministro", UI.f_sans_b, 13, UI.RED.lightened(0.2)))
	h.add_child(c4)
	# método
	var c5 := UI.vbox(2)
	c5.custom_minimum_size = Vector2(COLS[5], 0)
	var obm := OptionButton.new()
	obm.add_theme_font_size_override("font_size", 15)
	var mets: Array = (R.METODOS[r] as Dictionary).keys()
	for i in mets.size():
		var md: Dictionary = R.METODOS[r][mets[i]]
		obm.add_item(String(md["name"]) + ("" if mets[i] == String(pd["met"]) else "  (cambio: %s)" % UI.money(Mercado.coste_cambio(r))), i)
		if mets[i] == String(pd["met"]):
			obm.select(i)
	obm.tooltip_text = _tooltip_metodos(r)
	obm.item_selected.connect(func(idx):
		Sfx.play("stamp", -8.0)
		Mercado.cambiar_metodo(r, String(mets[idx]))
		_show())
	c5.add_child(obm)
	var md2 := Mercado.metodo(r)
	var dl := UI.lbl("%s Coste %d." % [String(md2["desc"]), int(md2["coste"])], UI.f_sans, 13, UI.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(COLS[5], 0)
	c5.add_child(dl)
	h.add_child(c5)
	# al mes
	var s := Mercado.saldo_de(r)
	var c6 := UI.lbl(UI.money(s, true) if absf(s) >= 1.0 else "—", UI.f_sans_b, 17, Color(0.55, 0.8, 0.55) if s > 0.0 else (Color(0.9, 0.5, 0.4) if s < 0.0 else UI.DIM))
	c6.custom_minimum_size = Vector2(COLS[6], 0)
	c6.tooltip_text = "Frente a un año normal: lo que gana o pierde el país con este recurso (ventas, compras, contratos y coste de producir)."
	c6.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(c6)
	return pc


func _tooltip_metodos(r: String) -> String:
	var out := []
	for k in (R.METODOS[r] as Dictionary).keys():
		var md: Dictionary = R.METODOS[r][k]
		var fx := []
		for e in (md.get("fx", {}) as Dictionary).keys():
			fx.append("%s %s" % [GS.label_of(e), "▲" if float(md["fx"][e]) > 0.0 else "▼"])
		out.append("%s — coste %d, capacidad ×%s%s%s%s" % [md["name"], int(md["coste"]), UI.num(float(md.get("cap", 1.0)), 1), (", vende un %d %% más caro" % int(md["prima"])) if md.has("prima") else "",
			(" · " + ", ".join(fx)) if fx.size() > 0 else "", " · riesgo de accidentes" if md.has("riesgo") else ""])
	return "\n".join(out)


func _resumen_prod() -> void:
	body.add_child(Widgets.section("Efecto en %s" % W.COUNTRY_NAME))
	var tot := Mercado.saldo()
	var l := UI.lbl("Comercio exterior y producción: %s al mes frente a un año normal  ·  Economía %s  ·  Inflación %s puntos" % [UI.money(tot, true), UI.signed(Mercado.economia_mod(), 1), UI.signed(Mercado.inflacion_mod(), 1)], UI.f_sans_b, 18, Color(0.55, 0.8, 0.55) if tot >= 0.0 else Color(0.9, 0.5, 0.4))
	body.add_child(l)
	var efs := []
	for k in GS.METERS + GS.FACTIONS:
		var e := Mercado.efecto(k)
		if absf(e) >= 0.1:
			efs.append({"k": k, "v": e})
	if efs.size() > 0:
		body.add_child(UI.lbl("Lo que notan el país y la gente por cómo se produce:", UI.f_sans, 15, UI.DIM))
		body.add_child(Widgets.effect_chips(efs, 15, 10))
	var tip := UI.lbl("Si recorta la producción de lo que exporta, el precio mundial sube (y los grandes exportadores de la IA reaccionan). Si produce mucho más, baja. En la mesa de negociación puede pactar con otros países cuánto producir, a quién vender y a qué precio.", UI.f_sans, 15, UI.DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(1700, 0)
	body.add_child(tip)


# ------------------------------------------------------------------ mercado mundial

func _mercado() -> void:
	var intro := UI.lbl("Precios de este mes (100 = lo normal). Suben si el mundo produce menos (recortes, cortes, sacudidas) y bajan si produce más. Lo que %s compra fuera se encarece con ellos; lo que vende, se cobra mejor." % W.COUNTRY_NAME, UI.f_sans, 16, UI.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(1700, 0)
	body.add_child(intro)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	body.add_child(g)
	for r in R.RECURSOS.keys():
		g.add_child(_tarjeta_precio(r))
	body.add_child(Widgets.section("Nuestra posición"))
	var tot := Mercado.saldo()
	body.add_child(UI.lbl("Comercio exterior: %s al mes frente a un año normal  ·  Economía %s  ·  Inflación %s puntos" % [UI.money(tot, true), UI.signed(Mercado.economia_mod(), 1), UI.signed(Mercado.inflacion_mod(), 1)], UI.f_sans_b, 17, Color(0.55, 0.8, 0.55) if tot >= 0.0 else Color(0.9, 0.5, 0.4)))
	if R.VENTAJAS.has(GS.pais):
		body.add_child(UI.lbl("Nuestra fuerza: %s  ·  Punto débil: %s" % R.VENTAJAS[GS.pais], UI.f_sans, 15, UI.DIM))
	if GS.mercado.get("cortes", {}).has("agua"):
		body.add_child(UI.lbl("⚠ Sin el agua del río Seco: las cosechas no llegan y hay que comprar alimentos fuera.", UI.f_sans_b, 15, Color(0.9, 0.5, 0.4)))
	var tip := UI.lbl("Si la relación con un proveedor se hunde, puede cortarnos el suministro: Kharovia el gas, Qadar el petróleo, Tsaing la industria, Aldora los minerales, Norland la tecnología y Sarvenia el agua del río Seco. Un contrato a precio fijo con otro proveedor protege de los vaivenes.", UI.f_sans, 15, UI.DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(1700, 0)
	body.add_child(tip)


func _tarjeta_precio(r: String) -> Control:
	var m: Dictionary = GS.mercado
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.035), 10, Color(1, 1, 1, 0.08), 1, 0, 14))
	pc.custom_minimum_size = Vector2(560, 0)
	var v := UI.vbox(4)
	pc.add_child(v)
	var p := float(m.get("precios", {}).get(r, 100.0))
	var a := float(m.get("antes", {}).get(r, p))
	var top := UI.hbox(10)
	top.add_child(UI.lbl(String(R.RECURSOS[r]["name"]), UI.f_sans_b, 20, UI.CREAM))
	var arrow := "▲" if p > a + 0.5 else ("▼" if p < a - 0.5 else "■")
	var pcol := Color(0.9, 0.45, 0.35) if p >= 115.0 else (Color(0.45, 0.8, 0.5) if p <= 88.0 else UI.TEXT)
	top.add_child(UI.lbl("%d %s" % [int(roundf(p)), arrow], UI.f_cond_b, 26, pcol))
	var eq := Mercado.equilibrio(r)
	if absf(eq - p) >= 5.0:
		top.add_child(UI.lbl("tiende a %d" % int(roundf(eq)), UI.f_sans, 14, UI.DIM))
	v.add_child(top)
	var hist: Array = m.get("hist", {}).get(r, [])
	var ch := Control.new()
	ch.custom_minimum_size = Vector2(530, 70)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lo := 85.0
	var hi := 115.0
	for x in hist:
		lo = minf(lo, float(x) - 5.0)
		hi = maxf(hi, float(x) + 5.0)
	ch.draw.connect(func():
		ch.draw_rect(Rect2(Vector2.ZERO, ch.size), Color(1, 1, 1, 0.03))
		var y100 := ch.size.y * (1.0 - (100.0 - lo) / (hi - lo))
		ch.draw_line(Vector2(0, y100), Vector2(ch.size.x, y100), Color(1, 1, 1, 0.15), 1.0)
		ch.draw_string(UI.f_sans, Vector2(4, y100 - 3), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.3))
		Widgets.draw_line_chart(ch, Rect2(Vector2.ZERO, ch.size), hist, pcol, lo, hi, 2.0, true))
	v.add_child(ch)
	var ex := []
	var im := []
	for c in W.COUNTRIES.keys():
		var pf := N.perfil_de(c, r)
		if pf >= 2.0:
			ex.append(N.nombre(c))
		elif pf <= -2.0:
			im.append(N.nombre(c))
	var nuestro := Mercado.perfil(r)
	var info := UI.lbl("Venden: %s  ·  Compran: %s" % [", ".join(ex) if ex.size() > 0 else "—", ", ".join(im) if im.size() > 0 else "—"], UI.f_sans, 14, UI.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(530, 0)
	v.add_child(info)
	var s := Mercado.saldo_de(r)
	v.add_child(UI.lbl("%s  ·  %s al mes" % [("Exportamos %s" % UI.num(nuestro, 1)) if nuestro > 0.05 else (("Importamos %s" % UI.num(-nuestro, 1)) if nuestro < -0.05 else "Nos autoabastecemos"), UI.money(s, true) if absf(s) >= 1.0 else "sin cambios"], UI.f_sans_m, 15, Color(0.55, 0.8, 0.55) if s > 0.0 else (Color(0.9, 0.5, 0.4) if s < 0.0 else UI.TEXT)))
	return pc


# ------------------------------------------------------------------ contratos y negociaciones

func _contratos() -> void:
	body.add_child(UI.lbl("Nuestra credibilidad: %d de 100 (sube al cumplir lo que se amenaza y al respetar los contratos; baja al echarse atrás o romperlos)." % int(N.credibilidad()), UI.f_sans_m, 16, UI.TEXT))
	body.add_child(Widgets.section("Contratos en vigor"))
	var ks: Array = GS.mercado.get("contratos", [])
	if ks.is_empty():
		body.add_child(UI.lbl("Ninguno. En el mapa del mundo, «Negociar en la mesa» con cualquier país para venderle, comprarle o pactar.", UI.f_sans, 16, UI.DIM))
	for k in ks:
		var h := UI.hbox(14)
		var v := UI.vbox(0)
		v.custom_minimum_size = Vector2(1300, 0)
		v.add_child(UI.lbl(Mercado.texto_contrato(k), UI.f_sans_b, 17, UI.TEXT))
		var val := Mercado.valor_contrato(k)
		var meses := maxi(0, (int(k["hasta"]) - GS.day) / 30)
		v.add_child(UI.lbl("%s · quedan %d meses (hasta el %s)" % [("%s al mes frente al mercado de hoy" % UI.money(val, true)) if String(k.get("tipo", "")) == "venta" else "pago mensual", meses, UI.date_short(int(k["hasta"]))], UI.f_sans, 14, UI.GREEN if val >= 0.0 else UI.RED.lightened(0.2)))
		h.add_child(v)
		var mb := UI.btn("Mesa", "ghost", 15)
		var c := String(k["con"])
		mb.pressed.connect(func(): _abrir_mesa(c))
		h.add_child(mb)
		var rb := UI.btn("Romper", "ghost", 15)
		rb.tooltip_text = "Romperlo cuesta una indemnización, relación (−15) y credibilidad."
		var id := String(k["id"])
		rb.pressed.connect(func():
			N.romper(id)
			_show())
		h.add_child(rb)
		body.add_child(h)
	body.add_child(Widgets.section("Mesas de negociación"))
	var mesas: Dictionary = GS.diplo.get("mesas", {}) if GS.diplo is Dictionary else {}
	var hay := false
	for c2 in mesas.keys():
		var ms: Dictionary = mesas[c2]
		if (ms.get("hist", []) as Array).is_empty() or not W.COUNTRIES.has(c2):
			continue
		hay = true
		var h2 := UI.hbox(14)
		var estado := String(ms.get("estado", ""))
		var txt: String = {"abierta": "Propuesta sobre la mesa" + (" · esperan nuestra respuesta" if String(ms.get("autor", "")) == "ellos" else " · esperamos su respuesta"),
			"aceptada": "Último acuerdo firmado", "rechazada": "Última propuesta rechazada", "retirada": "Propuesta retirada", "caducada": "Propuesta caducada"}.get(estado, "Conversación")
		var l := UI.lbl("%s (%s): %s" % [N.nombre(c2), N.lider(c2), txt], UI.f_sans_m, 16, UI.AMBER if estado == "abierta" and String(ms.get("autor", "")) == "ellos" else UI.TEXT)
		l.custom_minimum_size = Vector2(1300, 0)
		h2.add_child(l)
		var ab := UI.btn("Abrir la mesa", "normal", 15)
		var cc: String = c2
		ab.pressed.connect(func(): _abrir_mesa(cc))
		h2.add_child(ab)
		body.add_child(h2)
	if not hay:
		body.add_child(UI.lbl("Todavía no ha negociado con nadie.", UI.f_sans, 16, UI.DIM))
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.custom_minimum_size = Vector2(1700, 0)
	for c3 in W.COUNTRIES.keys():
		var b := UI.btn("Negociar con %s" % N.nombre(c3), "ghost", 15)
		var c4: String = c3
		b.pressed.connect(func(): _abrir_mesa(c4))
		g.add_child(b)
	body.add_child(g)


func _abrir_mesa(c: String) -> void:
	close()
	if main != null:
		main.call_deferred("open_overlay", "mesa", {"con": c})
