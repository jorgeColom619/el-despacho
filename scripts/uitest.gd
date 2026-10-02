extends Node
## Prueba de humo de la interfaz: abre cada pantalla, simula interacciones y la cierra.
## Uso: godot --headless --path . -- --uitest

var main: Node


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _open(kind: String, data: Dictionary = {}) -> Node:
	main.open_overlay(kind, data)
	await _wait(0.4)
	return main.current_overlay


func _close_current() -> void:
	if main.current_overlay != null:
		main.current_overlay.close()
	await _wait(0.4)


func run(m: Node) -> void:
	main = m
	for party in ["MP", "AR", "CC"]:
		GS.new_game({"name": "Prueba", "party": party, "difficulty": 1, "years": 1, "look": {}})
		GS.no_save = true
		main._show_office()
		GS.set_speed(0)
		await _wait(0.3)
		print("== partido ", party)
		await _suite()
	print("UITEST COMPLETADO")
	get_tree().quit()


func _suite() -> void:
	# documentos de todos los tipos
	for id in ["doc_honor", "doc_indulto_banquero", "doc_operacion_halcon", "doc_carta_nina", "doc_contrato_cazas", "doc_nombramiento_bc"]:
		GS.spawn(DB.event(id))
	for i in 4:
		GS.spawn(DB.gen_doc())
	var o = await _open("doc")
	var n := 0
	while o != null and is_instance_valid(o) and not o.closing and GS.inbox.size() > 0 and n < 12:
		n += 1
		o._set_lens(true)
		o._on_revealed()
		var st = o.stamps[0]
		var target = 0
		if o.ev.has("options"):
			target = o.zones[0]
		o._commit(st, target, o.paper.global_position + Vector2(300, 300))
		await _wait(1.6)
	print("OK documentos (%d sellados)" % n)
	await _close_current()
	# asesor
	GS.spawn(DB.event("banco_quiebra"))
	o = await _open("advisor", {"item": GS.visitors[0]})
	await _wait(0.5)
	o.tw.skip()
	await _wait(0.2)
	o._decide(0, false)
	await _wait(2.4)
	print("OK asesor")
	await _close_current()
	# llamada
	GS.spawn(DB.event("call_emir"))
	o = await _open("call", {"item": GS.calls[0]})
	o._dialog_choice(0)
	await _wait(2.8)
	print("OK llamada")
	await _close_current()
	await _wait(0.6)
	await _close_current()
	# negociaciones: país y doméstica
	for spec in [["norland", "comercio"], ["kharovia", "gas"], ["sindicato", "salarios"], ["opo", "pacto"]]:
		o = await _open("nego", {"who": spec[0], "topic": spec[1]})
		for t in ["argumentar", "halagar", "presionar", "argumentar"]:
			if o.ended:
				break
			o.busy = false
			o._tactic(t)
			await _wait(1.6)
		if not o.ended:
			o.busy = false
			o._tactic("cerrar")
			await _wait(1.6)
		if not o.ended:
			o._end(true, "Trato hecho.")
		await _wait(0.3)
		print("OK negociación ", spec)
		await _close_current()
	# crisis de varios tipos
	for cid in ["incendios", "terrorismo", "migrantes"]:
		GS.spawn({"id": "t_" + cid, "type": "crisis", "crisis": cid, "title": cid, "text": "", "gen": true})
		o = await _open("crisis", {"item": GS.alerts[0], "autostart": true})
		await _wait(2.0)
		o._use_special("emergencia")
		o._use_special("ayuda")
		o._deploy(0, 1)
		await _wait(1.0)
		o._finish(o._score(), false)
		await _wait(0.4)
		print("OK crisis ", cid, " score ", o._score())
		await _close_current()
	# Congreso: ley, presupuesto y moción
	o = await _open("dashboard", {})
	for tab in ["resumen", "sociedad", "leyes", "congreso", "agenda", "gabinete"]:
		o._show(tab)
		await _wait(0.2)
	GS.pc = 100
	o._propose("vivienda")
	await _wait(1.0)
	o = main.current_overlay
	o._lobby("CC", "enmienda")
	o._lobby("CR", "inversion")
	o._start_vote()
	await _wait(7.0)
	print("OK votación de ley · leyes en vigor: ", GS.policies)
	await _close_current()
	o = await _open("budget", {})
	o.sliders["sanidad"].value = 1.2
	o.sliders["renta"].value = 24.0
	o._to_congress()
	await _wait(1.0)
	o = main.current_overlay
	o._start_vote()
	await _wait(7.0)
	print("OK presupuestos")
	await _close_current()
	o = await _open("vote", {"mode": "mocion"})
	o._start_vote()
	await _wait(7.0)
	print("OK moción (fin de partida: %s)" % GS.game_ended)
	if GS.game_ended:
		GS.game_ended = false
		GS.active = true
		main._show_office()
		await _wait(0.5)
	await _close_current()
	# mundo
	o = await _open("world", {})
	for c in GS.countries.keys():
		o._select(c)
		await _wait(0.05)
	o._action("aldora", "ayuda")
	o._action("kharovia", "sanciones")
	print("OK mundo")
	await _close_current()
	# prensa, discurso, debate
	o = await _open("press", {"mode": "rueda"})
	o.intro_panel.queue_free()
	o._next()
	await _wait(0.3)
	o.q_text.skip()
	await _wait(0.3)
	if o.answers.get_child_count() > 0:
		o._answer(o.questions[0]["a"][0])
	await _wait(2.2)
	o._finish()
	print("OK prensa")
	await _close_current()
	o = await _open("speech", {"occasion": "campana"})
	for i in 4:
		var cards: Array = o.choice_box.get_children()
		if cards.size() > 0:
			o._choose(cards[0].get_meta("phrase"), true)
		await _wait(0.2)
		for k in 30:
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.pressed = true
			o._unhandled_input(ev)
			await _wait(0.1)
		await _wait(3.0)
	print("OK discurso")
	await _close_current()
	o = await _open("debate", {"electoral": false})
	await _wait(1.5)
	for r in 4:
		o.bubble_opp.skip()
		await _wait(0.3)
		o._reply(DB.P.DEBATE_REPLIES[r])
		await _wait(0.3)
		o.bubble_me.skip()
		await _wait(3.0)
	print("OK debate")
	await _close_current()
	for k in ["cabinet", "phonebook", "tv", "pause", "newspaper"]:
		o = await _open(k, {})
		print("OK ", k)
		await _close_current()
	o = await _open("election", {})
	await _wait(12.0)
	print("OK elecciones: ", GS.elections_result.get("won", false))
	await _close_current()
	GS.game_ended = false
	GS.active = true
