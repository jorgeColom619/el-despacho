extends RefCounted
## Mercado mundial: precio de cada recurso (índice 100 = lo normal), cortes de suministro y embargos.
##
## El país que se gobierna compra y vende según su perfil (recursos_data.gd). Cuando un precio se aleja de 100:
##   · el saldo mensual gana o pierde dinero (saldo()),
##   · la economía mejora o empeora (economia_mod(), en el objetivo del medidor),
##   · los básicos (gas, petróleo, alimentos) empujan la inflación de quien los compra (inflacion_mod()).
## Un corte (un proveedor enfadado cierra el grifo) encarece ese recurso solo para nosotros.
##
## Estado en GS.mercado: {"precios": {recurso: índice}, "antes": {recurso: índice del mes pasado},
##   "cortes": {recurso: {"who", "until", "prima"}}, "embargos": {país: día final}}

const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")

## Fracción del PIB mensual que mueve una unidad de recurso con el precio al doble
const UNIDAD := 0.004
## Lo que encarece un corte a quien lo sufre
const PRIMA_CORTE := 0.6
## Lo que encarece buscarse otros proveedores (tras un corte o un embargo propio)
const PRIMA_OTROS := 0.2


static func nuevo(rng: RandomNumberGenerator) -> Dictionary:
	var p := {}
	for r in R.RECURSOS.keys():
		p[r] = roundf(rng.randf_range(92.0, 108.0))
	return {"precios": p, "antes": p.duplicate(), "cortes": {}, "embargos": {}}


static func _m() -> Dictionary:
	if GS.mercado.is_empty() or not GS.mercado.has("precios"):
		GS.mercado = nuevo(GS.rng)
	return GS.mercado


## Saldo de un recurso para el país que se gobierna (el agua cortada se lleva cosechas: menos alimentos)
static func perfil(r: String) -> float:
	var v := float(R.PERFILES.get(GS.pais, {}).get(r, 0))
	if r == "alimentos" and _m()["cortes"].has("agua"):
		v -= 3.0
	return v


## Precio que pagamos nosotros (con la prima si nos han cortado ese recurso)
static func precio(r: String) -> float:
	var m := _m()
	var p := float(m["precios"].get(r, 100.0))
	var c: Dictionary = m["cortes"].get(r, {})
	if not c.is_empty() and perfil(r) < 0.0:
		p *= 1.0 + float(c.get("prima", PRIMA_CORTE))
	return p


## Dinero al mes que nos da (o quita) un recurso respecto a un año normal
static func saldo_de(r: String) -> float:
	return perfil(r) * (precio(r) - 100.0) / 100.0 * UNIDAD * GS.gdp / 12.0


static func saldo() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var s := 0.0
	for r in R.RECURSOS.keys():
		s += saldo_de(r)
	return s


static func economia_mod() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var e := 0.0
	for r in R.RECURSOS.keys():
		e += perfil(r) * (precio(r) - 100.0) / 100.0 * 1.5
	return clampf(e, -10.0, 8.0)


static func inflacion_mod() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var i := 0.0
	for r in R.BASICOS:
		i += (precio(r) - 100.0) / 100.0 * (0.4 + maxf(0.0, -perfil(r)) * 0.3)
	return clampf(i, -1.5, 5.0)


# ------------------------------------------------------------------ cada mes

static func monthly(dd: Dictionary) -> void:
	var m := _m()
	var rng: RandomNumberGenerator = GS.rng
	m["antes"] = m["precios"].duplicate()
	var month := int(dd.get("month", 1))
	for r in R.RECURSOS.keys():
		var p := float(m["precios"][r])
		# vuelve poco a poco a lo normal, con ruido; el gas, más caro en invierno
		p += (100.0 - p) * 0.12 + rng.randf_range(-5.0, 5.0)
		if r == "gas":
			p += 4.0 if month in [11, 12, 1, 2] else (-3.0 if month in [6, 7, 8] else 0.0)
		# los cortes en marcha también tensan el mercado mundial
		if m["cortes"].has(r):
			p += 2.0
		m["precios"][r] = clampf(p, 40.0, 300.0)
	var sacudido := ""
	if rng.randf() < 0.05:
		var s: Array = R.SACUDIDAS.pick_random()
		sacudida(String(s[0]), float(s[1]), String(s[2]))
		sacudido = String(s[0])
	_fin_cortes()
	_amenazas(dd)
	_avisos(sacudido)


