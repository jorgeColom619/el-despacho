extends Node
## Simulación automática sin interfaz para detectar errores y equilibrar la partida.
## Uso: godot --headless --path . -- --autotest=730 [--strategy=random|smart|worst|casual|player]
##      [--difficulty=0|1|2] [--mode=clasico|infinito|meme] [--runs=N]
## Estrategias:
##   random  · elige al azar y no usa leyes ni discursos
##   smart   · elige la mejor opción para su electorado, pero no usa leyes
##   worst   · elige siempre lo peor
##   casual  · elige al azar, pero aprueba alguna ley y da discursos (jugador medio)
##   player  · decide bien casi siempre, aprueba leyes afines, da discursos y hace campaña
## Variedad: godot --headless --path . -- --autotest=270 --variety=30
##   simula 30 partidas seguidas (con memoria entre partidas) y mide cuánto se parecen entre sí

const W := preload("res://scripts/data/world_data.gd")
const Promesas := preload("res://scripts/systems/promesas.gd")

var strategy := "random"
var save_day := 200
var difficulty := 1
var mode := "clasico"
var quiet := false
var events_seen := {}
var _first_ids := []
var _next_law_day := 0
var _result := {}


func run(days: int) -> void:
	var runs := 1
	var variety := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variety="):
			variety = int(a.substr(10))
		if a.begins_with("--strategy="):
			strategy = a.substr(11)
		elif a.begins_with("--difficulty="):
			difficulty = int(a.substr(13))
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--saveday="):
			save_day = int(a.substr(10))
		elif a.begins_with("--runs="):
			runs = int(a.substr(7))
	quiet = runs > 1
	GS.open_request.connect(_on_req)
	GS.game_over.connect(func(d):
		_result["end"] = d["reason"]
		_result["end_day"] = GS.day
		if not quiet:
			print(">>> FIN: ", d["reason"], " día ", GS.day))
	var t0 := Time.get_ticks_msec()
	if variety > 0:
		_variety(variety, days)
		print("Tiempo: %d ms" % (Time.get_ticks_msec() - t0))
		get_tree().quit()
		return
	var summary := []
	for r in runs:
		summary.append(_play(days))
	if runs > 1:
		_print_summary(summary)
	print("Tiempo: %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


func _play(days: int) -> Dictionary:
	_result = {"end": "", "end_day": 0, "won": false, "terms": 0, "approval_min": 100.0}
	_next_law_day = 0
	events_seen.clear()
	_first_ids.clear()
	var party: String = W.PLAYER_PARTIES.keys().pick_random() if quiet else "MP"
	# los jugadores medios y buenos hacen tres promesas de las seis que se ofrecen
	var prom := []
	if strategy in ["casual", "player"] and not ("--nopromises" in OS.get_cmdline_user_args()):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		prom = Promesas.offer(rng, party, mode)
		prom.shuffle()
		prom = prom.slice(0, 3)
	GS.new_game({"name": "Test", "party": party, "difficulty": difficulty, "years": int(ceil(days / 365.0)), "mode": mode, "look": {}, "promises": prom})
	GS.set_speed(0)
	for d in days + 5:
		if GS.game_ended or not GS.active:
			break
		GS.advance_day()
		_resolve_all()
		_act()
		_result["approval_min"] = minf(_result["approval_min"], GS.approval)
		if GS.day == save_day and not quiet:
			var before := GS.approval
			GS.save_path = "user://autotest_partida.json"
			GS.no_save = false
			GS.save_game()
			var ok := GS.load_game()
			GS.no_save = true
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GS.save_path))
			GS.save_path = GS.SAVE_PATH
			GS.set_speed(0)
			print(">>> guardar/cargar: ", ok, " aprob antes ", before, " después ", GS.approval, " día ", GS.day, " leyes ", GS.policies.size(), " legislatura ", GS.term_index, " modo ", GS.mode)
		if GS.day % 60 == 0 and not quiet:
			_report()
	if not quiet:
		_report()
		print("Eventos distintos vistos: %d" % events_seen.size())
		print("Leyes: ", GS.policies, "  Tratados: ", GS.treaties.size(), "  Corrupción: ", snappedf(GS.corruption, 0.1))
		print("Recuerdos con decisión: %d · hechos anotados: %d" % [int(_result.get("memo", 0)), GS.memo.size()])
	_result["approval"] = GS.approval
	_result["debt"] = GS.debt_ratio()
	_result["laws"] = GS.policies.size()
	_result["events"] = events_seen.size()
	_result["corr"] = GS.corruption
	var ps := Promesas.score()
	_result["prom_ok"] = ps[0]
	_result["prom_n"] = ps[1]
	_result["memo"] = int(_result.get("memo", 0))
	_result["fac"] = GS.fac.duplicate()
	return _result


