extends RefCounted
## Promesas electorales: qué se ofrece, cómo se cumplen o se rompen y qué pasa al llegar la campaña.
## El estado vive en GS.promises: [{id, state ("en_curso" · "cumplida" · "rota"), day, base}]

const D := preload("res://scripts/data/promises_data.gd")
const W := preload("res://scripts/data/world_data.gd")


static func def(id: String) -> Dictionary:
	if D.PROMISES.has(id):
		return D.PROMISES[id]
	return D.PROMISES_MEME.get(id, {})


## Seis promesas para elegir (tres de «nunca» y tres de «meta»), afines a la ideología del partido
static func offer(rng: RandomNumberGenerator, party: String, mode: String, n_each: int = 3) -> Array:
	var ideo: float = W.PARTIES[party]["ideo"]
	var pools := {"nunca": [], "meta": []}
	var all := D.PROMISES.duplicate()
	if mode == "meme":
		all.merge(D.PROMISES_MEME)
	for id in all.keys():
		var p: Dictionary = all[id]
		var w := clampf(1.25 - absf(float(p.get("ideo", 0.0)) - ideo) / 110.0, 0.12, 1.25)
		if p.get("meme", false):
			w = 2.5
		pools[p["kind"]].append([id, w])
	var out := []
	for kind in ["nunca", "meta"]:
		var pool: Array = pools[kind]
		for i in n_each:
			if pool.is_empty():
				break
			var total := 0.0
			for e in pool:
				total += float(e[1])
			var r := rng.randf() * total
			var pick := pool.size() - 1
			for j in pool.size():
				r -= float(pool[j][1])
				if r <= 0.0:
					pick = j
					break
			out.append(pool[pick][0])
			pool.remove_at(pick)
	return out


## Al empezar: guarda cómo estaba el país (para saber si una promesa se rompe) y aplica el efecto de prometer
static func start(ids: Array) -> void:
	GS.promises = []
	for id in ids:
		add(str(id), false)


static func add(id: String, announce: bool = true) -> void:
	var p := def(id)
	if p.is_empty():
		return
	for e in GS.promises:
		if e["id"] == id and e["state"] == "en_curso":
			return
	GS.promises.append({"id": id, "state": "en_curso", "day": GS.day, "term": GS.term_index, "base": _snapshot()})
	GS.apply_fx(p.get("fx", {}).duplicate(true), "Promesa electoral", announce)
	if announce:
		GS.push_news("%s promete: «%s»" % [GS.pres["name"], p["name"]], 2)


static func _snapshot() -> Dictionary:
	return {"taxes": GS.taxes.duplicate(), "budget": GS.budget.duplicate(), "debt": GS.debt_ratio(), "counters": GS.counters.duplicate(), "laws": GS.policies.size(), "treaties": GS.treaty_count()}


static func active() -> Array:
	var out := []
	for e in GS.promises:
		if e["state"] == "en_curso":
			out.append(e)
	return out


static func broken() -> Array:
	var out := []
	for e in GS.promises:
		if e["state"] == "rota" and int(e.get("term", 1)) == GS.term_index:
			out.append(e)
	return out


static func kept() -> Array:
	var out := []
	for e in GS.promises:
		if e["state"] == "cumplida" and int(e.get("term", 1)) == GS.term_index:
			out.append(e)
	return out


## Comprobación diaria: ¿se ha roto alguna promesa de «nunca»?
static func tick() -> void:
	for e in GS.promises:
		if e["state"] != "en_curso":
			continue
		var p := def(e["id"])
		if p.get("kind", "") == "nunca" and _check(p["check"], e, true):
			_break(e, p)


static func _break(e: Dictionary, p: Dictionary) -> void:
	e["state"] = "rota"
	e["end_day"] = GS.day
	var fx := {"approval": D.BROKEN_APPROVAL, "estabilidad": -2}
	for g in p.get("groups", []):
		fx[g] = float(fx.get(g, 0.0)) + D.BROKEN_GROUP
	GS.apply_fx(fx, "Promesa rota")
	GS.push_news("Promesa rota: el presidente prometió «%s»" % p["name"], 3)
	GS.toast.emit("Ha roto su promesa «%s». La oposición no lo olvidará." % p["name"], "bad", "corazon_roto")
	GS.log_history("Promesa rota", "«%s»" % p["name"])
	GS.remember("promesa_rota", {"id": e["id"], "name": p["name"]})