## Un cambio brusco del precio mundial de un recurso, con su titular
static func sacudida(r: String, cambio: float, titular: String) -> void:
	var m := _m()
	m["precios"][r] = clampf(float(m["precios"][r]) * (1.0 + cambio), 40.0, 300.0)
	if titular != "":
		GS.push_news(titular, 2 if absf(cambio) >= 0.25 else 1)


static func _fin_cortes() -> void:
	var m := _m()
	for r in m["cortes"].keys():
		var c: Dictionary = m["cortes"][r]
		# los cortes de otro jugador solo acaban cuando él reabre (o al cabo de un año)
		var humano := Red.es_humano(String(c["who"]))
		if GS.day >= int(c["until"]) or (not humano and float(GS.countries.get(String(c["who"]), {}).get("rel", 0.0)) > 10.0):
			m["cortes"].erase(r)
			GS.push_news(_txt_fin(r, String(c["who"])), 2)
	for c2 in m["embargos"].keys():
		if GS.day >= int(m["embargos"][c2]):
			m["embargos"].erase(c2)


static func _txt_fin(r: String, who: String) -> String:
	var nm := String(W.COUNTRIES.get(who, {}).get("name", who))
	if r == "agua":
		return "%s vuelve a abrir las compuertas del río Seco" % nm
	return "%s reanuda el suministro de %s a %s" % [nm, String(R.RECURSOS[r]["name"]).to_lower(), W.COUNTRY_NAME]


## Un país con un arma y una relación por los suelos puede cerrarnos el grifo
static func _amenazas(dd: Dictionary) -> void:
	var m := _m()
	if GS.day < 60 or GS._is_queued("corte_suministro"):
		return
	for c in R.ARMAS.keys():
		# los países de otros jugadores cortan cuando lo decide su jugador, no la IA
		if not GS.countries.has(c) or Red.es_humano(c):
			continue
		var r: String = R.ARMAS[c]
		if m["cortes"].has(r):
			continue
		if r == "agua":
			# el río Seco nace en Sarvenia y baja hacia Valdoria
			if GS.pais != "valdoria":
				continue
		elif perfil(r) >= 0.0:
			continue
		var rel := float(GS.countries[c]["rel"])
		if rel > -25.0:
			continue
		var p := 0.06 + (-25.0 - rel) * 0.004
		if GS.country_pers(c) in ["agresivo", "volatil"]:
			p *= 1.5
		if r == "gas" and int(dd.get("month", 1)) in [11, 12, 1, 2]:
			p *= 1.4
		if r == "agua" and int(dd.get("month", 1)) in [6, 7, 8]:
			p *= 1.5
		if GS.rng.randf() < p:
			cortar(c, r)
			return


