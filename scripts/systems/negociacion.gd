extends RefCounted
## Mesa de negociación con otros países: propuestas de verdad, contraofertas, amenazas y palabra dada.
##
## Con cada país hay una mesa (una conversación) en GS.diplo["mesas"][país]: {hist: [...], prop: la propuesta que
## está sobre la mesa, autor ("yo" / "ellos"), v (versión), estado ("abierta", "aceptada", "rechazada",
## "retirada", "caducada"), caduca (día), contras (contraofertas de la IA), nuevo (sin leer)}.
##
## Una propuesta, siempre desde el punto de vista de este ordenador: {"da": [lo que damos], "pide": [lo que pedimos],
## "amenaza": {lo que haremos si la rechazan}}. Cláusulas (cada una con su "id"):
##   venta {r, vol, precio, meses}  · en «da», les vendemos; en «pide», nos venden (contrato a precio fijo)
##   dinero {m} · dinero_mes {m, meses} · tratado {k} (para los dos) · reabrir {r} (un corte de suministro)
##   levantar {k: sanciones | embargo} · produccion {r, d, meses} (cambiar la producción: el cártel o lo contrario)
##   compromiso {t} (una promesa con sus palabras; nadie la hace cumplir)
## Amenaza: {k: corte | sanciones | embargo | embajador | aranceles | tropas}. Si la rechazan, toca decidir si se
## cumple; la credibilidad (GS.diplo["cred"], 0-100) sube al cumplir y se hunde al echarse atrás, y pesa en lo que
## la IA se cree las amenazas siguientes.
##
## Con otro jugador, las propuestas viajan por la red (Red.accion «nego») y decide él. Con la IA, el país evalúa la
## propuesta con lo que necesita (recursos_data.gd), el precio del mercado, la relación, su carácter y su poder:
## acepta, rechaza explicando por qué o hace una contraoferta. La IA también propone: vender lo que nos falta,
## comprar lo que nos sobra, tratados... y, los países duros, exigencias con amenaza.

const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")
const PD := preload("res://scripts/data/paises_data.gd")
const Mercado := preload("res://scripts/systems/mercado.gd")
const Charla := preload("res://scripts/systems/charla.gd")

const K := 4.0
## Días que una propuesta está sobre la mesa antes de caducar
const VIDA := 20
## Contraofertas que aguanta la IA antes de levantarse de la mesa
const PACIENCIA := {"pragmatico": 3, "paciente": 4, "orgulloso": 2, "agresivo": 2, "volatil": 2}

const TRATADOS := {
	"comercio": {"name": "Tratado comercial", "desc": "Menos aranceles entre los dos: más comercio y economía."},
	"energia": {"name": "Contrato energético", "desc": "Suministro de energía estable durante años."},
	"inversion": {"name": "Acuerdo de inversión", "desc": "Protege las inversiones mutuas: llegan empresas y capital."},
	"defensa": {"name": "Acuerdo de defensa", "desc": "Ayuda mutua si uno es atacado: seguridad y prestigio."},
	"no_agresion": {"name": "Pacto de no agresión", "desc": "Se acabaron las amenazas entre los dos. Calma la tensión."},
}

const AMENAZAS := {
	"corte": {"name": "Cortarles el suministro", "desc": "Dejar de venderles lo que les hace falta."},
	"sanciones": {"name": "Sanciones económicas", "desc": "Golpe a su economía y a la relación."},
	"embargo": {"name": "Embargo comercial", "desc": "Ni comprarles ni venderles durante un año."},
	"aranceles": {"name": "Aranceles a sus productos", "desc": "Les cuesta exportar... y a nosotros, importar."},
	"embajador": {"name": "Expulsar a su embajador", "desc": "Un desaire diplomático en toda regla."},
	"tropas": {"name": "Movilizar tropas en la frontera", "desc": "Presión militar. Puede salir muy mal."},
}


# ------------------------------------------------------------------ estado

static func _d() -> Dictionary:
	if not (GS.diplo is Dictionary) or GS.diplo.is_empty():
		GS.diplo = {"cred": 60.0, "mesas": {}, "seq": 0}
	return GS.diplo


static func mesa(c: String) -> Dictionary:
	var d := _d()
	if not d["mesas"].has(c):
		d["mesas"][c] = {"hist": [], "prop": {}, "autor": "", "v": 0, "estado": "", "caduca": 0, "contras": 0, "nuevo": false}
	return d["mesas"][c]


static func credibilidad() -> float:
	return float(_d().get("cred", 60.0))


static func _cred(delta: float) -> void:
	_d()["cred"] = clampf(credibilidad() + delta, 0.0, 100.0)


## Propuestas que esperan nuestra respuesta
static func pendientes() -> Array:
	var out := []
	for c in _d()["mesas"].keys():
		var ms: Dictionary = _d()["mesas"][c]
		if String(ms.get("estado", "")) == "abierta" and String(ms.get("autor", "")) == "ellos":
			out.append(c)
	return out


static func abierta(c: String) -> bool:
	return String(mesa(c).get("estado", "")) == "abierta" and not (mesa(c).get("prop", {}) as Dictionary).is_empty()


static func humano(c: String) -> bool:
	return Red.es_humano(c)


static func nombre(c: String) -> String:
	return String(W.COUNTRIES.get(c, {}).get("name", c))


static func lider(c: String) -> String:
	return Red.nombre_de(c) if humano(c) else String(W.COUNTRIES.get(c, {}).get("leader", c))


## Poder (0-100) del país que se gobierna: el de su ficha, algo movido por el prestigio
static func mi_poder() -> float:
	var base := float(PD.PAISES.get(GS.pais, {}).get("ai", {}).get("power", 55.0))
	return base + (float(GS.meters.get("prestigio", 50.0)) - 50.0) * 0.3


static func poder(c: String) -> float:
	return float(W.COUNTRIES.get(c, {}).get("power", 50.0))


static func _nid() -> String:
	var d := _d()
	d["seq"] = int(d.get("seq", 0)) + 1
	return "%s-%d-%d" % [GS.pais, GS.day, int(d["seq"])]


## Lo mismo visto desde el otro lado (lo que uno da es lo que el otro recibe)
static func invertir(prop: Dictionary) -> Dictionary:
	return {"da": (prop.get("pide", []) as Array).duplicate(true), "pide": (prop.get("da", []) as Array).duplicate(true), "amenaza": {}, "t": String(prop.get("t", ""))}


static func _hist(c: String, de: String, tipo: String, t: String, prop := {}) -> void:
	var ms := mesa(c)
	var e := {"de": de, "tipo": tipo, "t": t, "dia": GS.day}
	if not prop.is_empty():
		e["prop"] = prop.duplicate(true)
	ms["hist"].append(e)
	while (ms["hist"] as Array).size() > 80:
		ms["hist"].pop_front()


