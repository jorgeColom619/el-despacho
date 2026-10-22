extends Node
## Acceso a datos estáticos y generadores procedurales de contenido.

const W := preload("res://scripts/data/world_data.gd")
const E := preload("res://scripts/data/events_data.gd")
const E_TRAMAS := preload("res://scripts/data/events_tramas.gd")
const E_EXTRA := preload("res://scripts/data/events_extra.gd")
const E_MEME := preload("res://scripts/data/events_meme.gd")
const P := preload("res://scripts/data/press_data.gd")
const SC := preload("res://scripts/data/scenarios_data.gd")
const G := preload("res://scripts/data/generadores_data.gd")
const C := preload("res://scripts/data/conversaciones_data.gd")
const E_V3A := preload("res://scripts/data/events_v3a.gd")
const E_V3B := preload("res://scripts/data/events_v3b.gd")
const Promesas := preload("res://scripts/systems/promesas.gd")
const Memoria := preload("res://scripts/systems/memoria.gd")
## Días que tarda en volver a salir en el Congreso la misma promesa rota o el mismo recuerdo
const SPECIAL_ATTACK_CD := 180

var events_by_id := {}
## Todos los eventos del juego (base + tramas + extra)
var all_events := []
var world_map_info := {}
var region_info := {}

const DOMESTIC := {
	"sindicato": {"pers": "paciente", "power": 55.0, "topics": {
		"profes": {"id": "profes", "name": "Salarios de los docentes", "desc": "Los sindicatos de enseñanza quieren una subida salarial y más plantilla.", "term": ["Subida salarial", 9.0, 2.0, "%"], "fx_min": {"money": -2200, "jovenes": 5, "trabajadores": 5}, "fx_max": {"money": -600, "jovenes": 2, "trabajadores": 1}, "nodeal": {"trabajadores": -5, "jovenes": -4, "estabilidad": -2}},
		"salarios": {"id": "salarios", "name": "Pacto salarial", "desc": "Los sindicatos exigen subidas salariales generalizadas.", "term": ["Subida salarial pactada", 8.0, 2.5, "%"], "fx_min": {"trabajadores": 8, "empresarios": -6, "economia": -1}, "fx_max": {"trabajadores": 3, "empresarios": 1}, "nodeal": {"trabajadores": -6, "crisis": "huelga_general"}},
	}},
	"patronal": {"pers": "pragmatico", "power": 62.0, "topics": {
		"sociedades": {"id": "sociedades", "name": "Rebaja del Impuesto de Sociedades", "desc": "La patronal exige una rebaja fiscal para seguir invirtiendo.", "term": ["Rebaja de Sociedades", 8.0, 1.0, " puntos"], "fx_min": {"tax": {"sociedades": -8.0}, "empresarios": 10, "trabajadores": -3}, "fx_max": {"tax": {"sociedades": -1.0}, "empresarios": 3}, "nodeal": {"empresarios": -6, "economia": -2}},
	}},
	"islas": {"pers": "orgulloso", "power": 35.0, "topics": {
		"autonomia": {"id": "autonomia", "name": "Autogobierno de las Islas", "desc": "Quintana quiere más competencias para las Islas Cordales.", "term": ["Competencias transferidas", 90.0, 20.0, "%"], "fx_min": {"party": {"CR": 15}, "estabilidad": 4, "militares": -4, "clase_media": -3}, "fx_max": {"party": {"CR": 5}, "estabilidad": 2}, "nodeal": {"flag": "islas_tension", "party": {"CR": -10}, "chain": {"id": "islas_referendum", "delay": 60}}},
	}},
	"opo": {"pers": "orgulloso", "power": 60.0, "topics": {
		"pacto": {"id": "pacto", "name": "Pacto de Estado de las pensiones", "desc": "La oposición ofrece apoyo parlamentario a cambio de subir las pensiones.", "term": ["Revalorización anual", 4.0, 1.0, "%"], "fx_min": {"jubilados": 8, "monthly": -600, "estabilidad": 6}, "fx_max": {"jubilados": 3, "monthly": -100, "estabilidad": 6}, "nodeal": {"estabilidad": -3}},
	}},
}

