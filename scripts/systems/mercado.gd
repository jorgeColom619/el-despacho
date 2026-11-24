extends RefCounted
## Mercado mundial y recursos del país: lo que se produce, cómo, cuánto se vende y a quién.
##
## Precios con índice 100 = lo normal. Cada país produce y consume cada recurso (recursos_data.gd); lo que le sobra
## lo vende y lo que le falta lo compra. El país que se gobierna decide:
##   · cuánto produce (con un ritmo: los pozos y las fábricas no se abren de golpe) y hasta dónde amplía la
##     capacidad (obras que tardan meses y tienen un techo: no hay gas donde no hay yacimientos),
##   · cómo lo produce (método): coste, capacidad, efectos en el medio ambiente, el empleo, el prestigio... y
##     algún accidente,
##   · a quién vende o compra, cuánto y a qué precio, con contratos negociados en la mesa de negociación
##     (systems/negociacion.gd): el resto se vende o se compra en el mercado al precio del día.
## El precio mundial depende de lo que produce el mundo: si un país recorta, sube; si inunda el mercado, baja. Los
## grandes exportadores de la IA reaccionan (recortan si se hunde el precio, bombean si se dispara).
##
## Todo se mide frente a un año normal (la producción y el método de partida), así que sin tocar nada el juego va
## como antes: el saldo mensual solo nota lo que se aleja de lo normal.
##   · saldo(): dinero al mes (comercio, contratos, pagos y costes de producción), dentro de GS.monthly_balance()
##   · economia_mod(): objetivo de la economía · inflacion_mod(): inflación · efecto(k): medidores y grupos
## Un corte (un proveedor enfadado cierra el grifo) encarece lo que compramos en el mercado de ese recurso.
##
## Estado en GS.mercado: {"precios", "antes", "hist": {recurso: [precios]}, "cortes": {recurso: {who, until, prima}},
##   "embargos": {país: día}, "prod": {recurso: {nivel, obj, met, cap, obra, tope, f}}, "contratos": [...],
##   "ia": {país: {recurso: cambio}}, "ia_tope": [...], "jug": {país: {recurso: cambio}} (lo que el anfitrión sabe
##   de los otros jugadores)}

const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")

## Fracción del PIB mensual que mueve una unidad de recurso con el precio al doble (histórico)
const UNIDAD := 0.004
## Dinero al mes que mueve una unidad de recurso por cada punto de precio: 400 M al mes a precio 100. Es el mismo
## para todos los países, así un contrato entre dos jugadores cuadra al céntimo en los dos ordenadores.
const K := 4.0
## Lo que encarece un corte a quien lo sufre
const PRIMA_CORTE := 0.6
## Lo que encarece buscarse otros proveedores (tras un corte o un embargo propio)
const PRIMA_OTROS := 0.2
## Meses de precios que se guardan para las gráficas
const HIST := 24

## Caché de lo que solo cambia cuando cambia la producción (consumo y efectos): se consulta muchas veces al día
static var _pv := 0
static var _c_pv := -1
static var _c_ref: Dictionary = {}
static var _c_cons := {}
static var _c_ef := {}


static func _cache() -> void:
	if _c_pv != _pv or not is_same(GS.mercado, _c_ref):
		_c_pv = _pv
		_c_ref = GS.mercado
		_c_cons = {}
		_c_ef = {}


## Algo ha cambiado en la producción: hay que recalcular
static func _cambio() -> void:
	_pv += 1


static func nuevo(rng: RandomNumberGenerator) -> Dictionary:
	var p := {}
	for r in R.RECURSOS.keys():
		p[r] = roundf(rng.randf_range(92.0, 108.0))
	var m := {"precios": p, "antes": p.duplicate(), "cortes": {}, "embargos": {}}
	_preparar(m)
	return m


static func _m() -> Dictionary:
	if GS.mercado.is_empty() or not GS.mercado.has("precios"):
		GS.mercado = nuevo(GS.rng)
	elif not GS.mercado.has("prod"):
		_preparar(GS.mercado)
	return GS.mercado


