extends RefCounted
## Charla del móvil: el presidente escribe con sus propias palabras y cada persona le contesta a lo que ha dicho.
##
## Sin IA ni internet, con reglas (como scripts/systems/interprete.gd): se buscan intenciones (saludar, preguntar
## cómo está, pedir consejo, insultar, proponer un pacto...) y temas (la economía, la comida, Norland...) en lo
## que escribe, y cada persona contesta con su estilo (scripts/data/charla_data.gd). Si le habían preguntado algo
## (un mensaje con respuestas preparadas), se intenta entender cuál de ellas está eligiendo.
##
## Lo que se dice tiene consecuencias pequeñas (y con tope diario): hablar bien a su madre le quita estrés,
## insultar a la oposición o escribir algo turbio a una periodista puede acabar en los periódicos, halagar a un
## líder extranjero mejora un poco la relación...

const D := preload("res://scripts/data/charla_data.gd")
const Interprete := preload("res://scripts/systems/interprete.gd")
const W := preload("res://scripts/data/world_data.gd")

static var _norm := {}
static var _temas := {}


## Qué estilo de respuesta usa cada persona
static func persona(who: String) -> String:
	if who in ["madre", "jefa", "comunicacion", "opo", "ciudadano"]:
		return who
	if who in ["periodista_inc", "periodista"]:
		return "periodista"
	if W.COUNTRIES.has(who):
		return "lider"
	return "ministro"


## Personas a las que se puede escribir desde el móvil (además de las que ya tienen conversación)
static func contactos() -> Array:
	var out := ["madre", "jefa", "comunicacion"]
	for k in ["vice", "economia", "interior", "exteriores", "defensa", "sanidad"]:
		if GS.ministers.has(k):
			out.append(k)
	out.append("opo")
	if GS.cast.has("periodista_inc"):
		out.append("periodista_inc")
	for c in W.COUNTRIES.keys():
		out.append(c)
	return out


# ------------------------------------------------------------------ entender

static func _lista(nombre: String, src: Dictionary) -> Dictionary:
	if not _norm.has(nombre):
		var o := {}
		for k in src.keys():
			var arr := []
			for w in src[k]:
				arr.append(Interprete.normalize(str(w)).strip_edges())
			o[k] = arr
		_norm[nombre] = o
	return _norm[nombre]


## Intenciones de la charla presentes en un texto normalizado (las frases largas pesan más)
static func intenciones(t: String) -> Dictionary:
	var out := {}
	var lists := _lista("charla", D.INTENTS)
	for k in lists.keys():
		var sc := 0.0
		for w in lists[k]:
			if (" " + str(w) + " ") in t:
				sc += 0.9 + 0.35 * str(w).count(" ")
		if sc > 0.0:
			out[k] = sc
	return out


## Temas del texto: [clave, nombre] del más claro (o ["", ""]). Los países se reconocen por su nombre y su líder.
static func tema(t: String) -> Array:
	var best := ""
	var bn := ""
	var bs := 0.0
	var lists := _lista("temas", _temas_src())
	for k in lists.keys():
		var sc := 0.0
		for w in lists[k]:
			if (" " + str(w) + " ") in t:
				sc += 1.0 + 0.4 * str(w).count(" ")
		if sc > bs:
			bs = sc
			best = k
	if best == "":
		return ["", ""]
	if best.begins_with("pais_"):
		var c := best.substr(5)
		bn = String(W.COUNTRIES.get(c, {}).get("name", c))
	else:
		bn = String(D.TEMAS[best]["n"])
	return [best, bn]


static func _temas_src() -> Dictionary:
	if _temas.is_empty() or _temas.get("_pais", "") != GS.pais:
		_norm.erase("temas")
		_temas = {}
		for k in D.TEMAS.keys():
			_temas[k] = D.TEMAS[k]["w"]
		for c in W.COUNTRIES.keys():
			var cd: Dictionary = W.COUNTRIES[c]
			var ws := [String(cd["name"])]
			var ld := String(cd.get("leader", ""))
			if ld.contains(" "):
				ws.append(ld.get_slice(" ", ld.get_slice_count(" ") - 1))
			_temas["pais_" + c] = ws
		var src := _temas.duplicate()
		_temas["_pais"] = GS.pais
		return src
	var s := _temas.duplicate()
	s.erase("_pais")
	return s