## Cumbres internacionales: negociación con varios líderes a la vez (el acuerdo debe convencer a todos)
const SUMMITS := {
	"clima": {"name": "Cumbre del Clima de Marvella", "leaders": ["union", "tsaing", "norland"],
		"invite": "Presidente, la Unión, Tsaing y Norland celebran una cumbre climática en Marvella y nos invitan a liderar un pacto común. Si lo logramos, nuestro prestigio se disparará.",
		"desc": "Hay que fijar un objetivo común de reducción de emisiones que acepten los tres.",
		"term": ["Reducción de emisiones comprometida", 10.0, 55.0, "%"], "fx_min": {"ambiente": 2, "prestigio": 3}, "fx_max": {"ambiente": 9, "prestigio": 8, "jovenes": 5, "empresarios": -3}, "deal_rel": 6},
	"estrecho": {"name": "Cumbre del Estrecho", "leaders": ["union", "aldora", "sarvenia"],
		"invite": "La Unión, Aldora y Sarvenia se reúnen para pactar un plan conjunto de fronteras y migración. Valdoria puede salir de allí con mucho dinero... o con las manos vacías.",
		"desc": "Se reparte un fondo común para el control de fronteras. Cuanto más pidas, más difícil será que firmen todos.",
		"term": ["Fondos para Valdoria", 500.0, 6000.0, " M€"], "fx_min": {"money": 500, "seguridad": 2}, "fx_max": {"money": 6000, "seguridad": 5, "clase_media": 3}, "deal_rel": 5, "flag": "pacto_aldora"},
	"energia": {"name": "Cumbre de la Energía", "leaders": ["qadar", "kharovia", "union"],
		"invite": "Qadar y Kharovia, los grandes productores, se sientan con la Unión para fijar precios de la energía. Es nuestra oportunidad de abaratar la factura.",
		"desc": "Pactar una rebaja del precio de la energía para Valdoria que acepten productores y socios.",
		"term": ["Rebaja del precio de la energía", 2.0, 25.0, "%"], "fx_min": {"economia": 1}, "fx_max": {"economia": 5, "trabajadores": 4, "clase_media": 3}, "deal_rel": 5},
	"comercio": {"name": "Cumbre de Libre Comercio", "leaders": ["norland", "tsaing", "qadar"],
		"invite": "Norland, Tsaing y Qadar proponen un gran tratado comercial. Quien no esté en esa mesa se quedará fuera de los mercados.",
		"desc": "Negociar los aranceles que pagarán nuestras exportaciones en los tres mercados.",
		"term": ["Aranceles a nuestras exportaciones", 18.0, 0.0, "%"], "fx_min": {"economia": 2}, "fx_max": {"economia": 6, "empresarios": 5}, "deal_rel": 5, "treaty": "comercio"},
}

const BILLS := [
	{"t": "Ley de Protección de Datos Digitales", "fx": {"jovenes": 2, "empresarios": -1}},
	{"t": "Ley de Caza y Pesca", "fx": {"jubilados": 1, "ambiente": -2, "jovenes": -1}},
	{"t": "Ley de Horarios Comerciales", "fx": {"empresarios": 2, "trabajadores": -2}},
	{"t": "Ley del Deporte", "fx": {"jovenes": 1, "money": -40}},
	{"t": "Ley de Patrimonio Histórico", "fx": {"prestigio": 1, "money": -60}},
	{"t": "Ley de Seguridad Vial", "fx": {"seguridad": 1, "jovenes": -1}},
	{"t": "Ley de Cooperativas Agrarias", "fx": {"trabajadores": 1, "jubilados": 1}},
	{"t": "Ley de Startups", "fx": {"empresarios": 2, "jovenes": 1, "monthly": -30}},
	{"t": "Ley de Desconexión Digital", "fx": {"trabajadores": 2, "empresarios": -1}},
	{"t": "Ley de Envases y Plásticos", "fx": {"ambiente": 2, "empresarios": -1}},
	{"t": "Ley de Símbolos Nacionales", "fx": {"militares": 1, "jovenes": -1}},
	{"t": "Ley de Televisión Pública", "fx": {"estabilidad": 1, "jovenes": -1}},
	{"t": "Ley de Lenguas Regionales", "fx": {"party": {"CR": 5}, "militares": -1, "clase_media": -1}},
	{"t": "Ley de Aguas", "fx": {"ambiente": 1, "trabajadores": 1}},
	{"t": "Ley de Teletrabajo", "fx": {"jovenes": 2, "clase_media": 1, "empresarios": -1}},
	{"t": "Ley de Propiedad Horizontal", "fx": {"clase_media": 1}},
	{"t": "Ley del Cine y el Audiovisual", "fx": {"jovenes": 1, "money": -30}},
	{"t": "Ley de Montes y Bosques", "fx": {"ambiente": 2, "trabajadores": -1}},
]