# ------------------------------------------------------------------ textos

static func rnom(r: String) -> String:
	if r == "agua":
		return "agua del río Seco"
	return String(R.RECURSOS.get(r, {"name": r})["name"]).to_lower()


## Una cláusula en palabras. lado: "da" (lo damos nosotros) o "pide" (nos lo dan ellos)
static func texto(cl: Dictionary, lado: String) -> String:
	var da := lado == "da"
	match String(cl.get("tipo", "")):
		"venta":
			return "%s %s u./mes de %s a %d · %d meses" % ["Venderles" if da else "Que nos vendan", UI.num(float(cl["vol"]), 1), rnom(String(cl["r"])), int(roundf(float(cl["precio"]))), int(cl["meses"])]
		"dinero":
			return "%s %s" % ["Pagarles" if da else "Que nos paguen", UI.money(float(cl["m"]))]
		"dinero_mes":
			return "%s %s al mes · %d meses" % ["Pagarles" if da else "Que nos paguen", UI.money(float(cl["m"])), int(cl["meses"])]
		"tratado":
			return "Firmar un %s" % String(TRATADOS.get(String(cl["k"]), {"name": cl["k"]})["name"]).to_lower()
		"reabrir":
			return ("Reabrirles el suministro de %s" if da else "Que nos reabran el suministro de %s") % rnom(String(cl["r"]))
		"levantar":
			var k := "las sanciones" if String(cl["k"]) == "sanciones" else "el embargo"
			return ("Levantarles %s" if da else "Que nos levanten %s") % k
		"produccion":
			var d := float(cl["d"])
			return "%s %s %s u./mes la producción de %s · %d meses" % ["Nosotros:" if da else "Ellos:", "recortar" if d < 0.0 else "subir", UI.num(absf(d), 1), rnom(String(cl["r"])), int(cl["meses"])]
		"compromiso":
			return "%s «%s»" % ["Prometemos:" if da else "Prometen:", String(cl.get("t", ""))]
	return String(cl.get("tipo", "?"))


static func texto_amenaza(am: Dictionary) -> String:
	if am.is_empty():
		return ""
	var k := String(am.get("k", ""))
	if k == "corte":
		return "si no, cortarles el suministro de %s" % rnom(String(am.get("r", "gas")))
	return "si no, " + String(AMENAZAS.get(k, {"name": k})["name"]).to_lower()


## Resumen de una propuesta en una línea (para titulares y avisos)
static func resumen(prop: Dictionary) -> String:
	var partes := []
	for cl in prop.get("da", []):
		partes.append(_min(texto(cl, "da")))
	for cl2 in prop.get("pide", []):
		partes.append(_min(texto(cl2, "pide")))
	return "; ".join(partes)


## Primera letra en minúscula (para meter una frase en medio de otra)
static func _min(s: String) -> String:
	return s.left(1).to_lower() + s.substr(1)


# ------------------------------------------------------------------ lo que vale una propuesta

## Saldo de un recurso para un país de la IA (+ le sobra, − le falta), con sus cambios de producción
static func perfil_de(c: String, r: String) -> float:
	var v := float(R.PERFILES.get(c, {}).get(r, 0))
	if not GS.mercado.is_empty():
		v += float(GS.mercado.get("ia", {}).get(c, {}).get(r, 0.0))
	return v


## Lo que ese país ya nos vende (o nos compra) de un recurso por contrato
static func comprometido(c: String, r: String, vendiendo: bool) -> float:
	var n := 0.0
	for k in Mercado.contratos_con(c):
		if String(k.get("tipo", "")) == "venta" and String(k["r"]) == r and bool(k["vendo"]) != vendiendo:
			n += float(k["vol"])
	return n


static func precio_mercado(r: String) -> float:
	return float(GS.mercado.get("precios", {}).get(r, 100.0))


static func tiene_tratado(c: String, k: String) -> bool:
	for t in GS.treaties:
		if String(t["c"]) == c and String(t["type"]) == k:
			return true
	return false


## Valor (en M) de una cláusula para el país c (la IA). recibe: c se lleva lo que dice la cláusula (está en
## nuestro «da»); si no, c la da (está en nuestro «pide»).
static func valor_clausula(c: String, cl: Dictionary, recibe: bool) -> float:
	var rel := float(GS.countries.get(c, {}).get("rel", 0.0))
	var pers := GS.country_pers(c) if W.COUNTRIES.has(c) else "pragmatico"
	match String(cl.get("tipo", "")):
		"venta":
			var r := String(cl["r"])
			var vol := float(cl["vol"])
			var p := float(cl["precio"])
			var meses := float(cl["meses"])
			var pm := precio_mercado(r)
			var pf := perfil_de(c, r)
			if recibe:
				# nos compra: le interesa si lo necesita y si es más barato que el mercado (paga algo por tenerlo asegurado)
				var necesita := maxf(0.0, -pf - comprometido(c, r, false))
				var util := minf(vol, necesita + 0.5)
				var sobra := vol - util
				return (util * (pm * 1.04 - p) + sobra * (pm * 0.8 - p)) * K * meses
			# nos vende: le interesa si le sobra y si el precio es bueno; lo que no tiene, lo tendría que comprar
			var libre := maxf(0.0, pf + 0.5 - comprometido(c, r, true))
			var ok := minf(vol, libre)
			var falta := vol - ok
			var x := ok * (p - pm * 0.98) + falta * (p - pm * 1.2)
			if pf < 0.0:
				x -= vol * 20.0
			return x * K * meses
		"dinero":
			return float(cl["m"]) * (1.0 if recibe else -1.0)
		"dinero_mes":
			return float(cl["m"]) * float(cl["meses"]) * 0.9 * (1.0 if recibe else -1.0)
		"tratado":
			return _val_tratado(c, String(cl["k"]), rel)
		"reabrir":
			if recibe:
				return 2600.0
			return -2600.0 if pers == "agresivo" else -1500.0
		"levantar":
			if recibe:
				return 2200.0 if String(cl["k"]) == "embargo" else 1500.0
			return -700.0
		"produccion":
			var r2 := String(cl["r"])
			var d := float(cl["d"])
			var meses2 := float(cl["meses"])
			var cambio_precio := -R.ELASTICIDAD * d / float(R.MUNDO.get(r2, 50.0)) * 100.0
			var pf2 := perfil_de(c, r2)
			if recibe:
				# cambiamos nuestra producción: le afecta por el precio (bien si vende, mal si compra)
				return pf2 * cambio_precio * K * meses2 * 0.8
			# cambia la suya: deja de ganar (o gana) por lo que produce, y el precio se mueve para el resto de lo que vende
			var x2 := d * (precio_mercado(r2) - 50.0) * K * meses2
			x2 += pf2 * cambio_precio * K * meses2
			if d > 0.0 and pf2 + d > float(R.TECHO.get(c, {}).get(r2, Mercado.base_prod(c, r2) + 2.0)) - Mercado.consumo0(c, r2):
				x2 -= 4000.0
			return x2
		"compromiso":
			return 0.0
	return 0.0