## Juega varias partidas seguidas y mide cuántos eventos se repiten entre una partida y la siguiente
func _variety(n: int, days: int) -> void:
	quiet = true
	var sets := []
	var firsts := {}
	var scen := {}
	var tram := {}
	for i in n:
		_play(days)
		sets.append(events_seen.duplicate())
		var first3: Array = _first_ids.slice(0, 3)
		firsts[str(first3)] = true
		scen[GS.scenario] = scen.get(GS.scenario, 0) + 1
		for t in GS.tramas:
			tram[t] = tram.get(t, 0) + 1
	var consec := 0.0
	var anyp := 0.0
	var pairs := 0
	for i in n:
		for j in range(i + 1, n):
			var sh := _shared(sets[i], sets[j])
			anyp += sh
			pairs += 1
			if j == i + 1:
				consec += sh
	var freq := {}
	for st in sets:
		for k in st.keys():
			freq[k] = freq.get(k, 0) + 1
	var always := 0
	var always_ids := []
	for k in freq.keys():
		if float(freq[k]) / n >= 0.9:
			always += 1
			always_ids.append(k)
	var avg := 0.0
	for st in sets:
		avg += st.size()
	print("== Variedad · %d partidas de %d días" % [n, days])
	print("   Eventos distintos por partida: %.1f · distintos en total: %d" % [avg / n, freq.size()])
	print("   Coincidencia entre partidas seguidas: %d%% · entre dos partidas cualesquiera: %d%%" % [int(consec / maxf(1.0, n - 1) * 100.0), int(anyp / maxf(1.0, pairs) * 100.0)])
	print("   Eventos que salen en casi todas (>=90%%): %d · comienzos distintos (3 primeros eventos): %d" % [always, firsts.size()])
	print("   Siempre: ", always_ids)
	print("   Escenarios: ", scen)
	print("   Tramas: ", tram)


