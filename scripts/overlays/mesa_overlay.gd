extends "res://scripts/ui/overlay.gd"
## Mesa de negociación con otro país (de la IA o de otro jugador): a la izquierda, la conversación (mensajes,
## propuestas y respuestas); a la derecha, lo que hay sobre la mesa y el borrador de nuestra propuesta: lo que
## ofrecemos, lo que pedimos y, si se quiere, una amenaza. Ver systems/negociacion.gd.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const N := preload("res://scripts/systems/negociacion.gd")
const Mercado := preload("res://scripts/systems/mercado.gd")
const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")

const LEFT := Rect2(60, 140, 760, 880)
const RIGHT := Rect2(850, 140, 1010, 880)

var con := ""
var borrador := {"da": [], "pide": [], "amenaza": {}}
var hist_box: VBoxContainer
var hist_scroll: ScrollContainer
var der: VBoxContainer
var entrada: LineEdit
## Mientras el otro «piensa», lo último que ha contestado aún no se enseña
var pensando := false
var _oculto := 0


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.95)
	con = String(data.get("con", data.get("who", "norland")))
	if not W.COUNTRIES.has(con):
		con = String(W.COUNTRIES.keys()[0])
	var cd: Dictionary = W.COUNTRIES[con]
	var head := title_bar("Mesa de negociación", "%s · %s %s" % [cd["name"], cd["title"], N.lider(con)], "acuerdo")
	head.position = Vector2(60, 40)
	root.add_child(head)
	var close_b := close_button("Volver al despacho")
	close_b.position = Vector2(1640, 48)
	root.add_child(close_b)
	N.mesa(con)["nuevo"] = false
	_izquierda()
	der = UI.vbox(12)
	var dp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.45), 20)
	dp.position = RIGHT.position
	dp.custom_minimum_size = RIGHT.size
	dp.size = RIGHT.size
	var dsc := ScrollContainer.new()
	dsc.custom_minimum_size = RIGHT.size - Vector2(40, 40)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dsc.add_child(der)
	der.custom_minimum_size = Vector2(RIGHT.size.x - 64, 0)
	dp.add_child(dsc)
	root.add_child(dp)
	# un primer borrador con sentido: lo que nos falta o lo que nos sobra
	if (borrador["da"] as Array).is_empty() and (borrador["pide"] as Array).is_empty():
		borrador = _borrador_inicial()
	_conversacion()
	_derecha()
	# en línea: si el otro jugador contesta o escribe mientras la mesa está abierta, se ve al momento
	Red.nego.connect(_de_la_red)
	Red.mensaje.connect(_mensaje_red)


func _mensaje_red(de: String, _t: String) -> void:
	_de_la_red(de, "texto")


func _de_la_red(de: String, _tipo: String) -> void:
	if de != con or closing or not is_inside_tree():
		return
	N.mesa(con)["nuevo"] = false
	Sfx.play("notify", -10.0, 1.3)
	_conversacion()
	_derecha()


func on_escape() -> void:
	close()


# ------------------------------------------------------------------ izquierda: el otro país y la conversación

