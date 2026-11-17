extends RefCounted
## El Gobierno por dentro: la competencia de cada ministro y de la Vicepresidencia, los fichajes (independientes,
## gente del partido o cuota del socio), las crisis delegadas, lo que deciden los ministros cuando el presidente no
## contesta y las reglas de los Presupuestos (una ley al año) y de los decretos ley (ajustes pequeños que el Congreso
## tiene que convalidar).

const W := preload("res://scripts/data/world_data.gd")

## Cambios máximos respecto a lo vigente con una ley de Presupuestos (una por ejercicio)
const LAW_TAX := 3.0
const LAW_BUDGET := 0.15
## ...y con un decreto ley de ajuste
const DECREE_TAX := 1.0
const DECREE_BUDGET := 0.05
## Días entre dos decretos, días hasta la convalidación y días para volver a presentar unos Presupuestos tumbados
const DECREE_COOLDOWN := 120
const DECREE_CONVALIDATE := 30
const BUDGET_RETRY := 60
## Capital político extra que cuesta fichar a un independiente (el partido se queja de que no cuenten con los suyos)
const INDEP_CP := 6
## Lo que mejora la relación con el socio al darle un ministerio (o la Vicepresidencia), y lo que empeora al quitárselo
const SOCIO_REL := 10.0
const SOCIO_REL_VICE := 18.0
const SOCIO_FIRE := 12.0
const SOCIO_FIRE_VICE := 22.0
## Competencia «normal»: por encima ayuda, por debajo resta
const MID := 60.0


# ------------------------------------------------------------------ competencia

static func skill(key: String) -> float:
	return float(GS.ministers.get(key, {}).get("skill", MID))


## [nombre, color] del nivel de competencia
static func level(s: float) -> Array:
	if s >= 80.0:
		return ["Brillante", UI.GREEN]
	if s >= 64.0:
		return ["Solvente", UI.GREEN.lerp(UI.AMBER, 0.35)]
	if s >= 48.0:
		return ["Discreto", UI.AMBER]
	if s >= 34.0:
		return ["Flojo", UI.AMBER.lerp(UI.RED, 0.55)]
	return ["Incompetente", UI.RED]


## Los rasgos acotan la competencia: un tecnócrata nunca es un desastre y un inexperto nunca es brillante
static func fit_traits(s: float, traits: Array) -> float:
	if "tecnocrata" in traits:
		s = maxf(s, 66.0)
	if "inexperto" in traits:
		s = minf(s, 42.0)
	return clampf(roundf(s), 18.0, 96.0)


static func origin_label(m: Dictionary) -> String:
	match str(m.get("origin", "partido")):
		"independiente":
			return "Independiente"
		"socio":
			return "Cuota de %s" % W.PARTIES.get(str(m.get("party", "")), {}).get("short", "socio")
	return "Del partido"


## Lo que aporta cada cargo según su competencia (texto para la ficha del Gobierno)
static func role_help(key: String) -> String:
	match key:
		"vice":
			return "Supervisa lo que usted delega (crisis y decisiones que caducan) y le sustituye en el Congreso. Estabilidad."
		"jefa":
			return "Más o menos días para decidir y capital político cada mes. Estabilidad."
		"economia":
			return "Recaudación (lucha contra el fraude) y prima de riesgo. Economía."
		"interior":
			return "Dirige incendios, inundaciones, disturbios, terrorismo... Seguridad."
		"exteriores":
			return "Relaciones con los demás países cada mes. Prestigio."
		"defensa":
			return "Dirige golpes, guerras, apagones y mareas negras. Fuerzas Armadas."
		"sanidad":
			return "Dirige epidemias y huelgas sanitarias. Bienestar."
	return ""


## Bonificación de su área (se suma a los modificadores como los rasgos)
static func area_bonus(key: String) -> float:
	return (skill(key) - MID) * (0.06 if key == "vice" else 0.1)


## Recaudación: un buen equipo de Hacienda persigue mejor el fraude
static func revenue_factor() -> float:
	return 1.0 + (skill("economia") - MID) * 0.001


## Prima de riesgo: los mercados se fían (o no) del ministro de Economía
static func rate_adjust() -> float:
	return -(skill("economia") - MID) * 0.012


## Días de más (o de menos) para responder documentos y visitas, según la Jefatura de Gabinete
static func extra_days() -> int:
	return roundi((skill("jefa") - MID) / 12.0)


## Capital político mensual extra que consigue la Jefatura de Gabinete
static func monthly_pc() -> float:
	return (skill("jefa") - MID) * 0.05


## Cada mes: Exteriores mueve las relaciones, los socios con cartera se sienten parte del Gobierno, los ministros
## ganan oficio (o dan disgustos) y la Unión Continental vigila el déficit
static func monthly() -> void:
	var dr := (skill("exteriores") - MID) * 0.015
	for c in GS.countries.keys():
		GS.countries[c]["rel"] = clampf(float(GS.countries[c]["rel"]) + dr, -100.0, 100.0)
	for k in GS.ministers.keys():
		var m: Dictionary = GS.ministers[k]
		if str(m.get("origin", "")) == "socio" and GS.parties.has(str(m.get("party", ""))):
			var p := str(m["party"])
			GS.parties[p]["rel"] = clampf(float(GS.parties[p]["rel"]) + (1.0 if k == "vice" else 0.5), 0.0, 100.0)
	_experience()
	_deficit_rule()
	_troubles()
	_prices()
	_coalition_monthly()
	_pc_decay()


## ¿Tiene ese rasgo alguno de estos cargos? (los rasgos solo cuentan en el puesto que toca)
static func has(t: String, keys: Array) -> bool:
	for k in keys:
		if t in GS.ministers.get(k, {}).get("traits", []):
			return true
	return false


# ------------------------------------------------------------------ oficio, escándalos y dimisiones

## Cada mes en el cargo se aprende algo (más cuanto menos se sabía); a los diez meses nadie es ya un inexperto
static func _experience() -> void:
	for k in GS.ministers.keys():
		var m: Dictionary = GS.ministers[k]
		m["months"] = int(m.get("months", 0)) + 1
		var s := float(m.get("skill", MID))
		m["skill"] = minf(92.0, s + 0.6 * (1.0 - s / 100.0))
		if "inexperto" in m.get("traits", []) and int(m["months"]) >= 10:
			m["traits"].erase("inexperto")
			GS.toast.emit("%s ya conoce el oficio: deja de ser inexperto" % m["name"], "good", "empresarios")
	GS._recalc_traits()


