extends RefCounted
## El país que gobierna el presidente. Los datos del juego (eventos, preguntas, leyes, cartas, personajes, regiones,
## partidos...) están escritos para Valdoria; al empezar una partida, aplicar(id) los adapta al país elegido:
##  1. Cambia en todos los textos de datos los nombres de Valdoria por los del país (nombre y gentilicios, capital,
##     regiones, partidos y sus líderes, personajes fijos). Norland y Valdoria se intercambian: lo que los textos dicen
##     de Norland como país extranjero pasa a decirse de Valdoria.
##  2. Ajusta las tablas del mundo: el país elegido sale de la lista de países extranjeros y, si no es Valdoria, Valdoria
##     entra en ella con su presidenta.
##  3. Aparta lo que solo tiene sentido para Valdoria (vecinos, socios, geografía): eventos, tramas, escenarios y
##     cumbres que lo nombran no salen.
## Siempre parte de los datos originales (se guardan la primera vez), así que se puede cambiar de país entre partidas.

const PD := preload("res://scripts/data/paises_data.gd")
const W := preload("res://scripts/data/world_data.gd")

## Variables con textos de cada script de datos (las que se adaptan al país)
const DATOS := {
	"res://scripts/data/world_data.gd": ["COUNTRY_NAME", "CAPITAL", "METER_INFO", "FACTION_INFO", "BUDGET", "TAXES", "PARTIES", "PLAYER_PARTIES", "CHARACTERS", "TRAITS", "CABINET", "REFORMS", "COUNTRIES", "PERSONALITIES", "REGIONS", "LAWS", "OUTLETS", "NAMES_M", "NAMES_F", "SURNAMES", "COMPANIES", "PROJECTS", "TOPICS", "CRISES"],
	"res://scripts/data/events_data.gd": ["EVENTS"],
	"res://scripts/data/events_extra.gd": ["EVENTS"],
	"res://scripts/data/events_meme.gd": ["EVENTS", "BILLS", "RIDERS", "LETTERS", "CRIMES", "SPEECH", "QUESTIONS"],
	"res://scripts/data/events_tramas.gd": ["EVENTS"],
	"res://scripts/data/events_v3a.gd": ["EVENTS"],
	"res://scripts/data/events_v3b.gd": ["EVENTS"],
	"res://scripts/data/casino_data.gd": ["HOSTS", "SOURCES", "CROUPIER", "JEFA_CALL", "PHOTOGRAPHER", "COVERS", "PROFITS", "SCANDAL_LEVELS"],
	"res://scripts/data/conversaciones_data.gd": ["DEBATE", "DEBATE_LINES", "OPP_REACTIONS", "ORDER_LINES", "TELEPROMPTER_SWAPS", "TELEPROMPTER_INSERTS", "SPEECH", "QUESTIONS"],
	"res://scripts/data/generadores_data.gd": ["BILLS", "RIDERS", "LETTERS", "CRIMES", "BID_NOTES", "PROJECTS"],
	"res://scripts/data/memoria_data.gd": ["TEMPLATES", "PREFACES", "OPP_ATTACKS", "PRESS_CALLBACK", "PRESS_CALLBACK_ANSWERS", "PRESS_SCANDAL", "PRESS_SCANDAL_ANSWERS"],
	"res://scripts/data/plantillas_data.gd": ["PLACES", "PETITIONS", "MAYOR_LINES", "INVESTMENTS", "INVESTORS", "PROTESTS", "CONTROVERSIES", "INCIDENTS", "MEASURES", "CELEBRITIES", "DIPLO", "DIPLO_OPEN"],
	"res://scripts/data/press_data.gd": ["QUESTIONS", "SPEECH", "DEBATE", "DEBATE_REPLIES", "DEBATE_LINES", "OPP_REACTIONS"],
	"res://scripts/data/promises_data.gd": ["PROMISES", "PROMISES_MEME", "VOTES_KEPT", "VOTES_FAILED", "BROKEN_APPROVAL", "BROKEN_GROUP"],
	"res://scripts/data/scenarios_data.gd": ["SCENARIOS", "TRAMAS"],
	"res://scripts/data/social_data.gd": ["FAMOUS", "REACT", "AMBIENT", "FILLER_TRENDS", "FILLER_TRENDS_MEME", "POST_TEXT", "POST_RESULT", "REPLIES_GOOD", "REPLIES_BAD", "CHATS", "CHATS2"],
	"res://scripts/data/reto_data.gd": ["RULES", "CLASH"],
	"res://scripts/autoload/db.gd": ["DOMESTIC", "SUMMITS", "BILLS", "RIDERS", "LETTERS", "CRIMES", "BID_NOTES"],
}
## Listas de las que el juego elige al azar (cartas, preguntas, ataques, mensajes, protestas...): en otro país se
## quitan las frases que nombran a los vecinos y socios de Valdoria o a Norland como potencia («se van a Norland»,
## «una colonia de Norland»), igual que los eventos. Nunca se deja una lista vacía
const LISTAS := {
	"res://scripts/data/social_data.gd": ["AMBIENT", "CHATS", "CHATS2", "FAMOUS", "POST_TEXT"],
	"res://scripts/data/conversaciones_data.gd": ["DEBATE", "QUESTIONS", "SPEECH"],
	"res://scripts/data/press_data.gd": ["QUESTIONS", "SPEECH", "DEBATE"],
	"res://scripts/data/generadores_data.gd": ["LETTERS", "BID_NOTES", "PROJECTS"],
	"res://scripts/data/plantillas_data.gd": ["PETITIONS", "INVESTMENTS", "INVESTORS", "PROTESTS", "CONTROVERSIES", "INCIDENTS", "MEASURES", "CELEBRITIES", "DIPLO", "DIPLO_OPEN"],
	"res://scripts/data/memoria_data.gd": ["TEMPLATES", "PREFACES", "OPP_ATTACKS"],
	"res://scripts/data/events_meme.gd": ["BILLS", "RIDERS", "LETTERS", "CRIMES", "SPEECH", "QUESTIONS"],
	"res://scripts/autoload/db.gd": ["LETTERS", "BID_NOTES"],
}
## Scripts con eventos (para apartar los que no tienen sentido en el país)
const EVENTOS := ["res://scripts/data/events_data.gd", "res://scripts/data/events_extra.gd", "res://scripts/data/events_meme.gd",
	"res://scripts/data/events_tramas.gd", "res://scripts/data/events_v3a.gd", "res://scripts/data/events_v3b.gd"]