static func _val_tratado(c: String, k: String, rel: float) -> float:
	if tiene_tratado(c, k):
		return 0.0
	# con la relación por los suelos no se firma nada (salvo un pacto para dejar de amenazarse)
	if rel < -30.0 and k != "no_agresion":
		return -3000.0
	match k:
		"comercio":
			return 700.0 if rel >= -10.0 else -1800.0
		"energia":
			var exporta := perfil_de(c, "gas") >= 2.0 or perfil_de(c, "petroleo") >= 2.0
			return (650.0 if exporta else 250.0) if rel >= 0.0 else -1500.0
		"inversion":
			return 450.0 if rel >= 0.0 else -1200.0
		"defensa":
			return 300.0 if rel >= 35.0 else -3500.0
		"no_agresion":
			return 650.0 if rel < 10.0 else 150.0
	return 0.0


## Lo que exige cada carácter para firmar (y los poderosos, más)
static func umbral(c: String) -> float:
	var pers := GS.country_pers(c) if W.COUNTRIES.has(c) else "pragmatico"
	var u := float({"pragmatico": 0.0, "paciente": 200.0, "orgulloso": 300.0, "agresivo": 350.0, "volatil": 150.0}.get(pers, 150.0))
	return u + (poder(c) - mi_poder()) * 8.0


## Lo que pesa una amenaza: el daño que le haría, por lo que se la cree (credibilidad) y por su carácter. A los
## agresivos más fuertes, amenazarles les crece.
static func peso_amenaza(c: String, am: Dictionary, azar := true) -> float:
	if am.is_empty():
		return 0.0
	var pers := GS.country_pers(c) if W.COUNTRIES.has(c) else "pragmatico"
	if pers == "agresivo" and poder(c) > mi_poder():
		return -900.0
	var f := float({"pragmatico": 1.0, "paciente": 0.8, "orgulloso": 0.45, "agresivo": 0.6, "volatil": 0.7}.get(pers, 0.7))
	if pers == "volatil" and azar:
		f = randf_range(0.3, 1.1)
	return dolor(c, am) * credibilidad() / 100.0 * f


## Daño que haría cumplir la amenaza (en M)
static func dolor(c: String, am: Dictionary) -> float:
	match String(am.get("k", "")):
		"corte":
			var r := String(am.get("r", R.ARMAS.get(GS.pais, "")))
			if r == "agua":
				return 3000.0 if c == "valdoria" else 0.0
			var necesita := maxf(0.0, -perfil_de(c, r))
			return necesita * 60.0 * K * 6.0
		"sanciones":
			return 1600.0
		"embargo":
			return 2400.0
		"aranceles":
			return 1100.0
		"embajador":
			return 450.0
		"tropas":
			return 1900.0 if mi_poder() >= poder(c) * 0.7 else 350.0
	return 0.0


## La IA evalúa una propuesta (desde nuestro punto de vista). {neto, det: [[cláusula, lado, valor]], amenaza}
static func evaluar(c: String, prop: Dictionary, azar := true) -> Dictionary:
	var det := []
	var v := 0.0
	for cl in prop.get("da", []):
		var x := valor_clausula(c, cl, true)
		det.append([cl, "da", x])
		v += x
	for cl2 in prop.get("pide", []):
		var x2 := valor_clausula(c, cl2, false)
		det.append([cl2, "pide", x2])
		v += x2
	var rel := float(GS.countries.get(c, {}).get("rel", 0.0))
	var am := peso_amenaza(c, prop.get("amenaza", {}), azar)
	var neto := v + rel * 8.0 + am - umbral(c)
	if azar:
		neto += randf_range(-400.0, 400.0) if GS.country_pers(c) == "volatil" else randf_range(-120.0, 120.0)
	return {"neto": neto, "det": det, "amenaza": am, "valor": v}


## Lo que cree Exteriores que hará la IA con esta propuesta (sin azar): "acepta", "contra" o "rechaza"
static func pronostico(c: String, prop: Dictionary) -> String:
	if humano(c) or (prop.get("da", []) as Array).is_empty() and (prop.get("pide", []) as Array).is_empty():
		return ""
	var e := evaluar(c, prop, false)
	if float(e["neto"]) >= 150.0:
		return "acepta"
	if float(e["neto"]) > -limite(prop):
		return "contra"
	return "rechaza"


## Hasta dónde está dispuesta a regatear la IA antes de rechazar sin más
static func limite(prop: Dictionary) -> float:
	var tam := 0.0
	for cl in (prop.get("da", []) as Array) + (prop.get("pide", []) as Array):
		if String(cl.get("tipo", "")) == "venta":
			tam += float(cl["vol"]) * float(cl["meses"]) * K * 25.0
		elif String(cl.get("tipo", "")) in ["dinero", "dinero_mes"]:
			tam += absf(float(cl["m"])) * (float(cl.get("meses", 1)))
	return maxf(2500.0, tam * 0.5)


## Lo que vale para nosotros (al mes, frente a hacerlo en el mercado) y lo que nos cuesta de una vez
static func valor_propio(prop: Dictionary) -> Dictionary:
	var mes := 0.0
	var una := 0.0
	var otros := []
	for lado in ["da", "pide"]:
		for cl in prop.get(lado, []):
			var da: bool = lado == "da"
			match String(cl.get("tipo", "")):
				"venta":
					var pm := precio_mercado(String(cl["r"]))
					var dif := (float(cl["precio"]) - pm) if da else (pm - float(cl["precio"]))
					mes += float(cl["vol"]) * dif * K
				"dinero":
					una += float(cl["m"]) * (-1.0 if da else 1.0)
				"dinero_mes":
					mes += float(cl["m"]) * (-1.0 if da else 1.0)
				"tratado":
					otros.append("economía y relación ▲")
				"reabrir":
					otros.append("se acaba un corte" if not da else "perdemos una baza")
				"produccion":
					otros.append("compromiso de producción")
	return {"mes": mes, "una": una, "otros": otros}


# ------------------------------------------------------------------ proponer y responder