const RIDERS := [
	{"t": "Disp. adicional 7ª: exención fiscal para los clubes de golf.", "fx": {"empresarios": 1, "clase_media": -2, "corr": 1}},
	{"t": "Disp. final 3ª: los diputados podrán jubilarse con pensión máxima a los 7 años.", "fx": {"clase_media": -3, "trabajadores": -2}},
	{"t": "Anexo II: se autoriza la construcción de un hotel en la playa protegida de Calablanca.", "fx": {"ambiente": -3, "empresarios": 1, "corr": 2}},
	{"t": "Disp. adicional 2ª: 200 M€ para un aeropuerto en Vallegrande, localidad de 4.000 habitantes.", "fx": {"money": -200, "corr": 1}},
	{"t": "Art. 31 bis: se reduce el plazo de prescripción de los delitos fiscales.", "fx": {"corr": 3, "empresarios": 1, "clase_media": -1}},
	{"t": "Disp. transitoria 1ª: las eléctricas quedan exentas de la tasa medioambiental.", "fx": {"ambiente": -2, "empresarios": 1}},
]

const LETTERS := [
	{"from": "Marisa, enfermera de Puerto Alba", "t": "Llevo tres años encadenando contratos de un mes. Somos las que sostuvimos el país en la pandemia. ¿Nadie se acuerda de nosotras?", "fx_yes": {"trabajadores": 1, "bienestar": 1, "money": -20}, "yes": "AYUDAR"},
	{"from": "Joaquín, pequeño empresario de Ferrosa", "t": "Tengo un taller con ocho empleados. Entre impuestos y papeleo, dedico más tiempo a la burocracia que a trabajar. Por favor, simplifiquen.", "fx_yes": {"empresarios": 1, "clase_media": 1, "pc": -2}, "yes": "RESPONDER"},
	{"from": "Clase de 4º B del colegio Miramar", "t": "Hemos estudiado la Constitución y queremos invitarle a nuestro colegio para hacerle preguntas. Prometemos portarnos bien. Casi todos.", "fx_yes": {"jovenes": 1, "clase_media": 1, "stress": -3}, "yes": "ACEPTAR"},
	{"from": "Asociación de vecinos de San Blas", "t": "Nuestro barrio lleva dos años esperando el autobús nocturno prometido. Las mujeres vuelven a casa andando por descampados.", "fx_yes": {"seguridad": 1, "trabajadores": 1, "money": -15}, "yes": "FINANCIAR"},
	{"from": "Rogelio, agricultor de Rioseco", "t": "La presa de Sarvenia nos ha dejado sin agua. Tengo 64 años y mi campo se muere. No sé a quién más escribir.", "fx_yes": {"jubilados": 1, "trabajadores": 1, "money": -25}, "yes": "AYUDAR"},
	{"from": "Nadia, estudiante de Medicina", "t": "Voy a terminar la carrera y todos mis compañeros se van a Norland. Allí cobran el triple. ¿Por qué deberíamos quedarnos?", "fx_yes": {"jovenes": 1, "pc": -2}, "yes": "RESPONDER"},
	{"from": "Don Evaristo, 91 años", "t": "Señor presidente: le escribo para decirle que lo está haciendo usted regular, pero que me cae simpático. Siga así, pero mejor.", "fx_yes": {"jubilados": 1, "stress": -4}, "yes": "RESPONDER"},
	{"from": "Protectora de animales Huellas", "t": "Necesitamos ayuda: acogemos a 300 perros abandonados y no llegamos a pagar el pienso de este mes.", "fx_yes": {"jovenes": 1, "money": -2}, "yes": "DONAR"},
]