## Producción, contratos e historia de precios (también para las partidas de antes de la versión 5.1)
static func _preparar(m: Dictionary) -> void:
	_cambio()
	if not m.has("prod"):
		var prod := {}
		for r in R.RECURSOS.keys():
			var p0 := base_prod(GS.pais, r)
			var met := metodo_inicial(GS.pais, r)
			var cap := minf(techo(GS.pais, r, met), snappedf(p0 + maxf(0.5, p0 * 0.15), 0.5))
			prod[r] = {"nivel": p0, "obj": p0, "met": met, "cap": maxf(cap, p0), "obra": {}, "tope": {}, "f": 1.0}
		m["prod"] = prod
	for k in ["contratos", "ia_tope"]:
		if not m.has(k):
			m[k] = []
	for k2 in ["hist", "ia", "jug"]:
		if not m.has(k2):
			m[k2] = {}
	if (m["hist"] as Dictionary).is_empty():
		for r in R.RECURSOS.keys():
			m["hist"][r] = [float(m["precios"].get(r, 100.0))]


# ------------------------------------------------------------------ datos de partida de cada país

static func consumo0(c: String, r: String) -> float:
	return float(R.CONSUMO.get(c, {}).get(r, 1.0))


## Producción de un año normal: consumo + lo que exporta (o − lo que importa)
static func base_prod(c: String, r: String) -> float:
	return maxf(0.0, consumo0(c, r) + float(R.PERFILES.get(c, {}).get(r, 0)))


static func metodo_inicial(c: String, r: String) -> String:
	var d: Dictionary = R.METODO_INICIAL.get(c, {})
	if d.has(r):
		return String(d[r])
	return String((R.METODOS[r] as Dictionary).keys()[0])


## Capacidad máxima a la que se puede llegar con un método (yacimientos, tierra...)
static func techo(c: String, r: String, met: String) -> float:
	var mult := float(R.METODOS[r].get(met, {}).get("cap", 1.0))
	var t: Dictionary = R.TECHO.get(c, {})
	if t.has(r):
		return float(t[r]) * mult
	return (base_prod(c, r) + R.TECHO_LIBRE) * mult


# ------------------------------------------------------------------ el país que se gobierna

static func prod(r: String) -> Dictionary:
	return _m()["prod"][r]


static func metodo(r: String) -> Dictionary:
	return R.METODOS[r].get(String(prod(r)["met"]), R.METODOS[r][metodo_inicial(GS.pais, r)])


## Lo que sale de verdad este mes (las empresas emergentes van a rachas)
static func nivel(r: String) -> float:
	var pd := prod(r)
	return float(pd["nivel"]) * float(pd.get("f", 1.0))


## Consumo propio, con lo que gastan otros sectores según su método (las fábricas robotizadas usan tecnología...)
static func consumo(r: String) -> float:
	_cache()
	if _c_cons.has(r):
		return _c_cons[r]
	var c := consumo0(GS.pais, r)
	for r2 in R.RECURSOS.keys():
		var u_ahora := float(metodo(r2).get("usa", {}).get(r, 0.0))
		var u_antes := float(R.METODOS[r2][metodo_inicial(GS.pais, r2)].get("usa", {}).get(r, 0.0))
		c += nivel(r2) * u_ahora - base_prod(GS.pais, r2) * u_antes
	c = maxf(0.0, c)
	_c_cons[r] = c
	return c


## Saldo de un recurso: + lo que sobra para vender, − lo que hay que comprar fuera. Sin el agua del río Seco se
## pierden cosechas: dos unidades de alimentos menos (lo que se vendía fuera, o lo que hay que comprar).
static func perfil(r: String) -> float:
	var v := nivel(r) - consumo(r)
	if r == "alimentos" and _m()["cortes"].has("agua"):
		v -= 2.0
	return v


## Precio que pagamos nosotros en el mercado (con la prima si nos han cortado ese recurso)
static func precio(r: String) -> float:
	var m := _m()
	var p := float(m["precios"].get(r, 100.0))
	var c: Dictionary = m["cortes"].get(r, {})
	if not c.is_empty() and perfil(r) < 0.0:
		p *= 1.0 + float(c.get("prima", PRIMA_CORTE))
	return p