func _shared(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty():
		return 0.0
	var c := 0
	for k in a.keys():
		if b.has(k):
			c += 1
	return float(c) / a.size()


func _print_summary(rs: Array) -> void:
	var n := float(rs.size())
	var won := 0
	var ends := {}
	var sums := {"approval": 0.0, "approval_min": 0.0, "debt": 0.0, "laws": 0.0, "terms": 0.0, "corr": 0.0, "events": 0.0, "prom_ok": 0.0, "prom_n": 0.0, "memo": 0.0}
	var fac := {}
	for r in rs:
		if r["won"]:
			won += 1
		var e: String = r["end"] if r["end"] != "" else "sin_final"
		ends[e] = ends.get(e, 0) + 1
		for k in sums.keys():
			sums[k] += float(r[k])
		for k in r["fac"].keys():
			fac[k] = fac.get(k, 0.0) + r["fac"][k]
	var f := ""
	for k in fac.keys():
		f += "%s:%d " % [k.left(4), int(fac[k] / n)]
	print("== %s · dificultad %d · modo %s · %d partidas" % [strategy, difficulty, mode, rs.size()])
	print("   Victorias: %d%% · aprobación final %.1f (mínima %.1f) · deuda %.0f%% · leyes %.1f · corrupción %.1f · legislaturas ganadas %.1f · eventos %.0f" % [int(won * 100.0 / n), sums["approval"] / n, sums["approval_min"] / n, sums["debt"] / n, sums["laws"] / n, sums["corr"] / n, sums["terms"] / n, sums["events"] / n])
	print("   Finales: ", ends)
	print("   Recuerdos con decisión por partida: %.1f" % (sums["memo"] / n))
	if sums["prom_n"] > 0.0:
		print("   Promesas cumplidas: %.1f de %.1f por partida" % [sums["prom_ok"] / n, sums["prom_n"] / n])
	print("   Grupos: ", f)


func _report() -> void:
	var f := ""
	for k in GS.FACTIONS:
		f += "%s:%d " % [k.left(4), int(GS.fac[k])]
	var m := ""
	for k in GS.METERS:
		m += "%s:%d " % [k.left(4), int(GS.meters[k])]
	print("Día %4d | aprob %4.1f | deuda %5.1f%% | saldo %7.0f | CP %3d | %s| %s" % [GS.day, GS.approval, GS.debt_ratio(), GS.monthly_balance(), int(GS.pc), m, f])


## Valor de unos efectos para el electorado: lo que valoraría un jugador sensato
func _score_fx(fx: Dictionary) -> float:
	var s := 0.0
	for k in fx.keys():
		var v = fx[k]
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			if GS.fac.has(k):
				s += float(v) * (W.FACTION_INFO[k]["w"] * 4.0 + 0.2)
			elif GS.meters.has(k):
				s += float(v) * 0.6
			elif k == "money":
				s += float(v) / 700.0
			elif k == "monthly":
				s += float(v) / 60.0
			elif k == "corr" and strategy == "player":
				s -= float(v) * 0.5
			elif k == "approval":
				s += float(v) * 1.5
		elif k == "risk" and v is Dictionary:
			s += _score_fx(v.get("fx", {})) * float(v.get("p", 0.5))
	if fx.has("else") and fx["else"] is Dictionary and fx.has("risk"):
		s += _score_fx(fx["else"].get("fx", {})) * (1.0 - float(fx["risk"].get("p", 0.5)))
	return s


func _pick(n: int, choices: Array) -> int:
	var smartish := strategy in ["smart", "worst", "player"]
	if strategy == "player" and randf() < 0.15:
		smartish = false
	if not smartish:
		return randi() % n
	var best := 0
	var bs := -9999.0
	for i in choices.size():
		var c: Dictionary = choices[i]
		var s := _score_fx(c.get("fx", {}))
		if c.has("hidden") and strategy == "player" and randf() < 0.5:
			s += _score_fx(c["hidden"])
		if strategy == "worst":
			s = -s
		if s > bs:
			bs = s
			best = i
	return best


func _seen(ev: Dictionary) -> void:
	if ev.get("memo", false):
		_result["memo"] = int(_result.get("memo", 0)) + 1
	if ev.get("gen", false):
		return
	var id: String = ev.get("id", "")
	if not events_seen.has(id):
		_first_ids.append(id)
	events_seen[id] = true


func _resolve_all() -> void:
	var guard := 0
	while GS.inbox.size() > 0 and guard < 20:
		guard += 1
		var it: Dictionary = GS.inbox[0]
		_seen(it["ev"])
		if it["ev"].has("options"):
			var opts: Array = it["ev"]["options"]
			GS.resolve_option(it, opts[_pick(opts.size(), opts)])
		else:
			GS.resolve_choice(it, _pick(it["ev"]["choices"].size(), it["ev"]["choices"]))
	while GS.visitors.size() > 0 and guard < 40:
		guard += 1
		var it2: Dictionary = GS.visitors[0]
		_seen(it2["ev"])
		GS.resolve_choice(it2, _pick(it2["ev"]["choices"].size(), it2["ev"]["choices"]))
	while GS.calls.size() > 0 and guard < 60:
		guard += 1
		var it3: Dictionary = GS.calls[0]
		_seen(it3["ev"])
		GS.resolve_choice(it3, _pick(it3["ev"]["choices"].size(), it3["ev"]["choices"]))
	while GS.alerts.size() > 0 and guard < 80:
		guard += 1
		var it4: Dictionary = GS.alerts[0]
		_seen(it4["ev"])
		var skill := randf_range(0.35, 0.85)
		if strategy == "player":
			skill = randf_range(0.5, 0.95)
		elif strategy == "worst":
			skill = randf_range(0.2, 0.5)
		GS.resolve_crisis(it4, skill, {}, 300.0)
		if GS.game_ended:
			return


## Iniciativa propia del jugador: discursos, reuniones, leyes y campaña
func _act() -> void:
	if not GS.active or GS.game_ended or not (strategy in ["player", "casual"]):
		return
	if GS.campaign:
		# Actos de campaña: mitin (discurso regional) o visita
		while GS.campaign_acts > 0:
			GS.use_campaign_act(1)
			var q0 := randf_range(0.8, 1.15) if strategy == "player" else randf_range(0.6, 1.0)
			if randf() < 0.6:
				GS.add_region_boost(randi_range(1, 8), 1.5 + q0 * 3.5)
				GS.campaign_bonus += q0 * 0.6
			else:
				GS.add_region_boost(randi_range(1, 8), 2.5)
		return
	if GS.day >= GS.speech_until and GS.day > 20 and GS.is_unlocked("discurso"):
		var q := randf_range(0.8, 1.15) if strategy == "player" else randf_range(0.6, 1.0)
		var fx := {"approval": snappedf((q - 0.75) * 8.0, 0.1)}
		fx[["trabajadores", "clase_media", "jovenes", "jubilados"].pick_random()] = 2.0 * q
		GS.apply_fx(fx, "Discurso", false)
		GS.speech_until = GS.day + 45
	if strategy == "player" and GS.day % 30 == 15 and GS.pc >= 20:
		var own: String = GS.pres["party"]
		var best := ""
		var bd := 999.0
		for p in GS.parties.keys():
			var dist := absf(W.PARTIES[p]["ideo"] - W.PARTIES[own]["ideo"])
			if p != own and dist < bd and GS.parties[p]["rel"] < 70.0:
				bd = dist
				best = p
		if best != "":
			GS.pc -= 6
			GS.apply_fx({"party": {best: 7.0}}, "Reunión", false)
	_try_law()


func _try_law() -> void:
	if GS.day < _next_law_day or GS.day < 25 or not GS.is_unlocked("leyes"):
		return
	var best_law := ""
	var best_s := 0.5
	for id in W.LAWS.keys():
		var law: Dictionary = W.LAWS[id]
		if not GS.law_available(id) or law.get("super", false) or GS.pc < float(GS.law_cost(id)) + 4.0:
			continue
		var s := _score_fx(law.get("mods", {})) + _score_fx(law.get("fx", {})) * 0.5 + float(law.get("monthly", 0.0)) / 80.0
		if strategy == "casual":
			s = randf_range(-1.0, 3.0)
		var fc := GS.vote_forecast(law, {})
		var exp_yes := 0.0
		for p in fc.keys():
			exp_yes += float(GS.parties[p]["seats"]) * fc[p]
		if exp_yes >= 168.0 and s > best_s:
			best_s = s
			best_law = id
	if best_law == "":
		_next_law_day = GS.day + 10
		return
	var law2: Dictionary = W.LAWS[best_law]
	GS.pc -= float(GS.law_cost(best_law))
	var fc2 := GS.vote_forecast(law2, {})
	var yes := 0
	for p in fc2.keys():
		for s2 in int(GS.parties[p]["seats"]):
			if randf() < fc2[p]:
				yes += 1
	if yes >= 176:
		GS.enact_law(best_law)
	else:
		GS.law_rejected(best_law)
	_next_law_day = GS.day + (50 if strategy == "player" else 110)


func _on_req(kind: String, data: Dictionary) -> void:
	match kind:
		"nego", "summit":
			var t := DB.topic(data.get("who", ""), data.get("topic", ""))
			if not t.is_empty():
				var key := "fx_max" if strategy == "player" and randf() < 0.5 else "fx_min"
				GS.apply_fx(t.get(key, {}).duplicate(true), "nego", false)
				if t.has("treaty") and GS.countries.has(data.get("who", "")):
					GS.add_treaty(data["who"], t["treaty"])
		"election":
			var r := GS.compute_election()
			_result["won"] = r["won"]
			if r["won"]:
				_result["terms"] = int(_result["terms"]) + 1
			if not quiet:
				print(">>> ELECCIONES (día %d): ganado=%s escaños propios=%d aliados=%s aprob=%.1f" % [GS.day, r["won"], r["own_seats"], r["allies"], GS.approval])
			if GS.has_method("after_election"):
				GS.after_election(r)
			else:
				GS.end_game("reelegido" if r["won"] else "derrota")
		"vote":
			if data.get("mode", "") != "mocion":
				return
			if not quiet:
				print(">>> MOCIÓN DE CENSURA el día ", GS.day)
			var against := 0
			for p in GS.parties.keys():
				var pr := clampf(1.05 - float(GS.parties[p]["rel"]) / 70.0, 0.02, 0.97)
				if p == GS.pres["party"]:
					pr = 0.02
				for s in int(GS.parties[p]["seats"]):
					if randf() < pr:
						against += 1
			if against >= 176:
				GS.end_game("censura")
			else:
				GS.apply_fx({"estabilidad": 8, "pc": 5}, "Moción de censura", false)
		"control":
			var won := randf() < (0.65 if strategy == "player" else 0.45)
			var avg := randf_range(0.62, 0.9) if won else randf_range(0.3, 0.6)
			GS.apply_fx({"approval": snappedf((avg - 0.55) * 7.0, 0.1), "estabilidad": 3 if won else -3}, "Sesión de control", false)
		"debate":
			if GS.campaign:
				var avg2 := randf_range(0.55, 0.85) if strategy == "player" else randf_range(0.4, 0.75)
				GS.campaign_bonus += (avg2 - 0.55) * 14.0
		"speech":
			GS.apply_fx({"approval": 2.0}, "speech", false)
			GS.speech_until = GS.day + 45