## Valor del indicador o grupo del que se ocupa un cargo
static func area_value(key: String) -> float:
	var a: String = W.MINISTRY_AREA.get(key, "estabilidad")
	return float(GS.meters.get(a, GS.fac.get(a, 50.0)))


const SCANDALS := [
	"Un periódico publica que {n} usó el avión oficial para irse de vacaciones con su familia.",
	"Se filtran unos audios de {n} burlándose de los votantes de las Islas Cordales.",
	"{n} adjudicó a dedo un contrato a la empresa de un antiguo socio.",
	"{n} se contradice tres veces en una entrevista en directo y ya es el meme del día.",
	"Hacienda investiga a {n} por una sociedad patrimonial en Qadar.",
]


## Escándalos (los polémicos y los flojos los provocan más) y dimisiones (un incompetente con su área hundida)
static func _troubles() -> void:
	if GS.day < int(GS.flags.get("lio_ministro", -1)):
		return
	var keys: Array = GS.ministers.keys()
	keys.shuffle()
	for k in keys:
		var m: Dictionary = GS.ministers[k]
		var s := float(m.get("skill", MID))
		var p := 0.005 + (0.025 if "polemico" in m.get("traits", []) else 0.0) + maxf(0.0, 45.0 - s) * 0.0008 + GS.corruption * 0.0002
		if GS.rng.randf() < p:
			_scandal(k)
			GS.flags["lio_ministro"] = GS.day + 75
			return
	for k in keys:
		if k == "vice" or k == "jefa":
			continue
		if skill(k) < 42.0 and area_value(k) < 40.0 and GS.rng.randf() < 0.15:
			_resignation(k)
			GS.flags["lio_ministro"] = GS.day + 75
			return


static func _first(m: Dictionary) -> String:
	return String(m.get("name", "")).replace("Gral. ", "").split(" ")[0]


static func _scandal(k: String) -> void:
	var m: Dictionary = GS.ministers[k]
	var txt: String = SCANDALS[GS.rng.randi() % SCANDALS.size()].replace("{n}", m["name"])
	var back := {"estabilidad": -3, "clase_media": -2, "approval": -1}
	if "contrato" in txt or "Hacienda" in txt:
		back["corr"] = 2
	GS.spawn({"id": "escandalo_" + k, "type": "advisor", "who": "jefa", "gen": true,
		"title": "Escándalo: %s" % m["name"],
		"text": txt + " La oposición pide su cese y la prensa no habla de otra cosa. ¿Qué hacemos con %s?" % _first(m),
		"choices": [
			{"t": "Cesar a %s y elegir sustituto." % _first(m), "fx": {"pick": k, "estabilidad": -1}, "rec": "jefa"},
			{"t": "Respaldarle públicamente.", "fx": back, "news": "El presidente respalda a %s pese a la polémica" % m["name"]},
			{"t": "Que dé explicaciones en el Congreso.", "fx": {"pc": -5, "estabilidad": -1, "clase_media": -1}}],
		"default": 1})


static func _resignation(k: String) -> void:
	var m: Dictionary = GS.ministers[k]
	var a: String = W.MINISTRY_AREA.get(k, "estabilidad")
	GS.spawn({"id": "dimision_" + k, "type": "advisor", "who": k, "gen": true,
		"title": "%s presenta su dimisión" % m["name"],
		"text": "«Presidente, no he estado a la altura. %s está en %d y la responsabilidad es mía. Le presento mi dimisión.»" % [GS.label_of(a), int(area_value(k))],
		"choices": [
			{"t": "Aceptarla y elegir sustituto.", "fx": {"pick": k}, "rec": "jefa"},
			{"t": "Pedirle que se quede.", "fx": {"pc": -3, "estabilidad": -2}}],
		"default": 1})


# ------------------------------------------------------------------ deuda: la regla de déficit de la Unión

const DEFICIT_LIMIT := 3.0


## Déficit anual en % del PIB (0 si hay superávit)
static func deficit_pct() -> float:
	return maxf(0.0, -GS.monthly_balance() * 12.0 / GS.gdp * 100.0)


## Cuatro meses seguidos por encima del 3 %: expediente. Seis meses más sin corregirlo: multa (y otra cada medio año).
## Un plan de ajuste congela el contador ocho meses; una prórroga lo pone a cero.
static func _deficit_rule() -> void:
	var f: Dictionary = GS.flags
	if f.has("prorroga_ue"):
		f.erase("prorroga_ue")
		f["deficit_meses"] = 0
		return
	var n := int(f.get("deficit_meses", 0))
	if f.has("plan_ajuste") and GS.day < int(f["plan_ajuste"]) + 240:
		n = 0
	elif deficit_pct() > DEFICIT_LIMIT:
		n += 1
	else:
		n = maxi(0, n - 1)
	f["deficit_meses"] = n
	if n == 4:
		_expediente()
	elif n >= 10:
		f["deficit_meses"] = 4
		var fine := roundf(GS.gdp * 0.002)
		GS.apply_fx({"money": -fine, "rel": {"union": -8}, "prestigio": -4}, "Sanción de la Unión Continental")
		GS.push_news("La Unión Continental multa a Valdoria con %s por incumplir las reglas de déficit" % UI.money(fine), 3)
		GS.toast.emit("Multa de la Unión Continental por el déficit: %s" % UI.money(fine), "bad", "dinero")


static func _expediente() -> void:
	if GS._is_queued("expediente_ue"):
		return
	GS.spawn({"id": "expediente_ue", "type": "advisor", "who": "economia", "gen": true,
		"title": "Expediente de la Unión Continental",
		"text": "Presidente, la Comisión de la Unión Continental nos abre expediente: el déficit lleva cuatro meses por encima del 3 %% del PIB (ahora, el %s %%). Si no presentamos un plan creíble, en medio año llegará la multa." % UI.num(deficit_pct(), 1),
		"choices": [
			{"t": "Presentar un plan de ajuste: recortes y lucha contra el fraude.", "fx": {"monthly": 900, "trabajadores": -3, "bienestar": -2, "rel": {"union": 6}, "flag": "plan_ajuste"}, "rec": "economia"},
			{"t": "Pedir una prórroga: la economía no aguanta más recortes.", "fx": {"pc": -6, "rel": {"union": -4}, "flag": "prorroga_ue"}},
			{"t": "Plantar cara: Valdoria no recibe órdenes de fuera.", "fx": {"rel": {"union": -12}, "prestigio": -3, "trabajadores": 2, "flag": "prima"}, "news": "El Gobierno desafía a la Comisión Continental y los mercados castigan la deuda"}],
		"default": 1})