## Apellidos de los personajes de Valdoria que los textos usan sueltos («Arriaga ha dicho...»). Los que también son
## palabras corrientes (Campos, Solano, Robles) o nombres de otros personajes (Vidal) no se cambian sueltos
const APELLIDOS_SUELTOS := ["Arriaga", "Sotomayor", "Márquez", "Quintana", "Ferrer", "Villalba", "Prieto", "Varela", "Beltrán", "Lanz", "Aranda", "Iturbe", "Valverde"]

static var actual := "valdoria"
## Eventos, tramas y escenarios apartados para el país actual
static var apartados := {}
static var _base := {}


# ------------------------------------------------------------------ consultas

static func ficha(p := "") -> Dictionary:
	return PD.PAISES.get(p if p != "" else actual, PD.PAISES["valdoria"])


static func nombre() -> String:
	return String(ficha()["name"])


static func nombre_completo() -> String:
	return String(ficha()["full"])


## Gentilicio: 0 masculino, 1 femenino, 2 masculino plural, 3 femenino plural
static func gent(forma := 0) -> String:
	return String(ficha()["gent"][forma])


static func capital() -> String:
	return String(ficha()["cap"])


static func world_id() -> int:
	return int(ficha()["world_id"])


## Símbolo de la moneda del país que se gobierna (€ en Valdoria, $ en Norland)
static func moneda() -> String:
	return String(ficha().get("currency", "€"))


static func mapa() -> String:
	return String(ficha()["map"])


static func es_valdoria() -> bool:
	return actual == "valdoria"


# ------------------------------------------------------------------ aplicar un país

