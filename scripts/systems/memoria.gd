extends RefCounted
## Personajes con memoria: lo que hace el presidente (GS.memo) vuelve meses después.
## - Exministros cesados que van a las tertulias, escriben memorias o fichan por la oposición
## - Indultados que reinciden (o no), familias de los que no lo fueron, ciudadanos que escribieron cartas
## - Empresas de los contratos, leyes que dan (o no) resultado, aniversarios de las crisis
## - Líderes extranjeros que recuerdan una llamada perdida, un acuerdo o una cumbre plantada
## - La periodista incómoda de cada partida, que recuerda lo que se le contestó
## - La oposición, que lleva la cuenta de todo
## Cada hecho guardado: {k, d (datos), day, used: [plantillas ya disparadas]}

const D := preload("res://scripts/data/memoria_data.gd")
const W := preload("res://scripts/data/world_data.gd")


## Personajes fijos de la partida (la periodista incómoda) y sitio para los que irán apareciendo
static func setup_cast(rng: RandomNumberGenerator) -> void:
	GS.cast = {}
	var g := "f" if rng.randf() < 0.6 else "m"
	var outlet := hostile_outlet()
	var look := DB.rand_look(g)
	GS.cast["periodista_inc"] = {"name": DB.rand_name(g), "role": "Periodista de %s" % outlet["name"], "look": look, "outlet": outlet["name"], "bias": outlet["bias"], "tag": outlet["tag"], "g": g}


## El medio más crítico con el partido del presidente
static func hostile_outlet() -> Dictionary:
	var ideo := float(W.PARTIES[GS.pres["party"]]["ideo"])
	var best: Dictionary = W.OUTLETS[0]
	var bs := -INF
	for o in W.OUTLETS:
		var b := float(o["bias"])
		if absf(b) <= 20.0:
			continue
		var s := -b * signf(ideo if ideo != 0.0 else 1.0) + randf() * 25.0
		if s > bs:
			bs = s
			best = o
	return best


static func journalist() -> Dictionary:
	return GS.cast.get("periodista_inc", {})


## Último hecho de un tipo (o vacío)
static func last(kind: String) -> Dictionary:
	for i in range(GS.memo.size() - 1, -1, -1):
		if GS.memo[i]["k"] == kind:
			return GS.memo[i]
	return {}


static func count(kind: String) -> int:
	var n := 0
	for m in GS.memo:
		if m["k"] == kind:
			n += 1
	return n


## ¿Hay un hecho de este tipo con al menos `age` días?
static func has_fact(kind: String, age: int = 0) -> bool:
	for m in GS.memo:
		if m["k"] == kind and GS.day - int(m["day"]) >= age:
			return true
	return false


# ------------------------------------------------------------------ disparar recuerdos

## Cada mes: alguna consecuencia de lo que hizo hace tiempo (como mucho una con decisión y un par de noticias)
static func monthly() -> void:
	var cands := _candidates()
	if cands.is_empty():
		return
	var inter := []
	var news := []
	for c in cands:
		(news if c[0]["type"] == "news" else inter).append(c)
	if not inter.is_empty() and GS.rng.randf() < 0.75:
		var c: Array = _weighted(inter)
		_fire(c[0], c[1])
	news.shuffle()
	var n_news := 0
	for c2 in news:
		if n_news >= 2:
			break
		if GS.rng.randf() < 0.6:
			_fire(c2[0], c2[1])
			n_news += 1


static func _weighted(list: Array) -> Array:
	var total := 0.0
	for c in list:
		total += float(c[0].get("w", 1.0))
	var r := GS.rng.randf() * total
	for c in list:
		r -= float(c[0].get("w", 1.0))
		if r <= 0.0:
			return c
	return list.back()


static func _candidates() -> Array:
	var out := []
	for m in GS.memo:
		var age := GS.day - int(m["day"])
		for t in D.TEMPLATES:
			if t["kind"] != m["k"]:
				continue
			if age < int(t.get("after", 30)) or age > int(t.get("before", 9999)):
				continue
			var used: Array = m.get("used", [])
			if t["id"] in used:
				continue
			if t.get("once", false) and GS.memo_used.has(t["id"]):
				continue
			if t.has("excl") and _any_used(m, t["excl"]):
				continue
			if t.has("need") and not _match(m["d"], t["need"]):
				continue
			if not GS.check(t.get("cond", {})):
				continue
			out.append([t, m])
	return out


