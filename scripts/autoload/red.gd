extends Node
## Multijugador «Países rivales» por IP directa (ENet). Sin servidor propio: un jugador es el anfitrión, abre el
## puerto solo (UPnP) y los demás se conectan a su IP.
##
## Quién manda en qué:
##   · cada ordenador simula SU país (su gabinete, sus eventos, su Congreso...);
##   · el anfitrión lleva el reloj del mundo (todos avanzan al mismo día), la velocidad y los precios del mercado;
##   · lo que un jugador hace a otro (mensajes, tratados, sanciones, embargos, cortes de suministro) viaja como
##     una «acción» y lo aplica el ordenador que la recibe.
## Los países que no lleva nadie siguen siendo de la IA, como en la partida normal.
##
## Reloj: abrir una ventana (un documento, el ordenador...) ya no para el tiempo: marca al jugador como ocupado.
## Si alguien está ocupado, el mundo va al 25 %; si lo están todos, se para. La pausa la puede poner cualquiera.

signal sala_cambiada
signal estado(texto: String)
signal empezar_partida(opts: Dictionary)
signal mensaje(de_pais: String, texto: String)

const PUERTO := 24570
const MAX_JUGADORES := 7
const W := preload("res://scripts/data/world_data.gd")
const PD := preload("res://scripts/data/paises_data.gd")
const R := preload("res://scripts/data/recursos_data.gd")

## "off", "anfitrion" o "invitado"
var modo := "off"
var en_juego := false
## Lo que este jugador elige en la sala
var yo := {"name": "", "pais": "valdoria", "party": "MP", "look": {}}
## peer_id -> {"name", "pais", "party", "look"}
var jugadores := {}
## Lo que elige el anfitrión para todos
var config := {"difficulty": 1, "years": 2, "mode": "clasico"}
var dia_mundo := 0
var velocidad := 0
## peer_id -> ocupado (con una ventana abierta)
var ocupados := {}
## país -> final de quien lo llevaba (los que ya han caído)
var resultados := {}
## Mensajes de la partida: [{"pais", "texto", "dia", "mio"}]
var chat := []
## Recurso que cortamos nosotros a cada país (para poder reabrirlo)
var cortes_propios := {}
var ip_publica := ""
var upnp_ok := false

var _acc := 0.0
var _ocupado_enviado := false
var _desde_red := false
var _upnp: UPNP
var _hilo: Thread
var _puerto := PUERTO


func activo() -> bool:
	return modo != "off"


func en_partida() -> bool:
	return modo != "off" and en_juego


func anfitrion() -> bool:
	return modo == "anfitrion"


func mi_id() -> int:
	return multiplayer.get_unique_id() if activo() else 1


## ¿Lleva ese país otro jugador (que siga en el poder)?
func es_humano(c: String) -> bool:
	if not en_partida() or c == "":
		return false
	for id in jugadores.keys():
		if int(id) != mi_id() and String(jugadores[id]["pais"]) == c and not resultados.has(c):
			return true
	return false


func peer_de(c: String) -> int:
	for id in jugadores.keys():
		if String(jugadores[id]["pais"]) == c:
			return int(id)
	return 0


func nombre_de(c: String) -> String:
	var id := peer_de(c)
	return String(jugadores[id]["name"]) if id != 0 else c


## Las IP de este ordenador en la red de casa (o en Tailscale / ZeroTier)
func ips_locales() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			out.append(s)
	return out


# ------------------------------------------------------------------ conexión

func crear(puerto := PUERTO, con_upnp := true) -> int:
	salir()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(puerto, MAX_JUGADORES)
	if err != OK:
		estado.emit("No se ha podido abrir la partida en el puerto %d (¿ya hay otra abierta?)." % puerto)
		return err
	multiplayer.multiplayer_peer = peer
	modo = "anfitrion"
	_puerto = puerto
	jugadores = {1: yo.duplicate(true)}
	_conectar_senales()
	estado.emit("Partida creada. Abriendo el puerto %d en el router..." % puerto if con_upnp else "Partida creada en el puerto %d." % puerto)
	if con_upnp:
		_hilo = Thread.new()
		_hilo.start(_abrir_puerto.bind(puerto))
	sala_cambiada.emit()
	return OK