const CRIMES := [
	{"c": "Robo con fuerza en una joyería", "y": 5, "note": "Tiene tres hijos y participa en un programa de reinserción.", "fx_yes": {"seguridad": -1, "clase_media": -1}, "fx_no": {}},
	{"c": "Tráfico de drogas a pequeña escala", "y": 4, "note": "Fue captado por una red criminal con 17 años.", "fx_yes": {"jovenes": 1, "seguridad": -1, "jubilados": -1}, "fx_no": {}},
	{"c": "Desórdenes públicos en una manifestación", "y": 2, "note": "El vídeo de la detención muestra una actuación policial desproporcionada.", "fx_yes": {"jovenes": 2, "seguridad": -1}, "fx_no": {"jovenes": -1}},
	{"c": "Malversación de fondos públicos como alcalde", "y": 6, "note": "Es militante de su partido y amigo personal del secretario de organización.", "fx_yes": {"clase_media": -3, "corr": 4}, "fx_no": {"clase_media": 1}},
	{"c": "Homicidio imprudente en accidente de tráfico", "y": 3, "note": "Conducía ebrio. La familia de la víctima se opone al indulto.", "fx_yes": {"clase_media": -2}, "fx_no": {"clase_media": 1}},
	{"c": "Fraude fiscal de 2 millones de euros", "y": 3, "note": "Ha devuelto el dinero íntegramente con intereses.", "fx_yes": {"empresarios": 1, "trabajadores": -1}, "fx_no": {}},
	{"c": "Ocupación de una vivienda de un banco", "y": 1, "note": "Madre soltera desahuciada con dos hijos pequeños.", "fx_yes": {"jovenes": 1, "trabajadores": 1, "clase_media": -1}, "fx_no": {"trabajadores": -1}},
]

const BID_NOTES := [
	{"t": "Empresa con 15 años de obra pública sin incidencias.", "fx": {}},
	{"t": "Su consejero delegado es el cuñado de un alto cargo del partido.", "fx": {"corr": 5, "clase_media": -1}},
	{"t": "Prevé 'modificados' del 45% sobre el precio de adjudicación.", "fx": {"money_pct": 0.45}},
	{"t": "Capital 100% de Tsaing. Trabajadores traídos de su país.", "fx": {"rel": {"tsaing": 4}, "trabajadores": -2}},
	{"t": "Sancionada dos veces por incumplir normativa laboral.", "fx": {"trabajadores": -2}},
	{"t": "Compromiso de contratar un 60% de mano de obra local.", "fx": {"trabajadores": 2}},
	{"t": "Donó 50.000 € a la fundación de su partido el año pasado.", "fx": {"corr": 3}},
	{"t": "Filial de Norland Dynamics con sede fiscal en Qadar.", "fx": {"rel": {"norland": 3}, "corr": 1}},
]


func _ready() -> void:
	for list in [E.EVENTS, E_TRAMAS.EVENTS, E_EXTRA.EVENTS, E_MEME.EVENTS, E_V3A.EVENTS, E_V3B.EVENTS]:
		for e in list:
			if events_by_id.has(e["id"]):
				push_warning("Evento duplicado: " + e["id"])
			events_by_id[e["id"]] = e
			all_events.append(e)
	world_map_info = _load_json("res://art/maps/world.json")
	region_info = _load_json("res://art/maps/valdoria.json")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(txt)
	if d is Dictionary:
		return d
	return {}