## ¿Se cumple la comprobación? (para «nunca», true significa que se ha roto)
static func _check(c: Dictionary, e: Dictionary, nunca: bool) -> bool:
	if c.has("any"):
		for sub in c["any"]:
			if _check(sub, e, nunca):
				return true
		return false
	var base: Dictionary = e.get("base", {})
	if c.has("tax_up"):
		for t in c["tax_up"]:
			if float(GS.taxes.get(t, 0.0)) > float(base.get("taxes", {}).get(t, 999.0)) + 0.05:
				return true
		return false
	if c.has("tax_down"):
		for t in c["tax_down"].keys():
			if float(GS.taxes.get(t, 0.0)) > float(base.get("taxes", {}).get(t, 0.0)) - float(c["tax_down"][t]) + 0.05:
				return false
		return true
	if c.has("budget_cut"):
		for b in c["budget_cut"]:
			if float(GS.budget.get(b, 1.0)) < float(base.get("budget", {}).get(b, 1.0)) - 0.005:
				return true
		return false
	if c.has("budget_up"):
		for b in c["budget_up"].keys():
			if float(GS.budget.get(b, 1.0)) < float(c["budget_up"][b]) - 0.005:
				return false
		return true
	if c.has("law"):
		return str(c["law"]) in GS.policies
	if c.has("counter"):
		var k := str(c["counter"])
		return int(GS.counters.get(k, 0)) > int(base.get("counters", {}).get(k, 0))
	if c.has("debt_drop"):
		return GS.debt_ratio() <= float(base.get("debt", 999.0)) - float(c["debt_drop"])
	if c.has("laws_n"):
		return GS.policies.size() - int(base.get("laws", 0)) >= laws_needed(c)
	if c.has("treaties_n"):
		return GS.treaty_count() - int(base.get("treaties", 0)) >= int(c["treaties_n"])
	if c.has("gt"):
		for k in c["gt"].keys():
			if GS.value_of(k) <= float(c["gt"][k]):
				return false
		return true
	if c.has("lt"):
		for k in c["lt"].keys():
			if GS.value_of(k) >= float(c["lt"][k]):
				return false
		return true
	return false


static func laws_needed(c: Dictionary) -> int:
	var years := maxi(1, int(round(float(GS.term_days - GS.term_start) / 365.0)))
	return maxi(2, int(c["laws_n"]) * years / 2 + (1 if years >= 2 else 0))


## ¿Va camino de cumplirse? (true/false) — para la pantalla de promesas y los avisos
static func on_track(e: Dictionary) -> bool:
	var p := def(e["id"])
	if p.is_empty():
		return false
	if e["state"] != "en_curso":
		return e["state"] == "cumplida"
	if p["kind"] == "nunca":
		return true
	return _check(p["check"], e, false)


## Texto corto del progreso: «Paro: 11,2 % (objetivo: menos del 9 %)»
static func progress_text(e: Dictionary) -> String:
	var p := def(e["id"])
	if p.is_empty():
		return ""
	match e["state"]:
		"rota":
			return "Rota el %s" % UI.date_mid(int(e.get("end_day", GS.day)))
		"cumplida":
			return "Cumplida"
	if p["kind"] == "nunca":
		return "Se mantiene · se juzgará al empezar la campaña"
	var c: Dictionary = p["check"]
	if c.has("any"):
		c = c["any"][0]
	if c.has("lt") and c["lt"].has("paro"):
		return "Paro: %s (objetivo: menos del %s)" % [UI.pct(GS.unemployment(), 1), UI.pct(float(c["lt"]["paro"]), 0)]
	if c.has("gt"):
		var k: String = c["gt"].keys()[0]
		return "%s: %s (objetivo: más de %s)" % [GS.label_of(k), UI.num(GS.value_of(k), 0), UI.num(float(c["gt"][k]), 0)]
	if c.has("debt_drop"):
		return "Deuda: %s del PIB (objetivo: %s o menos)" % [UI.pct(GS.debt_ratio(), 1), UI.pct(float(e["base"]["debt"]) - float(c["debt_drop"]), 1)]
	if c.has("laws_n"):
		return "Leyes aprobadas: %d de %d" % [GS.policies.size() - int(e["base"].get("laws", 0)), laws_needed(c)]
	if c.has("treaties_n"):
		return "Tratados: %d de %d" % [GS.treaty_count() - int(e["base"].get("treaties", 0)), int(c["treaties_n"])]
	if c.has("law"):
		return "Ley aprobada" if str(c["law"]) in GS.policies else "Pendiente: %s" % W.LAWS[c["law"]]["name"]
	if c.has("tax_down"):
		var t: String = c["tax_down"].keys()[0]
		return "%s: %s %% (objetivo: %s %% o menos)" % [W.TAXES[t]["name"], UI.num(GS.taxes[t], 1), UI.num(float(e["base"]["taxes"][t]) - float(c["tax_down"][t]), 1)]
	if c.has("budget_up"):
		var b: String = c["budget_up"].keys()[0]
		return "Gasto en %s: %d %% (objetivo: %d %%)" % [W.BUDGET[b]["name"].to_lower(), int(round(GS.budget[b] * 100.0)), int(round(float(c["budget_up"][b]) * 100.0))]
	return "En curso"