func unirse(ip: String, puerto := PUERTO) -> int:
	salir()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), puerto)
	if err != OK:
		estado.emit("No se ha podido conectar con %s." % ip)
		return err
	multiplayer.multiplayer_peer = peer
	modo = "invitado"
	_puerto = puerto
	_conectar_senales()
	estado.emit("Conectando con %s:%d..." % [ip, puerto])
	return OK


func salir() -> void:
	if _hilo != null and _hilo.is_started():
		_hilo.wait_to_finish()
	_hilo = null
	if _upnp != null and upnp_ok:
		_upnp.delete_port_mapping(_puerto, "UDP")
	_upnp = null
	upnp_ok = false
	if multiplayer.multiplayer_peer != null and activo():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	modo = "off"
	en_juego = false
	jugadores = {}
	ocupados = {}
	resultados = {}
	chat = []
	cortes_propios = {}
	_acc = 0.0


func _conectar_senales() -> void:
	for pair in [[multiplayer.peer_connected, _al_entrar], [multiplayer.peer_disconnected, _al_salir],
			[multiplayer.connected_to_server, _conectado], [multiplayer.connection_failed, _fallo],
			[multiplayer.server_disconnected, _anfitrion_perdido]]:
		var sig: Signal = pair[0]
		if not sig.is_connected(pair[1]):
			sig.connect(pair[1])


