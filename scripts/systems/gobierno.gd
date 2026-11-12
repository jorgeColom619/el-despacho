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


const INTERACTIVE := ["nego", "speech", "debate", "press", "control", "casino", "summit", "pick"]


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


static func _sharp(p: float) -> float:
	var a := pow(p, 2.2)
	var b := pow(1.0 - p, 2.2)
	return a / (a + b)


static func _convalidate() -> void:
	var d: Dictionary = GS.decree_pending
	GS.decree_pending = {}
	var probs: Dictionary = GS.vote_forecast({"name": "Convalidación del decreto ley", "ideo": float(d.get("ideo", 0.0))}, {})
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