## Precio al que vendemos en el mercado (lo ecológico se paga más)
static func precio_venta(r: String) -> float:
	return float(_m()["precios"].get(r, 100.0)) * (1.0 + float(metodo(r).get("prima", 0.0)) / 100.0)


static func coste_u(r: String) -> float:
	return float(metodo(r).get("coste", 50.0))


static func coste_ini(r: String) -> float:
	return float(R.METODOS[r][metodo_inicial(GS.pais, r)].get("coste", 50.0))


## Contratos de venta en vigor de un recurso: neto (+ lo que vendemos por contrato, − lo que compramos)
static func contratado(r: String) -> float:
	var n := 0.0
	for k in _m()["contratos"]:
		if String(k.get("tipo", "venta")) == "venta" and String(k["r"]) == r:
			n += float(k["vol"]) * (1.0 if bool(k["vendo"]) else -1.0)
	return n


## Dinero al mes que nos da (o quita) un recurso frente a un año normal: comercio (contratos y mercado) menos lo
## que cuesta producir de más (o con otro método)
static func saldo_de(r: String) -> float:
	if GS.mercado.is_empty():
		return 0.0
	var m := _m()
	var val := 0.0
	for k in m["contratos"]:
		if String(k.get("tipo", "venta")) == "venta" and String(k["r"]) == r:
			val += float(k["vol"]) * float(k["precio"]) * (1.0 if bool(k["vendo"]) else -1.0)
	var resto := perfil(r) - contratado(r)
	val += resto * (precio_venta(r) if resto >= 0.0 else precio(r))
	var base := float(R.PERFILES.get(GS.pais, {}).get(r, 0)) * 100.0
	var coste := nivel(r) * coste_u(r) - base_prod(GS.pais, r) * coste_ini(r)
	return (val - base - coste) * K


## Pagos mensuales pactados (+ los que cobramos, − los que pagamos)
static func pagos() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var s := 0.0
	for k in _m()["contratos"]:
		if String(k.get("tipo", "")) == "pago":
			s += float(k["m"])
	return s


static func saldo() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var s := pagos()
	for r in R.RECURSOS.keys():
		s += saldo_de(r)
	return s


static func economia_mod() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var e := 0.0
	for r in R.RECURSOS.keys():
		e += saldo_de(r) / (K * 100.0) * 1.5
		e += (nivel(r) - base_prod(GS.pais, r)) * float(R.EMPLEO.get(r, 0.4))
	return clampf(e, -10.0, 8.0)


## Precio medio de lo que compramos fuera (contratos a precio fijo y el resto al del mercado)
static func precio_compra_medio(r: String) -> float:
	var falta := -perfil(r)
	if falta <= 0.0:
		return float(_m()["precios"].get(r, 100.0))
	var v := 0.0
	var p := 0.0
	for k in _m()["contratos"]:
		if String(k.get("tipo", "venta")) == "venta" and String(k["r"]) == r and not bool(k["vendo"]):
			v += float(k["vol"])
			p += float(k["vol"]) * float(k["precio"])
	var en_mercado := maxf(0.0, falta - v)
	return (p + en_mercado * precio(r)) / maxf(0.01, v + en_mercado)


static func inflacion_mod() -> float:
	if GS.mercado.is_empty():
		return 0.0
	var i := 0.0
	for r in R.BASICOS:
		i += (precio_compra_medio(r) - 100.0) / 100.0 * (0.4 + maxf(0.0, -perfil(r)) * 0.3)
	return clampf(i, -1.5, 5.0)


## Lo que mueven los métodos y el nivel de producción en un medidor o un grupo (frente a lo normal)
static func efecto(k: String) -> float:
	if GS.mercado.is_empty() or not GS.mercado.has("prod"):
		return 0.0
	_cache()
	if _c_ef.has(k):
		return _c_ef[k]
	var e := 0.0
	for r in R.RECURSOS.keys():
		var ahora := float(metodo(r).get("fx", {}).get(k, 0.0))
		var antes := float(R.METODOS[r][metodo_inicial(GS.pais, r)].get("fx", {}).get(k, 0.0))
		e += nivel(r) * ahora - base_prod(GS.pais, r) * antes
	e = clampf(e, -8.0, 8.0)
	_c_ef[k] = e
	return e


