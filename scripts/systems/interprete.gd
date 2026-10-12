extends RefCounted
## Entiende lo que el presidente escribe con sus propias palabras cuando alguien le plantea un dilema.
## Ahora funciona con reglas (scripts/data/interprete_reglas.gd): sin internet, gratis e instantáneo.
##
## Resultado de interpret(): {kind, idx, tone, reply}
##   kind: "elige" (una de las opciones, idx) · "aplazar" · "investigar" · "delegar" · "humor" · "insulto"
##         · "corrupcion" · "no_entiendo" · "vacio"
##   tone: "amable" · "neutro" · "brusco"
##
## Para conectar una IA en el futuro: un servidor propio recibe {texto, título, situación, opciones} y devuelve
## este mismo diccionario (con idx dentro de las opciones y kind de la lista de arriba). El juego nunca debe
## llevar la clave de la IA dentro; si no hay conexión, se usa interpret() como ahora.

const R := preload("res://scripts/data/interprete_reglas.gd")

static var _norm_intents := {}


static func normalize(s: String) -> String:
	var t := s.to_lower()
	var from := ["á", "à", "é", "è", "í", "ì", "ó", "ò", "ú", "ù", "ü", "ñ", "¿", "?", "¡", "!", ",", ".", ";", ":", "«", "»", "\"", "(", ")", "-", "…", "'"]
	var to := ["a", "a", "e", "e", "i", "i", "o", "o", "u", "u", "u", "n", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " "]
	for i in from.size():
		t = t.replace(from[i], to[i])
	while "  " in t:
		t = t.replace("  ", " ")
	return " " + t.strip_edges() + " "


static func _intent_lists() -> Dictionary:
	if _norm_intents.is_empty():
		for k in R.INTENTS.keys():
			var arr := []
			for w in R.INTENTS[k]:
				arr.append(normalize(str(w)).strip_edges())
			_norm_intents[k] = arr
	return _norm_intents


## Puntuación de cada intención en un texto ya normalizado (las frases largas pesan más que una palabra suelta)
static func intents(t: String) -> Dictionary:
	var out := {}
	var lists := _intent_lists()
	for k in lists.keys():
		var sc := 0.0
		for w0 in lists[k]:
			var w := str(w0)
			if (" " + w + " ") in t:
				var n := w.count(" ") + 1
				sc += 0.6 if (n == 1 and w.length() <= 2) else (0.9 + 0.35 * (n - 1))
		if sc > 0.0:
			out[k] = sc
	# «no lo apruebo», «no estoy de acuerdo»: la negación delante de un sí lo convierte en un no
	if out.has("aceptar") and (" no " in t):
		var p_no := t.find(" no ")
		var first_yes := 9999
		for w in lists["aceptar"]:
			var p := t.find(" " + w + " ")
			if p >= 0 and p < first_yes:
				first_yes = p
		if p_no < first_yes:
			out["rechazar"] = float(out.get("rechazar", 0.0)) + float(out["aceptar"])
			out.erase("aceptar")
	return out


static var _syn := {}


static func _syn_map() -> Dictionary:
	if _syn.is_empty():
		for i in R.SYN.size():
			for w in R.SYN[i]:
				_syn[str(w)] = "#g%d" % i
	return _syn


## Raíz de una palabra (o su grupo de sinónimos)
static func _stem(w: String) -> String:
	var sm := _syn_map()
	if sm.has(w):
		return sm[w]
	return w.left(5)


## Raíces del texto separadas en afirmadas y negadas: [afirmadas, negadas]
static func stems2(t: String) -> Array:
	var pos := []
	var neg := []
	var scope := 0
	for w in t.split(" ", false):
		var lw := String(w)
		if lw in R.NEGATORS:
			scope = 4
			continue
		if lw in R.SCOPE_END:
			scope = 0
			continue
		if lw in R.STOP or lw.length() < 3:
			continue
		(neg if scope > 0 else pos).append(_stem(lw))
		scope = maxi(0, scope - 1)
	return [pos, neg]


## Texto separado en lo afirmado y lo negado (con palabras vacías incluidas, para buscar frases): [afirmado, negado]
static func _split_negated(t: String) -> Array:
	var pos := " "
	var neg := " "
	var scope := 0
	for w in t.split(" ", false):
		var lw := String(w)
		if lw in R.NEGATORS:
			scope = 4
			continue
		if lw in R.SCOPE_END:
			scope = 0
		if scope > 0:
			neg += lw + " "
			if not (lw in R.STOP):
				scope -= 1
		else:
			pos += lw + " "
	return [pos, neg]