## Un país nos corta un recurso: lo encarece para nosotros y llega el aviso al despacho
static func cortar(c: String, r: String) -> void:
	var m := _m()
	m["cortes"][r] = {"who": c, "until": GS.day + GS.rng.randi_range(150, 240), "prima": PRIMA_CORTE}
	if r != "agua":
		m["precios"][r] = clampf(float(m["precios"][r]) * 1.12, 40.0, 300.0)
	var cd: Dictionary = W.COUNTRIES[c]
	var nm := String(cd["name"])
	# con su artículo: «el Emir Faisal al-Rashid», «la Presidenta Amina Seko»
	var lider := "%s %s %s" % ["la" if String(cd["title"]).ends_with("a") else "el", cd["title"], cd["leader"]]
	if Red.es_humano(c):
		_corte_humano(c, r, nm, lider)
		return
	if r == "agua":
		GS.push_news("%s cierra las compuertas del río Seco: la cuenca se queda sin agua" % nm, 3)
		GS.spawn({"id": "corte_suministro", "type": "advisor", "who": "exteriores", "gen": true,
			"title": "%s nos corta el agua" % nm,
			"text": "Presidente, %s ha cerrado las compuertas de la presa del río Seco. Los regantes de la cuenca se quedan sin agua en plena campaña y las cosechas se van a perder: tendremos que comprar fuera los alimentos que antes vendíamos. Es una represalia por cómo están las relaciones." % lider,
			"choices": [
				{"t": "Negociar: pagar una compensación por el agua.", "fx": {"money": -400, "rel": {c: 15}, "prestigio": -2, "mercado": {"fin_corte": "agua"}}, "rec": "exteriores"},
				{"t": "Llevarlo a la Unión Continental y a los tribunales.", "fx": {"prestigio": 2, "rel": {c: -8, "union": 4}, "estabilidad": -1}},
				{"t": "Plan de choque: pozos, trasvases y desaladoras.", "fx": {"money": -1800, "ambiente": -2, "mercado": {"fin_corte": "agua"}}, "rec": "economia"},
				{"t": "Movilizar tropas en la frontera.", "fx": {"rel": {c: -15}, "militares": 3, "estabilidad": -3, "prestigio": -2}}],
			"default": 1})
		return
	var rn := String(R.RECURSOS[r]["name"]).to_lower()
	GS.push_news("%s corta el suministro de %s a %s" % [nm, rn, W.COUNTRY_NAME], 3)
	GS.spawn({"id": "corte_suministro", "type": "advisor", "who": "economia", "gen": true,
		"title": "%s nos corta el %s" % [nm, rn] if r in ["gas", "petroleo"] else "%s corta las ventas de %s" % [nm, rn],
		"text": "Presidente, %s ha cerrado el grifo: %s deja de vendernos %s mientras no cambie nuestra política hacia su país. Lo que compremos en otros mercados nos costará un %d %% más, y lo notarán las empresas, las facturas y los precios." % [lider, nm, rn, int(PRIMA_CORTE * 100.0)],
		"choices": [
			{"t": "Negociar con %s: reabrir el grifo a cambio de gestos." % cd["leader"], "fx": {"rel": {c: 18}, "prestigio": -3, "mercado": {"fin_corte": r}}, "rec": "exteriores"},
			{"t": "Buscar otros proveedores, cueste lo que cueste.", "fx": {"money": -1500, "mercado": {"diversificar": r}}, "rec": "economia"},
			{"t": "Aguantar: ahorro y racionamiento.", "fx": {"estabilidad": -2, "trabajadores": -2, "empresarios": -2}},
			{"t": "Responder con sanciones.", "fx": {"rel": {c: -15}, "prestigio": 2, "militares": 1}}],
		"default": 1})


## Corte decidido por otro jugador: dura hasta que lo reabra (o un año); se le puede pedir que lo reabra
static func _corte_humano(c: String, r: String, nm: String, lider: String) -> void:
	_m()["cortes"][r]["until"] = GS.day + 365
	var agua := r == "agua"
	var rn := "el agua del río Seco" if agua else "el suministro de " + String(R.RECURSOS[r]["name"]).to_lower()
	GS.push_news("%s corta %s a %s" % [nm, rn, W.COUNTRY_NAME], 3)
	GS.spawn({"id": "corte_suministro", "type": "advisor", "who": "exteriores" if agua else "economia", "gen": true,
		"title": "%s nos corta el agua" % nm if agua else ("%s nos corta el %s" % [nm, String(R.RECURSOS[r]["name"]).to_lower()] if r in ["gas", "petroleo"] else "%s corta las ventas de %s" % [nm, String(R.RECURSOS[r]["name"]).to_lower()]),
		"text": "Presidente, %s ha decidido cortarnos %s. No es un error de los técnicos: es una decisión política, y la ha tomado en persona. Lo que compremos fuera nos costará un %d %% más mientras dure." % [lider, rn, int(PRIMA_CORTE * 100.0)],
		"choices": [
			{"t": "Pedirle que reabra el grifo.", "fx": {"rel": {c: 4}, "mercado": {"pedir": r, "a": c}}, "rec": "exteriores"},
			{"t": "Buscar otros proveedores, cueste lo que cueste." if not agua else "Plan de choque: pozos, trasvases y desaladoras.", "fx": {"money": -1500, "mercado": {"diversificar": r}} if not agua else {"money": -1800, "ambiente": -2, "mercado": {"fin_corte": "agua"}}, "rec": "economia"},
			{"t": "Aguantar: ahorro y racionamiento.", "fx": {"estabilidad": -2, "trabajadores": -2, "empresarios": -2}},
			{"t": "Responder con sanciones.", "fx": {"rel": {c: -15}, "prestigio": 2, "militares": 1, "mercado": {"sancionar": c}}}],
		"default": 1})