# ------------------------------------------------------------------ cumbres

## Mandar a Exteriores a una cumbre en vez de ir en persona: un buen ministro casi no se nota
static func summit_send_fx() -> Dictionary:
	var s := skill("exteriores")
	if s >= 80.0:
		return {"prestigio": 1}
	if s >= 64.0:
		return {"prestigio": -1}
	if s >= 48.0:
		return {"prestigio": -2}
	return {"prestigio": -4, "rel": {"union": -3}}


# ------------------------------------------------------------------ fichajes

## El socio más cercano (para la «cuota del socio»): el partido con mejor relación que no sea el propio ni la oposición
static func partner_party() -> String:
	if pact_partner() != "":
		return pact_partner()
	var own: String = GS.pres["party"]
	var opp: String = W.PLAYER_PARTIES[own]["opp"]
	var best := ""
	var br := 34.0
	for p in GS.parties.keys():
		if p == own or p == opp:
			continue
		if float(GS.parties[p]["rel"]) > br:
			br = float(GS.parties[p]["rel"])
			best = p
	return best


## Tres candidatos con perfiles distintos: un independiente brillante pero caro, alguien del partido (leal, solvente) y
## la cuota del socio (más flojo, pero afianza la coalición). Si no hay socio, dos del partido.
static func candidates(key: String) -> Array:
	var socio := partner_party()
	var out := [make(key, "independiente"), make(key, "partido")]
	out.append(make(key, "socio", socio) if socio != "" else make(key, "partido"))
	return out


static func make(key: String, origin: String, party := "") -> Dictionary:
	var rng: RandomNumberGenerator = GS.rng
	var good := []
	var bad := []
	for t in W.TRAITS.keys():
		(good if W.TRAITS[t].get("good", true) else bad).append(t)
	var g := "m" if rng.randf() < 0.5 else "f"
	var sk := 55.0
	var tr := []
	match origin:
		"independiente":
			sk = rng.randf_range(72.0, 93.0)
			tr = [good[rng.randi() % good.size()]]
			if rng.randf() < 0.35:
				var b2: String = ["polemico", "derrochador"][rng.randi() % 2]
				tr.append(b2)
		"socio":
			sk = rng.randf_range(38.0, 68.0)
			tr = [good[rng.randi() % good.size()]]
			if rng.randf() < 0.4:
				tr.append(bad[rng.randi() % bad.size()])
		_:
			sk = rng.randf_range(46.0, 70.0)
			tr = ["leal"] if rng.randf() < 0.55 else [good[rng.randi() % good.size()]]
			var r := rng.randf()
			if r < 0.3:
				var t2: String = good[rng.randi() % good.size()]
				if not (t2 in tr):
					tr.append(t2)
			elif r < 0.6:
				tr.append(bad[rng.randi() % bad.size()])
	sk = fit_traits(sk, tr)
	var look := DB.rand_look(g)
	var nm := DB.rand_name(g)
	if key == "defensa" and origin != "socio" and rng.randf() < 0.6:
		look["uniform"] = true
		look["suit"] = "3f4a32"
		nm = "Gral. " + nm
	return {"name": nm, "role": role_for(key, g), "look": look, "traits": tr, "skill": sk, "origin": origin, "party": party}


static func role_for(key: String, g: String) -> String:
	match key:
		"vice":
			return "Vicepresidenta del Gobierno" if g == "f" else "Vicepresidente del Gobierno"
		"jefa":
			return "Jefa de Gabinete" if g == "f" else "Jefe de Gabinete"
	var role: String = str(GS.ministers.get(key, W.CHARACTERS.get(key, {})).get("role", ""))
	return role.replace("Ministro", "Ministra") if g == "f" else role.replace("Ministra", "Ministro")


## Capital político que cuesta un nombramiento (además del cese)
static func hire_cost(cand: Dictionary) -> int:
	return INDEP_CP if str(cand.get("origin", "")) == "independiente" else 0


## Consecuencias políticas de un relevo: el socio que pierde su cartera se enfada; el que la gana, se acerca
static func on_change(key: String, old: Dictionary, cand: Dictionary) -> void:
	drop_reform(key)
	var vice := key == "vice"
	if str(old.get("origin", "")) == "socio" and GS.parties.has(str(old.get("party", ""))):
		var p := str(old["party"])
		GS.parties[p]["rel"] = clampf(float(GS.parties[p]["rel"]) - (SOCIO_FIRE_VICE if vice else SOCIO_FIRE), 0.0, 100.0)
		GS.push_news("%s se siente expulsado del Gobierno tras el cese de %s" % [W.PARTIES[p]["name"], old.get("name", "")], 2)
	match str(cand.get("origin", "")):
		"socio":
			var p2 := str(cand.get("party", ""))
			if GS.parties.has(p2):
				GS.parties[p2]["rel"] = clampf(float(GS.parties[p2]["rel"]) + (SOCIO_REL_VICE if vice else SOCIO_REL), 0.0, 100.0)
		"partido":
			GS.apply_fx({"estabilidad": 2}, "Nombramiento", false)


# ------------------------------------------------------------------ delegar

## Previsión de una crisis delegada: quién la dirige, con qué eficacia esperada (0-1) y a qué coste
static func crisis_forecast(crisis_id: String) -> Dictionary:
	var key: String = W.CRISIS_MINISTER.get(crisis_id, "interior")
	var m: Dictionary = GS.ministers.get(key, {})
	var s := skill(key)
	var sc := 0.16 + s * 0.0062
	for t in m.get("traits", []):
		sc += float(W.CRISIS_TRAITS.get(t, 0.0))
	# la Vicepresidencia supervisa
	sc += (skill("vice") - MID) * 0.0015
	# una reforma terminada con éxito (Protección Civil, Ciberdefensa, Salud Pública) ayuda en sus crisis
	if crisis_bonus(crisis_id):
		sc += 0.06
	sc = clampf(sc, 0.12, 0.86)
	var cost := 320.0 * (1.5 - s * 0.01)
	if "austero" in m.get("traits", []):
		cost *= 0.8
	if "derrochador" in m.get("traits", []):
		cost *= 1.35
	return {"key": key, "name": str(m.get("name", "")), "role": str(m.get("role", "")), "skill": s, "score": sc, "cost": roundf(cost)}