func event(id: String) -> Dictionary:
	return events_by_id.get(id, {})


func character(who: String) -> Dictionary:
	# Devuelve {name, role, look, country?}
	if GS.cast.has(who):
		return GS.cast[who]
	if who == "opo":
		if not GS.opo_override.is_empty():
			return GS.opo_override
		var opp: String = W.PLAYER_PARTIES[GS.pres["party"]]["opp"]
		var c: Dictionary = W.CHARACTERS.get("opo_" + opp, W.CHARACTERS["opo_AR"])
		return c
	if GS.ministers.has(who):
		return GS.ministers[who]
	if W.CHARACTERS.has(who):
		return W.CHARACTERS[who]
	if W.COUNTRIES.has(who):
		var c2: Dictionary = W.COUNTRIES[who]
		return {"name": c2["leader"], "role": "%s de %s" % [c2["title"], c2["name"]], "look": c2["look"], "country": who}
	return {"name": "Desconocido", "role": "", "look": {}}


func topic(who: String, topic_id: String) -> Dictionary:
	if W.TOPICS.has(who):
		for t in W.TOPICS[who]:
			if t["id"] == topic_id:
				return t
	if DOMESTIC.has(who) and DOMESTIC[who]["topics"].has(topic_id):
		return DOMESTIC[who]["topics"][topic_id]
	return {}


func counterpart(who: String) -> Dictionary:
	# Datos para negociar: personalidad, poder y relación (-100..100)
	if W.COUNTRIES.has(who):
		var c: Dictionary = W.COUNTRIES[who]
		return {"pers": GS.country_pers(who), "power": c["power"], "rel": GS.countries[who]["rel"], "country": who}
	if DOMESTIC.has(who):
		var d: Dictionary = DOMESTIC[who]
		var rel := 0.0
		match who:
			"sindicato":
				rel = (GS.fac["trabajadores"] - 50.0) * 1.2
			"patronal":
				rel = (GS.fac["empresarios"] - 50.0) * 1.2
			"islas":
				rel = (GS.parties["CR"]["rel"] - 50.0) * 1.5
			"opo":
				rel = (GS.parties[W.PLAYER_PARTIES[GS.pres["party"]]["opp"]]["rel"] - 50.0) * 1.5
		return {"pers": d["pers"], "power": d["power"], "rel": rel}
	return {"pers": "pragmatico", "power": 50.0, "rel": 0.0}


# ------------------------------------------------------------------ generadores

func rand_name(g: String = "") -> String:
	if g == "":
		g = "m" if randf() < 0.5 else "f"
	var first: String = W.NAMES_M.pick_random() if g == "m" else W.NAMES_F.pick_random()
	return "%s %s" % [first, W.SURNAMES.pick_random()]


func rand_look(g: String = "") -> Dictionary:
	if g == "":
		g = "m" if randf() < 0.5 else "f"
	var styles_m := ["short", "side", "slick", "bald", "balding", "buzz", "wavy", "curly"]
	var styles_f := ["bob", "long", "bun", "curly", "wavy", "ponytail"]
	var suits := ["1d2b4a", "2a2c30", "3a3d44", "15171b", "243653", "4a3b2a", "2e4a5a", "5a1f2a"]
	var ties := ["7a1f2b", "2d5a9e", "b08a3e", "1aa39a", "22262b", "8c1c1c", ""]
	var age := randi_range(0, 2)
	var hc := randi_range(0, 4)
	if age == 2 and randf() < 0.6:
		hc = randi_range(5, 6)
	var look := {"g": g, "skin": randi_range(0, 5), "hair": (styles_m if g == "m" else styles_f).pick_random(), "hc": hc,
		"glasses": randi_range(0, 2) if randf() < 0.35 else 0, "suit": suits.pick_random(), "shirt": ["f4f4f4", "e8eef5", "f3ece2"].pick_random(),
		"tie": ties.pick_random() if g == "m" else "", "age": age, "eyes": ["3b2a20", "2a1c14", "4d6a80", "5a4632", "3f5f3a"].pick_random()}
	if g == "m" and randf() < 0.35:
		look["beard"] = ["stubble", "mustache", "full", "goatee"].pick_random()
	return look