static func stems(t: String) -> Array:
	return stems2(t)[0]


## Perfil de una opción: qué intenciones encajan con ella (por su texto y por sus efectos)
static func profile(ch: Dictionary, idx: int, ev: Dictionary) -> Dictionary:
	var pr := intents(normalize(GS.fmt(str(ch.get("t", "")))))
	var fx: Dictionary = ch.get("fx", {})
	var money := float(fx.get("money", 0.0)) + float(fx.get("monthly", 0.0)) * 6.0
	if money < -50.0:
		pr["dinero"] = float(pr.get("dinero", 0.0)) + 1.0
	elif money > 50.0 or fx.is_empty():
		pr["ahorrar"] = float(pr.get("ahorrar", 0.0)) + 0.5
	if fx.has("nego") or fx.has("summit"):
		pr["negociar"] = float(pr.get("negociar", 0.0)) + 1.2
		pr["dialogo"] = float(pr.get("dialogo", 0.0)) + 0.6
	if fx.has("press") or fx.has("speech"):
		pr["comunicar"] = float(pr.get("comunicar", 0.0)) + 1.2
	if float(fx.get("corr", 0.0)) > 0.0 or float(ch.get("hidden", {}).get("corr", 0.0)) > 0.0:
		pr["corrupcion"] = float(pr.get("corrupcion", 0.0)) + 1.0
		pr["ocultar"] = float(pr.get("ocultar", 0.0)) + 0.5
	if float(fx.get("seguridad", 0.0)) > 0.0 or float(fx.get("militares", 0.0)) > 0.0:
		pr["fuerza"] = float(pr.get("fuerza", 0.0)) + 0.5
	var ct := normalize(GS.fmt(str(ch.get("t", ""))))
	if " nada " in ct or " ignorar" in ct or " ni caso " in ct or " esperar " in ct:
		pr["pasivo"] = float(pr.get("pasivo", 0.0)) + 1.5
	if idx == int(ev.get("default", -1)):
		pr["pasivo"] = float(pr.get("pasivo", 0.0)) + 0.6
		pr["aplazar"] = float(pr.get("aplazar", 0.0)) + 0.3
		pr["rechazar"] = float(pr.get("rechazar", 0.0)) + 0.4
	elif not pr.has("rechazar"):
		pr["aceptar"] = float(pr.get("aceptar", 0.0)) + 0.35
	return pr


static func _overlap(a: Array, b: Array) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var n := 0
	for w in a:
		if w in b:
			n += 1
	return float(n) / sqrt(float(a.size() * b.size()))


## Parecido entre lo que dice y una opción, teniendo en cuenta las negaciones de ambos lados
static func _similar(mine: Array, theirs: Array) -> float:
	var total := float(mine[0].size() + mine[1].size())
	var other := float(theirs[0].size() + theirs[1].size())
	if total == 0.0 or other == 0.0:
		return 0.0
	var s := 0.0
	for w in mine[0]:
		if w in theirs[0]:
			s += 1.0
		elif w in theirs[1]:
			s -= 1.0
	for w in mine[1]:
		if w in theirs[1]:
			s += 1.0
		elif w in theirs[0]:
			s -= 1.2
	return s / sqrt(total * other)