## La pregunta que sigue en el aire: la última frase entre «¿» y «?» del mensaje que le mandaron
static func pregunta_de(msg: String) -> String:
	var e := msg.rfind("?")
	if e < 0:
		return ""
	var s := msg.rfind("¿", e)
	if s < 0:
		return ""
	return msg.substr(s, e - s + 1)


# ------------------------------------------------------------------ contestar

## Responde a lo que el presidente ha escrito en una conversación del móvil.
## t: la conversación (ver Redes). pend: la definición del mensaje que espera respuesta ({} si no hay).
## Devuelve {"t": respuesta, "idx": respuesta preparada elegida (-1 si ninguna), "fx": efectos, "news": titular}
static func responder(t: Dictionary, texto: String, pend: Dictionary = {}) -> Dictionary:
	var who := String(t.get("who", ""))
	var per := persona(who)
	var p: Dictionary = D.PERSONAS.get(per, D.PERSONAS["ministro"])
	var n := Interprete.normalize(texto)
	var out := {"t": "", "idx": -1, "fx": {}, "news": ""}
	if n.strip_edges() == "":
		return out
	var base := Interprete.intents(n)
	var ci := intenciones(n)
	# insultos que el intérprete no conoce («tirano», «mentiroso»...)
	if ci.has("insulto"):
		base["insulto"] = maxf(float(base.get("insulto", 0.0)), float(ci["insulto"]))
	var tm := tema(n)
	var tono := _tono(texto, base, ci)
	var vars := _vars(t, per, tm)
	# 1) le habían preguntado algo: ¿cuál de las respuestas preparadas está eligiendo?
	if not pend.is_empty() and not (base.has("insulto") and float(base["insulto"]) >= 0.9):
		var reps: Array = pend.get("replies", [])
		var ev := {"who": who, "choices": [], "default": maxi(0, reps.size() - 1)}
		for rp in reps:
			ev["choices"].append({"t": GS.fmt(String(rp.get("t", ""))), "fx": rp.get("fx", {})})
		var r := Interprete.interpret(texto, ev)
		if String(r["kind"]) == "elige" and int(r["idx"]) >= 0 and int(r["idx"]) < reps.size():
			out["idx"] = int(r["idx"])
			var back := String(reps[out["idx"]].get("back", ""))
			var pre := ""
			if tono == "brusco":
				pre = _pick(p, "insulto", vars) + " "
			out["t"] = _cap((pre + (back if back != "" else _pick(p, "generico", vars))).strip_edges())
			out["fx"] = _efectos(t, per, ci, base, tono, tm)
			out["news"] = String(out["fx"].get("_news", ""))
			out["fx"].erase("_news")
			return out
		vars["q"] = pregunta_de(String(t.get("pregunta", "")))
		if vars["q"] == "":
			vars["q"] = "¿qué me dices de lo otro?"
	# 2) charla: lo que más claro se vea de lo que ha escrito
	var cat := _categoria(p, who, per, base, ci, tm, n, texto)
	# a un ministro, por lo suyo, se le contesta con datos («¿cómo va el paro?» al de Economía)
	if per == "ministro" and cat in ["tema", "pregunta", "dato"] and _tema_propio(who, String(tm[0])):
		cat = "opinion_propia"
	var linea := _pick(p, cat, vars)
	# saludo + lo demás («Hola, mamá, ¿qué tal?»): se contesta a las dos cosas
	if ci.has("saludo") and cat not in ["saludo", "despedida", "insulto"]:
		linea = _pick(p, "hola" if p.has("hola") else "saludo", vars) + " " + _cap(linea)
	# si le habían preguntado algo y no lo ha contestado, insiste
	if not pend.is_empty() and cat not in ["insulto", "despedida"]:
		linea += " " + _pick(p, "insiste", vars)
	out["t"] = _cap(linea.strip_edges())
	out["fx"] = _efectos(t, per, ci, base, tono, tm)
	out["news"] = String(out["fx"].get("_news", ""))
	out["fx"].erase("_news")
	return out