## Lo que se aleja nuestra producción (y lo que gastamos) de lo normal: lo que mueve el precio mundial
static func desvios() -> Dictionary:
	var d := {}
	for r in R.RECURSOS.keys():
		d[r] = snappedf((nivel(r) - base_prod(GS.pais, r)) - (consumo(r) - consumo0(GS.pais, r)), 0.01)
	return d


# ------------------------------------------------------------------ decisiones de producción

## Cuánto queremos producir (se llega poco a poco). Devuelve "" o por qué no se puede.
static func fijar_objetivo(r: String, v: float) -> String:
	var pd := prod(r)
	v = clampf(snappedf(v, 0.5), 0.0, float(pd["cap"]))
	var tp: Dictionary = pd.get("tope", {})
	if not tp.is_empty():
		var nm := String(W.COUNTRIES.get(String(tp.get("con", "")), {}).get("name", tp.get("con", "")))
		if float(tp.get("max", -1.0)) >= 0.0 and v > float(tp["max"]) + 0.01:
			return "Tiene firmado con %s no producir más de %s hasta el %s." % [nm, UI.num(float(tp["max"]), 1), UI.date_short(int(tp["hasta"]))]
		if float(tp.get("min", -1.0)) >= 0.0 and v < float(tp["min"]) - 0.01:
			return "Tiene firmado con %s producir al menos %s hasta el %s." % [nm, UI.num(float(tp["min"]), 1), UI.date_short(int(tp["hasta"]))]
	pd["obj"] = v
	Red.enviar_produccion(desvios())
	return ""


## Lo que cuesta cambiar de método (reconvertir pozos, fábricas o campos)
static func coste_cambio(r: String) -> float:
	return roundf(maxf(200.0, 240.0 * float(prod(r)["nivel"])) / 10.0) * 10.0


## Cambia el método de producción (efectos al momento; si el nuevo techo es más bajo, se pierde capacidad)
static func cambiar_metodo(r: String, met: String) -> Array:
	var pd := prod(r)
	if String(pd["met"]) == met or not R.METODOS[r].has(met):
		return []
	var coste := coste_cambio(r)
	pd["met"] = met
	var t := techo(GS.pais, r, met)
	pd["cap"] = minf(float(pd["cap"]), t)
	pd["obj"] = minf(float(pd["obj"]), float(pd["cap"]))
	pd["nivel"] = minf(float(pd["nivel"]), float(pd["cap"]))
	if met != "startups":
		pd["f"] = 1.0
	_cambio()
	GS.log_history("Producción de %s" % String(R.RECURSOS[r]["name"]).to_lower(), "Nuevo método: %s" % R.METODOS[r][met]["name"])
	Red.enviar_produccion(desvios())
	return GS.apply_fx({"money": -coste}, "Reconversión")


## Ampliar la capacidad: una obra que tarda meses. Devuelve "" o por qué no se puede.
static func ampliar(r: String) -> String:
	var pd := prod(r)
	if not (pd.get("obra", {}) as Dictionary).is_empty():
		return "Ya hay obras en marcha."
	var t := techo(GS.pais, r, String(pd["met"]))
	var hueco := t - float(pd["cap"])
	if hueco < 0.25:
		return "No hay más yacimientos ni terreno: ha llegado al techo con este método." if R.TECHO.get(GS.pais, {}).has(r) else "Ha llegado al máximo que se puede montar con este método."
	var ob: Array = R.OBRAS[r]
	GS.apply_fx({"money": -float(ob[0])}, "Obras")
	pd["obra"] = {"cap": minf(1.0, hueco), "fin": GS.day + int(ob[1]) * 30, "ini": GS.day}
	GS.push_news("%s invierte en ampliar su producción de %s" % [W.COUNTRY_NAME, String(R.RECURSOS[r]["name"]).to_lower()], 1)
	GS.log_history("Producción de %s" % String(R.RECURSOS[r]["name"]).to_lower(), "Obras para ampliar la capacidad")
	return ""