static func _any_used(m: Dictionary, ids: Array) -> bool:
	for id in ids:
		if id in m.get("used", []):
			return true
	return false


## Requisitos sobre los datos del hecho: {"campo": valor} o {"campo": [valores]}; "!campo" niega
static func _match(d: Dictionary, need: Dictionary) -> bool:
	for k in need.keys():
		var neg: bool = str(k).begins_with("!")
		var key: String = str(k).substr(1) if neg else str(k)
		var want = need[k]
		var have = d.get(key, null)
		var ok: bool = (have in want) if want is Array else (have == want)
		if ok == neg:
			return false
	return true


static func _fire(t: Dictionary, m: Dictionary) -> void:
	if not m.has("used"):
		m["used"] = []
	m["used"].append(t["id"])
	GS.memo_used[t["id"]] = GS.day
	var vars := _vars(m)
	if t["type"] == "news":
		GS.push_news(_f(_pick_text(t.get("text", "")), vars), int(t.get("imp", 2)))
		if t.has("fx"):
			GS.apply_fx(t["fx"].duplicate(true), "Noticia", false)
		return
	var ev := {"id": "memo_%s_%d" % [t["id"], GS.next_uid()], "type": t["type"], "gen": true, "memo": true,
		"title": _f(_pick_text(t.get("title", "")), vars), "text": _f(_pick_text(t.get("text", "")), vars)}
	var who := _f(str(t.get("who", "jefa")), vars)
	if who.begins_with("ex_") or who == "periodista_inc" or who.begins_with("cast_"):
		_ensure_cast(who, m)
	ev["who"] = who
	if t.has("kind_doc"):
		ev["kind"] = t["kind_doc"]
	if t.has("stamps"):
		ev["stamps"] = t["stamps"]
	if t.has("small"):
		ev["small"] = [_f(str(t["small"]), vars)]
	if t.has("urgent"):
		ev["urgent"] = t["urgent"]
	var choices := []
	for c in t.get("choices", []):
		var cc: Dictionary = c.duplicate(true)
		cc["t"] = _f(str(cc["t"]), vars)
		if cc.has("news"):
			cc["news"] = _f(str(cc["news"]), vars)
		if cc.has("fx"):
			cc["fx"] = _fx_vars(cc["fx"], vars)
		choices.append(cc)
	ev["choices"] = choices
	ev["default"] = int(t.get("default", choices.size() - 1))
	GS.spawn(ev)


## Los efectos pueden nombrar el país del recuerdo: {"rel": {"@": 5}}
static func _fx_vars(fx: Dictionary, vars: Dictionary) -> Dictionary:
	var out := fx.duplicate(true)
	if out.has("rel") and out["rel"] is Dictionary and out["rel"].has("@"):
		var v = out["rel"]["@"]
		out["rel"].erase("@")
		if str(vars.get("m_country_id", "")) != "":
			out["rel"][vars["m_country_id"]] = v
	if out.has("memo") and out["memo"] is Dictionary:
		for k in out["memo"].keys():
			if out["memo"][k] is String:
				out["memo"][k] = _f(out["memo"][k], vars)
	if out.has("risk") and out["risk"] is Dictionary and out["risk"].has("news"):
		out["risk"]["news"] = _f(str(out["risk"]["news"]), vars)
	if out.has("else") and out["else"] is Dictionary and out["else"].has("news"):
		out["else"]["news"] = _f(str(out["else"]["news"]), vars)
	return out


static func _pick_text(v) -> String:
	if v is Array:
		return str(v[GS.rng.randi() % v.size()])
	return str(v)


## Un personaje que vuelve (un exministro, la periodista...) necesita ficha para verle la cara
static func _ensure_cast(who: String, m: Dictionary) -> void:
	if GS.cast.has(who):
		return
	var d: Dictionary = m["d"]
	GS.cast[who] = {"name": str(d.get("name", "Desconocido")), "role": "Ex" + str(d.get("role", "ministro")).to_lower(), "look": d.get("look", {})}