func _izquierda() -> void:
	var lp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.45), 18)
	lp.position = LEFT.position
	lp.custom_minimum_size = LEFT.size
	lp.size = LEFT.size
	root.add_child(lp)
	var v := UI.vbox(10)
	lp.add_child(v)
	var top := UI.hbox(16)
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(96, 110)
	pc.clip_contents = true
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mp := Portrait.new()
	mp.position = Vector2(-12, -6)
	mp.size = Vector2(120, 146)
	mp.track_mouse = false
	pc.add_child(mp)
	mp.setup(W.COUNTRIES[con].get("look", {}), false)
	top.add_child(pc)
	var tv := UI.vbox(3)
	tv.add_child(UI.lbl(N.lider(con), UI.f_serif_b, 28, UI.CREAM))
	var cd: Dictionary = W.COUNTRIES[con]
	var pers: Dictionary = W.PERSONALITIES.get(GS.country_pers(con), {"name": "?"})
	tv.add_child(UI.lbl(("Otro jugador · Poder %d" % int(cd["power"])) if N.humano(con) else ("Carácter: %s · Poder %d (nosotros, %d)" % [pers["name"], int(cd["power"]), int(N.mi_poder())]), UI.f_sans, 15, UI.DIM))
	var rel := float(GS.countries[con]["rel"])
	tv.add_child(UI.lbl("Relación: %s  ·  Nuestra credibilidad: %d/100" % [UI.signed(rel, 0), int(N.credibilidad())], UI.f_sans_m, 15, UI.color_for(50.0 + rel * 0.5)))
	var rs := Mercado.resumen(con)
	if rs != "":
		tv.add_child(UI.lbl(rs, UI.f_sans, 14, UI.GOLD_L))
	top.add_child(tv)
	var fl := Control.new()
	fl.custom_minimum_size = Vector2(90, 58)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.draw.connect(func():
		var x := fl.size.x - 90.0
		Flags.draw_flag(fl, con, Rect2(x, 0, 90, 58))
		fl.draw_rect(Rect2(x, 0, 90, 58), Color(1, 1, 1, 0.3), false, 1.0))
	top.add_child(fl)
	v.add_child(top)
	v.add_child(Widgets.section("Conversación"))
	hist_scroll = ScrollContainer.new()
	hist_scroll.custom_minimum_size = Vector2(LEFT.size.x - 36, LEFT.size.y - 260)
	hist_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(hist_scroll)
	hist_box = UI.vbox(10)
	hist_box.custom_minimum_size = Vector2(LEFT.size.x - 60, 0)
	hist_scroll.add_child(hist_box)
	var bar := UI.hbox(8)
	entrada = LineEdit.new()
	entrada.placeholder_text = "Escriba a %s..." % N.lider(con)
	entrada.max_length = 240
	entrada.custom_minimum_size = Vector2(LEFT.size.x - 36 - 110, 46)
	entrada.add_theme_font_override("font", UI.f_sans)
	entrada.add_theme_font_size_override("font_size", 17)
	bar.add_child(entrada)
	var send := UI.btn("Enviar", "normal", 16)
	send.custom_minimum_size = Vector2(100, 46)
	bar.add_child(send)
	var enviar := func():
		var t := entrada.text.strip_edges()
		if t == "" or pensando:
			return
		entrada.text = ""
		Sfx.play("whoosh", -10.0, 1.6)
		var antes := (N.mesa(con)["hist"] as Array).size()
		N.escribir(con, t)
		_espera(antes + 1)
	entrada.text_submitted.connect(func(_t): enviar.call())
	send.pressed.connect(enviar)
	v.add_child(bar)


## Enseña la respuesta del otro tras un momento («pensando...»). desde: lo que ya se puede ver.
func _espera(desde: int) -> void:
	var hist: Array = N.mesa(con)["hist"]
	if N.humano(con) or hist.size() <= desde:
		_conversacion()
		_derecha()
		return
	pensando = true
	_oculto = desde
	_conversacion()
	_derecha()
	get_tree().create_timer(1.3).timeout.connect(func():
		if not is_instance_valid(self) or closing:
			return
		pensando = false
		Sfx.play("notify", -12.0, 1.4)
		_conversacion()
		_derecha())


func _conversacion() -> void:
	for ch in hist_box.get_children():
		ch.queue_free()
	var hist: Array = N.mesa(con)["hist"]
	var hasta := _oculto if pensando else hist.size()
	if hist.is_empty():
		var l := UI.lbl("Todavía no han hablado. Escriba a %s o ponga una propuesta sobre la mesa: qué ofrece, qué pide y, si quiere, con qué amenaza." % N.lider(con), UI.f_sans, 16, UI.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LEFT.size.x - 70, 0)
		hist_box.add_child(l)
	for i in mini(hasta, hist.size()):
		hist_box.add_child(_entrada_hist(hist[i]))
	if pensando:
		hist_box.add_child(_burbuja("• • •", false))
	var sc := hist_scroll
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(sc):
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value))