## UPnP en otro hilo (puede tardar unos segundos): pide al router que abra el puerto
func _abrir_puerto(puerto: int) -> void:
	var u := UPNP.new()
	var res := {"ok": false, "ip": ""}
	if u.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		res["ip"] = u.query_external_address()
		res["ok"] = u.add_port_mapping(puerto, puerto, "El Despacho", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
	call_deferred("_puerto_listo", res, u)


func _puerto_listo(res: Dictionary, u: UPNP) -> void:
	if _hilo != null and _hilo.is_started():
		_hilo.wait_to_finish()
	_hilo = null
	if modo != "anfitrion":
		return
	_upnp = u
	upnp_ok = bool(res["ok"])
	ip_publica = String(res["ip"])
	if upnp_ok:
		estado.emit("Puerto %d abierto automáticamente. Su IP pública: %s · Désela a sus amigos." % [_puerto, ip_publica])
	else:
		estado.emit("El router no deja abrir el puerto solo. En la misma red: %s. Desde fuera: abra a mano el puerto %d (UDP) o usen Tailscale, ZeroTier o Radmin VPN." % [", ".join(ips_locales()), _puerto])
	sala_cambiada.emit()


func _al_entrar(_id: int) -> void:
	pass


func _al_salir(id: int) -> void:
	if not anfitrion():
		return
	var c := String(jugadores.get(id, {}).get("pais", ""))
	jugadores.erase(id)
	ocupados.erase(id)
	if en_juego and c != "":
		_se_fue.rpc(c)
	else:
		_sala.rpc(jugadores, config)


func _conectado() -> void:
	estado.emit("Conectado. Esperando al anfitrión...")
	_hola.rpc_id(1, yo)


func _fallo() -> void:
	estado.emit("No se ha podido conectar. Compruebe la IP y que el anfitrión haya abierto el puerto.")
	salir()


func _anfitrion_perdido() -> void:
	var jugando := en_juego
	salir()
	if jugando:
		GS.toast.emit("Se ha perdido la conexión con el anfitrión. La partida sigue en solitario.", "warn", "alerta")
		GS.set_speed(0)
	else:
		estado.emit("El anfitrión ha cerrado la partida.")
	sala_cambiada.emit()


# ------------------------------------------------------------------ sala de espera

## Cambia lo que elige este jugador (nombre, país, partido)
func cambiar_yo(datos: Dictionary) -> void:
	for k in datos.keys():
		yo[k] = datos[k]
	if anfitrion():
		_aplicar_cambio(1, yo)
	elif activo():
		_cambio.rpc_id(1, yo)


func _aplicar_cambio(id: int, datos: Dictionary) -> void:
	var pais := String(datos.get("pais", "valdoria"))
	for otro in jugadores.keys():
		if int(otro) != id and String(jugadores[otro]["pais"]) == pais:
			var aviso := "%s ya lo lleva %s. Elija otro país." % [PD.PAISES[pais]["name"], jugadores[otro]["name"]]
			if id == 1:
				estado.emit(aviso)
				yo["pais"] = String(jugadores.get(1, yo)["pais"])
			else:
				_aviso.rpc_id(id, aviso)
			pais = String(jugadores.get(id, {}).get("pais", _pais_libre(id)))
			break
	jugadores[id] = {"name": String(datos.get("name", "Jugador")), "pais": pais, "party": String(datos.get("party", "MP")), "look": datos.get("look", {})}
	_sala.rpc(jugadores, config)


func _pais_libre(id: int) -> String:
	for p in PD.ORDEN:
		var libre := true
		for otro in jugadores.keys():
			if int(otro) != id and String(jugadores[otro]["pais"]) == p:
				libre = false
		if libre:
			return p
	return "valdoria"


func cambiar_config(c: Dictionary) -> void:
	if not anfitrion():
		return
	for k in c.keys():
		config[k] = c[k]
	_sala.rpc(jugadores, config)


## "" si se puede empezar; si no, por qué
func motivo_no_empezar() -> String:
	if not anfitrion():
		return "Solo el anfitrión puede empezar."
	if jugadores.size() < 2:
		return "Hace falta al menos otro jugador."
	var vistos := {}
	for id in jugadores.keys():
		var p := String(jugadores[id]["pais"])
		if vistos.has(p):
			return "Dos jugadores han elegido %s." % PD.PAISES[p]["name"]
		vistos[p] = true
	return ""


func empezar() -> void:
	if motivo_no_empezar() != "":
		return
	_empezar.rpc(randi(), config)


@rpc("any_peer", "call_remote", "reliable")
func _hola(datos: Dictionary) -> void:
	if not anfitrion():
		return
	var id := multiplayer.get_remote_sender_id()
	if en_juego:
		_aviso.rpc_id(id, "La partida ya ha empezado.")
		return
	var d := datos.duplicate(true)
	if d.get("name", "") == "":
		d["name"] = "Jugador %d" % (jugadores.size() + 1)
	# si su país está cogido, se le da uno libre
	for otro in jugadores.keys():
		if String(jugadores[otro]["pais"]) == String(d.get("pais", "")):
			d["pais"] = _pais_libre(id)
			_aviso.rpc_id(id, "Su país ya estaba elegido: le toca %s (puede cambiarlo)." % PD.PAISES[d["pais"]]["name"])
			break
	_aplicar_cambio(id, d)
	estado.emit("%s se ha unido a la partida." % d["name"])


@rpc("any_peer", "call_remote", "reliable")
func _cambio(datos: Dictionary) -> void:
	if anfitrion() and not en_juego:
		_aplicar_cambio(multiplayer.get_remote_sender_id(), datos)


@rpc("authority", "call_local", "reliable")
func _sala(j: Dictionary, c: Dictionary) -> void:
	jugadores = j
	config = c
	if jugadores.has(mi_id()):
		yo["pais"] = String(jugadores[mi_id()]["pais"])
	sala_cambiada.emit()


@rpc("authority", "call_remote", "reliable")
func _aviso(texto: String) -> void:
	estado.emit(texto)
	if en_partida():
		GS.toast.emit(texto, "info", "info")


@rpc("authority", "call_local", "reliable")
func _empezar(semilla: int, cfg: Dictionary) -> void:
	config = cfg
	en_juego = true
	resultados = {}
	chat = []
	cortes_propios = {}
	velocidad = 0
	_acc = 0.0
	var mio: Dictionary = jugadores.get(mi_id(), yo)
	empezar_partida.emit({"name": mio["name"], "party": mio["party"], "difficulty": int(cfg["difficulty"]), "years": int(cfg["years"]),
		"mode": String(cfg["mode"]), "look": mio.get("look", {}), "pais": mio["pais"], "seed": semilla, "multi": true})


## Tras crear la partida en este ordenador: los otros jugadores ocupan el sitio de sus países en el mundo
func preparar_mundo() -> void:
	if not en_partida():
		return
	GS.no_save = true
	for id in jugadores.keys():
		if int(id) == mi_id():
			continue
		var c := String(jugadores[id]["pais"])
		if W.COUNTRIES.has(c):
			W.COUNTRIES[c]["leader"] = String(jugadores[id]["name"])
			W.COUNTRIES[c]["title"] = _titulo(c)
			if not (jugadores[id].get("look", {}) as Dictionary).is_empty():
				W.COUNTRIES[c]["look"] = jugadores[id]["look"]
		if GS.countries.has(c):
			GS.countries[c]["rel"] = 10.0
	dia_mundo = GS.day
	if anfitrion():
		_precios.rpc(GS.mercado.get("precios", {}))


func _titulo(c: String) -> String:
	match String(PD.PAISES.get(c, {}).get("regimen", "")):
		"monarquia":
			return "Emir"
		"junta":
			return "General-Presidente"
	return "Presidente"


# ------------------------------------------------------------------ reloj del mundo

func _process(delta: float) -> void:
	if not en_partida():
		return
	var ocupado := GS.holds > 0 and GS.active
	if anfitrion():
		ocupados[1] = ocupado
		var f := _factor()
		if velocidad > 0 and f > 0.0:
			_acc += delta * GS.SPEED_MULT[velocidad] * f
			var n := 0
			while _acc >= GS.DAY_SEC and n < 8:
				_acc -= GS.DAY_SEC
				n += 1
				dia_mundo += 1
				_dia.rpc(dia_mundo)
	elif ocupado != _ocupado_enviado:
		_ocupado_enviado = ocupado
		_ocupado.rpc_id(1, ocupado)


## Con alguien ocupado, el mundo va al 25 %; con todos ocupados, se para
func _factor() -> float:
	var n := 0
	var ocu := 0
	for id in jugadores.keys():
		if resultados.has(String(jugadores[id]["pais"])):
			continue
		n += 1
		if ocupados.get(id, false):
			ocu += 1
	if n == 0 or ocu == 0:
		return 1.0
	return 0.0 if ocu >= n else 0.25


## Avanza la partida de este ordenador hasta el día del mundo
func _seguir() -> void:
	var guard := 0
	while GS.active and not GS.game_ended and GS.day < dia_mundo and guard < 40:
		GS.advance_day()
		guard += 1


@rpc("authority", "call_local", "reliable")
func _dia(d: int) -> void:
	dia_mundo = d
	_seguir()


@rpc("any_peer", "call_remote", "reliable")
func _ocupado(o: bool) -> void:
	if anfitrion():
		ocupados[multiplayer.get_remote_sender_id()] = o


## Cualquiera cambia la velocidad (la pausa también): la decide el anfitrión para todos
func pedir_velocidad(s: int) -> void:
	if anfitrion():
		_vel.rpc(s)
	elif activo():
		_pedir_vel.rpc_id(1, s)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_vel(s: int) -> void:
	if anfitrion():
		_vel.rpc(s)


@rpc("authority", "call_local", "reliable")
func _vel(s: int) -> void:
	velocidad = s
	_desde_red = true
	GS.set_speed(s)
	_desde_red = false


func desde_red() -> bool:
	return _desde_red


## Cada mes, el anfitrión manda los precios del mercado mundial (los mismos para todos)
func mes() -> void:
	if en_partida() and anfitrion():
		_precios.rpc(GS.mercado.get("precios", {}))


@rpc("authority", "call_remote", "reliable")
func _precios(p: Dictionary) -> void:
	if not GS.mercado.is_empty() and not p.is_empty():
		GS.mercado["precios"] = p.duplicate()


# ------------------------------------------------------------------ entre jugadores

## Una acción de este jugador sobre el país de otro jugador
func accion(c: String, tipo: String, extra := {}) -> void:
	var id := peer_de(c)
	if id == 0 or not es_humano(c):
		return
	if tipo == "mensaje":
		chat.append({"pais": c, "texto": String(extra.get("texto", "")), "dia": GS.day, "mio": true})
	elif tipo == "corte":
		cortes_propios[c] = String(extra.get("recurso", ""))
	elif tipo == "reabrir":
		cortes_propios.erase(c)
	_accion.rpc_id(id, GS.pais, tipo, extra)


@rpc("any_peer", "call_remote", "reliable")
func _accion(de: String, tipo: String, extra: Dictionary) -> void:
	if not GS.active or GS.game_ended:
		return
	var nm := String(W.COUNTRIES.get(de, {}).get("name", de))
	var quien := "%s (%s)" % [nombre_de(de), nm]
	match tipo:
		"mensaje":
			var t := String(extra.get("texto", "")).substr(0, 240)
			chat.append({"pais": de, "texto": t, "dia": GS.day, "mio": false})
			GS.toast.emit("%s: «%s»" % [quien, t], "info", "telefono")
			mensaje.emit(de, t)
		"visita":
			GS.apply_fx({"rel": {de: 8}, "prestigio": 1}, "Visita de " + nm)
			GS.push_news("%s, de visita oficial en %s" % [quien, W.COUNTRY_NAME], 2)
		"ayuda":
			GS.apply_fx({"money": float(extra.get("dinero", 600)), "rel": {de: 11}}, "Ayuda de " + nm)
			GS.push_news("%s nos envía un paquete de ayuda" % nm, 2)
		"sanciones":
			GS.apply_fx({"rel": {de: -25}, "economia": -2.0, "empresarios": -2}, "Sanciones de " + nm)
			GS.push_news("%s impone sanciones económicas a %s" % [nm, W.COUNTRY_NAME], 3)
		"embajador":
			GS.apply_fx({"rel": {de: -15}}, "Diplomacia")
			GS.push_news("%s expulsa a nuestro embajador" % nm, 2)
		"embargo":
			var fx: Dictionary = GS.Mercado.embargo_recibido(de)
			GS.apply_fx(fx, "Embargo de " + nm)
			GS.push_news("%s decreta un embargo comercial contra %s" % [nm, W.COUNTRY_NAME], 3)
		"corte":
			GS.Mercado.cortar(de, String(extra.get("recurso", "gas")))
		"reabrir":
			GS.Mercado.fx({"fin_corte": String(extra.get("recurso", ""))})
			GS.apply_fx({"rel": {de: 6}}, nm, false)
		"pide_reabrir":
			var r := String(extra.get("recurso", ""))
			chat.append({"pais": de, "texto": "Le pide que reabra el suministro de %s." % _nombre_recurso(r), "dia": GS.day, "mio": false})
			GS.toast.emit("%s le pide que reabra el suministro de %s (globo terráqueo)" % [quien, _nombre_recurso(r)], "info", "telefono")
		"propuesta":
			_propuesta_recibida(de, String(extra.get("tratado", "comercio")))
		"respuesta":
			var tr := String(extra.get("tratado", "comercio"))
			if bool(extra.get("si", false)):
				GS.add_treaty(de, tr)
				GS.apply_fx({"rel": {de: 10}, "prestigio": 2}, "Tratado con " + nm)
				GS.push_news("%s y %s firman un %s" % [W.COUNTRY_NAME, nm, TRATADOS[tr]["name"].to_lower()], 3)
				GS.toast.emit("%s acepta el %s" % [quien, TRATADOS[tr]["name"].to_lower()], "good", "acuerdo")
			else:
				GS.apply_fx({"rel": {de: -4}}, nm, false)
				GS.toast.emit("%s rechaza el %s" % [quien, TRATADOS[tr]["name"].to_lower()], "warn", "acuerdo")


func _nombre_recurso(r: String) -> String:
	if r == "agua":
		return "agua del río Seco"
	return String(R.RECURSOS.get(r, {"name": r})["name"]).to_lower()


## Tratados que se pueden proponer a otro jugador
const TRATADOS := {
	"comercio": {"name": "Tratado comercial", "desc": "Menos aranceles entre los dos: más comercio y economía.", "fx": {"economia": 2, "empresarios": 2}},
	"defensa": {"name": "Acuerdo de defensa", "desc": "Ayuda mutua si uno es atacado: seguridad y prestigio.", "fx": {"seguridad": 2, "prestigio": 2, "militares": 2}},
	"energia": {"name": "Contrato energético", "desc": "Suministro de energía a precio fijo durante años.", "fx": {"economia": 1, "estabilidad": 1}},
}


func proponer(c: String, tratado: String) -> void:
	accion(c, "propuesta", {"tratado": tratado})
	GS.toast.emit("Propuesta enviada a %s" % nombre_de(c), "info", "acuerdo")


func _propuesta_recibida(de: String, tratado: String) -> void:
	var nm := String(W.COUNTRIES.get(de, {}).get("name", de))
	var t: Dictionary = TRATADOS.get(tratado, TRATADOS["comercio"])
	var si_fx: Dictionary = t["fx"].duplicate()
	si_fx["rel"] = {de: 10}
	si_fx["red"] = {"responder": de, "tratado": tratado, "si": true}
	GS.spawn({"id": "red_propuesta_%s_%d" % [de, GS.day], "type": "advisor", "who": "exteriores", "gen": true,
		"title": "%s propone un %s" % [nm, String(t["name"]).to_lower()],
		"text": "Presidente, %s, que gobierna %s, nos propone un %s. %s ¿Firmamos?" % [nombre_de(de), nm, String(t["name"]).to_lower(), t["desc"]],
		"choices": [
			{"t": "Firmar el %s." % String(t["name"]).to_lower(), "fx": si_fx, "rec": "exteriores"},
			{"t": "Rechazarlo con cortesía.", "fx": {"rel": {de: -4}, "red": {"responder": de, "tratado": tratado, "si": false}}}],
		"default": 1})


## Efecto «red» de una decisión: contestar a la propuesta de otro jugador
func fx(v: Dictionary) -> void:
	if not v.has("responder"):
		return
	var de := String(v["responder"])
	var tr := String(v.get("tratado", "comercio"))
	if bool(v.get("si", false)):
		GS.add_treaty(de, tr)
		GS.push_news("%s y %s firman un %s" % [W.COUNTRY_NAME, W.COUNTRIES.get(de, {}).get("name", de), TRATADOS[tr]["name"].to_lower()], 3)
	accion(de, "respuesta", {"tratado": tr, "si": bool(v.get("si", false))})


## Los titulares importantes de un país llegan a los demás (como noticia internacional)
func compartir_noticia(texto: String) -> void:
	if en_partida() and not _desde_red:
		_noticia.rpc(GS.pais, texto)


@rpc("any_peer", "call_remote", "reliable")
func _noticia(de: String, texto: String) -> void:
	if not GS.active:
		return
	_desde_red = true
	GS.push_news("%s · %s" % [W.COUNTRIES.get(de, {}).get("name", de), texto], 1)
	_desde_red = false


## Cuando la partida de este jugador termina (reelegido, golpe, derrota...), los demás se enteran
func fin_propio(reason: String) -> void:
	if en_partida():
		_fin.rpc(GS.pais, reason)


@rpc("any_peer", "call_local", "reliable")
func _fin(de: String, reason: String) -> void:
	resultados[de] = reason
	if de != GS.pais and GS.active:
		var nm := String(W.COUNTRIES.get(de, {}).get("name", de))
		GS.toast.emit("%s (%s) deja el poder: %s" % [nombre_de(de), nm, FINALES.get(reason, reason)], "info", "bandera")
		GS.push_news("Cambio de gobierno en %s: %s" % [nm, FINALES.get(reason, reason)], 2)


const FINALES := {"reelegido": "reelegido", "derrota": "pierde las elecciones", "revolucion": "revuelta popular", "censura": "moción de censura",
	"confianza": "pierde la confianza", "golpe": "golpe de Estado", "bancarrota": "bancarrota", "casino": "escándalo del casino",
	"purgado": "purgado por el Partido", "golpe_palacio": "golpe de palacio", "contragolpe": "contragolpe", "consolidado": "consolida su poder",
	"transicion": "transición democrática", "limite": "límite de mandatos"}


@rpc("authority", "call_local", "reliable")
func _se_fue(c: String) -> void:
	for id in jugadores.keys():
		if String(jugadores[id]["pais"]) == c:
			jugadores.erase(id)
			break
	if GS.active:
		GS.toast.emit("El jugador de %s se ha desconectado: su país pasa a la IA." % W.COUNTRIES.get(c, {}).get("name", c), "warn", "alerta")
	sala_cambiada.emit()


func _exit_tree() -> void:
	salir()