## Variables de texto de un recuerdo: {m_name}, {m_role}, {m_law}, {m_country}, {m_leader}, {m_date}...
static func _vars(m: Dictionary) -> Dictionary:
	var d: Dictionary = m["d"]
	var v := {}
	for k in d.keys():
		if typeof(d[k]) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_STRING_NAME]:
			v["m_" + str(k)] = str(d[k])
	v["m_date"] = UI.date_mid(int(m["day"]))
	v["m_ago"] = ago(GS.day - int(m["day"]))
	if d.has("role"):
		v["m_area"] = str(d["role"]).replace("Ministro de ", "").replace("Ministra de ", "").replace("Ministro del ", "").replace("Ministra del ", "")
	if d.has("law") and W.LAWS.has(str(d["law"])):
		v["m_law"] = W.LAWS[d["law"]]["name"]
	if d.has("who") and W.COUNTRIES.has(str(d["who"])):
		var c: Dictionary = W.COUNTRIES[d["who"]]
		v["m_country"] = c["name"]
		v["m_country_id"] = str(d["who"])
		v["m_leader"] = c["leader"]
	v["periodista"] = journalist().get("name", "una periodista")
	v["periodico"] = journalist().get("outlet", "El Heraldo")
	if m["k"] == "cese":
		v["ex"] = "ex_%d" % int(m["day"]) + "_" + str(d.get("key", ""))
	v["ex_g"] = "a" if str(d.get("look", {}).get("g", "m")) == "f" else "o"
	return v


static func _f(s: String, vars: Dictionary) -> String:
	if not "{" in s:
		return s
	return GS.fmt(s.format(vars))


static func ago(days: int) -> String:
	if days < 45:
		return "hace unas semanas"
	if days < 75:
		return "hace un par de meses"
	if days < 330:
		return "hace %d meses" % int(round(days / 30.0))
	if days < 540:
		return "hace un año"
	return "hace %d años" % int(round(days / 365.0))


# ------------------------------------------------------------------ recuerdos dentro de otros sistemas

## Frase con la que un líder extranjero empieza la llamada si recuerda algo (o vacío)
static func call_preface(who: String) -> String:
	if not W.COUNTRIES.has(who):
		return ""
	for i in range(GS.memo.size() - 1, -1, -1):
		var m: Dictionary = GS.memo[i]
		if str(m["d"].get("who", "")) != who:
			continue
		if GS.day - int(m["day"]) > 400:
			break
		var lines: Array = D.PREFACES.get(m["k"], [])
		if lines.is_empty():
			continue
		var vars := _vars(m)
		return _f(str(lines[GS.rng.randi() % lines.size()]), vars)
	return ""


## Ataques de la oposición que recuerdan lo que hizo el presidente
static func attacks() -> Array:
	var out := []
	for spec in D.OPP_ATTACKS:
		var m := last(spec["kind"])
		if m.is_empty() or GS.day - int(m["day"]) < int(spec.get("after", 0)):
			continue
		if spec.has("need") and not _match(m["d"], spec["need"]):
			continue
		var a: Dictionary = spec.duplicate(true)
		a["attack"] = _f(_pick_text(spec["attack"]), _vars(m))
		a.erase("kind")
		a["kind"] = spec.get("akind", "personal")
		a["memo"] = true
		out.append(a)
	out.shuffle()
	return out.slice(0, 2)


## Pregunta de la periodista incómoda que recuerda una respuesta anterior (o vacío)
static func press_question() -> Dictionary:
	var cands := []
	for m in GS.memo:
		if m["k"] != "prensa" or m.get("asked", false) or GS.day - int(m["day"]) < 40:
			continue
		cands.append(m)
	if cands.is_empty():
		var esc := last("escandalo")
		if not esc.is_empty() and not esc.get("asked", false) and GS.day - int(esc["day"]) >= 20:
			esc["asked"] = true
			var v := _vars(esc)
			return {"q": _f(_pick_text(D.PRESS_SCANDAL), v), "cast": "periodista_inc", "memo": true, "a": D.PRESS_SCANDAL_ANSWERS.duplicate(true)}
		return {}
	var m2: Dictionary = cands.pick_random()
	m2["asked"] = true
	var vars := _vars(m2)
	return {"q": _f(_pick_text(D.PRESS_CALLBACK), vars), "cast": "periodista_inc", "memo": true, "a": D.PRESS_CALLBACK_ANSWERS.duplicate(true)}