## Al empezar la campaña: cada promesa cumplida da votos; cada una incumplida, los quita
static func judge() -> void:
	var good := 0
	var bad := 0
	for e in GS.promises:
		if int(e.get("term", 1)) != GS.term_index:
			continue
		var p := def(e["id"])
		if e["state"] == "en_curso":
			var ok := true if p["kind"] == "nunca" else _check(p["check"], e, false)
			e["state"] = "cumplida" if ok else "rota"
			e["end_day"] = GS.day
			if not ok:
				GS.remember("promesa_rota", {"id": e["id"], "name": p["name"]})
		if e["state"] == "cumplida":
			good += 1
			GS.campaign_bonus += D.VOTES_KEPT
		else:
			bad += 1
			GS.campaign_bonus += D.VOTES_FAILED
	if good + bad == 0:
		return
	if bad == 0:
		GS.push_news("El presidente llega a la campaña con todas sus promesas cumplidas", 3)
		GS.toast.emit("¡Ha cumplido sus %d promesas! Los votantes lo tendrán en cuenta." % good, "good", "check")
	elif good == 0:
		GS.push_news("Ni una promesa cumplida: la oposición abre la campaña con la hemeroteca", 3)
		GS.toast.emit("No ha cumplido ninguna de sus promesas. La campaña empieza cuesta arriba.", "bad", "corazon_roto")
	else:
		GS.push_news("Balance del programa: %d promesas cumplidas y %d incumplidas" % [good, bad], 2)
		GS.toast.emit("Promesas: %d cumplidas y %d incumplidas." % [good, bad], "info", "pluma")


## Ataques de la oposición en la sesión de control y el debate por las promesas rotas o que no se cumplen
static func attacks() -> Array:
	var out := []
	var opener := ["Usted prometió «%s». ¿Qué ha pasado con aquello, presidente?", "«%s». Lo dijo usted, en campaña, mirando a la cámara. ¿Se acuerda?", "Los ciudadanos tienen memoria: usted prometió «%s». Y les ha fallado.", "¿Qué vale su palabra, presidente? Prometió «%s» y mire."]
	for e in broken():
		var p := def(e["id"])
		out.append({"topic": "Promesas", "attack": opener.pick_random() % p["name"], "kind": "personal", "meter": "estabilidad", "promise": true, "key": "prom_" + str(e["id"])})
	for e in active():
		var p2 := def(e["id"])
		if p2["kind"] == "meta" and not on_track(e) and GS.day - GS.term_start > 200:
			out.append({"topic": "Promesas", "attack": "Le queda poco tiempo y sigue lejos de cumplir lo que prometió: «%s». ¿Lo da usted por perdido?" % p2["name"], "kind": "cifras", "meter": "estabilidad", "promise": true, "key": "meta_" + str(e["id"])})
	return out