static func aplicar(p: String) -> void:
	if not PD.PAISES.has(p):
		p = "valdoria"
	_guardar_base()
	actual = p
	var cambios := tabla(p)
	var re := _regex(cambios)
	var f: Dictionary = ficha(p)
	for path in DATOS.keys():
		var s: GDScript = load(path)
		for n in DATOS[path]:
			var orig = _base[path + ":" + n]
			if LISTAS.get(path, []).has(n) and f.has("excl_ids"):
				orig = _filtrar(orig, f["excl_ids"], f["excl_names"])
			s.set(n, _loc(orig, re, cambios) if re != null else orig.duplicate(true) if orig is Dictionary or orig is Array else orig)
	_mundo(p)
	_apartar(p)


## Pares [texto de Valdoria, texto del país] (vacía para Valdoria)
static func tabla(p: String) -> Dictionary:
	var out := {}
	if p == "valdoria":
		return out
	var v: Dictionary = PD.PAISES["valdoria"]
	var f: Dictionary = PD.PAISES[p]
	# nombre oficial (con su artículo), gentilicios y país
	out["la " + String(v["full"])] = _articulado(String(f["full"]))
	out[String(v["full"])] = f["full"]
	for i in 4:
		out[String(v["gent"][i])] = f["gent"][i]
		out[String(v["gent"][i]).capitalize()] = String(f["gent"][i]).capitalize()
	out[String(v["name"])] = f["name"]
	# capital y regiones (también juntas, como salen en los hashtags: #NieveEnSantaAurora)
	for k in v["regions"].keys():
		out[String(v["regions"][k])] = f["regions"][k]
		if " " in String(v["regions"][k]):
			out[String(v["regions"][k]).replace(" ", "")] = String(f["regions"][k]).replace(" ", "")
	# partidos y líderes
	for k in v["parties"].keys():
		out[String(v["parties"][k]["name"])] = f["parties"][k]["name"]
		out[String(v["parties"][k]["leader"])] = f["parties"][k]["leader"]
	# personajes fijos, con nombre completo y (los seguros) solo con el apellido
	for k in v["cast"].keys():
		out[String(v["cast"][k])] = f["cast"][k]
	var apellidos := {}
	for k in v["cast"].keys():
		apellidos[String(v["cast"][k]).get_slice(" ", 1)] = String(f["cast"][k]).get_slice(" ", 1)
	for k in v["parties"].keys():
		apellidos[String(v["parties"][k]["leader"]).get_slice(" ", 1)] = String(f["parties"][k]["leader"]).get_slice(" ", 1)
	for a in APELLIDOS_SUELTOS:
		if apellidos.has(a):
			out[a] = apellidos[a]
	# el país elegido era extranjero en los textos: se intercambia con Valdoria
	if p == "norland":
		var ai: Dictionary = v["ai"]
		out["Estados Federados de Norland"] = ai["full"]
		out["Norland"] = v["name"]
		out["Harrison Kade"] = ai["leader"]
		out["Kade"] = String(ai["leader"]).get_slice(" ", 1)
		for i in 4:
			out[String(f["gent"][i])] = v["gent"][i]
			out[String(f["gent"][i]).capitalize()] = String(v["gent"][i]).capitalize()
	# moneda: «200 M€» pasa a «200 M$» (también con la M delante, que la frontera de palabra no deja pasar)
	if String(f.get("currency", "€")) != "€":
		out["M€"] = "M" + String(f["currency"])
		out["€"] = String(f["currency"])
	return out


static func _articulado(full: String) -> String:
	if full.begins_with("Estados"):
		return "los " + full
	return "la " + full


# ------------------------------------------------------------------ sustitución de textos

static func _regex(cambios: Dictionary) -> RegEx:
	if cambios.is_empty():
		return null
	var keys := cambios.keys()
	keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	var alt := PackedStringArray()
	for k in keys:
		alt.append(_escape(String(k)))
	# \b no conoce las letras con tilde: se comprueba el borde de palabra a mano en _sustituir
	return RegEx.create_from_string("(" + "|".join(alt) + ")")


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in ".^$*+?()[]{}|\\":
			out += "\\"
		out += ch
	return out


static func _letra(ch: String) -> bool:
	return ch != "" and (ch.to_lower() != ch.to_upper() or ch.is_valid_int())