## Manda nuestra propuesta (nueva o contraoferta). Con la IA, contesta enseguida.
static func proponer(c: String, prop: Dictionary, txt := "") -> void:
	var ms := mesa(c)
	var p := prop.duplicate(true)
	var nid := _nid()
	var i := 0
	for lado in ["da", "pide"]:
		for cl in p.get(lado, []):
			cl["id"] = "%s-%d" % [nid, i]
			i += 1
	p["nid"] = nid
	ms["prop"] = p
	ms["autor"] = "yo"
	ms["v"] = int(ms.get("v", 0)) + 1
	ms["estado"] = "abierta"
	ms["caduca"] = GS.day + VIDA
	var aviso := ""
	if not (p.get("amenaza", {}) as Dictionary).is_empty():
		aviso = " Y avisa: " + texto_amenaza(p["amenaza"]) + "."
	_hist(c, "yo", "propuesta", (txt + aviso).strip_edges(), p)
	if humano(c):
		Red.accion(c, "nego", {"tipo": "propuesta", "prop": p, "v": int(ms["v"]), "t": txt})
		GS.toast.emit("Propuesta enviada a %s (%s)" % [lider(c), nombre(c)], "info", "acuerdo")
		return
	# una amenaza ofende aunque funcione
	if not (p.get("amenaza", {}) as Dictionary).is_empty():
		var pers := GS.country_pers(c)
		GS.apply_fx({"rel": {c: -10 if pers in ["orgulloso", "agresivo"] else -4}}, nombre(c), false)
	_responde_ia(c)


## La IA contesta a lo que hay sobre la mesa
static func _responde_ia(c: String) -> void:
	var ms := mesa(c)
	var prop: Dictionary = ms["prop"]
	var e := evaluar(c, prop)
	var pers := GS.country_pers(c)
	if float(e["neto"]) >= 0.0:
		_hist(c, "ellos", "acepta", _frase_ia(c, "acepta"))
		_cerrar_trato(c, prop)
		if not (prop.get("amenaza", {}) as Dictionary).is_empty():
			_cred(3.0)
		return
	var contras := int(ms.get("contras", 0))
	if float(e["neto"]) > -limite(prop) and contras < int(PACIENCIA.get(pers, 2)):
		var co := contraoferta(c, prop, e)
		if not co.is_empty():
			ms["prop"] = co["prop"]
			ms["autor"] = "ellos"
			ms["v"] = int(ms["v"]) + 1
			ms["contras"] = contras + 1
			ms["caduca"] = GS.day + VIDA
			ms["nuevo"] = true
			_hist(c, "ellos", "propuesta", String(co["t"]), co["prop"])
			return
	ms["estado"] = "rechazada"
	ms["contras"] = 0
	_hist(c, "ellos", "rechaza", _motivo(c, e))
	_rechazada(c, prop)


## Contraoferta de la IA: quita lo que no firmaría nunca y cuadra el resto con el precio o con dinero
static func contraoferta(c: String, prop: Dictionary, e: Dictionary) -> Dictionary:
	var p := prop.duplicate(true)
	p["amenaza"] = {}
	var cambios := []
	# lo que no firmaría nunca (un tratado de defensa con quien se lleva mal, reabrir un grifo...)
	for lado in ["pide", "da"]:
		var quedan := []
		for cl in p.get(lado, []):
			var v := valor_clausula(c, cl, lado == "da")
			if v <= -2500.0 and String(cl.get("tipo", "")) != "venta":
				cambios.append("sin «%s»" % _min(texto(cl, lado)))
			else:
				quedan.append(cl)
		p[lado] = quedan
	# volúmenes: no compra más de lo que necesita ni vende lo que no tiene
	for lado4 in ["da", "pide"]:
		var quedan2 := []
		for cl5 in p.get(lado4, []):
			if String(cl5.get("tipo", "")) == "venta":
				var r5 := String(cl5["r"])
				var pf5 := perfil_de(c, r5)
				var tope := (maxf(0.0, -pf5 - comprometido(c, r5, false)) + 0.5) if lado4 == "da" else (pf5 + 0.5 - comprometido(c, r5, true))
				tope = snappedf(floorf(tope * 2.0) / 2.0, 0.5)
				if tope < 0.5:
					cambios.append("sin «%s»" % _min(texto(cl5, lado4)))
					continue
				if float(cl5["vol"]) > tope:
					cambios.append("%s u./mes de %s en vez de %s" % [UI.num(tope, 1), rnom(r5), UI.num(float(cl5["vol"]), 1)])
					cl5["vol"] = tope
			quedan2.append(cl5)
		p[lado4] = quedan2
	var neto := float(evaluar(c, p, false)["neto"])
	var falta := -neto + 120.0
	if falta > 0.0:
		# el precio de un contrato de venta (lo primero que se toca)
		for lado2 in ["da", "pide"]:
			for cl2 in p.get(lado2, []):
				if falta <= 0.0 or String(cl2.get("tipo", "")) != "venta":
					continue
				var vol := float(cl2["vol"])
				var meses := float(cl2["meses"])
				var paso := falta / maxf(0.1, vol * meses * K)
				var antes := float(cl2["precio"])
				var nuevo := antes - paso if lado2 == "da" else antes + paso
				nuevo = clampf(roundf(nuevo), 45.0, 260.0)
				if absf(nuevo - antes) >= 1.0:
					cl2["precio"] = nuevo
					falta -= absf(nuevo - antes) * vol * meses * K
					cambios.append("%s a %d en vez de %d" % [rnom(String(cl2["r"])), int(nuevo), int(antes)])
		# y si no basta, dinero encima de la mesa
		if falta > 0.0:
			var m := ceilf(falta / 100.0) * 100.0
			var hecho := false
			for cl3 in p["da"]:
				if String(cl3.get("tipo", "")) == "dinero":
					cl3["m"] = float(cl3["m"]) + m
					hecho = true
			if not hecho:
				p["da"].append({"tipo": "dinero", "m": m})
			cambios.append("una compensación de %s" % UI.money(m))
	if cambios.is_empty() or ((p["da"] as Array).is_empty() and (p["pide"] as Array).is_empty()):
		return {}
	var nid := _nid()
	var i := 0
	for lado3 in ["da", "pide"]:
		for cl4 in p[lado3]:
			cl4["id"] = "%s-%d" % [nid, i]
			i += 1
	p["nid"] = nid
	var lista := ", ".join(cambios)
	return {"prop": p, "t": _frase_ia(c, "contra") + " " + lista.left(1).to_upper() + lista.substr(1) + "."}