## Compromiso firmado de producción: no pasar de (max) o no bajar de (min) hasta un día
static func comprometer(r: String, cambio: float, meses: int, con: String) -> void:
	var pd := prod(r)
	var base := float(pd["nivel"])
	var tp := {"max": -1.0, "min": -1.0, "hasta": GS.day + meses * 30, "con": con}
	if cambio < 0.0:
		tp["max"] = maxf(0.0, base + cambio)
		pd["obj"] = minf(float(pd["obj"]), float(tp["max"]))
	else:
		tp["min"] = minf(float(pd["cap"]), base + cambio)
		pd["obj"] = maxf(float(pd["obj"]), float(tp["min"]))
	pd["tope"] = tp
	Red.enviar_produccion(desvios())


# ------------------------------------------------------------------ contratos

static func nuevo_contrato(id: String, con: String, r: String, vol: float, precio_c: float, vendo: bool, meses: int) -> Dictionary:
	var k := {"id": id, "tipo": "venta", "con": con, "r": r, "vol": vol, "precio": precio_c, "vendo": vendo, "desde": GS.day, "hasta": GS.day + meses * 30}
	_m()["contratos"].append(k)
	return k


static func nuevo_pago(id: String, con: String, mensual: float, meses: int) -> Dictionary:
	var k := {"id": id, "tipo": "pago", "con": con, "m": mensual, "desde": GS.day, "hasta": GS.day + meses * 30}
	_m()["contratos"].append(k)
	return k


static func contratos_con(c: String) -> Array:
	var out := []
	for k in _m()["contratos"]:
		if String(k["con"]) == c:
			out.append(k)
	return out


static func contrato(id: String) -> Dictionary:
	for k in _m()["contratos"]:
		if String(k["id"]) == id:
			return k
	return {}


## Valor al mes de un contrato frente a vender o comprar lo mismo en el mercado hoy
static func valor_contrato(k: Dictionary) -> float:
	if String(k.get("tipo", "")) == "pago":
		return float(k["m"])
	var pm := float(_m()["precios"].get(String(k["r"]), 100.0))
	var dif := (float(k["precio"]) - pm) if bool(k["vendo"]) else (pm - float(k["precio"]))
	return float(k["vol"]) * dif * K


static func quitar_contrato(id: String) -> Dictionary:
	var lst: Array = _m()["contratos"]
	for i in lst.size():
		if String(lst[i]["id"]) == id:
			var k: Dictionary = lst[i]
			lst.remove_at(i)
			return k
	return {}


static func texto_contrato(k: Dictionary) -> String:
	var nm := String(W.COUNTRIES.get(String(k["con"]), {}).get("name", k["con"]))
	if String(k.get("tipo", "")) == "pago":
		return ("%s nos paga %s al mes" if float(k["m"]) > 0.0 else "Pagamos a %s %s al mes") % [nm, UI.money(absf(float(k["m"])))]
	var rn := String(R.RECURSOS[String(k["r"])]["name"]).to_lower()
	return ("Vendemos a %s %s u./mes de %s a %d" if bool(k["vendo"]) else "%s nos vende %s u./mes de %s a %d") % [nm, UI.num(float(k["vol"]), 1), rn, int(roundf(float(k["precio"])))]


# ------------------------------------------------------------------ cada mes

static func monthly(dd: Dictionary) -> void:
	var m := _m()
	m["antes"] = m["precios"].duplicate()
	_produccion_mes()
	var rng: RandomNumberGenerator = GS.rng
	var month := int(dd.get("month", 1))
	var manda := not Red.en_partida() or Red.anfitrion()
	if manda:
		_ia_mes()
	for r in R.RECURSOS.keys():
		var p := float(m["precios"][r])
		# va hacia el precio que marca lo que produce el mundo, con ruido; el gas, más caro en invierno
		p += (equilibrio(r) - p) * 0.2 + rng.randf_range(-4.0, 4.0)
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
	_historia()
	_contratos_mes()
	_fin_cortes()
	_amenazas(dd)
	_avisos(sacudido)
	if not manda:
		Red.enviar_produccion(desvios())


