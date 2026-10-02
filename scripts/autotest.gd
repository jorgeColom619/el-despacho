extends Node
## Simulación automática sin interfaz para detectar errores y equilibrar la partida.
## Uso: godot --headless --path . -- --autotest=730

const W := preload("res://scripts/data/world_data.gd")

var strategy := "random"
var events_seen := {}


func run(days: int) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--strategy="):
			strategy = a.substr(11)
	GS.new_game({"name": "Test", "party": "MP", "difficulty": 1, "years": int(ceil(days / 365.0)), "look": {}})
	GS.set_speed(0)
	GS.open_request.connect(_on_req)
	GS.game_over.connect(func(d): print(">>> FIN: ", d["reason"], " día ", GS.day))
	var t0 := Time.get_ticks_msec()
	for d in days + 5:
		if GS.game_ended or not GS.active:
			break
		GS.advance_day()
		_resolve_all()
		if GS.day == 200:
			var before := GS.approval
			GS.save_game()
			var ok := GS.load_game()
			GS.set_speed(0)
			print(">>> guardar/cargar: ", ok, " aprob antes ", before, " después ", GS.approval, " día ", GS.day, " leyes ", GS.policies.size())
		if GS.day % 60 == 0:
			_report()
	_report()
	print("Eventos distintos vistos: %d" % events_seen.size())
	print("Leyes: ", GS.policies, "  Tratados: ", GS.treaties.size())
	print("Tiempo: %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


func _report() -> void:
	var f := ""
	for k in GS.FACTIONS:
		f += "%s:%d " % [k.left(4), int(GS.fac[k])]
	var m := ""
	for k in GS.METERS:
		m += "%s:%d " % [k.left(4), int(GS.meters[k])]
	print("Día %4d | aprob %4.1f | deuda %5.1f%% | saldo %7.0f | CP %3d | %s| %s" % [GS.day, GS.approval, GS.debt_ratio(), GS.monthly_balance(), int(GS.pc), m, f])


func _pick(n: int, choices: Array) -> int:
	if strategy == "smart" or strategy == "worst":
		var best := 0
		var bs := -9999.0
		for i in choices.size():
			var s := 0.0
			var fx: Dictionary = choices[i].get("fx", {})
			for k in fx.keys():
				var v = fx[k]
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					if GS.fac.has(k):
						s += float(v) * (W.FACTION_INFO[k]["w"] * 4.0 + 0.2)
					elif GS.meters.has(k):
						s += float(v) * 0.6
					elif k == "money":
						s += float(v) / 700.0
			if strategy == "worst":
				s = -s
			if s > bs:
				bs = s
				best = i
		return best
	return randi() % n


func _resolve_all() -> void:
	var guard := 0
	while GS.inbox.size() > 0 and guard < 20:
		guard += 1
		var it: Dictionary = GS.inbox[0]
		events_seen[it["ev"].get("id", "")] = true
		if it["ev"].has("options"):
			GS.resolve_option(it, it["ev"]["options"].pick_random())
		else:
			GS.resolve_choice(it, _pick(it["ev"]["choices"].size(), it["ev"]["choices"]))
	while GS.visitors.size() > 0 and guard < 40:
		guard += 1
		var it2: Dictionary = GS.visitors[0]
		events_seen[it2["ev"].get("id", "")] = true
		GS.resolve_choice(it2, _pick(it2["ev"]["choices"].size(), it2["ev"]["choices"]))
	while GS.calls.size() > 0 and guard < 60:
		guard += 1
		var it3: Dictionary = GS.calls[0]
		events_seen[it3["ev"].get("id", "")] = true
		GS.resolve_choice(it3, _pick(it3["ev"]["choices"].size(), it3["ev"]["choices"]))
	while GS.alerts.size() > 0 and guard < 80:
		guard += 1
		var it4: Dictionary = GS.alerts[0]
		events_seen[it4["ev"].get("id", "")] = true
		GS.resolve_crisis(it4, randf_range(0.35, 0.85), {}, 300.0)
		if GS.game_ended:
			return


func _on_req(kind: String, data: Dictionary) -> void:
	match kind:
		"nego":
			var t := DB.topic(data.get("who", ""), data.get("topic", ""))
			if not t.is_empty():
				GS.apply_fx(t.get("fx_min", {}), "nego", false)
		"election":
			var r := GS.compute_election()
			print(">>> ELECCIONES: ganado=", r["won"], " escaños propios=", r["own_seats"], " aliados=", r["allies"], " reparto=", r["seats"])
		"vote":
			print(">>> MOCIÓN DE CENSURA el día ", GS.day)
		"speech":
			GS.apply_fx({"approval": 2.0}, "speech", false)
			GS.speech_until = GS.day + 45