func gen_doc() -> Dictionary:
	var r := randf()
	if r < 0.34:
		return _gen_bill()
	elif r < 0.56:
		return _gen_contract()
	elif r < 0.76:
		return _gen_pardon()
	return _gen_letter()


func _meme() -> bool:
	return GS.mode == "meme" and randf() < 0.7


## Elige una pieza para un documento generado: lo de esta partida no se repite y lo de partidas recientes sale menos.
## Devuelve [pieza, id] (el id se anota en GS.used y pasa a la memoria entre partidas)
func _fresh(list: Array, prefix: String, key: String) -> Array:
	var pool := []
	var total := 0.0
	for it in list:
		var id := "tpl_%s_%d" % [prefix, absi(hash(str(it.get(key, ""))))]
		if GS.used.has(id):
			continue
		var w := Perfil.recent_factor(id)
		pool.append([it, id, w])
		total += w
	if pool.is_empty():
		var it2: Dictionary = list.pick_random()
		return [it2, "tpl_%s_%d" % [prefix, absi(hash(str(it2.get(key, ""))))]]
	var r := randf() * total
	for e in pool:
		r -= float(e[2])
		if r <= 0.0:
			GS.used[e[1]] = GS.day
			return [e[0], e[1]]
	GS.used[pool.back()[1]] = GS.day
	return [pool.back()[0], pool.back()[1]]


func _gen_bill() -> Dictionary:
	var pk := _fresh(E_MEME.BILLS if _meme() else BILLS + G.BILLS, "ley", "t")
	var b: Dictionary = pk[0]
	var fx: Dictionary = b["fx"].duplicate(true)
	var veto := {"estabilidad": -1}
	for k in fx.keys():
		if k in ["money", "monthly", "party"]:
			continue
		veto[k] = -int(round(float(fx[k]) * 0.5))
	var doc := {"id": pk[1], "type": "doc", "kind": "ley", "gen": true, "title": b["t"],
		"text": "Proyecto aprobado por el Congreso de los Diputados y remitido a la Presidencia para su sanción y promulgación. Entrará en vigor al día siguiente de su publicación en el Boletín Oficial.",
		"choices": [{"t": "Aprobar", "fx": fx}, {"t": "Vetar", "fx": veto}], "default": 0, "small": []}
	if randf() < 0.45:
		var rider: Dictionary = _fresh(E_MEME.RIDERS if _meme() else RIDERS + G.RIDERS, "anexo", "t")[0]
		doc["small"] = [rider["t"]]
		doc["choices"][0]["hidden"] = rider["fx"].duplicate(true)
	return doc


func _gen_contract() -> Dictionary:
	var pp := _fresh(W.PROJECTS + G.PROJECTS, "obra", "t")
	var p: Dictionary = pp[0]
	var reg: Dictionary = W.REGIONS[randi_range(1, 8)]
	var title: String = p["t"] % reg["name"] if "%s" in p["t"] else p["t"]
	var base: float = p["cost"]
	var companies: Array = W.COMPANIES.duplicate()
	companies.shuffle()
	var notes: Array = BID_NOTES + G.BID_NOTES
	notes.shuffle()
	var options := []
	var meter := "economia"
	match p["kind"]:
		"sanidad":
			meter = "bienestar"
		"ambiente":
			meter = "ambiente"
		"seguridad":
			meter = "seguridad"
		"educacion":
			meter = "bienestar"
	for i in 3:
		var q := randi_range(2, 5)
		var price := base * randf_range(0.7, 1.3) * (0.8 + q * 0.08)
		var note: Dictionary = notes[i]
		var fx := {"money": -round(price), meter: 1 + int(q >= 4) + int(q >= 5), "trabajadores": 1}
		for k in note["fx"].keys():
			if k == "money_pct":
				fx["money"] = -round(price * (1.0 + float(note["fx"][k])))
			elif k == "rel":
				fx["rel"] = note["fx"][k]
			else:
				fx[k] = fx.get(k, 0) + note["fx"][k]
		if q <= 2:
			fx[meter] = 0
			fx["clase_media"] = fx.get("clase_media", 0) - 1
		var stars := ""
		for s in 5:
			stars += "★" if s < q else "☆"
		options.append({"name": companies[i], "lines": ["Precio: %s" % UI.money(price), "Calidad técnica: %s" % stars, "Plazo: %d meses" % randi_range(14, 40)], "small": note["t"], "fx": fx})
	return {"id": pp[1], "type": "doc", "kind": "contrato", "gen": true, "title": title,
		"text": "Concurso público de adjudicación. Se han presentado tres ofertas que cumplen los requisitos técnicos. Selle la oferta ganadora.",
		"options": options}