## Embargo de otro jugador contra nosotros: si nos vendía algo que necesitamos, toca buscarlo fuera (más caro)
static func embargo_recibido(c: String) -> Dictionary:
	var m := _m()
	var econ := -1.0
	var su: Dictionary = R.PERFILES.get(c, {})
	for r in su.keys():
		if int(su[r]) >= 3 and perfil(r) < 0.0 and not m["cortes"].has(r):
			m["cortes"][r] = {"who": c, "until": GS.day + 365, "prima": PRIMA_OTROS}
			econ -= 0.5
	return {"rel": {c: -30}, "economia": econ}


## Efectos de las decisiones: {"fin_corte": recurso} o {"diversificar": recurso}
static func fx(v: Dictionary) -> void:
	var m := _m()
	if v.has("fin_corte"):
		var r := String(v["fin_corte"])
		if m["cortes"].has(r):
			var who := String(m["cortes"][r]["who"])
			m["cortes"].erase(r)
			GS.push_news(_txt_fin(r, who), 2)
	if v.has("diversificar"):
		var r2 := String(v["diversificar"])
		if m["cortes"].has(r2):
			m["cortes"][r2]["prima"] = PRIMA_OTROS
	# contra otro jugador: pedirle que reabra, o devolverle las sanciones
	if v.has("pedir"):
		Red.accion(String(v.get("a", "")), "pide_reabrir", {"recurso": String(v["pedir"])})
	if v.has("sancionar"):
		Red.accion(String(v["sancionar"]), "sanciones")


## Embargo comercial nuestro a un país: deja de comprarnos y de vendernos. Le duele a él (y a su relación), pero
## si era nuestro proveedor principal de algo, a nosotros también.
static func embargar(c: String) -> Dictionary:
	var m := _m()
	m["embargos"][c] = GS.day + 365
	var fx := {"rel": {c: -30}, "prestigio": 1}
	var su: Dictionary = R.PERFILES.get(c, {})
	var econ := -0.5
	for r in su.keys():
		if int(su[r]) >= 4 and perfil(r) < 0.0 and not m["cortes"].has(r):
			m["cortes"][r] = {"who": c, "until": GS.day + 365, "prima": PRIMA_OTROS}
			econ -= 1.0
		elif int(su[r]) <= -2 and perfil(r) > 0.0:
			econ -= 0.5
	fx["economia"] = econ
	return fx


static func embargado(c: String) -> bool:
	return GS.mercado.get("embargos", {}).has(c)


## Lo que exporta e importa un país (para la ficha del mapa)
static func resumen(c: String) -> String:
	var su: Dictionary = R.PERFILES.get(c, {})
	var ex := []
	var im := []
	for r in R.RECURSOS.keys():
		var v := int(su.get(r, 0))
		if v >= 2:
			ex.append(String(R.RECURSOS[r]["name"]))
		elif v <= -2:
			im.append(String(R.RECURSOS[r]["name"]))
	var out := ""
	if ex.size() > 0:
		out += "Exporta: " + ", ".join(ex)
	if im.size() > 0:
		out += ("  ·  " if out != "" else "") + "Importa: " + ", ".join(im)
	return out


## Precios que se han movido mucho este mes: titular para el periódico
static func _avisos(ya: String) -> void:
	var m := _m()
	for r in R.RECURSOS.keys():
		if r == ya:
			continue
		var a := float(m["antes"][r])
		var p := float(m["precios"][r])
		if a > 0.0 and absf(p - a) / a >= 0.15:
			GS.push_news("%s: el precio %s un %d %% en un mes" % [R.RECURSOS[r]["name"], "sube" if p > a else "baja", int(absf(p - a) / a * 100.0)], 1)
