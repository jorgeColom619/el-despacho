extends Node
## Prueba de la partida en línea con dos copias del juego en el mismo ordenador:
##   godot --headless --path . -- --redtest=anfitrion --pais=kharovia
##   godot --headless --path . -- --redtest=invitado --pais=valdoria
## El anfitrión crea la partida (sin UPnP), el invitado se une por 127.0.0.1, empiezan, el reloj corre, se mandan
## un mensaje, un tratado, sanciones y un corte de gas, y cada uno imprime su estado: los dos deben ir por el mismo
## día y con los mismos precios.
## Mesa de negociación (5.1): el anfitrión propone un contrato de venta con un pago y una amenaza; el invitado
## contraoferta más barato; el anfitrión acepta. Los dos deben acabar con el mismo contrato visto desde cada lado.
## Después, una exigencia con amenaza que el invitado rechaza: el anfitrión la cumple (aranceles). El invitado
## sube su producción y el anfitrión lo tiene en cuenta para el precio mundial.

const PUERTO := 24599
const W := preload("res://scripts/data/world_data.gd")
const N := preload("res://scripts/systems/negociacion.gd")
const R := preload("res://scripts/data/recursos_data.gd")

var main: Node
var rol := "anfitrion"
var pais := "valdoria"
var t := 0.0
var fase := "sala"
var inicio := 0
var hecho := {}
var otro := ""


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--redtest="):
			rol = a.substr(10)
		elif a.begins_with("--pais="):
			pais = a.substr(7)
	if Red.empezar_partida.is_connected(main.start_new):
		Red.empezar_partida.disconnect(main.start_new)
	# sin ventanas: aquí nadie las cierra (y con todos «ocupados» el reloj del mundo se pararía)
	if GS.open_request.is_connected(main._on_request):
		GS.open_request.disconnect(main._on_request)
	Red.empezar_partida.connect(_empezar)
	Red.estado.connect(func(s: String): print("[%s] %s" % [rol, s]))
	Red.mensaje.connect(func(de: String, texto: String): print("[%s] MENSAJE de %s: %s" % [rol, de, texto]))
	Red.yo = {"name": "Prueba %s" % rol, "pais": pais, "party": "MP", "look": {}}
	if rol == "anfitrion":
		Red.crear(PUERTO, false)
		Red.cambiar_config({"years": 1, "difficulty": 1, "mode": "clasico"})
	else:
		await get_tree().create_timer(1.5).timeout
		Red.unirse("127.0.0.1", PUERTO)


func _empezar(opts: Dictionary) -> void:
	GS.no_save = true
	GS.new_game(opts)
	Red.preparar_mundo()
	inicio = GS.day
	fase = "juego"
	for id in Red.jugadores.keys():
		if String(Red.jugadores[id]["pais"]) != GS.pais:
			otro = String(Red.jugadores[id]["pais"])
	print("[%s] EMPIEZA como %s (%s) contra %s · líder rival en mi mundo: %s · humano: %s" % [rol, W.COUNTRY_NAME, GS.pres["name"], otro,
		W.COUNTRIES.get(otro, {}).get("leader", "?"), Red.es_humano(otro)])
	if rol == "anfitrion":
		await get_tree().create_timer(0.5).timeout
		GS.set_speed(3)