## Pregunta de la prensa sobre una promesa (rota o pendiente), o vacío si no hay ninguna
static func press_question() -> Dictionary:
	var br := broken()
	if not br.is_empty():
		var p := def(br.pick_random()["id"])
		return {"q": "Usted prometió «%s» y no lo ha cumplido. ¿Por qué deberían volver a creerle?" % p["name"], "promise": true,
			"a": [
				{"t": "Me equivoqué y lo asumo. Las circunstancias cambiaron y gobernar es elegir.", "tone": "honesto", "s": 5, "fx": {"clase_media": 1}},
				{"t": "No he roto nada: he adaptado el compromiso a la realidad del país.", "tone": "evasivo", "s": -4, "fx": {"jovenes": -1}},
				{"t": "Lo volvería a hacer. Prefiero incumplir una frase que hundir al país.", "tone": "firme", "s": 2, "fx": {"empresarios": 1}},
				{"t": "Prometer es como hacer dieta: el lunes siempre empiezo.", "tone": "humor", "s": -2, "fx": {"jovenes": 1, "jubilados": -1}},
			]}
	var act := active()
	if not act.is_empty():
		var e: Dictionary = act.pick_random()
		var p2 := def(e["id"])
		return {"q": "Su promesa estrella fue «%s». ¿Va a cumplirla antes de las elecciones?" % p2["name"], "promise": true,
			"a": [
				{"t": "Sí. Y les invito a juzgarme por ello el día de las elecciones.", "tone": "firme", "s": 4 if on_track(e) else -1, "fx": {"clase_media": 1}},
				{"t": "Vamos por el buen camino, aunque queda trabajo por hacer.", "tone": "honesto", "s": 3, "fx": {}},
				{"t": "Ya veremos. Las promesas son para las campañas.", "tone": "humor", "s": -3, "fx": {"clase_media": -1}},
				{"t": "La pregunta es qué ha prometido la oposición. Nada.", "tone": "ataque", "s": 0, "fx": {"estabilidad": -1}},
			]}
	return {}


## Para la pantalla final: [cumplidas, total] de esta legislatura
static func score() -> Array:
	var k := 0
	var n := 0
	for e in GS.promises:
		if int(e.get("term", 1)) != GS.term_index:
			continue
		n += 1
		var st: String = e["state"]
		if st == "en_curso":
			var p := def(e["id"])
			st = "cumplida" if (p["kind"] == "nunca" or _check(p["check"], e, false)) else "rota"
		if st == "cumplida":
			k += 1
	return [k, n]


## A mitad de legislatura, la Jefa de Gabinete hace balance del programa
static func midterm_event() -> Dictionary:
	var lines := []
	for e in GS.promises:
		if int(e.get("term", 1)) != GS.term_index:
			continue
		var p := def(e["id"])
		var st := "rota" if e["state"] == "rota" else ("va bien" if on_track(e) else "va mal")
		lines.append("«%s»: %s" % [p["name"], st])
	if lines.is_empty():
		return {}
	return {"id": "promesas_mitad_%d" % GS.term_index, "type": "advisor", "who": "jefa", "gen": true, "title": "Mitad de legislatura: sus promesas",
		"text": "Presidente, estamos a mitad de camino y el partido me pide un balance del programa. " + ". ".join(lines) + ". Lo que no cumplamos, nos lo cobrarán en las urnas.",
		"choices": [
			{"t": "A por todas: quiero llegar a la campaña con todo cumplido.", "fx": {"pc": 2, "stress": 5}},
			{"t": "Lo que no se pueda cumplir, se explicará con honestidad.", "fx": {"estabilidad": 1, "stress": -3}},
		], "default": 1}


## Nueva legislatura (modo infinito): la Jefa de Gabinete propone una promesa nueva para el programa
static func new_term_event(rng: RandomNumberGenerator) -> Dictionary:
	var ids := offer(rng, GS.pres["party"], GS.mode, 2)
	var choices := []
	for id in ids.slice(0, 3):
		var p := def(id)
		choices.append({"t": "Prometer: «%s»." % p["name"], "fx": {"promise": id}})
	choices.append({"t": "Esta vez, sin promesas. Que me juzguen por lo hecho.", "fx": {"pc": 3}})
	return {"id": "promesa_nueva_legislatura_%d" % GS.term_index, "type": "advisor", "who": "jefa", "gen": true, "title": "El programa de la nueva legislatura",
		"text": "Presidente, el partido quiere que encabece el programa con un compromiso claro. Cumplirlo nos dará votos dentro de cuatro años; romperlo, ya sabe lo que pasa. ¿Qué promete?",
		"choices": choices, "default": choices.size() - 1}