## Resultado real de la crisis delegada (la previsión, con algo de suerte)
static func crisis_result(f: Dictionary) -> float:
	return clampf(float(f["score"]) + GS.rng.randf_range(-0.08, 0.08), 0.05, 0.95)


const INTERACTIVE := ["nego", "speech", "debate", "press", "control", "casino", "summit", "pick", "pact"]


## Cuando el presidente no contesta a una visita, decide el ministro que la trajo. Uno competente (y una buena
## Vicepresidencia) elige la opción más sensata; uno flojo se queda con la que venía por defecto.
static func auto_choice(ev: Dictionary) -> int:
	var choices: Array = ev.get("choices", [])
	var dflt := int(ev.get("default", choices.size() - 1))
	if choices.size() < 2 or ev.get("front", false):
		return dflt
	var who := str(ev.get("who", "jefa"))
	var key := who if GS.ministers.has(who) else "vice"
	var p := clampf((skill(key) - 30.0) / 60.0 + (skill("vice") - MID) / 200.0, 0.05, 0.95)
	if GS.rng.randf() >= p:
		return dflt
	var best := dflt
	var bs := -INF
	for i in choices.size():
		var c: Dictionary = choices[i]
		var fx: Dictionary = c.get("fx", {})
		var skip := false
		for k in INTERACTIVE:
			if fx.has(k):
				skip = true
		if skip:
			continue
		var sc: float = GS._score_fx(fx) + GS._score_fx(c.get("hidden", {}))
		if sc > bs:
			bs = sc
			best = i
	return best


## Si el presidente no va a la sesión de control, contesta la Vicepresidencia: lo bien o mal que salga depende de ella
static func control_skip_fx() -> Dictionary:
	var s := skill("vice")
	if s >= 78.0:
		return {"estabilidad": -1}
	if s >= 60.0:
		return {"estabilidad": -2, "clase_media": -1}
	if s >= 42.0:
		return {"estabilidad": -3, "clase_media": -2}
	return {"estabilidad": -5, "clase_media": -3, "approval": -1}


# ------------------------------------------------------------------ presupuestos y decretos

static func year() -> int:
	return int(UI.date_dict(GS.day)["year"])


static func budget_passed() -> bool:
	return int(GS.budget_passed_year) >= year()


## Si se puede llevar una ley de Presupuestos al Congreso ahora ("" si sí; si no, por qué)
static func congress_block() -> String:
	if budget_passed():
		return "Los Presupuestos de %d ya están aprobados. Los siguientes, en enero." % year()
	if GS.day < int(GS.budget_retry_day):
		return "El Congreso los tumbó hace poco: podrá volver a presentarlos dentro de %d días." % (int(GS.budget_retry_day) - GS.day)
	return ""


## Si se puede aprobar un decreto ley ahora ("" si sí)
static func decree_block() -> String:
	if not GS.decree_pending.is_empty():
		return "Ya hay un decreto ley pendiente de convalidar en el Congreso."
	if GS.day < int(GS.decree_next_day):
		return "Hace poco que aprobó otro decreto ley: podrá aprobar el siguiente dentro de %d días." % (int(GS.decree_next_day) - GS.day)
	return ""


static func within(new_b: Dictionary, new_t: Dictionary, tax_lim: float, bud_lim: float) -> bool:
	for k in new_t.keys():
		if absf(float(new_t[k]) - float(GS.taxes[k])) > tax_lim + 0.001:
			return false
	for k in new_b.keys():
		if absf(float(new_b[k]) - float(GS.budget[k])) > bud_lim + 0.001:
			return false
	return true


static func changed(new_b: Dictionary, new_t: Dictionary) -> bool:
	return not within(new_b, new_t, 0.0, 0.0)


## Capital político de un decreto: más caro cuanto más toca
static func decree_cost(new_b: Dictionary, new_t: Dictionary) -> int:
	var c := 10.0
	for k in new_t.keys():
		c += absf(float(new_t[k]) - float(GS.taxes[k])) * 6.0
	for k in new_b.keys():
		c += absf(float(new_b[k]) - float(GS.budget[k])) * 40.0
	return int(roundf(c))


## Orientación ideológica de unas cuentas (−80 izquierda … +80 derecha)
static func ideology(b: Dictionary, t: Dictionary) -> float:
	var social: float = (float(b["sanidad"]) + float(b["educacion"]) + float(b["social"]) + float(b["pensiones"]) + float(b["ambiente"])) / 5.0 - 1.0
	var hard: float = (float(b["defensa"]) + float(b["seguridad"])) / 2.0 - 1.0
	var tax: float = (float(t["renta"]) - 22.0) + (float(t["sociedades"]) - 25.0)
	return clampf(-social * 180.0 + hard * 120.0 - tax * 3.0, -80.0, 80.0)


## Saldo mensual que darían unas cuentas (sin tocarlas de verdad)
static func projected_balance(nb: Dictionary, nt: Dictionary) -> float:
	var ob: Dictionary = GS.budget.duplicate()
	var ot: Dictionary = GS.taxes.duplicate()
	for k in nb.keys():
		GS.budget[k] = float(nb[k])
	for k in nt.keys():
		GS.taxes[k] = float(nt[k])
	var bal := GS.monthly_balance()
	GS.budget = ob
	GS.taxes = ot
	return bal