func _entrada_hist(e: Dictionary) -> Control:
	var de := String(e.get("de", ""))
	var mio := de == "yo"
	match String(e.get("tipo", "")):
		"texto":
			return _burbuja(String(e["t"]), mio)
		"propuesta":
			return _tarjeta_prop(e.get("prop", {}), mio, String(e.get("t", "")))
		_:
			var col := UI.GREEN if e["tipo"] == "acepta" else (UI.RED if e["tipo"] == "rechaza" else UI.DIM)
			var quien := "Nosotros" if mio else (N.lider(con) if de == "ellos" else "")
			var t := String(e.get("t", ""))
			var l := UI.lbl(("%s: %s" % [quien, t]) if quien != "" else t, UI.f_sans_m, 15, col)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(LEFT.size.x - 80, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			return l


func _burbuja(texto: String, mio: bool) -> Control:
	var row := HBoxContainer.new()
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", UI.sb(Color("1d4f8f") if mio else Color("2a3442"), 14, Color(0, 0, 0, 0), 0, 0, 12))
	var t := UI.lbl(texto, UI.f_sans, 16, Color.WHITE)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(minf(520.0, 30.0 + texto.length() * 8.5), 0)
	b.add_child(t)
	if mio:
		row.add_child(UI.spacer(0, 0, true))
	row.add_child(b)
	return row


func _tarjeta_prop(p: Dictionary, mio: bool, txt: String) -> Control:
	var pc := PanelContainer.new()
	var st := UI.sb(Color(0.07, 0.1, 0.16, 0.95), 10, Color(UI.GOLD, 0.5) if not mio else Color(UI.BLUE, 0.5), 1, 0, 14)
	pc.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(4)
	pc.add_child(v)
	v.add_child(UI.lbl("PROPUESTA DE %s" % ("NOSOTROS" if mio else N.lider(con).to_upper()), UI.f_sans_b, 13, UI.GOLD if not mio else UI.BLUE))
	if txt != "":
		var tl := UI.lbl(txt, UI.f_serif, 16, UI.CREAM)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(LEFT.size.x - 100, 0)
		v.add_child(tl)
	for cl in p.get("pide", []):
		v.add_child(_linea_cl("▼ Recibimos: ", cl, "pide", UI.GREEN))
	for cl2 in p.get("da", []):
		v.add_child(_linea_cl("▲ Damos: ", cl2, "da", UI.AMBER))
	return pc


func _linea_cl(pre: String, cl: Dictionary, lado: String, col: Color) -> Control:
	var l := UI.lbl(pre + N.texto(cl, lado), UI.f_sans, 15, col.lightened(0.3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LEFT.size.x - 100, 0)
	return l


# ------------------------------------------------------------------ derecha: lo que hay sobre la mesa y el borrador

func _derecha() -> void:
	for ch in der.get_children():
		ch.queue_free()
	var ms := N.mesa(con)
	var abierta := N.abierta(con) and not pensando
	if abierta and String(ms["autor"]) == "ellos":
		_sobre_la_mesa(ms)
	elif abierta and String(ms["autor"]) == "yo":
		der.add_child(Widgets.section("Esperando respuesta"))
		var l := UI.lbl("%s está estudiando su propuesta. Caduca el %s." % [N.lider(con), UI.date_short(int(ms["caduca"]))], UI.f_sans, 16, UI.TEXT)
		der.add_child(l)
		var rb := UI.btn("Retirar la propuesta", "ghost", 15)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rb.pressed.connect(func():
			N.retirar(con)
			_conversacion()
			_derecha())
		der.add_child(rb)
	_editor()
	_contratos()


## Su propuesta: aceptar, rechazar o hacer una contraoferta
func _sobre_la_mesa(ms: Dictionary) -> void:
	var p: Dictionary = ms["prop"]
	der.add_child(Widgets.section("Sobre la mesa: su propuesta"))
	var box := UI.vbox(4)
	for cl in p.get("pide", []):
		box.add_child(_linea_der("Recibimos: ", cl, "pide", UI.GREEN))
	for cl2 in p.get("da", []):
		box.add_child(_linea_der("Damos: ", cl2, "da", UI.AMBER))
	var am: Dictionary = p.get("amenaza", {})
	if not am.is_empty():
		var al := UI.lbl("⚠ Si no aceptamos: %s." % N.texto_amenaza(am).replace("si no, ", "").replace("cortarles", "nos cortarán").replace("sanciones económicas", "habrá sanciones"), UI.f_sans_b, 15, UI.RED.lightened(0.2))
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(RIGHT.size.x - 90, 0)
		box.add_child(al)
	der.add_child(box)
	der.add_child(_valoracion(p, false))
	var h := UI.hbox(10)
	var ok := UI.btn("Aceptar", "gold", 18)
	ok.pressed.connect(func():
		N.aceptar(con)
		_conversacion()
		_derecha())
	h.add_child(ok)
	var no := UI.btn("Rechazar", "danger", 17)
	no.pressed.connect(func():
		var antes := (N.mesa(con)["hist"] as Array).size()
		N.rechazar(con)
		_espera(antes + 1))
	h.add_child(no)
	var co := UI.btn("Contraoferta: editarla abajo", "normal", 17)
	co.pressed.connect(func():
		borrador = {"da": (p.get("da", []) as Array).duplicate(true), "pide": (p.get("pide", []) as Array).duplicate(true), "amenaza": {}}
		_derecha())
	h.add_child(co)
	der.add_child(h)


func _linea_der(pre: String, cl: Dictionary, lado: String, col: Color) -> Control:
	var l := UI.lbl(pre + N.texto(cl, lado), UI.f_sans_m, 16, col.lightened(0.25))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(RIGHT.size.x - 90, 0)
	return l


## Para nosotros (frente al mercado) y, con la IA, lo que cree Exteriores que harán
func _valoracion(p: Dictionary, propia: bool) -> Control:
	var v := UI.vbox(2)
	var vp := N.valor_propio(p)
	var partes := []
	if absf(float(vp["mes"])) >= 1.0:
		partes.append("%s al mes frente al mercado" % UI.money(float(vp["mes"]), true))
	if absf(float(vp["una"])) >= 1.0:
		partes.append("%s de una vez" % UI.money(float(vp["una"]), true))
	for o in vp["otros"]:
		partes.append(String(o))
	if partes.size() > 0:
		var l := UI.lbl("Para nosotros: " + " · ".join(partes), UI.f_sans_m, 15, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(RIGHT.size.x - 90, 0)
		v.add_child(l)
	if propia:
		if N.humano(con):
			v.add_child(UI.lbl("Lo decide %s, otro jugador." % N.lider(con), UI.f_sans, 15, UI.DIM))
		else:
			var pr := N.pronostico(con, p)
			if pr != "":
				var txt: String = {"acepta": "Exteriores cree que la aceptarán.", "contra": "Exteriores cree que harán una contraoferta.", "rechaza": "Exteriores cree que la rechazarán."}[pr]
				v.add_child(UI.lbl(txt, UI.f_sans_b, 15, {"acepta": UI.GREEN, "contra": UI.AMBER, "rechaza": UI.RED}[pr].lightened(0.2)))
	return v


# ------------------------------------------------------------------ borrador

func _borrador_inicial() -> Dictionary:
	var b := {"da": [], "pide": [], "amenaza": {}}
	var falta := ""
	var fv := -0.4
	var sobra := ""
	var sv := 0.4
	for r in R.RECURSOS.keys():
		var p := Mercado.perfil(r) - Mercado.contratado(r)
		if p < fv and N.perfil_de(con, r) >= 1.0:
			fv = p
			falta = r
		if p > sv and N.perfil_de(con, r) <= -1.0:
			sv = p
			sobra = r
	if falta != "":
		b["pide"].append(_cl_venta(falta, minf(2.0, snappedf(-fv, 0.5))))
	elif sobra != "":
		b["da"].append(_cl_venta(sobra, minf(2.0, snappedf(sv, 0.5))))
	return b


func _cl_venta(r: String, vol: float) -> Dictionary:
	return {"tipo": "venta", "r": r, "vol": maxf(0.5, vol), "precio": roundf(N.precio_mercado(r)), "meses": 12}


func _editor() -> void:
	var ms := N.mesa(con)
	var es_contra := N.abierta(con) and String(ms["autor"]) == "ellos"
	der.add_child(Widgets.section("Contraoferta" if es_contra else "Nuestra propuesta"))
	var cols := UI.hbox(18)
	for lado in ["da", "pide"]:
		var c := UI.vbox(8)
		c.custom_minimum_size = Vector2((RIGHT.size.x - 100) / 2.0, 0)
		c.add_child(UI.lbl("LO QUE OFRECEMOS" if lado == "da" else "LO QUE PEDIMOS", UI.f_sans_b, 14, UI.AMBER if lado == "da" else UI.GREEN))
		for i in (borrador[lado] as Array).size():
			c.add_child(_fila(lado, i))
		c.add_child(_menu_anadir(lado))
		cols.add_child(c)
	der.add_child(cols)
	# amenaza
	var ah := UI.hbox(10)
	ah.add_child(UI.lbl("Si la rechazan:", UI.f_sans_b, 15, UI.TEXT))
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 15)
	var ops := [["", "Nada: sin amenazas"]]
	var arma := String(R.ARMAS.get(GS.pais, ""))
	if arma != "" and (arma == "agua" and con == "valdoria" or arma != "agua" and N.perfil_de(con, arma) < 0.0):
		ops.append(["corte", "Cortarles " + ("el agua del río Seco" if arma == "agua" else "el " + N.rnom(arma))])
	for k in ["sanciones", "embargo", "aranceles", "embajador", "tropas"]:
		ops.append([k, String(N.AMENAZAS[k]["name"])])
	var sel := 0
	for i in ops.size():
		ob.add_item(ops[i][1], i)
		if String((borrador["amenaza"] as Dictionary).get("k", "")) == ops[i][0]:
			sel = i
	ob.select(sel)
	ob.item_selected.connect(func(idx):
		var k: String = ops[idx][0]
		borrador["amenaza"] = {} if k == "" else ({"k": k, "r": arma} if k == "corte" else {"k": k})
		_derecha())
	ah.add_child(ob)
	der.add_child(ah)
	if not (borrador["amenaza"] as Dictionary).is_empty():
		var al := UI.lbl("Amenazar ofende (la relación baja aunque acepten). Si la rechazan, tendrá que decidir si la cumple: echarse atrás hunde su credibilidad (%d/100)." % int(N.credibilidad()), UI.f_sans, 14, UI.AMBER.lightened(0.2))
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(RIGHT.size.x - 90, 0)
		der.add_child(al)
	var vacio := (borrador["da"] as Array).is_empty() and (borrador["pide"] as Array).is_empty()
	if not vacio:
		der.add_child(_valoracion(borrador, true))
	var nota := UI.lbl("", UI.f_sans, 14, UI.DIM)
	var mensaje := LineEdit.new()
	mensaje.placeholder_text = "Unas palabras para acompañarla (opcional)"
	mensaje.max_length = 200
	mensaje.custom_minimum_size = Vector2(RIGHT.size.x - 90, 40)
	mensaje.add_theme_font_override("font", UI.f_sans)
	mensaje.add_theme_font_size_override("font_size", 16)
	der.add_child(mensaje)
	var go := UI.btn("Enviar contraoferta" if es_contra else "Poner la propuesta sobre la mesa", "gold", 18)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.disabled = vacio or pensando or (N.abierta(con) and String(ms["autor"]) == "yo")
	go.pressed.connect(func():
		Sfx.play("stamp", -8.0)
		var antes := (N.mesa(con)["hist"] as Array).size()
		N.proponer(con, borrador.duplicate(true), mensaje.text.strip_edges())
		borrador = {"da": [], "pide": [], "amenaza": {}}
		_espera(antes + 1))
	der.add_child(go)
	if N.abierta(con) and String(ms["autor"]) == "yo":
		nota.text = "Ya tiene una propuesta sobre la mesa: espere la respuesta o retírela."
		der.add_child(nota)


## Una fila del borrador, con sus mandos
func _fila(lado: String, i: int) -> Control:
	var cl: Dictionary = borrador[lado][i]
	var box := UI.vbox(4)
	var st := PanelContainer.new()
	st.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.04), 8, Color(1, 1, 1, 0.1), 1, 0, 10))
	st.add_child(box)
	var top := UI.hbox(6)
	var tl := UI.lbl(N.texto(cl, lado), UI.f_sans_m, 14, UI.TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2((RIGHT.size.x - 100) / 2.0 - 60, 0)
	top.add_child(tl)
	var x := UI.btn("✕", "ghost", 14)
	x.tooltip_text = "Quitar"
	x.pressed.connect(func():
		(borrador[lado] as Array).remove_at(i)
		_derecha())
	top.add_child(x)
	box.add_child(top)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 4)
	match String(cl["tipo"]):
		"venta":
			h.add_child(_selector_recurso(cl, false))
			h.add_child(_paso(cl, "vol", 0.5, 0.5, 6.0, "u./mes", 1))
			h.add_child(_paso(cl, "precio", 2.0, 40.0, 260.0, "precio", 0))
			h.add_child(_paso(cl, "meses", 3.0, 3.0, 36.0, "meses", 0))
			var pm := N.precio_mercado(String(cl["r"]))
			box.add_child(h)
			box.add_child(UI.lbl("Mercado hoy: %d · %s" % [int(roundf(pm)), _quien_tiene(String(cl["r"]), lado)], UI.f_sans, 13, UI.DIM))
			return st
		"dinero":
			h.add_child(_paso(cl, "m", 100.0, 100.0, 20000.0, "M", 0))
		"dinero_mes":
			h.add_child(_paso(cl, "m", 50.0, 50.0, 3000.0, "M/mes", 0))
			h.add_child(_paso(cl, "meses", 3.0, 3.0, 36.0, "meses", 0))
		"tratado":
			var ob := OptionButton.new()
			ob.add_theme_font_size_override("font_size", 14)
			var keys := N.TRATADOS.keys()
			for j in keys.size():
				ob.add_item(String(N.TRATADOS[keys[j]]["name"]) + (" (ya firmado)" if N.tiene_tratado(con, keys[j]) else ""), j)
				if keys[j] == String(cl["k"]):
					ob.select(j)
			ob.item_selected.connect(func(idx):
				cl["k"] = keys[idx]
				_derecha())
			h.add_child(ob)
		"reabrir":
			h.add_child(_selector_recurso(cl, true))
		"levantar":
			var ob2 := OptionButton.new()
			ob2.add_theme_font_size_override("font_size", 14)
			ob2.add_item("Sanciones", 0)
			ob2.add_item("Embargo", 1)
			ob2.select(1 if String(cl["k"]) == "embargo" else 0)
			ob2.item_selected.connect(func(idx):
				cl["k"] = "embargo" if idx == 1 else "sanciones"
				_derecha())
			h.add_child(ob2)
		"produccion":
			h.add_child(_selector_recurso(cl, false))
			h.add_child(_paso(cl, "d", 0.5, -4.0, 4.0, "u./mes", 1))
			h.add_child(_paso(cl, "meses", 3.0, 3.0, 24.0, "meses", 0))
		"compromiso":
			var le := LineEdit.new()
			le.text = String(cl.get("t", ""))
			le.placeholder_text = "Escriba la promesa"
			le.max_length = 120
			le.custom_minimum_size = Vector2((RIGHT.size.x - 100) / 2.0 - 30, 36)
			le.text_changed.connect(func(t): cl["t"] = t)
			h.add_child(le)
	box.add_child(h)
	return st