func _process(delta: float) -> void:
	t += delta
	if t > 240.0:
		print("[%s] REDTEST FALLO: tiempo agotado en la fase %s (día %d)" % [rol, fase, GS.day])
		_salir()
		return
	if fase == "sala":
		if rol == "anfitrion" and Red.jugadores.size() >= 2 and Red.motivo_no_empezar() == "":
			print("[%s] sala: %s" % [rol, Red.jugadores])
			Red.empezar()
		return
	if fase != "juego":
		return
	_resolver()
	var d := GS.day - inicio
	if rol == "anfitrion" and d >= 15 and not hecho.has("a"):
		hecho["a"] = true
		Red.accion(otro, "mensaje", {"texto": "Hola, vecino. ¿Hablamos de comercio?"})
		Red.proponer(otro, "comercio")
		print("[%s] envío mensaje y propuesta de tratado comercial" % rol)
	if rol == "anfitrion" and d >= 30 and not hecho.has("b"):
		hecho["b"] = true
		Red.accion(otro, "sanciones")
		var r: String = GS.Mercado.R.ARMAS.get(GS.pais, "")
		if r != "" and ((r == "agua" and otro == "valdoria") or (r != "agua" and int(GS.Mercado.R.PERFILES.get(otro, {}).get(r, 0)) < 0)):
			Red.accion(otro, "corte", {"recurso": r})
			print("[%s] sanciones y corte de %s" % [rol, r])
		else:
			print("[%s] sanciones" % rol)
	if rol == "invitado" and d >= 45 and not hecho.has("c"):
		hecho["c"] = true
		Red.accion(otro, "mensaje", {"texto": "Recibido. Firmo el tratado, pero quite las sanciones."})
		print("[%s] contesto con un mensaje" % rol)
	# --- mesa de negociación
	if rol == "anfitrion" and d >= 50 and not hecho.has("n1"):
		hecho["n1"] = true
		var r := _recurso_para(otro)
		var pm := N.precio_mercado(r)
		N.proponer(otro, {"da": [{"tipo": "venta", "r": r, "vol": 1.5, "precio": roundf(pm + 5.0), "meses": 12}], "pide": [{"tipo": "dinero", "m": 300.0}], "amenaza": {"k": "aranceles"}}, "Un suministro estable para su invierno.")
		print("[%s] MESA: propongo venderle %s a %d (mercado %d) + 300 M, con amenaza de aranceles" % [rol, r, int(pm + 5.0), int(pm)])
	if rol == "invitado" and d >= 55 and not hecho.has("n2") and N.abierta(otro) and String(N.mesa(otro)["autor"]) == "ellos":
		hecho["n2"] = true
		var p: Dictionary = N.mesa(otro)["prop"]
		var co := {"da": [], "pide": [], "amenaza": {}}
		for cl in p["pide"]:
			if cl["tipo"] == "venta":
				var c2: Dictionary = cl.duplicate()
				c2["precio"] = float(cl["precio"]) - 8.0
				co["pide"].append(c2)
		print("[%s] MESA: recibo «%s» · amenaza: %s · contraoferta sin el pago y 8 puntos más barato" % [rol, N.resumen(p), N.texto_amenaza(p.get("amenaza", {}))])
		N.proponer(otro, co, "Sin el pago, y algo más barato.")
	if rol == "anfitrion" and d >= 60 and not hecho.has("n3") and N.abierta(otro) and String(N.mesa(otro)["autor"]) == "ellos":
		hecho["n3"] = true
		print("[%s] MESA: recibo la contraoferta «%s» y la acepto" % [rol, N.resumen(N.mesa(otro)["prop"])])
		N.aceptar(otro)
	if rol == "invitado" and d >= 50 and not hecho.has("prod"):
		hecho["prod"] = true
		var rp := "industria"
		var e := GS.Mercado.fijar_objetivo(rp, float(GS.Mercado.prod(rp)["cap"]))
		print("[%s] PRODUCCIÓN: subo %s a %.1f %s" % [rol, rp, float(GS.Mercado.prod(rp)["cap"]), e])
	if rol == "anfitrion" and d >= 80 and not hecho.has("n4"):
		hecho["n4"] = true
		N.proponer(otro, {"da": [], "pide": [{"tipo": "dinero", "m": 2000.0}], "amenaza": {"k": "aranceles"}}, "Págueme o habrá aranceles.")
		print("[%s] MESA: exijo 2.000 M con amenaza de aranceles (credibilidad %d)" % [rol, int(N.credibilidad())])
	if rol == "invitado" and d >= 85 and not hecho.has("n5") and N.abierta(otro) and String(N.mesa(otro)["autor"]) == "ellos":
		hecho["n5"] = true
		print("[%s] MESA: rechazo la exigencia" % rol)
		N.rechazar(otro, "No pagamos chantajes.")
	if d >= 110 and not hecho.has("fin"):
		hecho["fin"] = true
		_informe()
		await get_tree().create_timer(4.0 if rol == "anfitrion" else 2.0).timeout
		print("[%s] REDTEST TERMINADO" % rol)
		_salir()


## Decide solo: acepta las propuestas de otro jugador y, en lo demás, la opción recomendada o la primera
func _resolver() -> void:
	for q in [GS.inbox, GS.visitors, GS.calls]:
		var guard := 0
		while q.size() > 0 and guard < 20:
			guard += 1
			var it: Dictionary = q[0]
			var ev: Dictionary = it["ev"]
			var eid := String(ev.get("id", ""))
			# las propuestas de la mesa las contesta la prueba (aquí, «dejarla para más tarde»)
			var idx := 3 if eid.begins_with("propuesta_") else 0
			if eid.begins_with("red_propuesta") or eid == "corte_suministro" or eid.begins_with("amenaza_") or eid.begins_with("propuesta_"):
				print("[%s] RECIBO: %s → elijo «%s»" % [rol, ev["title"], ev["choices"][idx]["t"]])
			if ev.has("options"):
				GS.resolve_option(it, ev["options"][0])
			elif ev.has("choices"):
				GS.resolve_choice(it, idx)
			else:
				q.pop_front()


func _informe() -> void:
	var tr := []
	for x in GS.treaties:
		if x["c"] == otro:
			tr.append(x["type"])
	var precios := {}
	for k in GS.mercado["precios"].keys():
		precios[k] = int(roundf(float(GS.mercado["precios"][k])))
	print("[%s] INFORME día %d (mundo %d) · relación con %s: %d · tratados con él: %s · cortes que sufro: %s · mensajes: %d" % [rol, GS.day, Red.dia_mundo,
		otro, int(GS.countries.get(otro, {}).get("rel", 0)), tr, GS.mercado["cortes"].keys(), Red.chat.size()])
	print("[%s] PRECIOS %s" % [rol, precios])
	var ks := []
	for k in GS.Mercado.contratos_con(otro):
		ks.append("%s %s %s u. a %d (%s)" % [k["id"], "VENDO" if k.get("vendo", false) else "COMPRO", k.get("r", "pago"), int(roundf(float(k.get("precio", 0.0)))), UI.num(float(k.get("vol", k.get("m", 0.0))), 1)])
	print("[%s] CONTRATOS con %s: %s" % [rol, otro, ks])
	print("[%s] MESA con %s: estado %s · credibilidad %d · historial %d entradas" % [rol, otro, N.mesa(otro).get("estado", ""), int(N.credibilidad()), (N.mesa(otro)["hist"] as Array).size()])
	if rol == "anfitrion":
		print("[%s] PRODUCCIÓN DEL OTRO (para el precio mundial): %s" % [rol, GS.mercado.get("jug", {}).get(otro, {})])


## Un recurso que exportamos y el otro necesita (si no, gas)
func _recurso_para(c: String) -> String:
	for r in R.RECURSOS.keys():
		if GS.Mercado.perfil(r) > 0.5 and N.perfil_de(c, r) < 0.0:
			return r
	return "gas"


func _salir() -> void:
	fase = "fin"
	Red.salir()
	get_tree().quit()