## Lo que le parece a un partido un cambio de las cuentas respecto a lo vigente (+ le gusta, − le disgusta).
## La izquierda quiere más gasto social e impuestos a la renta y a las empresas; la derecha, lo contrario; el IVA no
## lo quiere nadie; recortar pensiones es tóxico para todos; el déficit alto asusta (más a la derecha) y un vuelco
## brusco de las cuentas no lo apoya casi nadie.
static func budget_utility(p: String, nb: Dictionary, nt: Dictionary, bal: float) -> float:
	var x := clampf(float(W.PARTIES[p]["ideo"]) / 75.0, -1.0, 1.0)
	var dr := float(nt.get("renta", GS.taxes["renta"])) - float(GS.taxes["renta"])
	var ds := float(nt.get("sociedades", GS.taxes["sociedades"])) - float(GS.taxes["sociedades"])
	var di := float(nt.get("iva", GS.taxes["iva"])) - float(GS.taxes["iva"])
	var u := dr * (-0.45 - 0.75 * x) + ds * (-0.2 - 0.9 * x) + di * (-0.9 + 0.3 * x)
	var mag := absf(dr) + absf(ds) + absf(di)
	for k in nb.keys():
		# en tramos del 10 %
		var d := (float(nb[k]) - float(GS.budget[k])) * 10.0
		mag += absf(d)
		match str(k):
			"sanidad", "educacion", "social", "ambiente":
				u += d * (0.3 - 0.5 * x)
			"pensiones":
				u += d * (0.25 - 0.3 * x) + minf(0.0, d) * 0.6
			"defensa", "seguridad":
				u += d * (0.6 * x - 0.1)
			"infraestructura":
				u += d * (0.9 if p == "CR" else 0.3)
	var dp := maxf(0.0, -bal * 12.0 / GS.gdp * 100.0)
	u -= maxf(0.0, dp - DEFICIT_LIMIT) * (0.8 + 0.4 * x)
	u -= maxf(0.0, mag - 4.0) * 0.3
	return u


## Probabilidad de que cada partido vote a favor de unas cuentas. Las negociaciones (lobby) ayudan, pero con
## rendimientos decrecientes y un tope: no se puede comprar cualquier cosa.
static func budget_probs(nb: Dictionary, nt: Dictionary, lobby: Dictionary = {}) -> Dictionary:
	var bal := projected_balance(nb, nt)
	var own: String = GS.pres["party"]
	var late := GS.term_days - GS.day < 180
	var out := {}
	for p in GS.parties.keys():
		var u := budget_utility(p, nb, nt, bal)
		if late and u < 0.0:
			u *= 1.5
		var pr: float
		if p == own:
			# hasta los diputados propios se rebelan contra unas cuentas que les hunden en su circunscripción
			pr = 0.96 + minf(0.0, u) * 0.05
		else:
			var dist := absf(float(W.PARTIES[p]["ideo"]) - float(W.PARTIES[own]["ideo"]))
			pr = 0.42 + (60.0 - dist) / 200.0 + (float(GS.parties[p]["rel"]) - 50.0) / 140.0 + u * 0.07 - [-0.04, 0.0, 0.07][GS.difficulty]
			if GS.approval < 40.0:
				pr -= (40.0 - GS.approval) * 0.006
			# el socio de coalición vota con el Gobierno
			if p == pact_partner():
				pr += 0.15
			# negociar ayuda, pero no se compra a un partido para que vote lo que detesta
			pr += 0.22 * tanh(float(lobby.get(p, 0.0)) / 0.22) * clampf(1.0 + u / 8.0, 0.3, 1.0)
		out[p] = clampf(pr, 0.02, 0.98)
	return out


## Pone en vigor unas cuentas. Los cambios bruscos tienen un coste inmediato que se va olvidando (además del efecto
## permanente de tener los impuestos altos o el gasto bajo): subidas de impuestos y recortes enfadan a quien los paga.
static func apply_budget(new_b: Dictionary, new_t: Dictionary) -> void:
	var ob: Dictionary = GS.budget.duplicate()
	var ot: Dictionary = GS.taxes.duplicate()
	for k in new_b.keys():
		GS.budget[k] = float(new_b[k])
	for k in new_t.keys():
		GS.taxes[k] = float(new_t[k])
	shock(ob, ot)
	GS.flags.erase("presupuesto_pendiente")
	GS._update_targets()
	GS.stats_changed.emit()


const CUT_HITS := {
	"pensiones": {"jubilados": 30.0},
	"sanidad": {"jubilados": 10.0, "clase_media": 10.0, "bienestar": 8.0},
	"educacion": {"jovenes": 16.0, "clase_media": 6.0},
	"social": {"trabajadores": 16.0, "jovenes": 6.0},
	"defensa": {"militares": 25.0},
	"seguridad": {"seguridad": 10.0, "clase_media": 4.0},
	"infraestructura": {"economia": 8.0, "trabajadores": 6.0},
	"ambiente": {"jovenes": 8.0, "ambiente": 8.0},
}


static func shock(ob: Dictionary, ot: Dictionary) -> void:
	const HL := 150.0
	var dr := float(GS.taxes["renta"]) - float(ot["renta"])
	var ds := float(GS.taxes["sociedades"]) - float(ot["sociedades"])
	var di := float(GS.taxes["iva"]) - float(ot["iva"])
	if dr > 0.0:
		GS.add_memory("clase_media", -1.6 * dr, HL)
		GS.add_memory("trabajadores", -0.6 * dr, HL)
	if ds > 0.0:
		GS.add_memory("empresarios", -2.0 * ds, HL)
		GS.add_memory("economia", -0.6 * ds, HL)
	if di > 0.0:
		GS.add_memory("trabajadores", -1.2 * di, HL)
		GS.add_memory("jubilados", -1.0 * di, HL)
		GS.add_memory("clase_media", -0.6 * di, HL)
	var hikes := maxf(0.0, dr) + maxf(0.0, ds) + maxf(0.0, di)
	if hikes > 0.0:
		GS.add_memory("economia", -0.5 * hikes, HL)
	for k in CUT_HITS.keys():
		var c := float(ob.get(k, 1.0)) - float(GS.budget[k])
		if c > 0.001:
			for f in CUT_HITS[k].keys():
				GS.add_memory(f, -float(CUT_HITS[k][f]) * c, HL)


## Decreto ley de ajuste: entra en vigor ya, pero el Congreso tiene que convalidarlo en 30 días o se deroga
static func decree(new_b: Dictionary, new_t: Dictionary) -> void:
	var cost := decree_cost(new_b, new_t)
	var db := {}
	var dt := {}
	for k in new_b.keys():
		db[k] = float(new_b[k]) - float(GS.budget[k])
	for k in new_t.keys():
		dt[k] = float(new_t[k]) - float(GS.taxes[k])
	GS.pc -= cost
	apply_budget(new_b, new_t)
	GS.decree_pending = {"day": GS.day + DECREE_CONVALIDATE, "db": db, "dt": dt, "ideo": ideology(GS.budget, GS.taxes)}
	GS.decree_next_day = GS.day + DECREE_COOLDOWN
	GS.apply_fx({"estabilidad": -2}, "Decreto ley")
	GS.push_news("El Gobierno aprueba un decreto ley de ajuste fiscal. El Congreso tendrá que convalidarlo", 2)