## Amable, neutro o brusco (como en el intérprete: insultos, gritos y mayúsculas)
static func _tono(texto: String, base: Dictionary, ci: Dictionary) -> String:
	var letters := 0
	var caps := 0
	for c in texto:
		if c.to_lower() != c.to_upper():
			letters += 1
			if c == c.to_upper():
				caps += 1
	if base.has("insulto") or texto.count("!") >= 3 or (letters > 8 and float(caps) / letters > 0.7) or ci.has("amenaza"):
		return "brusco"
	if base.has("cortesia") or base.has("elogio") or ci.has("carino") or ci.has("gracias"):
		return "amable"
	return "neutro"


static func _categoria(p: Dictionary, who: String, per: String, base: Dictionary, ci: Dictionary, tm: Array, n: String, texto: String) -> String:
	if base.has("insulto") and float(base["insulto"]) >= 0.9:
		return "insulto"
	if base.has("corrupcion") and float(base["corrupcion"]) >= 0.9:
		return "turbio"
	if ci.has("despido") and per != "madre":
		return "despido"
	if ci.has("amenaza"):
		return "amenaza"
	if ci.has("sin_comentarios") and p.has("sin_comentarios"):
		return "sin_comentarios"
	if ci.has("secreto"):
		return "secreto"
	var adios := false
	for w in [" adios ", " hasta luego ", " hasta manana ", " hasta pronto ", " chao ", " nos vemos ", " me voy ", " te dejo ", " le dejo "]:
		if w in n:
			adios = true
	if adios and not "?" in texto:
		return "despedida"
	# lo que se pregunta o se pide
	for k in ["consejo", "cansancio", "opinion"]:
		if ci.has(k):
			if k == "opinion" and per == "ministro" and _tema_propio(who, String(tm[0])):
				return "opinion_propia"
			return k
	if ci.has("estado"):
		return "estado"
	if ci.has("dato") and (tm[0] in ["economia", "elecciones", "redes", "seguridad", "sanidad", "impuestos", ""]):
		return "dato"
	if ci.has("pacto") and per in ["opo", "lider", "jefa", "ministro", "comunicacion", "periodista", "madre", "ciudadano"]:
		return "pacto"
	if ci.has("comercio") and per in ["lider", "ministro", "jefa", "comunicacion", "periodista", "madre", "ciudadano", "opo"]:
		return "comercio"
	if ci.has("visita"):
		return "visita" if p.has("visita") else "generico"
	if ci.has("promesa") and p.has("promesa"):
		return "promesa"
	if ci.has("disculpa"):
		return "disculpa"
	if ci.has("gracias"):
		return "gracias"
	if ci.has("carino"):
		return "carino"
	if base.has("elogio"):
		return "elogio"
	if base.has("humor"):
		return "humor"
	# preguntas: «¿cuándo...?», «¿dónde...?», «¿por qué...?»
	if "?" in texto or n.begins_with(" que ") or n.begins_with(" como ") or n.begins_with(" cuando ") or n.begins_with(" donde "):
		for q in [["cuando", "pregunta_cuando"], ["donde", "pregunta_donde"], ["quien", "pregunta_quien"], ["por que", "pregunta_porque"]]:
			if (" " + q[0] + " ") in n and p.has(q[1]):
				return q[1]
		if tm[0] != "":
			return _cat_tema(p, tm[0])
		return "pregunta"
	if tm[0] != "":
		return _cat_tema(p, tm[0])
	if ci.has("saludo"):
		return "saludo"
	if ci.has("despedida"):
		return "despedida"
	if base.has("aceptar") or base.has("rechazar"):
		return "sino"
	return "generico"


static func _cat_tema(p: Dictionary, tk: String) -> String:
	if p.has("tema_" + tk):
		return "tema_" + tk
	return "tema"