func _gen_pardon() -> Dictionary:
	var pc := _fresh(E_MEME.CRIMES if _meme() else CRIMES + G.CRIMES, "indulto", "c")
	var c: Dictionary = pc[0]
	var g := "m" if randf() < 0.65 else "f"
	var nm := rand_name(g)
	var look := rand_look(g)
	return {"id": pc[1], "type": "doc", "kind": "indulto", "gen": true, "title": "Solicitud de indulto: %s" % nm,
		"text": "%s, condenado/a a %d años por: %s. Ha cumplido parte de la condena y solicita el indulto alegando arrepentimiento y arraigo familiar." % [nm, c["y"], c["c"].to_lower()],
		"prisoner": look, "small": [c["note"]],
		"choices": [{"t": "Conceder", "fx": c["fx_yes"].duplicate(true)}, {"t": "Denegar", "fx": c["fx_no"].duplicate(true)}], "default": 1}


func _gen_letter() -> Dictionary:
	var pl := _fresh(E_MEME.LETTERS if _meme() else LETTERS + G.LETTERS, "carta", "from")
	var l: Dictionary = pl[0]
	return {"id": pl[1], "type": "doc", "kind": "carta", "gen": true, "title": "Carta de %s" % l["from"],
		"text": l["t"], "stamps": [l["yes"], "ARCHIVAR"],
		"choices": [{"t": l["yes"].capitalize(), "fx": l["fx_yes"].duplicate(true)}, {"t": "Archivar", "fx": {}}], "default": 1}


## Ataques de la oposición para la sesión de control o el debate: primero lo que el presidente ha hecho
## (promesas rotas...), después el resto según cómo esté el país
func opposition_attacks(n: int) -> Array:
	var out := []
	var special: Array = Promesas.attacks()
	special.append_array(Memoria.attacks())
	special.shuffle()
	for a in special:
		if out.size() >= mini(2, n - 1):
			break
		# la misma promesa rota o el mismo recuerdo no vuelven a salir hasta pasado medio año
		var sk := "spatk_%s" % str(a.get("key", absi(hash(str(a.get("attack", ""))))))
		if GS.used.has(sk) and GS.day - int(GS.used[sk]) < SPECIAL_ATTACK_CD:
			continue
		GS.used[sk] = GS.day
		out.append(a)
	var pool := []
	for a in P.DEBATE + C.DEBATE:
		if GS.check(a.get("cond", {})):
			pool.append(a)
	for a in pick_fresh(pool, n - out.size(), "atk", "attack"):
		var a2: Dictionary = a.duplicate()
		a2["attack"] = GS.fmt(str(a["attack"]))
		out.append(a2)
	var i := 0
	while out.size() < n and not P.DEBATE.is_empty():
		out.append(P.DEBATE[i % P.DEBATE.size()])
		i += 1
	out.shuffle()
	return out