## Cambia en s todas las apariciones de palabras enteras de la tabla (de una pasada: los intercambios no se pisan)
static func sustituir(s: String, re: RegEx, cambios: Dictionary) -> String:
	if s.length() < 3:
		return s
	var ms := re.search_all(s)
	if ms.is_empty():
		return s
	var out := ""
	var pos := 0
	for m in ms:
		var a := m.get_start()
		var b := m.get_end()
		var antes := s.substr(a - 1, 1) if a > 0 else ""
		var despues := s.substr(b, 1) if b < s.length() else ""
		# borde de palabra; en los hashtags (#FeriaDeFerrosa) también cuenta el paso de minúscula a mayúscula
		var hashtag_antes := _letra(antes) and antes == antes.to_lower() and m.get_string().left(1) == m.get_string().left(1).to_upper()
		var hashtag_despues := _letra(despues) and despues == despues.to_upper() and not despues.is_valid_int()
		if (_letra(antes) and not hashtag_antes) or (_letra(despues) and not hashtag_despues):
			continue
		out += s.substr(pos, a - pos) + String(cambios[m.get_string()])
		pos = b
	return out + s.substr(pos)


static func _loc(v, re: RegEx, cambios: Dictionary):
	if v is String:
		return sustituir(v, re, cambios)
	if v is Array:
		var a := []
		for x in v:
			a.append(_loc(x, re, cambios))
		return a
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[_loc(k, re, cambios) if k is String else k] = _loc(v[k], re, cambios)
		return d
	return v


static func _guardar_base() -> void:
	if not _base.is_empty():
		return
	for path in DATOS.keys():
		var s: GDScript = load(path)
		for n in DATOS[path]:
			var val = s.get(n)
			_base[path + ":" + n] = val.duplicate(true) if val is Dictionary or val is Array else val


# ------------------------------------------------------------------ el mundo visto desde el país

static func _mundo(p: String) -> void:
	var f: Dictionary = ficha(p)
	# siglas de los partidos (los nombres y líderes ya se han cambiado en los textos)
	for k in W.PARTIES.keys():
		W.PARTIES[k]["short"] = f["parties"][k]["short"]
	for k in W.CHARACTERS.keys():
		if String(k).begins_with("opo_"):
			var pk := String(k).substr(4)
			if W.PARTIES.has(pk):
				W.CHARACTERS[k]["role"] = "Líder de la Oposición (%s)" % W.PARTIES[pk]["short"]
	if f.has("names_m"):
		W.NAMES_M = f["names_m"].duplicate()
		W.NAMES_F = f["names_f"].duplicate()
		W.SURNAMES = f["surnames"].duplicate()
	if p == "valdoria":
		return
	# el país elegido deja de ser extranjero; Valdoria pasa a serlo
	W.COUNTRIES.erase(p)
	W.TOPICS.erase(p)
	# las negociaciones con los vecinos y socios de Valdoria están escritas para Valdoria
	for c in f.get("excl_ids", []):
		W.TOPICS.erase(c)
	var ai: Dictionary = PD.PAISES["valdoria"]["ai"].duplicate(true)
	W.COUNTRIES["valdoria"] = ai
	W.TOPICS["valdoria"] = str_to_var(var_to_str(TEMAS_VALDORIA).replace("€", String(f.get("currency", "€"))))
	for c in f.get("vistos", {}).keys():
		if W.COUNTRIES.has(c):
			W.COUNTRIES[c]["desc"] = f["vistos"][c]


## Negociaciones con Valdoria cuando es un país extranjero
const TEMAS_VALDORIA := [
	{"id": "agricola", "name": "Acuerdo agrícola", "desc": "Valdoria quiere vender su aceite, su vino y su fruta sin aranceles; nuestros agricultores protestan.", "term": ["Aranceles a la fruta de Valdoria", 18.0, 0.0, "%"], "fx_min": {"rel": {"valdoria": 6}}, "fx_max": {"economia": 2, "clase_media": 2, "trabajadores": -2, "rel": {"valdoria": 2}}, "treaty": "comercio"},
	{"id": "base_sur", "name": "La base naval del sur", "desc": "Nuestra flota necesita el puerto de Puerto Alba. Valdoria pide una compensación... y respeto.", "term": ["Compensación anual a Valdoria", 2500.0, 200.0, " M€"], "fx_min": {"militares": 2, "rel": {"valdoria": 4}}, "fx_max": {"militares": 5, "prestigio": 3, "rel": {"valdoria": 1}}, "treaty": "defensa"},
]