## Quién vende o compra ese recurso (para saber si tiene sentido pedírselo)
func _quien_tiene(r: String, lado: String) -> String:
	var pf := N.perfil_de(con, r)
	var nm := N.nombre(con)
	if lado == "pide":
		return ("a %s le sobra" % nm) if pf > 0.0 else ("%s también lo compra fuera" % nm)
	return ("%s lo necesita" % nm) if pf < 0.0 else ("a %s no le hace falta" % nm)


func _selector_recurso(cl: Dictionary, solo_cortes: bool) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 14)
	var keys := R.RECURSOS.keys()
	if solo_cortes:
		keys = keys + ["agua"]
	for j in keys.size():
		var rn := N.rnom(keys[j])
		ob.add_item(rn.left(1).to_upper() + rn.substr(1), j)
		if keys[j] == String(cl["r"]):
			ob.select(j)
	ob.item_selected.connect(func(idx):
		cl["r"] = keys[idx]
		if cl["tipo"] == "venta":
			cl["precio"] = roundf(N.precio_mercado(keys[idx]))
		_derecha())
	return ob


## Un valor con − y + (cantidad, precio, meses...)
func _paso(cl: Dictionary, k: String, paso: float, lo: float, hi: float, unidad: String, dec: int) -> Control:
	var h := UI.hbox(2)
	var menos := UI.btn("−", "ghost", 16)
	var mas := UI.btn("+", "ghost", 16)
	var val := float(cl.get(k, lo))
	var txt := UI.money(val) if unidad == "M" else (UI.money(val) + "/mes" if unidad == "M/mes" else "%s %s" % [UI.num(val, dec), unidad])
	if k == "precio":
		txt = "a %d" % int(val)
	var l := UI.lbl(txt, UI.f_sans_b, 15, UI.CREAM)
	l.custom_minimum_size = Vector2(96 if unidad.begins_with("M") else 78, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.pressed.connect(func():
		cl[k] = clampf(snappedf(float(cl.get(k, lo)) - paso, paso), lo, hi)
		if k == "d" and absf(float(cl[k])) < 0.01:
			cl[k] = -paso
		_derecha())
	mas.pressed.connect(func():
		cl[k] = clampf(snappedf(float(cl.get(k, lo)) + paso, paso), lo, hi)
		if k == "d" and absf(float(cl[k])) < 0.01:
			cl[k] = paso
		_derecha())
	h.add_child(menos)
	h.add_child(l)
	h.add_child(mas)
	return h


func _menu_anadir(lado: String) -> Control:
	var mb := MenuButton.new()
	mb.text = "+ Añadir"
	mb.flat = false
	mb.add_theme_font_size_override("font_size", 15)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pm := mb.get_popup()
	pm.add_theme_font_size_override("font_size", 16)
	var items := [["venta", "Venderles un recurso" if lado == "da" else "Que nos vendan un recurso"], ["dinero", "Un pago" if lado == "da" else "Que nos paguen"],
		["dinero_mes", "Pagos mensuales" if lado == "da" else "Que nos paguen cada mes"], ["tratado", "Un tratado"],
		["produccion", "Cambiar nuestra producción" if lado == "da" else "Que cambien su producción"], ["levantar", "Levantarles sanciones o embargo" if lado == "da" else "Que nos levanten sanciones"],
		["reabrir", "Reabrirles un suministro" if lado == "da" else "Que nos reabran un suministro"], ["compromiso", "Una promesa (con sus palabras)"]]
	for i in items.size():
		pm.add_item(items[i][1], i)
	pm.id_pressed.connect(func(id):
		var tipo: String = items[id][0]
		var cl := {"tipo": tipo}
		match tipo:
			"venta":
				cl = _cl_venta(_mejor_recurso(lado), 1.0)
			"dinero":
				cl["m"] = 500.0
			"dinero_mes":
				cl["m"] = 100.0
				cl["meses"] = 12
			"tratado":
				cl["k"] = "comercio"
				for k in N.TRATADOS.keys():
					if not N.tiene_tratado(con, k):
						cl["k"] = k
						break
			"produccion":
				cl["r"] = _mejor_recurso("da" if lado == "da" else "pide_prod")
				cl["d"] = -1.0
				cl["meses"] = 6
			"levantar":
				cl["k"] = "embargo" if Mercado.embargado(con) else "sanciones"
			"reabrir":
				cl["r"] = String(Red.cortes_propios.get(con, R.ARMAS.get(GS.pais, "gas"))) if lado == "da" else _corte_de()
			"compromiso":
				cl["t"] = ""
		borrador[lado].append(cl)
		_derecha())
	return mb


## Recurso con más sentido: lo que nos sobra y a ellos les falta (si les vendemos), lo que nos falta y a ellos les
## sobra (si nos venden), su exportación principal (si cambian su producción)
func _mejor_recurso(lado: String) -> String:
	var best := String(R.RECURSOS.keys()[0])
	var bv := -999.0
	for r in R.RECURSOS.keys():
		var nuestro := Mercado.perfil(r) - Mercado.contratado(r)
		var suyo := N.perfil_de(con, r)
		var v := 0.0
		match lado:
			"da":
				v = nuestro - suyo
			"pide":
				v = suyo - nuestro
			"pide_prod":
				v = suyo
		if v > bv:
			bv = v
			best = r
	return best


## Lo que nos tienen cortado (para pedir que lo reabran)
func _corte_de() -> String:
	for r in GS.mercado.get("cortes", {}).keys():
		if String(GS.mercado["cortes"][r]["who"]) == con:
			return String(r)
	return String(R.ARMAS.get(con, "gas"))


# ------------------------------------------------------------------ contratos con este país

func _contratos() -> void:
	var ks := Mercado.contratos_con(con)
	if ks.is_empty():
		return
	der.add_child(Widgets.section("Contratos en vigor con %s" % N.nombre(con)))
	for k in ks:
		var h := UI.hbox(10)
		var v := UI.vbox(0)
		v.custom_minimum_size = Vector2(RIGHT.size.x - 260, 0)
		v.add_child(UI.lbl(Mercado.texto_contrato(k), UI.f_sans_m, 15, UI.TEXT))
		var val := Mercado.valor_contrato(k)
		v.add_child(UI.lbl("%s · hasta el %s" % [("%s al mes frente al mercado" % UI.money(val, true)) if String(k.get("tipo", "")) == "venta" else "pago mensual", UI.date_short(int(k["hasta"]))], UI.f_sans, 13, UI.GREEN if val >= 0.0 else UI.RED.lightened(0.2)))
		h.add_child(v)
		var rb := UI.btn("Romper", "ghost", 14)
		rb.tooltip_text = "Romperlo cuesta una indemnización, relación (−15) y credibilidad."
		var id := String(k["id"])
		rb.pressed.connect(func():
			N.romper(id)
			_conversacion()
			_derecha())
		h.add_child(rb)
		der.add_child(h)