static func tick() -> void:
	if not GS.decree_pending.is_empty() and GS.day >= int(GS.decree_pending.get("day", 0)):
		_convalidate()
	_reforms_tick()
	_coalition_check()


static func _sharp(p: float) -> float:
	var a := pow(p, 2.2)
	var b := pow(1.0 - p, 2.2)
	return a / (a + b)


static func _convalidate() -> void:
	var d: Dictionary = GS.decree_pending
	GS.decree_pending = {}
	# se vota lo que hizo el decreto: las cuentas de antes frente a las de ahora
	var nb: Dictionary = GS.budget.duplicate()
	var nt: Dictionary = GS.taxes.duplicate()
	for k in d.get("db", {}).keys():
		GS.budget[k] = float(GS.budget[k]) - float(d["db"][k])
	for k in d.get("dt", {}).keys():
		GS.taxes[k] = float(GS.taxes[k]) - float(d["dt"][k])
	var probs: Dictionary = budget_probs(nb, nt)
	GS.budget = nb
	GS.taxes = nt
	var yes := 0
	for p in GS.parties.keys():
		if GS.rng.randf() < _sharp(float(probs.get(p, 0.5))):
			yes += int(GS.parties[p]["seats"])
	if yes >= 176:
		GS.push_news("El Congreso convalida el decreto ley del Gobierno (%d votos a favor)" % yes, 2)
		GS.toast.emit("Decreto ley convalidado por el Congreso (%d votos)" % yes, "good", "mazo")
		GS.apply_fx({"estabilidad": 1}, "Decreto ley convalidado", false)
		return
	var db: Dictionary = d.get("db", {})
	var dt: Dictionary = d.get("dt", {})
	for k in dt.keys():
		GS.taxes[k] = clampf(float(GS.taxes[k]) - float(dt[k]), W.TAXES[k]["min"], W.TAXES[k]["max"])
	for k in db.keys():
		GS.budget[k] = clampf(float(GS.budget[k]) - float(db[k]), 0.5, 1.6)
	GS._update_targets()
	GS.push_news("El Congreso tumba el decreto ley: las medidas fiscales quedan derogadas", 3)
	GS.toast.emit("El Congreso no convalida su decreto ley (%d votos a favor): queda derogado" % yes, "bad", "mazo")
	GS.apply_fx({"estabilidad": -5, "pc": -8}, "Decreto ley derogado")


# ------------------------------------------------------------------ capital político

## Por encima de esto, el capital político se va perdiendo: no se puede guardar, hay que gastarlo
const PC_KEEP := 40.0


## Capital político que llega cada mes: aprobación, estabilidad, dificultad y la Jefatura de Gabinete
static func pc_income() -> float:
	return 2.0 + GS.approval * 0.05 + float(GS.meters["estabilidad"]) * 0.03 + [1.0, 0.0, -1.0][GS.difficulty] + monthly_pc()


static func _pc_decay() -> void:
	if GS.pc > PC_KEEP:
		GS.pc -= (GS.pc - PC_KEEP) * 0.25


# ------------------------------------------------------------------ inflación y Banco Central

const INFL_TARGET := 2.0


## Gasto público respecto al habitual (1 = el de siempre)
static func spend_ratio() -> float:
	var sb := 0.0
	var sn := 0.0
	for k in W.BUDGET.keys():
		sb += float(W.BUDGET[k]["base"])
		sn += float(W.BUDGET[k]["base"]) * float(GS.budget[k])
	return sn / maxf(1.0, sb)


## Hacia dónde van los precios: más gasto, déficit, IVA alto o una economía recalentada los empujan hacia arriba
static func inflation_target() -> float:
	return INFL_TARGET + (spend_ratio() - 1.0) * 6.0 + maxf(0.0, deficit_pct() - 2.0) * 0.35 + (float(GS.meters["economia"]) - 55.0) * 0.06 + GS.cycle * 0.8 + (float(GS.taxes["iva"]) - 21.0) * 0.12


## Cada mes: los precios se mueven y el Banco Central (independiente) ajusta los tipos, como mucho medio punto
static func _prices() -> void:
	GS.inflation = clampf(GS.inflation + (inflation_target() - GS.inflation) * 0.18 + GS.rng.randf_range(-0.15, 0.15), -2.0, 18.0)
	var want := clampf(INFL_TARGET + 1.5 * (GS.inflation - INFL_TARGET) + (float(GS.meters["economia"]) - 55.0) * 0.05, 0.0, 9.0)
	want = roundf(want * 4.0) / 4.0
	var old: float = GS.policy_rate
	GS.policy_rate = move_toward(GS.policy_rate, want, 0.5)
	if absf(GS.policy_rate - old) >= 0.24:
		GS.push_news("El Banco Central %s los tipos de interés al %s %%" % ["sube" if GS.policy_rate > old else "baja", UI.num(GS.policy_rate, 2)], 2)
	if GS.inflation > 5.0 and GS.day >= int(GS.flags.get("infl_aviso", -1)) and not GS._is_queued("inflacion_alta"):
		GS.flags["infl_aviso"] = GS.day + 150
		_inflation_event()


## Puntos de satisfacción que quita la subida de precios (por encima del 3 %)
static func price_pain() -> float:
	return maxf(0.0, GS.inflation - 3.0)


static func _inflation_event() -> void:
	GS.spawn({"id": "inflacion_alta", "type": "advisor", "who": "economia", "gen": true,
		"title": "Los precios se disparan",
		"text": "Presidente, la inflación ya está en el %s %%. La cesta de la compra, la luz y los alquileres suben cada mes, los jubilados y los trabajadores pierden poder adquisitivo y el Banco Central tiene los tipos al %s %%. ¿Qué hacemos?" % [UI.num(GS.inflation, 1), UI.num(GS.policy_rate, 2)],
		"choices": [
			{"t": "Rebajar el IVA de los alimentos y la energía.", "fx": {"monthly": -600, "inflation": -0.8, "trabajadores": 2, "jubilados": 2}},
			{"t": "Pacto de rentas con sindicatos y patronal.", "fx": {"pc": -8, "inflation": -1.2, "trabajadores": -1, "empresarios": 1}, "rec": "economia"},
			{"t": "Recortar gasto para enfriar la economía.", "fx": {"monthly": 700, "inflation": -1.0, "bienestar": -2, "trabajadores": -2}},
			{"t": "Dejar actuar al Banco Central.", "fx": {"estabilidad": -1}}],
		"default": 3})