## Temas de cada ministerio (el vicepresidente, de todo)
const RAMO := {"economia": ["economia", "impuestos", "energia", "vivienda", "trabajo"], "interior": ["seguridad", "ambiente"],
	"exteriores": ["guerra", "energia"], "defensa": ["guerra", "seguridad"], "sanidad": ["sanidad", "salud"]}


## ¿El tema es el de su ministerio?
static func _tema_propio(who: String, tk: String) -> bool:
	if tk == "":
		return false
	if who == "vice":
		return true
	if who == "exteriores" and tk.begins_with("pais_"):
		return true
	return tk in RAMO.get(who, [])


## Primera letra en mayúscula (los datos empiezan en minúscula para poder ir en medio de una frase)
static func _cap(s: String) -> String:
	if s == "":
		return s
	var i := 0
	while i < s.length() and s[i] in ["¿", "¡", "«", "(", "\"", " "]:
		i += 1
	if i >= s.length():
		return s
	return s.left(i) + s[i].to_upper() + s.substr(i + 1)


static func _pick(p: Dictionary, cat: String, vars: Dictionary) -> String:
	var lines: Array = p.get(cat, p.get("generico", ["..."]))
	if lines.is_empty():
		return ""
	return _f(String(lines.pick_random()), vars)


static func _f(s: String, vars: Dictionary) -> String:
	return GS.fmt(s.format(vars))


# ------------------------------------------------------------------ lo que sabe cada uno

static func _vars(t: Dictionary, per: String, tm: Array) -> Dictionary:
	var who := String(t.get("who", ""))
	var hijo := "hija" if str(GS.pres.get("look", {}).get("g", "m")) == "f" else "hijo"
	var tn := String(tm[1]) if String(tm[1]) != "" else "eso"
	var v := {"hijo": hijo, "Hijo": hijo.capitalize(), "tema": tn, "Tema": tn.left(1).to_upper() + tn.substr(1), "q": "",
		"nombre": String(t.get("name", "")), "su_pais": String(W.COUNTRIES.get(who, {}).get("name", "")),
		"rel": UI.signed(float(GS.countries.get(who, {}).get("rel", 0.0)), 0), "flojo": _flojo()[1],
		"consejo": String(D.CONSEJOS.get(_flojo()[0], D.CONSEJOS["nada"])), "animo": _animo_redes_txt()}
	v["dato"] = _dato(who, per, String(tm[0]))
	return v


## Lo que peor va del país: [clave, nombre]
static func _flojo() -> Array:
	var worst := ""
	var wv := 999.0
	for k in D.FLOJO.keys():
		var val := float(GS.meters.get(k, 50.0))
		if val < wv:
			wv = val
			worst = k
	if GS.approval < 38.0 and GS.approval < wv:
		return ["aprobacion", "la aprobación"]
	if wv >= 55.0:
		return ["nada", "nada en especial"]
	return [worst, String(D.FLOJO[worst])]


static func _animo_redes() -> int:
	var pos := 0
	var neg := 0
	for p in (GS.social.get("feed", []) as Array).slice(0, 25):
		if p.get("mood", "") == "pos":
			pos += 1
		elif p.get("mood", "") == "neg":
			neg += 1
	return 50 if pos + neg == 0 else int(100.0 * pos / float(pos + neg))


static func _animo_redes_txt() -> String:
	var a := _animo_redes()
	return "a favor" if a >= 58 else ("en contra" if a <= 42 else "dividido")