static func interpret(text: String, ev: Dictionary) -> Dictionary:
	var t := normalize(text)
	var out := {"kind": "no_entiendo", "idx": -1, "tone": "neutro", "reply": ""}
	if t.strip_edges() == "":
		out["kind"] = "vacio"
		return out
	var ints := intents(t)
	# tono: amable (por favor, gracias) o brusco (insultos, muchas exclamaciones, todo en mayúsculas)
	var letters := 0
	var caps := 0
	for c in text:
		if c.to_lower() != c.to_upper():
			letters += 1
			if c == c.to_upper():
				caps += 1
	if ints.has("insulto") or text.count("!") >= 3 or (letters > 8 and float(caps) / letters > 0.7):
		out["tone"] = "brusco"
	elif ints.has("cortesia") or ints.has("elogio"):
		out["tone"] = "amable"
	# las intenciones «de contenido» (dinero, fuerza, diálogo...) cuentan al revés si van negadas: «sin gastar», «nada de policía»
	var split := _split_negated(t)
	var ip := intents(split[0])
	var ineg := intents(split[1])
	for k in ["dinero", "ahorrar", "fuerza", "dialogo", "comunicar", "ocultar", "negociar"]:
		var v := float(ip.get(k, 0.0)) - 0.8 * float(ineg.get(k, 0.0))
		if v != 0.0:
			ints[k] = v
		else:
			ints.erase(k)
	var choices: Array = ev.get("choices", [])
	# un insulto o pedir algo turbio se impone a todo lo demás
	if ints.has("insulto") and float(ints["insulto"]) >= 0.9:
		out["kind"] = "insulto"
		return _reply(out)
	var corrupt_choice := false
	for c in choices:
		if float(c.get("fx", {}).get("corr", 0.0)) > 0.0 or float(c.get("hidden", {}).get("corr", 0.0)) > 0.0:
			corrupt_choice = true
	# «la segunda», «opción 1», «la última»
	var words := t.strip_edges().split(" ", false)
	for i in words.size():
		var w := String(words[i])
		if w == "ultima" or w == "ultimo":
			if " la ultima " in t or " el ultimo " in t or " opcion ultima " in t:
				out["kind"] = "elige"
				out["idx"] = choices.size() - 1
				return _reply(out)
		if R.ORDINALS.has(w) and int(R.ORDINALS[w]) < choices.size():
			var prev := String(words[i - 1]) if i > 0 else ""
			if prev in ["la", "el", "opcion", "numero", "elijo", "prefiero", "escojo"] or words.size() <= 2:
				out["kind"] = "elige"
				out["idx"] = int(R.ORDINALS[w])
				return _reply(out)
	# cuánto se parece a cada opción: palabras en común + intenciones que encajan
	var mine := stems2(t)
	var scores := []
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var sim := _similar(mine, stems2(normalize(GS.fmt(str(ch.get("t", "")))))) * 3.0
		var pr := profile(ch, i, ev)
		for k in ints.keys():
			if k in ["cortesia", "elogio", "humor"]:
				continue
			sim += float(ints[k]) * float(pr.get(k, 0.0)) * 0.9
		scores.append(sim)
	var best := -1
	var bs := -1.0
	var second := -1.0
	for i in scores.size():
		if scores[i] > bs:
			second = bs
			bs = scores[i]
			best = i
		elif scores[i] > second:
			second = scores[i]
	# pedir algo turbio (si no está claramente eligiendo una opción que ya lo es)
	if ints.has("corrupcion") and float(ints["corrupcion"]) >= 0.9 and not (corrupt_choice and bs >= 1.0):
		out["kind"] = "corrupcion"
		return _reply(out)
	var dominant := ""
	var dv := 0.0
	for k in ints.keys():
		if k in ["cortesia", "elogio"]:
			continue
		if float(ints[k]) > dv:
			dv = float(ints[k])
			dominant = k
	# pedir tiempo, datos o que decida otro, si no apunta claramente a una opción
	if dominant in ["aplazar", "investigar", "delegar"] and bs < 1.4:
		out["kind"] = dominant
		return _reply(out)
	if best >= 0 and bs >= 0.55 and bs - second >= 0.25:
		out["kind"] = "elige"
		out["idx"] = best
		return _reply(out)
	# rechaza claramente una opción («no pienso rescatar a nadie»): se queda con la que no hace nada
	var worst := 0.0
	for sc in scores:
		worst = minf(worst, float(sc))
	var def_idx := int(ev.get("default", choices.size() - 1))
	if ints.has("rechazar") and worst < -0.3 and def_idx >= 0 and def_idx < scores.size() and float(scores[def_idx]) >= bs - 0.05:
		out["kind"] = "elige"
		out["idx"] = def_idx
		return _reply(out)
	# un «sí» a secas: lo que recomienda quien se lo plantea
	if ints.has("aceptar") and not ints.has("rechazar"):
		for i in choices.size():
			if str(choices[i].get("rec", "")) == str(ev.get("who", "")):
				out["kind"] = "elige"
				out["idx"] = i
				return _reply(out)
	# un «sí» o un «no» a secas en un dilema de dos opciones
	if choices.size() == 2 and (ints.has("aceptar") or ints.has("rechazar")) and not (ints.has("aceptar") and ints.has("rechazar")):
		var def_i := int(ev.get("default", 1))
		out["kind"] = "elige"
		out["idx"] = (1 - def_i) if ints.has("aceptar") else def_i
		return _reply(out)
	if dominant == "humor":
		out["kind"] = "humor"
		return _reply(out)
	return _reply(out)


static func _reply(out: Dictionary) -> Dictionary:
	var key: String = out["kind"]
	if key == "elige":
		key = {"amable": "elige_amable", "brusco": "elige_brusco"}.get(out["tone"], "elige")
	var lines: Array = R.REPLIES.get(key, R.REPLIES["no_entiendo"])
	out["reply"] = lines[randi() % lines.size()]
	return out