static func _frase_ia(c: String, tipo: String) -> String:
	var pers := GS.country_pers(c) if W.COUNTRIES.has(c) else "pragmatico"
	var f := {
		"acepta": {"orgulloso": ["Me parece una propuesta digna de {pais}. Trato hecho.", "Acepto. Que conste que lo hago por la amistad entre nuestros pueblos."],
			"agresivo": ["Hecho. Cumplan su parte y no habrá problemas.", "Trato hecho. No me decepcionen."],
			"pragmatico": ["Los números salen. Aceptamos.", "Es un buen acuerdo para los dos. Firmamos."],
			"paciente": ["Lo hemos estudiado con calma. Aceptamos.", "Bien. Este es el principio de una larga colaboración."],
			"volatil": ["¡Hecho! Hoy estoy de buen humor.", "Vale, vale. Aceptamos. Antes de que cambie de idea."]},
		"contra": {"orgulloso": ["Su oferta se queda corta para un país como el nuestro. Aceptaríamos con esto:", "Podemos hablar, pero no así. Proponemos:"],
			"agresivo": ["Eso no basta. Nuestra oferta:", "Así no. Esto es lo que firmamos:"],
			"pragmatico": ["Casi. Si ajustamos esto, firmamos:", "Estamos cerca. Nuestra contraoferta:"],
			"paciente": ["Sin prisa. Lo podríamos aceptar con estos cambios:", "Démosle una vuelta más:"],
			"volatil": ["Mmm. Hoy no. Bueno, quizá con esto:", "Ni sí ni no. Depende:"]},
	}
	var lst: Array = f.get(tipo, {}).get(pers, ["De acuerdo."])
	return GS.fmt(String(lst.pick_random()))


## Por qué la IA rechaza: lo que más le duele de la propuesta
static func _motivo(c: String, e: Dictionary) -> String:
	var peor: Array = []
	var pv := 0.0
	for d in e["det"]:
		if float(d[2]) < pv:
			pv = float(d[2])
			peor = d
	var pers := GS.country_pers(c) if W.COUNTRIES.has(c) else "pragmatico"
	var pre := String({"orgulloso": "Me sorprende que nos ofrezca esto.", "agresivo": "¿Esto es todo lo que tiene?", "pragmatico": "No nos salen las cuentas.",
		"paciente": "Lo hemos pensado con calma y no.", "volatil": "No. Hoy no."}.get(pers, "No."))
	if float(e.get("amenaza", 0.0)) < 0.0:
		return pre + " ¿Amenazas? Con nosotros no funcionan."
	if peor.is_empty():
		return pre + " No vemos qué ganamos con esto."
	var cl: Dictionary = peor[0]
	var lado: String = peor[1]
	match String(cl.get("tipo", "")):
		"venta":
			if lado == "da":
				return pre + (" No necesitamos comprar tanto (%s), y menos a ese precio." % rnom(String(cl["r"])))
			if perfil_de(c, String(cl["r"])) <= 0.0:
				return pre + (" Nosotros también tenemos que comprar %s fuera: no nos sobra." % rnom(String(cl["r"])))
			return pre + (" Ese precio está muy por debajo de lo que nos pagan otros (%s)." % rnom(String(cl["r"])))
		"tratado":
			return pre + (" No firmamos un %s con un Gobierno que nos trata así." % String(TRATADOS.get(String(cl["k"]), {"name": "tratado"})["name"]).to_lower())
		"reabrir":
			return pre + " El grifo se abrirá cuando cambie su política hacia nosotros, no antes."
		"produccion":
			return pre + " No vamos a tocar nuestra producción por ustedes."
		"dinero", "dinero_mes":
			return pre + " Es mucho dinero para lo que ofrecen."
		"levantar":
			return pre + " Las sanciones siguen mientras no cambien las cosas."
	return pre + " No nos interesa."


## Aceptamos lo que hay sobre la mesa (propuesta de ellos)
static func aceptar(c: String) -> void:
	var ms := mesa(c)
	if not abierta(c) or String(ms["autor"]) != "ellos":
		GS.toast.emit("Esa propuesta de %s ya no está sobre la mesa." % nombre(c), "info", "acuerdo")
		return
	var prop: Dictionary = ms["prop"]
	_hist(c, "yo", "acepta", "Aceptamos.")
	if humano(c):
		Red.accion(c, "nego", {"tipo": "acepta", "v": int(ms["v"])})
	_cerrar_trato(c, prop)


## Rechazamos lo que hay sobre la mesa
static func rechazar(c: String, txt := "") -> void:
	var ms := mesa(c)
	if not abierta(c) or String(ms["autor"]) != "ellos":
		GS.toast.emit("Esa propuesta de %s ya no está sobre la mesa." % nombre(c), "info", "acuerdo")
		return
	var prop: Dictionary = ms["prop"]
	ms["estado"] = "rechazada"
	ms["contras"] = 0
	_hist(c, "yo", "rechaza", txt if txt != "" else "No nos interesa.")
	if humano(c):
		Red.accion(c, "nego", {"tipo": "rechaza", "v": int(ms["v"]), "t": txt})
		return
	# si la IA traía una amenaza, decide si la cumple
	_ia_cumple(c, prop)


## Retiramos nuestra propuesta
static func retirar(c: String) -> void:
	var ms := mesa(c)
	if not abierta(c) or String(ms["autor"]) != "yo":
		return
	ms["estado"] = "retirada"
	_hist(c, "yo", "retira", "Retiramos la propuesta.")
	if humano(c):
		Red.accion(c, "nego", {"tipo": "retira", "v": int(ms["v"])})


## Escribimos algo en la mesa. Con la IA, contesta su líder (con la charla del móvil).
static func escribir(c: String, txt: String) -> String:
	txt = txt.strip_edges().substr(0, 240)
	if txt == "":
		return ""
	_hist(c, "yo", "texto", txt)
	if humano(c):
		Red.accion(c, "mensaje", {"texto": txt})
		return ""
	var t := {"who": c, "name": lider(c), "msgs": [{"me": true, "t": txt, "day": GS.day}], "mood": float(mesa(c).get("mood", 0.0))}
	var r := Charla.responder(t, txt)
	mesa(c)["mood"] = t.get("mood", 0.0)
	if not (r.get("fx", {}) as Dictionary).is_empty():
		GS.apply_fx(r["fx"], "Mesa de negociación")
	if String(r.get("news", "")) != "":
		GS.push_news(String(r["news"]), 2)
	var resp := String(r.get("t", ""))
	if resp != "":
		_hist(c, "ellos", "texto", resp)
	return resp


# ------------------------------------------------------------------ cerrar un trato

