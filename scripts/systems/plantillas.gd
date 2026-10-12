extends RefCounted
## Situaciones generadas combinando piezas (scripts/data/plantillas_data.gd): alcaldes que piden algo, empresas que
## quieren invertir, protestas, polémicas, sucesos, propuestas de los ministros, visitas ilustres y propuestas de
## otros países. Se usan cuando lo escrito a mano ya salió en las últimas partidas, así casi nada se repite.
## Cada pieza usada se anota en GS.used («tpl_familia_pieza») y pasa a la memoria entre partidas.

const D := preload("res://scripts/data/plantillas_data.gd")
const W := preload("res://scripts/data/world_data.gd")

const ADVISOR_FAMILIES := {"alcalde": 1.2, "inversion": 1.0, "protesta": 1.1, "polemica": 0.8, "suceso": 0.9, "medida": 1.2, "celebridad": 0.6}


## Elige una pieza: lo que salió en esta partida no vuelve y lo de partidas recientes sale menos
static func _pick(list: Array, fam: String) -> Dictionary:
	var pool := []
	var total := 0.0
	for it in list:
		if it.get("meme", false) and GS.mode != "meme" and GS.rng.randf() < 0.85:
			continue
		var id := "tpl_%s_%s" % [fam, it["id"]]
		if GS.used.has(id):
			continue
		var w := Perfil.recent_factor(id)
		pool.append([it, w])
		total += w
	if pool.is_empty():
		return list[GS.rng.randi() % list.size()]
	var r := GS.rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return pool.back()[0]


static func _mark(fam: String, it: Dictionary) -> String:
	var id := "tpl_%s_%s" % [fam, it["id"]]
	GS.used[id] = GS.day
	return id


static func _place() -> Array:
	return D.PLACES[GS.rng.randi() % D.PLACES.size()]


static func _rand(list: Array):
	return list[GS.rng.randi() % list.size()]


static func _money_txt(m: float) -> String:
	return UI.money(m)


## Una situación nueva del tipo pedido ("advisor" o "call"), o vacío si no hay
static func make(kind: String) -> Dictionary:
	if kind == "call":
		return _diplo()
	var total := 0.0
	for f in ADVISOR_FAMILIES.keys():
		total += float(ADVISOR_FAMILIES[f])
	var r := GS.rng.randf() * total
	var fam: String = ADVISOR_FAMILIES.keys()[0]
	for f in ADVISOR_FAMILIES.keys():
		r -= float(ADVISOR_FAMILIES[f])
		if r <= 0.0:
			fam = f
			break
	match fam:
		"alcalde":
			return _alcalde()
		"inversion":
			return _inversion()
		"protesta":
			return _protesta()
		"polemica":
			return _polemica()
		"suceso":
			return _suceso()
		"medida":
			return _medida()
		"celebridad":
			return _celebridad()
	return {}


# ------------------------------------------------------------------ alcaldes

static func _alcalde() -> Dictionary:
	var p := _pick(D.PETITIONS, "alcalde")
	var id := _mark("alcalde", p)
	var pl := _place()
	var g := "f" if GS.rng.randf() < 0.45 else "m"
	var mayor := DB.rand_name(g)
	var cost := float(round(float(p["cost"]) * GS.rng.randf_range(0.8, 1.25)))
	var grp: String = p["group"]
	var met: String = p["meter"]
	var choices := [
		{"t": "Financiarlo entero (%s)." % _money_txt(cost), "fx": {"money": -cost, grp: 3, met: 1, "region": [pl[1], 1.5]}, "news": "El Gobierno financiará %s en %s" % [p["short"], pl[0]]},
	]
	if cost >= 15.0:
		choices.append({"t": "Poner la mitad si el ayuntamiento pone la otra mitad.", "fx": {"money": -round(cost / 2.0), grp: 1,
			"risk": {"p": 0.6, "fx": {met: 1, "region": [pl[1], 0.8]}, "news": "%s acepta el trato: %s irá a medias" % [pl[0], p["short"]]},
			"else": {"fx": {grp: -1}, "news": "%s, alcalde%s de %s, rechaza la oferta del Gobierno: «Migajas»" % [mayor, "sa" if g == "f" else "", pl[0]]}}})
	choices.append({"t": "No hay dinero para todo. Lo siento.", "fx": {grp: -2, "region": [pl[1], -1.0]}})
	return {"id": id, "type": "advisor", "who": p.get("who", "jefa"), "gen": true, "tpl": true,
		"title": "%s pide %s" % [pl[0], p["short"]],
		"text": "Presidente, %s, alcalde%s de %s, pide %s: %s. %s" % [mayor, "sa" if g == "f" else "", pl[0], p["what"], p["why"], _rand(D.MAYOR_LINES)],
		"choices": choices, "default": choices.size() - 1}


# ------------------------------------------------------------------ inversiones