# ------------------------------------------------------------------ coalición de gobierno

const PACT_CP := 10
const PACT_SEAT_DAYS := 75
const PACT_DAYS := 365
## La partida que cada partido exige subir (al menos un 10 %) si entra en el Gobierno
const PARTY_ITEM := {"FS": "social", "VV": "ambiente", "MP": "sanidad", "CC": "educacion", "CR": "infraestructura", "AR": "seguridad", "PO": "defensa"}


static func pact_partner() -> String:
	return str(GS.coalition.get("party", ""))


## Partidos con los que se puede negociar un pacto de gobierno: afines y con buena relación
static func pact_candidates() -> Array:
	var own: String = GS.pres["party"]
	var opp: String = W.PLAYER_PARTIES[own]["opp"]
	var out := []
	for p in W.PARTY_ORDER:
		if p == own or p == opp or not GS.parties.has(p):
			continue
		if absf(float(W.PARTIES[p]["ideo"]) - float(W.PARTIES[own]["ideo"])) <= 50.0 and float(GS.parties[p]["rel"]) >= 50.0:
			out.append(p)
	return out


## La ley de su programa (closest) o su línea roja (la más alejada de sus ideas)
static func _law_for(p: String, closest: bool) -> String:
	var own_i := float(W.PARTIES[GS.pres["party"]]["ideo"])
	var pi := float(W.PARTIES[p]["ideo"])
	var best := ""
	var bd := INF if closest else -INF
	for id in W.LAWS.keys():
		var law: Dictionary = W.LAWS[id]
		if law.get("super", false) or id in GS.policies:
			continue
		var li := float(law.get("ideo", 0.0))
		var d := absf(li - pi)
		if closest:
			if absf(li - own_i) <= 45.0 and d < bd:
				bd = d
				best = id
		elif d > bd:
			bd = d
			best = id
	return best


static func pact_offer(p: String) -> Dictionary:
	var item: String = PARTY_ITEM.get(p, "social")
	return {"party": p, "law": _law_for(p, true), "veto": _law_for(p, false), "item": item, "item_from": float(GS.budget[item])}


## La Vicepresidencia trae las condiciones del socio; se firma (o no) como cualquier otra decisión
static func offer_pact(p: String) -> void:
	if GS._is_queued("pacto_" + p):
		return
	var o := pact_offer(p)
	GS.flags["pact_offer"] = o
	var pn: String = W.PARTIES[p]["name"]
	var law_n: String = W.LAWS[o["law"]]["name"] if o["law"] != "" else "su programa"
	var veto_n: String = W.LAWS[o["veto"]]["name"] if o["veto"] != "" else "ninguna"
	GS.spawn({"id": "pacto_" + p, "type": "advisor", "who": "vice", "gen": true, "front": true,
		"title": "Pacto de gobierno con %s" % pn,
		"text": "Presidente, %s está dispuesto a entrar en el Gobierno y votar con nosotros las leyes y los Presupuestos. Sus condiciones: una cartera para uno de los suyos (antes de %d días), aprobar «%s» y subir al menos un 10 %% la partida de %s (antes de un año). Su línea roja: «%s». Si incumplimos, romperá el pacto." % [pn, PACT_SEAT_DAYS, law_n, String(W.BUDGET[o["item"]]["name"]).to_lower(), veto_n],
		"choices": [
			{"t": "Firmar el pacto de gobierno (−%d CP)." % PACT_CP, "fx": {"pact": p}, "rec": "vice"},
			{"t": "No aceptar sus condiciones.", "fx": {"party": {p: -3}}}],
		"default": 1})


static func sign_pact(p: String) -> void:
	var o: Dictionary = GS.flags.get("pact_offer", {})
	if str(o.get("party", "")) != p:
		o = pact_offer(p)
	GS.flags.erase("pact_offer")
	GS.pc -= PACT_CP
	GS.coalition = {"party": p, "since": GS.day, "law": o["law"], "veto": o["veto"], "item": o["item"], "item_from": float(o["item_from"]),
		"seat_due": GS.day + PACT_SEAT_DAYS, "due": GS.day + PACT_DAYS}
	GS.parties[p]["rel"] = clampf(float(GS.parties[p]["rel"]) + 12.0, 0.0, 100.0)
	GS.push_news("%s entra en el Gobierno: firmado el pacto de coalición" % W.PARTIES[p]["name"], 3)
	GS.log_history("Pacto de gobierno", "Coalición con %s" % W.PARTIES[p]["name"])
	GS._update_targets()
	GS.stats_changed.emit()


## Estado de las condiciones del pacto: [{t, done, due}]
static func pact_status() -> Array:
	var c: Dictionary = GS.coalition
	if c.is_empty():
		return []
	var p := str(c["party"])
	var seat := false
	for k in GS.ministers.keys():
		var m: Dictionary = GS.ministers[k]
		if str(m.get("origin", "")) == "socio" and str(m.get("party", "")) == p:
			seat = true
	var out := [{"t": "Una cartera para %s (cese a un ministro y elija la «cuota de %s»)" % [W.PARTIES[p]["short"], W.PARTIES[p]["short"]], "done": seat, "due": int(c["seat_due"])}]
	if str(c["law"]) != "":
		out.append({"t": "Aprobar «%s»" % W.LAWS[c["law"]]["name"], "done": str(c["law"]) in GS.policies, "due": int(c["due"])})
	var item := str(c["item"])
	out.append({"t": "Subir un 10 %% la partida de %s" % String(W.BUDGET[item]["name"]).to_lower(), "done": float(GS.budget[item]) >= float(c["item_from"]) + 0.099, "due": int(c["due"])})
	return out