# ------------------------------------------------------------------ lo que solo tiene sentido para Valdoria

static func _apartar(p: String) -> void:
	apartados = {"eventos": {}, "tramas": [], "escenarios": [], "cumbres": []}
	var f: Dictionary = ficha(p)
	var ids: Array = f.get("excl_ids", [])
	var nombres: Array = f.get("excl_names", [])
	if ids.is_empty() and nombres.is_empty():
		return
	# eventos que nombran (en el texto original) un país o un lugar apartado, y los que encadenan con ellos
	var cadena := {}
	var malos := {}
	for path in EVENTOS:
		for e in _base[path + ":EVENTS"]:
			var id := String(e.get("id", ""))
			cadena[id] = _cadenas(e)
			if _nombra(e, ids, nombres):
				malos[id] = true
	var cambio := true
	while cambio:
		cambio = false
		for id in cadena.keys():
			if malos.has(id):
				continue
			for nxt in cadena[id]:
				if malos.has(nxt):
					malos[id] = true
					cambio = true
					break
	apartados["eventos"] = malos
	var SC: GDScript = load("res://scripts/data/scenarios_data.gd")
	for t in SC.TRAMAS.keys():
		if malos.has(String(SC.TRAMAS[t].get("start", ""))) or _nombra(_base["res://scripts/data/scenarios_data.gd:TRAMAS"][t], ids, nombres):
			apartados["tramas"].append(t)
			SC.TRAMAS.erase(t)
	for s in SC.SCENARIOS.keys():
		if _nombra(_base["res://scripts/data/scenarios_data.gd:SCENARIOS"][s], ids, nombres):
			apartados["escenarios"].append(s)
			SC.SCENARIOS.erase(s)
	var DBS: GDScript = load("res://scripts/autoload/db.gd")
	for k in DBS.SUMMITS.keys():
		var ls: Array = DBS.SUMMITS[k].get("leaders", [])
		var fuera := 0
		for l in ls:
			if l in ids and l != "union":
				fuera += 1
		if fuera > 0 and not (p in ls and fuera == 1):
			apartados["cumbres"].append(k)
			DBS.SUMMITS.erase(k)
		elif p in ls:
			var i := ls.find(p)
			DBS.SUMMITS[k]["leaders"][i] = "valdoria"


## Quita de las listas (a cualquier profundidad) los elementos que nombran países o lugares apartados, sin dejar
## ninguna lista vacía
static func _filtrar(v, ids: Array, nombres: Array):
	if v is Array:
		var a := []
		for x in v:
			if not _nombra(x, ids, nombres):
				a.append(_filtrar(x, ids, nombres))
		if a.is_empty() and not v.is_empty():
			return v.duplicate(true)
		return a
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[k] = _filtrar(v[k], ids, nombres)
		return d
	return v


static func _cadenas(v) -> Array:
	var out := []
	if v is Dictionary:
		for k in v.keys():
			if k == "chain" and v[k] is Dictionary and v[k].has("id"):
				out.append(String(v[k]["id"]))
			else:
				out.append_array(_cadenas(v[k]))
	elif v is Array:
		for x in v:
			out.append_array(_cadenas(x))
	return out


## ¿Nombra el dato (en cualquier texto o en sus efectos) alguno de esos países o lugares?
static func _nombra(v, ids: Array, nombres: Array) -> bool:
	if v is String:
		if v in ids:
			return true
		for n in nombres:
			if String(n) in v:
				return true
		return false
	if v is Array:
		for x in v:
			if _nombra(x, ids, nombres):
				return true
		return false
	if v is Dictionary:
		for k in v.keys():
			if k is String and k in ids:
				return true
			if _nombra(v[k], ids, nombres):
				return true
	return false