## Se firma: cada cláusula, desde nuestro punto de vista (con otro jugador, él hace lo mismo con la suya)
static func _cerrar_trato(c: String, prop: Dictionary) -> void:
	var ms := mesa(c)
	ms["estado"] = "aceptada"
	ms["contras"] = 0
	ms["nuevo"] = false
	var nm := nombre(c)
	for lado in ["da", "pide"]:
		var da: bool = lado == "da"
		for cl in prop.get(lado, []):
			var id := String(cl.get("id", "%s-%d" % [c, GS.day]))
			match String(cl.get("tipo", "")):
				"venta":
					Mercado.nuevo_contrato(id, c, String(cl["r"]), float(cl["vol"]), float(cl["precio"]), da, int(cl["meses"]))
					# firmar una venta acaba con el corte de ese recurso entre los dos (en los dos ordenadores)
					var rv := String(cl["r"])
					if da and String(Red.cortes_propios.get(c, "")) == rv:
						Red.cortes_propios.erase(c)
					elif not da and String(GS.mercado.get("cortes", {}).get(rv, {}).get("who", "")) == c:
						Mercado.fx({"fin_corte": rv})
				"dinero":
					GS.apply_fx({"money": -float(cl["m"]) if da else float(cl["m"])}, "Acuerdo con " + nm)
				"dinero_mes":
					Mercado.nuevo_pago(id, c, -float(cl["m"]) if da else float(cl["m"]), int(cl["meses"]))
				"tratado":
					GS.add_treaty(c, String(cl["k"]))
				"reabrir":
					if da:
						Red.cortes_propios.erase(c)
					else:
						Mercado.fx({"fin_corte": String(cl["r"])})
				"levantar":
					if da:
						if String(cl["k"]) == "embargo":
							GS.mercado.get("embargos", {}).erase(c)
						GS.countries[c]["cd"].erase("sanciones")
					else:
						for r in GS.mercado.get("cortes", {}).keys():
							if String(GS.mercado["cortes"][r]["who"]) == c and float(GS.mercado["cortes"][r].get("prima", 0.0)) <= Mercado.PRIMA_OTROS:
								GS.mercado["cortes"].erase(r)
				"produccion":
					if da:
						Mercado.comprometer(String(cl["r"]), float(cl["d"]), int(cl["meses"]), c)
					elif not humano(c):
						Red.ia_compromiso(c, String(cl["r"]), float(cl["d"]), GS.day + int(cl["meses"]) * 30)
	GS.apply_fx({"rel": {c: 6}, "prestigio": 1}, "Acuerdo con " + nm)
	GS.push_news("%s y %s cierran un acuerdo: %s" % [W.COUNTRY_NAME, nm, resumen(prop).left(110)], 2)
	GS.log_history("Acuerdo con " + nm, resumen(prop))
	GS.toast.emit("Acuerdo con %s: %s" % [nm, resumen(prop).left(90)], "good", "acuerdo")
	GS.remember("acuerdo", {"who": c})
	Sfx.play("stamp", -6.0)


## Rechazaron nuestra propuesta: si llevaba amenaza, toca decidir si se cumple
static func _rechazada(c: String, prop: Dictionary) -> void:
	var am: Dictionary = prop.get("amenaza", {})
	if am.is_empty():
		return
	var ms := mesa(c)
	ms["amenaza"] = am.duplicate()
	GS.spawn({"id": "amenaza_%s_%d" % [c, GS.day], "type": "advisor", "who": "exteriores", "gen": true,
		"title": "%s no cede" % nombre(c),
		"text": "Presidente, %s ha rechazado nuestra propuesta. Usted les avisó: %s. Si no lo cumplimos, nadie se volverá a creer nuestras amenazas (credibilidad: %d de 100). Si lo cumplimos, la relación lo va a notar." % [lider(c), texto_amenaza(am), int(credibilidad())],
		"choices": [
			{"t": "Cumplir la amenaza: %s." % String(AMENAZAS.get(String(am["k"]), {"name": "?"})["name"]).to_lower(), "fx": {"amenaza": {"cumplir": c}}},
			{"t": "Echarse atrás.", "fx": {"amenaza": {"retirar": c}}, "rec": "exteriores"}],
		"default": 1})


## Efecto de las decisiones: {"cumplir": país} o {"retirar": país}
static func fx_amenaza(v: Dictionary) -> void:
	if v.has("cumplir"):
		var c := String(v["cumplir"])
		var am: Dictionary = mesa(c).get("amenaza", {})
		mesa(c).erase("amenaza")
		if not am.is_empty():
			cumplir(c, am)
			_cred(8.0)
			_hist(c, "yo", "aviso", "Cumplimos lo que dijimos: %s." % String(AMENAZAS.get(String(am["k"]), {"name": "?"})["name"]).to_lower())
	if v.has("retirar"):
		var c2 := String(v["retirar"])
		mesa(c2).erase("amenaza")
		_cred(-15.0)
		_hist(c2, "yo", "aviso", "No cumplimos la amenaza.")
		GS.push_news("%s se echa atrás en su pulso con %s" % [W.COUNTRY_NAME, nombre(c2)], 1)


## Cumplir una amenaza (lo mismo que las acciones del mapa del mundo)
static func cumplir(c: String, am: Dictionary) -> void:
	var nm := nombre(c)
	var k := String(am.get("k", ""))
	match k:
		"corte":
			var r := String(am.get("r", R.ARMAS.get(GS.pais, "")))
			# cortarles lo que les vendíamos por contrato es romper el contrato
			romper_ventas(c, r)
			GS.apply_fx({"rel": {c: -20}, "prestigio": -1}, "Diplomacia")
			GS.push_news("%s corta %s a %s" % [W.COUNTRY_NAME, "el agua del río Seco" if r == "agua" else "el suministro de " + rnom(r), nm], 3)
			if humano(c):
				Red.cortes_propios[c] = r
				Red.accion(c, "corte", {"recurso": r})
		"sanciones":
			GS.apply_fx({"rel": {c: -25}, "economia": -1.0, "prestigio": 1}, "Diplomacia")
			GS.push_news("%s impone sanciones económicas a %s" % [W.COUNTRY_NAME, nm], 3)
			GS.countries[c]["cd"]["sanciones"] = GS.day + 180
			if humano(c):
				Red.accion(c, "sanciones")
		"embargo":
			GS.apply_fx(Mercado.embargar(c), "Diplomacia")
			GS.push_news("%s decreta un embargo comercial contra %s" % [W.COUNTRY_NAME, nm], 3)
			if humano(c):
				Red.accion(c, "embargo")
		"aranceles":
			GS.apply_fx({"rel": {c: -12}, "economia": -0.4, "empresarios": -1}, "Diplomacia")
			GS.push_news("%s sube los aranceles a los productos de %s" % [W.COUNTRY_NAME, nm], 2)
			if humano(c):
				Red.accion(c, "aranceles")
		"embajador":
			GS.apply_fx({"rel": {c: -15}, "militares": 1}, "Diplomacia")
			GS.push_news("%s expulsa al embajador de %s" % [W.COUNTRY_NAME, nm], 2)
			if humano(c):
				Red.accion(c, "embajador")
		"tropas":
			GS.apply_fx({"rel": {c: -20}, "militares": 2, "estabilidad": -1, "prestigio": -1, "seguridad": 1}, "Diplomacia")
			GS.push_news("%s moviliza tropas en la frontera con %s" % [W.COUNTRY_NAME, nm], 3)
			if humano(c):
				Red.accion(c, "tropas")
	GS.log_history("Diplomacia: " + nm, "Amenaza cumplida: " + String(AMENAZAS.get(k, {"name": k})["name"]))