static func _inversion() -> Dictionary:
	var inv := _pick(D.INVESTMENTS, "inversion")
	var id := _mark("inversion", inv)
	var who: Array = _rand(D.INVESTORS)
	var pl := _place()
	var jobs := int(round(float(inv["jobs"]) * GS.rng.randf_range(0.8, 1.2) / 10.0) * 10)
	var ask := float(round(float(inv["ask"]) * GS.rng.randf_range(0.8, 1.2)))
	var env := int(inv["env"])
	var big := 1 + int(jobs >= 1500) + int(jobs >= 3000)
	var yes := {"money": -ask, "economia": big, "trabajadores": 1 + big, "empresarios": 2, "region": [pl[1], 1.0 + big * 0.5]}
	if env > 0:
		yes["ambiente"] = -env
	if env >= 2:
		yes["jovenes"] = -1
	if who[1] != "":
		yes["rel"] = {who[1]: 4}
	var no := {"trabajadores": -1 - big, "empresarios": -2}
	if env >= 2:
		no["ambiente"] = 1
		no["jovenes"] = 1
	var origin := "" if who[1] == "" else " (%s)" % W.COUNTRIES[who[1]]["name"]
	return {"id": id, "type": "advisor", "who": "economia", "gen": true, "tpl": true,
		"title": "%s quiere invertir en %s" % [who[0], pl[0]],
		"text": "Presidente, %s%s quiere construir %s en %s: %d empleos directos. El problema: %s. Para decidirse, piden %s en ayudas públicas. Hay otros dos países interesados." % [who[0], origin, inv["what"], pl[0], jobs, inv["con"], _money_txt(ask)],
		"choices": [
			{"t": "Ayudas y alfombra roja: los empleos son lo primero.", "fx": yes, "news": "%s construirá %s en %s" % [who[0], inv["what"], pl[0]]},
			{"t": "Bienvenidos, pero sin dinero público.", "fx": {"risk": {"p": 0.45, "fx": {"economia": 1, "trabajadores": 1, "region": [pl[1], 0.8]}, "news": "%s sigue adelante en %s sin ayudas públicas" % [who[0], pl[0]]},
				"else": {"fx": {"trabajadores": -1}, "news": "%s se lleva su inversión a otro país" % who[0]}}},
			{"t": "No la queremos aquí.", "fx": no},
		], "default": 1}


# ------------------------------------------------------------------ protestas

static func _protesta() -> Dictionary:
	var pr := _pick(D.PROTESTS, "protesta")
	var id := _mark("protesta", pr)
	var why: String = _rand(pr["why"])
	var grp: String = pr["group"]
	var cost := float(GS.rng.randi_range(12, 40))
	return {"id": id, "type": "advisor", "who": "interior", "gen": true, "tpl": true,
		"title": "%s, en la calle" % pr["who"],
		"text": "Presidente, %s están concentrados frente al Palacio: dicen que %s. Son miles, han cortado la avenida principal y las televisiones llevan toda la mañana en directo. Quieren que usted les reciba." % [String(pr["who"]).to_lower(), why],
		"choices": [
			{"t": "Recibirles y comprometer una solución.", "fx": {"monthly": -cost, grp: 3, "pc": -2}, "news": "El presidente recibe a %s y se compromete a atender sus demandas" % String(pr["who"]).to_lower()},
			{"t": "Abrir una mesa de diálogo, sin compromisos.", "fx": {"pc": -1, "risk": {"p": 0.5, "fx": {grp: 1}}, "else": {"fx": {grp: -2}, "news": "%s abandonan la mesa de diálogo: «Nos toman el pelo»" % pr["who"]}}},
			{"t": "Ni caso. Ya se cansarán.", "fx": {grp: -3, "estabilidad": -1}},
			{"t": "Desalojar la avenida: han cortado el tráfico.", "fx": {"seguridad": 1, grp: -4, "jovenes": -1, "jubilados": 1, "estabilidad": -1}, "news": "La policía desaloja a %s frente al Palacio" % String(pr["who"]).to_lower()},
		], "default": 2}


# ------------------------------------------------------------------ polémicas

static func _polemica() -> Dictionary:
	var c := _pick(D.CONTROVERSIES, "polemica")
	var id := _mark("polemica", c)
	var a: Array = c["a"]
	var b: Array = c["b"]
	return {"id": id, "type": "advisor", "who": "jefa", "gen": true, "tpl": true,
		"title": _rand(["El debate que divide al país", "La polémica de la semana", "Todo el país discute", "Sobremesas incendiadas"]),
		"text": "Presidente, %s. Las tertulias no hablan de otra cosa, en Pío ya hay dos bandos y la prensa quiere saber qué opina el presidente. Diga lo que diga, media Valdoria se enfadará." % c["what"],
		"choices": [
			{"t": "%s." % a[0], "fx": {a[1]: 2, b[1]: -1}},
			{"t": "%s." % b[0], "fx": {b[1]: 2, a[1]: -1}},
			{"t": "No opinar: «El Gobierno tiene asuntos más importantes».", "fx": {"pc": 1, "jovenes": -1}},
		], "default": 2}