## Precio hacia el que va el mercado según lo que se produce en el mundo (100 si todos producen lo normal)
static func equilibrio(r: String) -> float:
	var m := _m()
	var d := 0.0
	var mio: Dictionary = desvios()
	d += float(mio.get(r, 0.0))
	for c in m["ia"].keys():
		d += float(m["ia"][c].get(r, 0.0))
	for c2 in m["jug"].keys():
		if c2 != GS.pais:
			d += float(m["jug"][c2].get(r, 0.0))
	return clampf(100.0 * (1.0 - R.ELASTICIDAD * d / float(R.MUNDO.get(r, 50.0))), 45.0, 260.0)


static func _historia() -> void:
	var m := _m()
	for r in R.RECURSOS.keys():
		var h: Array = m["hist"].get(r, [])
		h.append(float(m["precios"][r]))
		while h.size() > HIST:
			h.pop_front()
		m["hist"][r] = h


## Producción: se acerca a lo que se quiere producir, terminan las obras, caducan los compromisos y, con algunos
## métodos, hay accidentes
static func _produccion_mes() -> void:
	_cambio()
	for r in R.RECURSOS.keys():
		var pd := prod(r)
		var rn := String(R.RECURSOS[r]["name"]).to_lower()
		var ob: Dictionary = pd.get("obra", {})
		if not ob.is_empty() and GS.day >= int(ob["fin"]):
			pd["cap"] = minf(techo(GS.pais, r, String(pd["met"])), float(pd["cap"]) + float(ob["cap"]))
			pd["obra"] = {}
			GS.push_news("Terminan las obras: %s puede producir más %s" % [W.COUNTRY_NAME, rn], 1)
			GS.toast.emit("Terminan las obras: ya puede producir más %s (Comercio y recursos)" % rn, "good", "fabrica")
		var tp: Dictionary = pd.get("tope", {})
		if not tp.is_empty() and GS.day >= int(tp["hasta"]):
			pd["tope"] = {}
			GS.toast.emit("Se acaba el compromiso de producción de %s con %s" % [rn, W.COUNTRIES.get(String(tp.get("con", "")), {}).get("name", "")], "info", "acuerdo")
		var obj := clampf(float(pd["obj"]), 0.0, float(pd["cap"]))
		var nv := float(pd["nivel"])
		if obj > nv:
			nv = minf(obj, nv + R.RITMO_SUBIR)
		elif obj < nv:
			nv = maxf(obj, nv - R.RITMO_BAJAR)
		pd["nivel"] = snappedf(nv, 0.05)
		var vai := float(metodo(r).get("vaiven", 0.0))
		pd["f"] = (1.0 + GS.rng.randf_range(-vai, vai)) if vai > 0.0 else 1.0
		_cambio()
		var rk: Array = metodo(r).get("riesgo", [])
		if rk.size() == 3 and GS.rng.randf() < float(rk[0]) * nivel(r):
			GS.push_news(String(rk[1]), 3)
			GS.apply_fx((rk[2] as Dictionary).duplicate(true), "Accidente")


## Los grandes exportadores de la IA defienden el precio: recortan si se hunde y bombean si se dispara. Si han
## firmado un compromiso de producción, lo cumplen.
static func _ia_mes() -> void:
	var m := _m()
	var vivos := []
	for t in m["ia_tope"]:
		if GS.day < int(t["hasta"]):
			vivos.append(t)
	m["ia_tope"] = vivos
	for c in W.COUNTRIES.keys():
		if Red.es_humano(c):
			m["ia"].erase(c)
			continue
		var cur: Dictionary = m["ia"].get(c, {})
		for r in R.RECURSOS.keys():
			var p := float(R.PERFILES.get(c, {}).get(r, 0))
			var v := float(cur.get(r, 0.0))
			var pz := float(m["precios"][r])
			if p >= 3.0:
				if pz < 85.0 and v > -2.0:
					v -= 0.5
				elif pz > 125.0 and v < 1.5:
					v += 0.5
				elif pz > 92.0 and pz < 112.0 and v != 0.0:
					v = move_toward(v, 0.0, 0.5)
			for t2 in vivos:
				if String(t2["c"]) == c and String(t2["r"]) == r:
					v = float(t2["d"])
			if v != 0.0:
				cur[r] = v
			else:
				cur.erase(r)
		if cur.is_empty():
			m["ia"].erase(c)
		else:
			m["ia"][c] = cur