## La IA cumple (o no) la amenaza que traía su propuesta, si se la hemos rechazado
static func _ia_cumple(c: String, prop: Dictionary) -> void:
	var am: Dictionary = prop.get("amenaza", {})
	if am.is_empty():
		return
	var pers := GS.country_pers(c)
	var p := float({"agresivo": 0.8, "volatil": 0.6, "orgulloso": 0.55, "pragmatico": 0.4, "paciente": 0.3}.get(pers, 0.5))
	if GS.rng.randf() >= p:
		_hist(c, "ellos", "aviso", "Lo dejamos estar. Por esta vez.")
		return
	var k := String(am.get("k", ""))
	var nm := nombre(c)
	_hist(c, "ellos", "aviso", "Se lo advertimos.")
	match k:
		"corte":
			var r := String(am.get("r", "gas"))
			if not GS.mercado.get("cortes", {}).has(r):
				Mercado.cortar(c, r)
		"sanciones":
			GS.apply_fx({"rel": {c: -15}, "economia": -2.0, "empresarios": -2}, "Sanciones de " + nm)
			GS.push_news("%s impone sanciones económicas a %s" % [nm, W.COUNTRY_NAME], 3)
		"aranceles":
			GS.apply_fx({"rel": {c: -8}, "economia": -1.2, "empresarios": -1}, "Aranceles de " + nm)
			GS.push_news("%s sube los aranceles a los productos de %s" % [nm, W.COUNTRY_NAME], 2)
		_:
			GS.apply_fx({"rel": {c: -10}}, nm)


# ------------------------------------------------------------------ con otro jugador (por la red)

## Lo que llega de otro jugador: propuestas, respuestas, contratos rotos
static func recibir(de: String, datos: Dictionary) -> void:
	var ms := mesa(de)
	var nm := nombre(de)
	var quien := "%s (%s)" % [lider(de), nm]
	match String(datos.get("tipo", "")):
		"propuesta":
			var p := invertir(datos.get("prop", {}))
			p["nid"] = String(datos.get("prop", {}).get("nid", ""))
			p["amenaza"] = (datos.get("prop", {}).get("amenaza", {}) as Dictionary).duplicate()
			ms["prop"] = p
			ms["autor"] = "ellos"
			ms["v"] = int(datos.get("v", 1))
			ms["estado"] = "abierta"
			ms["caduca"] = GS.day + VIDA + 10
			ms["nuevo"] = true
			var txt := String(datos.get("t", ""))
			var aviso := ""
			if not (p["amenaza"] as Dictionary).is_empty():
				aviso = " Avisa: %s." % texto_amenaza(p["amenaza"]).replace("cortarles", "cortarnos").replace("expulsar a su embajador", "expulsar a nuestro embajador")
			_hist(de, "ellos", "propuesta", (txt + aviso).strip_edges(), p)
			GS.toast.emit("%s le hace una propuesta (mesa de negociación)" % quien, "info", "acuerdo")
			_aviso_despacho(de, p)
		"acepta":
			if int(datos.get("v", -1)) == int(ms.get("v", 0)) and String(ms.get("autor", "")) == "yo" and String(ms.get("estado", "")) in ["abierta", "retirada"]:
				_hist(de, "ellos", "acepta", "Aceptamos.")
				_cerrar_trato(de, ms["prop"])
				if not (ms["prop"].get("amenaza", {}) as Dictionary).is_empty():
					_cred(3.0)
		"rechaza":
			if int(datos.get("v", -1)) == int(ms.get("v", 0)) and String(ms.get("autor", "")) == "yo" and String(ms.get("estado", "")) == "abierta":
				ms["estado"] = "rechazada"
				_hist(de, "ellos", "rechaza", String(datos.get("t", "")) if String(datos.get("t", "")) != "" else "No nos interesa.")
				GS.toast.emit("%s rechaza su propuesta" % quien, "warn", "acuerdo")
				_rechazada(de, ms["prop"])
		"retira":
			if int(datos.get("v", -1)) == int(ms.get("v", 0)) and String(ms.get("autor", "")) == "ellos" and String(ms.get("estado", "")) == "abierta":
				ms["estado"] = "retirada"
				_hist(de, "ellos", "retira", "Retiran su propuesta.")
		"rompe":
			var k := Mercado.quitar_contrato(String(datos.get("id", "")))
			if not k.is_empty():
				GS.apply_fx({"rel": {de: -15}}, nm)
				_hist(de, "ellos", "aviso", "Rompen el contrato: %s." % _min(Mercado.texto_contrato(k)))
				GS.toast.emit("%s rompe un contrato con nosotros" % quien, "bad", "acuerdo")
				GS.push_news("%s rompe su contrato con %s" % [nm, W.COUNTRY_NAME], 2)


## Un mensaje de texto de otro jugador también queda en la mesa
static func texto_recibido(de: String, t: String) -> void:
	_hist(de, "ellos", "texto", t)
	mesa(de)["nuevo"] = true


# ------------------------------------------------------------------ contratos

## Romper un contrato antes de tiempo: relación, credibilidad y una indemnización (un mes de lo que valía)
static func romper(id: String) -> void:
	var k := Mercado.contrato(id)
	if k.is_empty():
		return
	var c := String(k["con"])
	var pena := maxf(0.0, absf(float(k.get("vol", 1.0))) * float(k.get("precio", 100.0)) * K * 0.5) if String(k.get("tipo", "")) == "venta" else absf(float(k.get("m", 0.0)))
	Mercado.quitar_contrato(id)
	GS.apply_fx({"rel": {c: -15}, "money": -pena}, "Contrato roto")
	_cred(-8.0)
	_hist(c, "yo", "aviso", "Rompemos el contrato: %s." % _min(Mercado.texto_contrato(k)))
	GS.push_news("%s rompe su contrato con %s" % [W.COUNTRY_NAME, nombre(c)], 2)
	if humano(c):
		Red.accion(c, "nego", {"tipo": "rompe", "id": id})


## Cortar un recurso a quien se lo vendemos por contrato rompe esos contratos (con su penalización y aviso)
static func romper_ventas(c: String, r: String) -> void:
	for kk in Mercado.contratos_con(c):
		if String(kk.get("tipo", "")) == "venta" and String(kk["r"]) == r and bool(kk["vendo"]):
			romper(String(kk["id"]))


# ------------------------------------------------------------------ cada día y cada mes

static func tick() -> void:
	if not (GS.diplo is Dictionary) or GS.diplo.is_empty():
		return
	for c in _d()["mesas"].keys():
		var ms: Dictionary = _d()["mesas"][c]
		if String(ms.get("estado", "")) == "abierta" and GS.day > int(ms.get("caduca", 0)):
			ms["estado"] = "caducada"
			ms["contras"] = 0
			_hist(c, "sistema", "aviso", "La propuesta ha caducado.")
			if String(ms.get("autor", "")) == "ellos" and not humano(c):
				_ia_cumple(c, ms["prop"])