# ------------------------------------------------------------------ sucesos

static func _suceso() -> Dictionary:
	var it := _pick(D.INCIDENTS, "suceso")
	var id := _mark("suceso", it)
	var pl := _place()
	var grp: String = it["group"]
	return {"id": id, "type": "advisor", "who": it.get("who", "interior"), "gen": true, "tpl": true, "urgent": 25.0,
		"title": "%s en %s" % [it["what"], pl[0]],
		"text": "Presidente, malas noticias de %s: %s. %s. Los vecinos piden que el Gobierno dé la cara y la oposición ya pregunta dónde está usted." % [pl[0], String(it["what"]).to_lower(), it["victims"]],
		"choices": [
			{"t": "Voy ahora mismo a la zona.", "fx": {"stress": 4, "approval": 1, grp: 2, "money": -40, "region": [pl[1], 1.5]}, "news": "El presidente se desplaza a %s tras el suceso" % pl[0]},
			{"t": "Ayudas de emergencia y que vaya el ministro.", "fx": {"money": -120, grp: 1, "region": [pl[1], 0.8]}},
			{"t": "Que lo gestionen las autoridades locales.", "fx": {grp: -2, "clase_media": -1, "region": [pl[1], -1.0]}},
		], "default": 2}


# ------------------------------------------------------------------ propuestas de los ministros

static func _medida() -> Dictionary:
	var m := _pick(D.MEASURES, "medida")
	var id := _mark("medida", m)
	var half := {}
	for k in m["yes"].keys():
		var v = m["yes"][k]
		if k == "rel" or k == "corr_mult":
			continue
		half[k] = round(float(v) * 0.5) if absf(float(v)) >= 2.0 else float(v) * 0.5
	var t: String = m["t"]
	return {"id": id, "type": "advisor", "who": m["who"], "gen": true, "tpl": true,
		"title": "Propuesta: %s" % (t.left(1).to_upper() + t.substr(1)),
		"text": "Presidente, le traigo una propuesta: %s. La razón: %s. Lo tengo todo preparado; solo necesito su luz verde." % [t, m["why"]],
		"choices": [
			{"t": "Adelante, tal cual.", "fx": m["yes"].duplicate(true), "rec": m["who"]},
			{"t": "Sí, pero en una versión más modesta.", "fx": half},
			{"t": "No. No es el momento.", "fx": m["no"].duplicate(true)},
		], "default": 2}


# ------------------------------------------------------------------ visitas ilustres

static func _celebridad() -> Dictionary:
	var c := _pick(D.CELEBRITIES, "celebridad")
	var id := _mark("celebridad", c)
	var grp: String = c["group"]
	var cost := float(c.get("cost", 0))
	var yes := {grp: 2, "approval": 0.5}
	if cost > 0.0:
		yes["money"] = -cost
	if c["id"] == "empresario":
		yes = {"empresarios": 3, "trabajadores": -2, "monthly": -40}
	return {"id": id, "type": "advisor", "who": "jefa", "gen": true, "tpl": true,
		"title": "Una visita ilustre",
		"text": "Presidente, en la antesala está %s. Viene con cámaras. Quiere una foto con usted... y pedirle %s." % [c["who"], c["ask"]],
		"choices": [
			{"t": "Concedérselo. Buena foto.", "fx": yes},
			{"t": "Una foto, una sonrisa y nada más.", "fx": {grp: 1}},
			{"t": "No tengo tiempo para famosos.", "fx": {grp: -1, "stress": -1}},
		], "default": 2}


# ------------------------------------------------------------------ propuestas de otros países (llamada)

static func _diplo() -> Dictionary:
	var it := _pick(D.DIPLO, "diplo")
	var cands := []
	for c in GS.countries.keys():
		if float(GS.countries[c]["rel"]) > -40.0:
			cands.append(c)
	if cands.is_empty():
		return {}
	var c: String = cands[GS.rng.randi() % cands.size()]
	var id := _mark("diplo", it)
	var leader: String = W.COUNTRIES[c]["leader"]
	var rel := float(it["rel"])
	var yes: Dictionary = it["yes"].duplicate(true)
	yes["rel"] = {c: rel}
	return {"id": id, "type": "call", "who": c, "gen": true, "tpl": true,
		"title": "%s tiene una propuesta" % leader,
		"text": "%s Le propongo %s. Mi Gobierno lo tiene estudiado y mis ministros están deseando empezar. ¿Qué me dice?" % [_rand(D.DIPLO_OPEN), it["t"]],
		"choices": [
			{"t": "Me parece una gran idea. Adelante.", "fx": yes, "news": "Valdoria y %s acuerdan %s" % [W.COUNTRIES[c]["name"], it["t"]]},
			{"t": "Lo estudiaremos con calma.", "fx": {"rel": {c: 1}}},
			{"t": "No nos interesa, gracias.", "fx": {"rel": {c: -round(rel / 2.0)}}},
		], "default": 1}