## Un país de la IA se compromete a cambiar su producción (lo pacta en la mesa de negociación)
static func ia_compromiso(c: String, r: String, d: float, hasta: int) -> void:
	var m := _m()
	m["ia_tope"].append({"c": c, "r": r, "d": d, "hasta": hasta})
	var cur: Dictionary = m["ia"].get(c, {})
	cur[r] = d
	m["ia"][c] = cur


## Contratos: caducan, mejoran poco a poco la relación y se rompen si el socio nos corta ese recurso
static func _contratos_mes() -> void:
	var m := _m()
	var quedan := []
	for k in m["contratos"]:
		var c := String(k["con"])
		var nm := String(W.COUNTRIES.get(c, {}).get("name", c))
		if GS.day >= int(k["hasta"]):
			var tx := texto_contrato(k)
			GS.toast.emit("Vence el contrato con %s: %s" % [nm, tx.left(1).to_lower() + tx.substr(1)], "info", "acuerdo")
			continue
		if String(k.get("tipo", "")) == "venta":
			var ct: Dictionary = m["cortes"].get(String(k["r"]), {})
			if not bool(k["vendo"]) and not ct.is_empty() and String(ct.get("who", "")) == c:
				GS.apply_fx({"rel": {c: -10}}, nm, false)
				GS.push_news("%s rompe su contrato de %s con %s" % [nm, String(R.RECURSOS[String(k["r"])]["name"]).to_lower(), W.COUNTRY_NAME], 2)
				continue
			if GS.countries.has(c) and float(GS.countries[c]["rel"]) < 60.0:
				GS.countries[c]["rel"] = float(GS.countries[c]["rel"]) + 0.3
		quedan.append(k)
	m["contratos"] = quedan


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
		"text": "Presidente, %s ha cerrado el grifo: %s deja de vendernos %s mientras no cambie nuestra política hacia su país. Lo que compremos en otros mercados nos costará un %d %% más, y lo notarán las empresas, las facturas y los precios. También podemos negociar en serio con ellos o producir más nosotros." % [lider, nm, rn, int(PRIMA_CORTE * 100.0)],
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
		"text": "Presidente, %s ha decidido cortarnos %s. No es un error de los técnicos: es una decisión política, y la ha tomado en persona. Lo que compremos fuera nos costará un %d %% más mientras dure. Podemos sentarnos con su Gobierno en la mesa de negociación." % [lider, rn, int(PRIMA_CORTE * 100.0)],
		"choices": [
			{"t": "Abrir la mesa de negociación con %s." % nm, "fx": {"mesa": c}, "rec": "exteriores"},
			{"t": "Pedirle que reabra el grifo.", "fx": {"rel": {c: 4}, "mercado": {"pedir": r, "a": c}}},
			{"t": "Buscar otros proveedores, cueste lo que cueste." if not agua else "Plan de choque: pozos, trasvases y desaladoras.", "fx": {"money": -1500, "mercado": {"diversificar": r}} if not agua else {"money": -1800, "ambiente": -2, "mercado": {"fin_corte": "agua"}}, "rec": "economia"},
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
	_romper_con(c)
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


## Embargo comercial nuestro a un país: deja de comprarnos y de vendernos (y se acaban los contratos con él). Le
## duele a él (y a su relación), pero si era nuestro proveedor principal de algo, a nosotros también.
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
	_romper_con(c)
	return fx


## Con embargo de por medio no hay contratos que valgan
static func _romper_con(c: String) -> void:
	var m := _m()
	var quedan := []
	for k in m["contratos"]:
		if String(k["con"]) != c:
			quedan.append(k)
	m["contratos"] = quedan


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