static func _coalition_check() -> void:
	var c: Dictionary = GS.coalition
	if c.is_empty():
		return
	if str(c["veto"]) != "" and str(c["veto"]) in GS.policies:
		break_pact("el Gobierno ha aprobado su línea roja («%s»)" % W.LAWS[c["veto"]]["name"])
		return
	for d in pact_status():
		if not d["done"] and GS.day > int(d["due"]):
			break_pact("no se ha cumplido lo pactado: %s" % String(d["t"]).to_lower())
			return


static func _coalition_monthly() -> void:
	if GS.coalition.is_empty():
		return
	if GS.approval < 30.0 and GS.rng.randf() < 0.2:
		break_pact("no quiere hundirse con un Gobierno sin apoyo en la calle")


static func break_pact(reason: String, by_player := false) -> void:
	var p := pact_partner()
	if p == "":
		return
	GS.coalition = {}
	GS.parties[p]["rel"] = clampf(float(GS.parties[p]["rel"]) - (30.0 if by_player else 25.0), 0.0, 100.0)
	GS.apply_fx({"estabilidad": -4 if by_player else -6}, "Ruptura de la coalición")
	var pn: String = W.PARTIES[p]["name"]
	if by_player:
		GS.push_news("El presidente rompe la coalición con %s" % pn, 3)
	else:
		GS.push_news("Se rompe la coalición: %s sale del Gobierno porque %s" % [pn, reason], 3)
		GS.toast.emit("%s rompe la coalición: %s" % [pn, reason], "bad", "alerta")
	# sus ministros se van con ellos (sin el enfado extra de un cese: ya se van por su cuenta)
	for k in GS.ministers.keys():
		var m: Dictionary = GS.ministers[k]
		if str(m.get("origin", "")) == "socio" and str(m.get("party", "")) == p:
			m["origin"] = "ex_socio"
			GS._fire_minister(k)
	GS._update_targets()
	GS.stats_changed.emit()


# ------------------------------------------------------------------ cuestión de confianza

static func confidence_used() -> bool:
	return int(GS.flags.get("confianza_term", -1)) == GS.term_index


# ------------------------------------------------------------------ encargos a los ministros

## Probabilidades [éxito, fracaso] de una reforma según la competencia del ministro (y la Vicepresidencia)
static func reform_chance(key: String) -> Array:
	var q := skill(key) / 100.0
	var ok := clampf(0.15 + q * 0.75 + (skill("vice") - MID) * 0.002, 0.1, 0.92)
	var bad := clampf(0.45 - q * 0.45, 0.03, 0.4)
	return [ok, bad]


static func reform_data(key: String, id: String) -> Dictionary:
	for r in W.REFORMS.get(key, []):
		if r["id"] == id:
			return r
	return {}


static func start_reform(key: String, id: String) -> bool:
	var r := reform_data(key, id)
	if r.is_empty() or GS.reforms.has(key) or GS.pc < float(r["pc"]):
		return false
	GS.pc -= float(r["pc"])
	if float(r.get("money", 0.0)) > 0.0:
		GS.apply_fx({"money": -float(r["money"])}, r["name"], false)
	GS.reforms[key] = {"id": id, "start": GS.day, "end": GS.day + int(r["days"])}
	GS.push_news("%s pone en marcha: %s" % [GS.ministers[key]["name"], r["name"]], 2)
	GS.stats_changed.emit()
	return true


## Si cesan al ministro, su reforma se queda en un cajón
static func drop_reform(key: String) -> void:
	if GS.reforms.has(key):
		var r := reform_data(key, str(GS.reforms[key]["id"]))
		GS.reforms.erase(key)
		GS.toast.emit("La reforma «%s» se queda en un cajón" % r.get("name", ""), "warn", "documento")


static func _reforms_tick() -> void:
	for key in GS.reforms.keys():
		if GS.day >= int(GS.reforms[key]["end"]):
			_resolve_reform(key)


static func _resolve_reform(key: String) -> void:
	var id := str(GS.reforms[key]["id"])
	GS.reforms.erase(key)
	var r := reform_data(key, id)
	if r.is_empty():
		return
	var ch := reform_chance(key)
	var x := GS.rng.randf()
	var m: Dictionary = GS.ministers.get(key, {})
	var fx: Dictionary
	var how := ""
	if x < float(ch[0]):
		fx = r["ok"]
		how = "con éxito"
		if r.has("flag"):
			GS.flags[r["flag"]] = GS.day
	elif x < 1.0 - float(ch[1]):
		fx = _scaled(r["ok"], 0.5)
		how = "a medias"
	else:
		fx = r["bad"]
		how = "en fracaso"
	GS.apply_fx(_tokens(fx), r["name"])
	GS.push_news("%s termina «%s» %s" % [m.get("name", "El Gobierno"), r["name"], how], 2)
	GS.toast.emit("Reforma «%s»: %s" % [r["name"], how], "good" if how == "con éxito" else ("info" if how == "a medias" else "bad"), "documento")
	GS.log_history(r["name"], "Reforma terminada %s" % how)


static func _scaled(fx: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in fx.keys():
		var v = fx[key]
		if v is Dictionary:
			out[key] = _scaled(v, k)
		elif typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			out[key] = float(v) * k
		else:
			out[key] = v
	return out


## «@all» (todos los países) y «@opp» (el partido de la oposición) en los efectos de las reformas
static func _tokens(fx: Dictionary) -> Dictionary:
	var out := fx.duplicate(true)
	if out.has("rel") and out["rel"].has("@all"):
		var v := float(out["rel"]["@all"])
		out["rel"] = {}
		for c in GS.countries.keys():
			out["rel"][c] = v
	if out.has("party") and out["party"].has("@opp"):
		var v2 := float(out["party"]["@opp"])
		out["party"].erase("@opp")
		out["party"][W.PLAYER_PARTIES[GS.pres["party"]]["opp"]] = v2
	return out


## Reformas terminadas con éxito que ayudan en ciertas crisis: +1 unidad de cada tipo y mejor resultado si se delega
const CRISIS_FLAGS := {"proteccion_civil": ["incendios", "inundaciones", "terremoto", "temporal_nieve"],
	"ciberdefensa": ["apagon", "ciber_bancos", "wifi"], "salud_publica": ["pandemia", "plaga", "palomas", "huelga_sanitaria"]}


static func crisis_bonus(crisis_id: String) -> bool:
	for f in CRISIS_FLAGS.keys():
		if GS.flags.has(f) and crisis_id in CRISIS_FLAGS[f]:
			return true
	return false