## Una cifra que conoce esa persona (cada ministro, la de su ramo)
static func _dato(who: String, per: String, tk: String) -> String:
	var m: Dictionary = GS.meters
	match per:
		"madre":
			if float(m.get("economia", 50.0)) < 45.0 or GS.inflation > 4.0:
				return "la compra está carísima y la vecina dice que no llega a fin de mes."
			if GS.approval >= 55.0:
				return "en la peluquería todas hablan bien de ti. Estoy muy orgullosa."
			if GS.approval < 38.0:
				return "en la peluquería dicen cosas feas de ti. Yo les digo que eres muy buen chico."
			return "unos dicen que bien y otros que mal. Lo normal."
		"jefa":
			var n := GS.inbox.size() + GS.visitors.size() + GS.calls.size()
			return "aprobación del {aprob} %%, y tiene %d asuntos esperando en la bandeja, las visitas y el teléfono." % n
		"comunicacion":
			return "tiene %s seguidores en Pío y el %d %% de lo que se dice de usted hoy es a favor." % [UI.num(float(GS.social.get("followers", 0))), _animo_redes()]
		"opo", "periodista", "ciudadano":
			if per == "ciudadano":
				return "el paro está en el {paro} % y aquí no se nota que mejore." if float(m.get("economia", 50.0)) < 50.0 else "dicen que la economía va mejor, pero en mi casa no se nota."
			return "una aprobación del {aprob} %, el paro en el {paro} % y la deuda en el {deuda} % del PIB."
		"lider":
			return "relaciones en %s." % UI.signed(float(GS.countries.get(who, {}).get("rel", 0.0)), 0)
	# ministros: cada uno, lo suyo (y según de qué le pregunten)
	if tk.begins_with("pais_") and per == "ministro":
		var c := tk.substr(5)
		if GS.countries.has(c):
			var r := float(GS.countries[c]["rel"])
			var nm := String(W.COUNTRIES.get(c, {}).get("name", c))
			var tr := []
			for t in GS.treaties:
				if t["c"] == c:
					tr.append(String(t["type"]))
			return "con %s estamos en %s%s. %s" % [nm, UI.signed(r, 0), (" y tenemos acuerdos de " + ", ".join(tr)) if tr.size() > 0 else ", sin acuerdos firmados",
				"La relación es buena: es buen momento para proponerles algo." if r >= 30.0 else ("Están muy molestos con nosotros: cuidado." if r <= -25.0 else "Ni amigos ni enemigos: hay margen para negociar.")]
	if who == "economia" and tk == "impuestos":
		return "la renta está al %s %%, el IVA al %s %% y sociedades al %s %%. Cada mes ingresamos %s y gastamos %s." % [UI.num(float(GS.taxes["renta"]), 1), UI.num(float(GS.taxes["iva"]), 1), UI.num(float(GS.taxes["sociedades"]), 1), UI.money(GS.revenue()), UI.money(GS.spending())]
	if tk == "energia" and per in ["ministro", "jefa"] and not GS.mercado.is_empty():
		var pr: Dictionary = GS.mercado.get("precios", {})
		return "el gas está a %d y el petróleo a %d (100 es lo normal). %s" % [int(pr.get("gas", 100.0)), int(pr.get("petroleo", 100.0)),
			"Lo estamos pagando caro." if float(pr.get("gas", 100.0)) + float(pr.get("petroleo", 100.0)) > 225.0 else "De momento, aguantamos."]
	match who:
		"economia":
			return "el paro está en el {paro} %%, la economía crece al {crec} %%, la inflación anda por el %s %% y la deuda es del {deuda} %% del PIB." % UI.num(GS.inflation, 1)
		"interior":
			return "la seguridad está en %d sobre 100 y la estabilidad en %d." % [int(m.get("seguridad", 50.0)), int(m.get("estabilidad", 50.0))]
		"exteriores":
			var mejor := ""
			var peor := ""
			var hi := -999.0
			var lo := 999.0
			for c in GS.countries.keys():
				var r := float(GS.countries[c]["rel"])
				if r > hi:
					hi = r
					mejor = c
				if r < lo:
					lo = r
					peor = c
			return "nuestro prestigio está en %d; la mejor relación, con %s (%s), y la peor, con %s (%s)." % [int(m.get("prestigio", 50.0)), W.COUNTRIES.get(mejor, {}).get("name", mejor), UI.signed(hi, 0), W.COUNTRIES.get(peor, {}).get("name", peor), UI.signed(lo, 0)]
		"defensa":
			return "las Fuerzas Armadas están en %d de satisfacción y la seguridad en %d." % [int(GS.fac.get("militares", 50.0)), int(m.get("seguridad", 50.0))]
		"sanidad":
			return "el bienestar está en %d sobre 100. Los hospitales aguantan, pero justos." % int(m.get("bienestar", 50.0))
	return "la aprobación está en el {aprob} %% y la economía en %d sobre 100." % int(m.get("economia", 50.0))