func press_questions(n: int, mode: String = "rueda") -> Array:
	var pool := []
	var src: Array = P.QUESTIONS + C.QUESTIONS
	if GS.mode == "meme":
		src.append_array(E_MEME.QUESTIONS)
		src.append_array(E_MEME.QUESTIONS)
	for q in src:
		if GS.check(q.get("cond", {})):
			pool.append(q)
	pool = pick_fresh(pool, n, "q", "q")
	var out := []
	# si hay promesas rotas o pendientes, algún periodista pregunta por ellas
	var pq := Promesas.press_question()
	if not pq.is_empty() and randf() < 0.6:
		out.append(pq)
	# la periodista incómoda recuerda lo que se le contestó (o el escándalo que destapó)
	if mode == "rueda":
		var mq := Memoria.press_question()
		if not mq.is_empty() and randf() < 0.75:
			out.append(mq)
	for q in pool:
		if out.size() >= n:
			break
		out.append(q)
	out.shuffle()
	return out


## Elige n cosas sin repetir: primero lo que no ha salido en esta partida, y lo de partidas recientes, menos.
## Lo elegido se anota en GS.used («prefijo_hash del texto») y pasa a la memoria entre partidas.
func pick_fresh(list: Array, n: int, prefix: String, key: String) -> Array:
	var pool := []
	for it in list:
		var id := "%s_%d" % [prefix, absi(hash(str(it.get(key, ""))))]
		var w := Perfil.recent_factor(id) * (0.02 if GS.used.has(id) else 1.0)
		pool.append([it, id, w])
	var out := []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for e in pool:
			total += float(e[2])
		var r := randf() * total
		var k := pool.size() - 1
		for i in pool.size():
			r -= float(pool[i][2])
			if r <= 0.0:
				k = i
				break
		out.append(pool[k][0])
		GS.used[pool[k][1]] = GS.day
		pool.remove_at(k)
	return out


## Una frase de la lista que no haya salido aún en esta partida; si ya salieron todas, la que lleve más tiempo
## sin salir. Así las réplicas y las reacciones no se repiten de una sesión de control a la siguiente.
func fresh_line(list: Array, prefix: String) -> String:
	if list.is_empty():
		return "..."
	var fresh := []
	var oldest := str(list[0])
	var oldest_day := 1 << 30
	for l in list:
		var id := "%s_%d" % [prefix, absi(hash(str(l)))]
		if not GS.used.has(id):
			fresh.append(str(l))
		elif int(GS.used[id]) < oldest_day:
			oldest_day = int(GS.used[id])
			oldest = str(l)
	var pick: String = str(fresh.pick_random()) if not fresh.is_empty() else oldest
	GS.used["%s_%d" % [prefix, absi(hash(pick))]] = GS.day
	return pick


## Réplicas del presidente y reacciones de la oposición en la sesión de control y el debate
func debate_lines(id: String) -> Array:
	return (P.DEBATE_LINES.get(id, ["..."]) as Array) + (C.DEBATE_LINES.get(id, []) as Array)


func opp_reactions(kind: String) -> Array:
	return (P.OPP_REACTIONS.get(kind, ["..."]) as Array) + (C.OPP_REACTIONS.get(kind, []) as Array)


## Frases para una sección del discurso: primero las que no ha usado en esta partida
func speech_pool(sec: String) -> Array:
	var all: Array = (P.SPEECH.get(sec, []) as Array) + (C.SPEECH.get(sec, []) as Array)
	var fresh := []
	var used := []
	for ph in all:
		(used if GS.used.has("sp_%d" % absi(hash(str(ph["t"])))) else fresh).append(ph)
	fresh.shuffle()
	used.shuffle()
	return fresh + used


func mark_speech(ph: Dictionary) -> void:
	GS.used["sp_%d" % absi(hash(str(ph.get("t", ""))))] = GS.day


## Una pregunta normal de la prensa (sin recuerdos ni promesas)
func plain_question() -> Dictionary:
	var pool := []
	for q in P.QUESTIONS + C.QUESTIONS:
		if GS.check(q.get("cond", {})):
			pool.append(q)
	var pk := pick_fresh(pool, 1, "q", "q")
	return pk[0] if not pk.is_empty() else P.QUESTIONS[0]