## La IA también propone: vender lo que nos falta, comprar lo que nos sobra, tratados y, los duros, exigencias
static func monthly() -> void:
	if GS.day < 45 or GS.rng.randf() > 0.3 or GS.game_ended:
		return
	var paises := W.COUNTRIES.keys()
	paises.shuffle()
	for c in paises:
		if humano(c) or abierta(c) or not GS.countries.has(c) or Mercado.embargado(c):
			continue
		var p := _oferta_ia(c)
		if p.is_empty():
			continue
		var ms := mesa(c)
		var nid := _nid()
		var i := 0
		for lado in ["da", "pide"]:
			for cl in p.get(lado, []):
				cl["id"] = "%s-%d" % [nid, i]
				i += 1
		p["nid"] = nid
		ms["prop"] = p
		ms["autor"] = "ellos"
		ms["v"] = int(ms.get("v", 0)) + 1
		ms["estado"] = "abierta"
		ms["caduca"] = GS.day + VIDA
		ms["nuevo"] = true
		ms["contras"] = 0
		var txt := String(p.get("t", ""))
		if not (p.get("amenaza", {}) as Dictionary).is_empty():
			txt += " Y si no: %s." % texto_amenaza(p["amenaza"]).replace("si no, ", "").replace("cortarles", "les cortaremos").replace("sanciones económicas", "habrá sanciones")
		_hist(c, "ellos", "propuesta", txt.strip_edges(), p)
		_aviso_despacho(c, p)
		return


## Qué propondría un país de la IA ahora mismo (o {})
static func _oferta_ia(c: String) -> Dictionary:
	var rel := float(GS.countries[c]["rel"])
	var pers := GS.country_pers(c)
	var arma := String(R.ARMAS.get(c, ""))
	# los duros, con la relación por los suelos y un arma que nos duele: exigencias con amenaza
	if pers in ["agresivo", "volatil"] and rel < -20.0 and arma != "" and arma != "agua" and Mercado.perfil(arma) < -0.5 and not GS.mercado.get("cortes", {}).has(arma):
		var exige := [{"tipo": "dinero", "m": roundf(randf_range(6.0, 12.0)) * 100.0}] if GS.rng.randf() < 0.5 else [{"tipo": "tratado", "k": "energia"}]
		if tiene_tratado(c, "energia") and exige[0]["tipo"] == "tratado":
			exige = [{"tipo": "dinero", "m": 800.0}]
		return {"da": exige, "pide": [], "amenaza": {"k": "corte", "r": arma}, "t": "Las cosas entre nuestros países no van bien. Para que sigan funcionando, esto es lo que pedimos."}
	if rel < -30.0:
		return {}
	# nos vende lo que nos falta
	for r in R.RECURSOS.keys():
		var pf := perfil_de(c, r)
		var falta := -Mercado.perfil(r) + Mercado.contratado(r)
		if pf >= 2.0 and falta >= 0.8 and comprometido(c, r, true) <= 0.0:
			var vol := snappedf(minf(minf(2.0, falta), pf), 0.5)
			var pm := precio_mercado(r)
			var pr := roundf(pm * (1.08 - clampf(rel, -30.0, 60.0) / 1000.0))
			return {"da": [], "pide": [{"tipo": "venta", "r": r, "vol": vol, "precio": pr, "meses": 12 if GS.rng.randf() < 0.6 else 24}], "amenaza": {},
				"t": "Sabemos que necesitan %s. Les ofrecemos un suministro estable a precio fijo, a salvo de los vaivenes del mercado." % rnom(r)}
	# nos compra lo que nos sobra
	for r2 in R.RECURSOS.keys():
		var pf2 := perfil_de(c, r2)
		var sobra := Mercado.perfil(r2) - Mercado.contratado(r2)
		if pf2 <= -2.0 and sobra >= 0.8 and comprometido(c, r2, false) <= 0.0:
			var vol2 := snappedf(minf(minf(2.0, sobra), -pf2), 0.5)
			var pr2 := roundf(precio_mercado(r2) * (0.95 + clampf(rel, -30.0, 60.0) / 1500.0))
			return {"da": [{"tipo": "venta", "r": r2, "vol": vol2, "precio": pr2, "meses": 12}], "pide": [], "amenaza": {},
				"t": "Nos interesa comprarles %s con un contrato a un año. Precio fijo: ustedes cobran seguro." % rnom(r2)}
	# los amigos proponen tratados
	if rel >= 40.0:
		for k in ["comercio", "inversion"]:
			if not tiene_tratado(c, k):
				return {"da": [{"tipo": "tratado", "k": k}], "pide": [], "amenaza": {}, "t": "Nuestras relaciones son excelentes. ¿Por qué no lo dejamos por escrito?"}
	return {}


## La propuesta llega al despacho como una visita de Exteriores: abrir la mesa, aceptar tal cual o rechazar
static func _aviso_despacho(c: String, p: Dictionary) -> void:
	var nm := nombre(c)
	var lineas := []
	for cl in p.get("pide", []):
		lineas.append("· Nos dan: " + _min(texto(cl, "pide")))
	for cl2 in p.get("da", []):
		lineas.append("· Piden: " + _min(texto(cl2, "da")))
	var am: Dictionary = p.get("amenaza", {})
	var txt := "Presidente, %s, de %s, nos pone una propuesta sobre la mesa:\n%s" % [lider(c), nm, "\n".join(lineas)]
	if not am.is_empty():
		txt += "\nY avisa de que, si no aceptamos, %s." % texto_amenaza(am).replace("si no, ", "").replace("cortarles", "nos cortará").replace("sanciones económicas", "habrá sanciones")
	var vp := valor_propio(p)
	if absf(float(vp["mes"])) >= 1.0:
		txt += "\nFrente al mercado, para nosotros: %s al mes." % UI.money(float(vp["mes"]), true)
	GS.spawn({"id": "propuesta_%s_%d" % [c, GS.day], "type": "advisor", "who": "exteriores", "gen": true,
		"title": "%s nos hace una propuesta" % nm, "text": txt,
		"choices": [
			{"t": "Verla en la mesa de negociación (contraoferta, preguntas...).", "fx": {"mesa": c}, "rec": "exteriores"},
			{"t": "Aceptarla tal cual.", "fx": {"negocia": {"acepta": c}}},
			{"t": "Rechazarla.", "fx": {"negocia": {"rechaza": c}}},
			{"t": "Dejarla para más tarde.", "fx": {}}],
		"default": 3})


## Efecto de las decisiones del despacho: {"acepta": país} o {"rechaza": país}
static func fx(v: Dictionary) -> void:
	if v.has("acepta"):
		aceptar(String(v["acepta"]))
	if v.has("rechaza"):
		rechazar(String(v["rechaza"]))
