extends Node
## Prueba de la charla del móvil: godot --headless --path . -- --charlatest [--pais=qadar]
## Escribe frases típicas a varias personas y enseña qué contestan. Comprueba también que los mensajes de una
## misma persona van a una sola conversación (antes salían tres chats de «Mamá») y que una partida antigua con
## varias conversaciones de la misma persona se junta en una.

const Redes := preload("res://scripts/systems/redes.gd")

const CASES := [
	["madre", ["Hola mamá, ¿qué tal estás?", "Estoy agotado, no puedo más", "¿Qué opinas de la economía?", "Te quiero mucho", "¿Cuándo voy a comer?",
		"El domingo voy a comer y haces croquetas", "Qué pesada eres, déjame en paz idiota", "¿Me aconsejas algo?", "jajaja", "adiós, un beso"]],
	["economia", ["Buenos días, ¿cómo va el paro?", "¿Qué opina de los impuestos?", "Necesito un consejo", "Eres un inútil", "Gracias por todo"]],
	["exteriores", ["¿Cómo están las relaciones con Kharovia?", "¿Qué opinas de Norland?"]],
	["opo", ["Hola, ¿pactamos los presupuestos? Necesito sus votos", "Es usted un payaso", "Le propongo un acuerdo a cambio de inversiones en su región"]],
	["periodista_inc", ["Off the record: el Gobierno prepara cambios", "Sin comentarios", "Le paso un sobre si no publica nada"]],
	["kharovia", ["Buenas, presidente Drogan. Quiero hablar del precio del gas", "Es usted un tirano", "Gracias por su amabilidad, es un placer"]],
	["comunicacion", ["¿Cómo van las redes?", "¿Qué publicamos hoy?", "Estoy harto de los memes"]],
]

## Mensajes con respuestas preparadas y lo que contesta el presidente con sus palabras
const PEND := [
	["madre_domingo", ["Claro que sí mamá, allí estaré, haz croquetas", "No puedo, tengo una cumbre, lo siento", "¿Qué tiempo hace por ahí?", "ya veremos"]],
	["madre_comer", ["Sí, he comido un bocadillo", "Mamá, estoy reunido con el ministro"]],
	["eco_mercados", ["Sí, mande un mensaje de calma a los mercados", "No, mejor no decir nada"]],
]


func run() -> void:
	var pais := "valdoria"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pais="):
			pais = a.substr(7)
	GS.new_game({"name": "Test", "party": "MP", "difficulty": 1, "years": 2, "mode": "clasico", "look": {}, "pais": pais})
	if not Redes.on():
		Redes.start(GS.rng)
	var fallos := 0
	for c in CASES:
		var who: String = c[0]
		if not GS.cast.has(who) and who == "periodista_inc":
			GS.cast[who] = {"name": "Lucía Ferrer", "role": "Periodista", "look": {}}
		var t := Redes.hilo(who)
		print("\n== %s (%s)" % [t["name"], t["role"]])
		for phrase in c[1]:
			var r := Redes.escribir(t, phrase)
			print("   P: %s\n   R: %s%s" % [phrase, r.get("t", "(nada)"), ("   [efectos: %s]" % str(r["out"])) if not (r.get("out", []) as Array).is_empty() else ""])
			if String(r.get("t", "")) == "" or "{" in String(r.get("t", "")):
				fallos += 1
				print("   ^^^ FALLO: respuesta vacía o con huecos sin rellenar")
	print("\n== Mensajes con respuestas preparadas, contestados con palabras propias")
	for pc in PEND:
		for phrase in pc[1]:
			Redes._send_chat(Redes.chat_def(pc[0]))
			var t2 := Redes.hilo(String(Redes.chat_def(pc[0])["who"]))
			var pregunta := String(t2["pregunta"])
			var r2 := Redes.escribir(t2, phrase)
			print("   %s: «%s»\n   P: %s\n   R: %s  (elige la respuesta %d · estado: %s)" % [pc[0], pregunta, phrase, r2.get("t", ""), int(r2.get("idx", -1)), t2["state"]])
	# una conversación por persona
	var n_madre := 0
	for ch in GS.social["chats"]:
		if String(ch["who"]) == "madre":
			n_madre += 1
	print("\nConversaciones con la madre: %d (debe ser 1)" % n_madre)
	if n_madre != 1:
		fallos += 1
	# partida antigua: tres conversaciones de la madre se juntan en una
	GS.social["chats"] = [
		{"id": "madre_tia", "who": "madre", "name": "Mamá", "role": "Su madre", "msgs": [{"me": false, "t": "Tu tía Puri...", "day": 40}], "state": "visto", "deadline": 46, "day": 40},
		{"id": "jefa_agenda", "who": "jefa", "name": "Jefa", "role": "Jefa de Gabinete", "msgs": [{"me": false, "t": "Agenda...", "day": 30}], "state": "respondido", "deadline": 36, "day": 30},
		{"id": "madre_comer", "who": "madre", "name": "Mamá", "role": "Su madre", "msgs": [{"me": false, "t": "¿Has comido?", "day": 60}], "state": "nuevo", "deadline": 66, "day": 60},
		{"id": "madre_domingo", "who": "madre", "name": "Mamá", "role": "Su madre", "msgs": [{"me": false, "t": "¿Vienes el domingo?", "day": 10}, {"me": true, "t": "Allí estaré", "day": 10}], "state": "respondido", "deadline": 16, "day": 10}]
	GS.social.erase("hilos")
	Redes.unread()
	var antes: Array = GS.social["chats"]
	var madre := Redes.hilo("madre", false)
	print("Partida antigua: %d conversaciones tras juntarlas (deben ser 2); la de la madre tiene %d mensajes (deben ser 4), estado %s, pendiente %s" % [antes.size(), (madre["msgs"] as Array).size(), madre["state"], madre["id"]])
	if antes.size() != 2 or (madre["msgs"] as Array).size() != 4 or madre["state"] != "nuevo" or madre["id"] != "madre_comer":
		fallos += 1
	print("\nCHARLA: %s (%d fallos)" % ["OK" if fallos == 0 else "FALLOS", fallos])
	get_tree().quit()