# ------------------------------------------------------------------ consecuencias

## Efectos de lo que ha escrito (pequeños y como mucho una vez al día por conversación). "_news": titular.
static func _efectos(t: Dictionary, per: String, ci: Dictionary, base: Dictionary, tono: String, tm: Array) -> Dictionary:
	var who := String(t.get("who", ""))
	var fx := {}
	var insulto := base.has("insulto") and float(base["insulto"]) >= 0.9
	var turbio := base.has("corrupcion") and float(base["corrupcion"]) >= 0.9
	var amable := tono == "amable"
	# el humor de la persona con el presidente (sale en el tono de la siguiente respuesta)
	var mood := float(t.get("mood", 0.0))
	if insulto or ci.has("amenaza"):
		mood -= 3.0
	elif amable:
		mood += 1.0
	t["mood"] = clampf(mood, -10.0, 10.0)
	# lo grave siempre cuenta; lo pequeño, una vez al día
	var hoy := int(t.get("fx_day", -1)) == GS.day
	match per:
		"madre":
			if not hoy and (amable or ci.has("visita") or ci.has("carino")):
				fx["stress"] = -2
			elif insulto:
				fx["stress"] = 2
		"jefa", "ministro", "comunicacion":
			if insulto:
				fx["stress"] = 1
				if GS.rng.randf() < 0.3:
					fx["approval"] = -1.0
					fx["_news"] = "Un miembro del Gobierno filtra que el presidente insulta a su equipo por mensajes"
			elif not hoy and ci.has("cansancio") and per == "jefa":
				fx["stress"] = -3
			elif not hoy and amable:
				fx["stress"] = -1
		"opo":
			var opp: String = W.PLAYER_PARTIES[GS.pres["party"]]["opp"]
			if insulto or turbio or ci.has("amenaza"):
				fx["party"] = {opp: -3}
				if GS.rng.randf() < (0.7 if turbio else 0.4):
					fx["approval"] = -1.5 if turbio else -1.0
					fx["_news"] = "%s difunde un mensaje privado del presidente: «%s»" % [GS.opo_name(), _cita(String(t["msgs"].back()["t"]) if not (t["msgs"] as Array).is_empty() else "")]
			elif not hoy and ci.has("pacto"):
				fx["party"] = {opp: 2}
			elif not hoy and amable:
				fx["party"] = {opp: 1}
		"periodista":
			# lo que se le escribe a una periodista puede acabar en portada (salvo que se pida off the record)
			if (insulto or turbio or ci.has("amenaza")) and not ci.has("secreto"):
				fx["approval"] = -2.0 if turbio else -1.0
				if turbio:
					fx["corr"] = 1.0
				fx["_news"] = "Exclusiva: el presidente, en un mensaje a una periodista: «%s»" % _cita(String(t["msgs"].back()["t"]) if not (t["msgs"] as Array).is_empty() else "")
			elif not hoy and ci.has("secreto") and GS.rng.randf() < 0.15:
				fx["_news"] = "Fuentes de Presidencia aseguran que el Gobierno prepara movimientos sobre %s" % (String(tm[1]) if String(tm[1]) != "" else "varios asuntos")
		"lider":
			if insulto or ci.has("amenaza"):
				fx["rel"] = {who: -6 if insulto else -3}
				if insulto:
					fx["_news"] = "Tensión diplomática: el presidente insulta por mensaje al líder de %s" % W.COUNTRIES.get(who, {}).get("name", who)
			elif not hoy and (amable or base.has("elogio")):
				fx["rel"] = {who: 2}
		"ciudadano":
			if insulto:
				fx["approval"] = -1.0
				fx["_news"] = "Se hace viral la respuesta del presidente a un ciudadano que le escribió por el pediatra"
			elif not hoy and amable:
				fx["approval"] = 0.3
	if not fx.is_empty():
		t["fx_day"] = GS.day
	return fx


## Un trozo de lo que escribió, para el titular
static func _cita(s: String) -> String:
	s = s.strip_edges()
	return s.left(70) + ("…" if s.length() > 70 else "")
