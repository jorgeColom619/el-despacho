extends Node
## Estado de la partida y simulación: economía, facciones, parlamento, eventos y consecuencias.

signal day_passed
signal month_passed
signal stats_changed
signal toast(text: String, kind: String, icon: String)
signal deltas(items: Array)
signal queue_changed
signal headline(text: String)
signal game_over(data: Dictionary)
signal speed_changed(s: int)
signal open_request(kind: String, data: Dictionary)
signal weather_changed
signal result_text(text: String)

const W := preload("res://scripts/data/world_data.gd")
const DAY_SEC := 1.5
const SPEED_MULT := [0.0, 1.0, 2.0, 4.0]
const METERS := ["economia", "bienestar", "seguridad", "estabilidad", "prestigio", "ambiente"]
const FACTIONS := ["trabajadores", "empresarios", "clase_media", "jovenes", "jubilados", "militares"]
const RING_SECONDS := 14.0

var active := false
var day := 0
var speed := 1
var holds := 0
var _acc := 0.0
var rng := RandomNumberGenerator.new()

var pres := {"name": "Alejandro Ríos", "party": "MP", "look": {}}
var difficulty := 1
var term_days := 730

var meters := {}
var mtarget := {}
var fac := {}
var ftarget := {}
var approval := 50.0
var approval_bonus := 0.0
var pc := 30.0
var stress := 10.0
var gdp := 1200000.0
var debt := 1176000.0
var taxes := {}
var budget := {}
var monthly_adj := 0.0
var balance := 0.0
var last_balance := 0.0
var parties := {}
var countries := {}
var treaties := []
var policies := []
var mods := []
var _mod_sums := {}
var flags := {}
var history := []
var news_feed := []
var month_log := []
var inbox := []
var calls := []
var visitors := []
var alerts := []
var scheduled := []
var cooldowns := {}
var used := {}
var timers := {}
var ministers := {}
var corruption := 0.0
var fortune := 0.0
var stat_hist := {}
var uid_counter := 0
var speech_until := 0
var weather := "clear"
var weather_days := 5
var celebrate_until := -1
var low_approval_days := 0
var mocion_until := 0
var campaign_bonus := 0.0
var campaign := false
var debate_done := false
var last_law := ""
var tutorial := {}
var game_ended := false
var ringing_time := 0.0
var budget_year_done := -1
var elections_result := {}
var wear := 0.0
var _trait_sums := {}
var region_bonus := {}
var campaign_acts := 0
var acts_done := 0
var _campaign_days := 0
## Leyes aprobadas en la legislatura actual (cada una encarece la siguiente)
var laws_term := 0
## Sistemas que se presentan poco a poco en fácil y normal: {clave: día en que se desbloquean}
var unlocks := {}
## Modo de juego: "clasico" (una legislatura), "infinito" (hasta que le echen) o "meme"
var mode := "clasico"
## Escenario inicial de la partida y tramas sorteadas
var scenario := "estable"
var tramas := []
## Modo infinito: número de legislatura, día en que empezó y elecciones ganadas
var term_index := 1
var term_start := 0
var terms_won := 0
## Líder de la oposición cuando cambia (modo infinito): {name, role, look}
var opo_override := {}
## Eventos vistos en legislaturas anteriores (salen menos en las siguientes)
var seen_terms := {}
## Ciclo económico (-1 recesión · +1 expansión): da rachas buenas y malas que no dependen del jugador
var cycle := 0.0
var scandals := 0
## Promesas electorales de la partida (ver scripts/systems/promesas.gd)
var promises := []
## Contadores de cosas que pueden romper una promesa: ministros cesados, indultos firmados y escándalos
var counters := {"ceses": 0, "indultos": 0, "escandalos": 0}
## Memoria de la partida: lo que ha hecho el presidente y que los personajes recordarán más adelante
var memo := []
## Personajes que aparecen durante la partida (la periodista incómoda, exministros...): {clave: {name, role, look}}
var cast := {}
## Recuerdos de una sola vez por partida que ya han salido
var memo_used := {}

const Promesas := preload("res://scripts/systems/promesas.gd")
const Memoria := preload("res://scripts/systems/memoria.gd")

## Los efectos de las decisiones se olvidan poco a poco (vida media en días)
const MEMORY_HALF_LIFE := 150.0
## Techo suave de los modificadores acumulados: evita grupos al 99 % o al 1 %
const MOD_SOFTCAP := 24.0
## Fuerza de los efectos positivos permanentes de las leyes (la sociedad se acostumbra a ellas)
const LAW_STRENGTH := 0.65
## Presentación progresiva de los sistemas (fácil / normal). En difícil todo está disponible desde el primer día.
const UNLOCK_DAYS := [
	{"discurso": 15, "leyes": 35, "diplomacia": 55, "presupuestos": 90},
	{"discurso": 12, "leyes": 28, "diplomacia": 45, "presupuestos": 75},
	{},
]
const UNLOCK_INFO := {
	"discurso": {"name": "Discursos a la nación", "event": "intro_discurso"},
	"leyes": {"name": "Agenda legislativa y Congreso", "event": "intro_leyes"},
	"diplomacia": {"name": "Diplomacia y agenda telefónica", "event": "intro_diplomacia"},
	"presupuestos": {"name": "Presupuestos Generales", "event": "intro_presupuestos"},
}
## Plazos para decidir según la dificultad (días)
const DEADLINES := {"doc": [21, 14, 10], "advisor": [10, 7, 5], "crisis": [7, 5, 4]}


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE


# ================================================================== nueva partida

func new_game(opts: Dictionary) -> void:
	pres = {"name": opts.get("name", "Alejandro Ríos"), "party": opts.get("party", "MP"), "look": Perfil.apply_outfit(opts.get("look", {}))}
	difficulty = opts.get("difficulty", 1)
	mode = opts.get("mode", "clasico")
	term_days = int(opts.get("years", 2)) * 365
	if mode == "infinito":
		term_days = 4 * 365
	term_index = 1
	term_start = 0
	terms_won = 0
	opo_override = {}
	seen_terms = {}
	Perfil.start_game()
	day = 0
	speed = 1
	holds = 0
	_acc = 0.0
	game_ended = false
	for m in METERS:
		meters[m] = 50.0
	meters["seguridad"] = 55.0
	meters["estabilidad"] = 58.0
	meters["ambiente"] = 44.0
	meters["prestigio"] = 50.0
	for f in FACTIONS:
		fac[f] = 50.0
	var bonus: Dictionary = W.PLAYER_PARTIES[pres["party"]]["bonus"]
	for f in bonus.keys():
		fac[f] += bonus[f] * 0.8
	approval = 55.0
	approval_bonus = 0.0
	pc = 35.0 - difficulty * 5.0
	stress = 10.0
	gdp = 1200000.0
	debt = gdp * (0.94 + difficulty * 0.04)
	taxes = {}
	for t in W.TAXES.keys():
		taxes[t] = W.TAXES[t]["base"]
	budget = {}
	for b in W.BUDGET.keys():
		budget[b] = 1.0
	monthly_adj = 0.0
	parties = {}
	var seats: Dictionary = W.SEATS[pres["party"]]
	for p in W.PARTIES.keys():
		var dist := absf(W.PARTIES[p]["ideo"] - W.PARTIES[pres["party"]]["ideo"])
		var rel := clampf(75.0 - dist * 0.55, 15.0, 70.0)
		if p == pres["party"]:
			rel = 90.0
		if p == "CR":
			rel = 50.0
		parties[p] = {"seats": seats[p], "rel": rel}
	countries = {}
	for c in W.COUNTRIES.keys():
		countries[c] = {"rel": W.COUNTRIES[c]["rel"], "cd": {}}
	treaties = []
	policies = []
	mods = []
	_mod_sums = {}
	flags = {}
	history = []
	news_feed = []
	month_log = []
	inbox = []
	calls = []
	visitors = []
	alerts = []
	scheduled = []
	cooldowns = {}
	used = {}
	ministers = {}
	for k in ["jefa", "economia", "interior", "exteriores", "defensa", "sanidad"]:
		ministers[k] = W.CHARACTERS[k].duplicate(true)
		ministers[k]["traits"] = W.INITIAL_TRAITS.get(k, []).duplicate()
	_recalc_traits()
	region_bonus = {}
	campaign_acts = 0
	acts_done = 0
	corruption = 0.0
	fortune = 0.0
	stat_hist = {"approval": [], "economia": [], "bienestar": [], "seguridad": [], "estabilidad": [], "prestigio": [], "ambiente": [], "debt": [], "balance": []}
	uid_counter = 0
	speech_until = 0
	weather = "clear"
	weather_days = 6
	celebrate_until = -1
	low_approval_days = 0
	mocion_until = 0
	campaign_bonus = 0.0
	campaign = false
	debate_done = false
	last_law = ""
	budget_year_done = 2027
	elections_result = {}
	wear = 0.0
	laws_term = 0
	cycle = rng.randf_range(-0.3, 0.3)
	scandals = 0
	promises = []
	counters = {"ceses": 0, "indultos": 0, "escandalos": 0}
	memo = []
	memo_used = {}
	var mult: float = [1.25, 1.0, 0.8][difficulty]
	timers = {"doc": 2, "advisor": 9, "call": 6, "crisis": int(55 * mult), "press": int(50 * mult), "news": 3, "control": 35, "summit": 110}
	_recalc_mods()
	_update_targets()
	_update_approval()
	active = true
	# Cada partida es distinta: mundo aleatorio, escenario inicial y tramas sorteadas
	_randomize_world()
	Memoria.setup_cast(rng)
	_apply_scenario(_pick_scenario(str(opts.get("scenario", "aleatorio"))))
	_draw_tramas()
	_update_targets()
	_update_approval()
	_sample_stats()
	# Promesas del programa electoral (elegidas en la pantalla de nueva partida)
	Promesas.start(opts.get("promises", []))
	# Presentación progresiva de los sistemas
	unlocks = UNLOCK_DAYS[difficulty].duplicate()
	for k in unlocks.keys():
		schedule(UNLOCK_INFO[k]["event"], int(unlocks[k]))
	# Arranque guionizado
	if mode == "meme":
		spawn(DB.event("bienvenida_meme"))
	else:
		spawn(DB.event("bienvenida_guiada" if not unlocks.is_empty() else "bienvenida"))
	schedule("doc_nombramientos", 1)
	schedule(["call_felicitacion", "call_felicitacion_norland", "call_felicitacion_hao", "call_felicitacion_drogan"][rng.randi() % 4], rng.randi_range(2, 5))
	push_news("%s jura su cargo como presidente de Valdoria" % pres["name"], 3)


# ================================================================== variedad entre partidas

const SC := preload("res://scripts/data/scenarios_data.gd")


## Carácter de un líder extranjero en esta partida (puede cambiar de una partida a otra)
func country_pers(c: String) -> String:
	if countries.has(c) and countries[c].has("pers"):
		return str(countries[c]["pers"])
	return str(W.COUNTRIES[c]["pers"])


## Ministros, líderes extranjeros, relaciones y escaños cambian un poco en cada partida
func _randomize_world() -> void:
	var good := []
	var bad := []
	for t in W.TRAITS.keys():
		(good if W.TRAITS[t].get("good", true) else bad).append(t)
	for k in ministers.keys():
		var m: Dictionary = ministers[k]
		# Algunos ministros son otras personas (mismo cargo y mismo género, para que los textos cuadren)
		if k != "jefa" and rng.randf() < 0.45:
			var g: String = m["look"].get("g", "m")
			var look := DB.rand_look(g)
			if k == "defensa":
				look["uniform"] = true
				look["suit"] = "3f4a32"
			m["name"] = ("Gral. " if k == "defensa" else "") + DB.rand_name(g)
			m["look"] = look
		var tr := [good[rng.randi() % good.size()]]
		var r := rng.randf()
		if r < 0.35:
			var t2: String = good[rng.randi() % good.size()]
			if not (t2 in tr):
				tr.append(t2)
		elif r < 0.7:
			tr.append(bad[rng.randi() % bad.size()])
		m["traits"] = tr
	_recalc_traits()
	var pers_keys: Array = W.PERSONALITIES.keys()
	for c in countries.keys():
		countries[c]["rel"] = clampf(countries[c]["rel"] + rng.randf_range(-12.0, 12.0), -100.0, 100.0)
		if rng.randf() < 0.35:
			countries[c]["pers"] = pers_keys[rng.randi() % pers_keys.size()]
	var own: String = pres["party"]
	for p in parties.keys():
		if p != own:
			parties[p]["rel"] = clampf(parties[p]["rel"] + rng.randf_range(-8.0, 8.0), 0.0, 100.0)
	# Escaños: pequeñas variaciones (el total sigue siendo 350)
	var opp: String = W.PLAYER_PARTIES[own]["opp"]
	for p in parties.keys():
		if p == opp:
			continue
		var dv := rng.randi_range(-6, 6) if p == own else rng.randi_range(-4, 4)
		var nv := maxi(2, int(parties[p]["seats"]) + dv)
		parties[opp]["seats"] = int(parties[opp]["seats"]) - (nv - int(parties[p]["seats"]))
		parties[p]["seats"] = nv


func _pick_scenario(id: String) -> String:
	if SC.SCENARIOS.has(id):
		return id
	var total := 0.0
	for k in SC.SCENARIOS.keys():
		total += float(SC.SCENARIOS[k].get("w", 1.0))
	var r := rng.randf() * total
	for k in SC.SCENARIOS.keys():
		r -= float(SC.SCENARIOS[k].get("w", 1.0))
		if r <= 0.0:
			return k
	return "estable"


func _apply_scenario(id: String) -> void:
	scenario = id
	var sc: Dictionary = SC.SCENARIOS[id]
	var st: Dictionary = sc.get("setup", {})
	# El contexto inicial se nota de golpe y se va diluyendo (vida media de un año)
	for k in st.get("meters", {}).keys():
		var v := float(st["meters"][k])
		meters[k] = clampf(meters[k] + v, 0.0, 100.0)
		add_memory(k, v, 365.0)
	for k in st.get("fac", {}).keys():
		var v2 := float(st["fac"][k])
		fac[k] = clampf(fac[k] + v2, 0.0, 100.0)
		add_memory(k, v2, 365.0)
	if st.has("debt"):
		debt += gdp * float(st["debt"])
	if st.has("cycle"):
		cycle = float(st["cycle"])
	for c in st.get("rel", {}).keys():
		countries[c]["rel"] = clampf(countries[c]["rel"] + float(st["rel"][c]), -100.0, 100.0)
	var pr: Dictionary = st.get("party_rel", {})
	for p in parties.keys():
		if p == pres["party"]:
			continue
		var dv := float(pr.get(p, pr.get("*", 0.0)))
		parties[p]["rel"] = clampf(parties[p]["rel"] + dv, 0.0, 100.0)
	if st.has("own_seats"):
		var own: String = pres["party"]
		var opp: String = W.PLAYER_PARTIES[own]["opp"]
		var d := int(st["own_seats"])
		parties[own]["seats"] = int(parties[own]["seats"]) + d
		parties[opp]["seats"] = int(parties[opp]["seats"]) - int(d * 0.6)
		var rest: int = -d - (-int(d * 0.6))
		for p in ["CC", "VV", "PO", "FS"]:
			if p != own and p != opp and rest != 0:
				var step := signi(rest) * mini(absi(rest), 4)
				parties[p]["seats"] = int(parties[p]["seats"]) + step
				rest -= step
		parties[opp]["seats"] = int(parties[opp]["seats"]) + rest
	for f in st.get("flags", []):
		flags[f] = 0
	for e in sc.get("schedule", []):
		schedule(str(e[0]), int(e[1]))
	push_news(sc.get("headline", ""), 3)


## Sortea las tramas de esta legislatura y programa su arranque
func _draw_tramas() -> void:
	tramas = []
	var sc: Dictionary = SC.SCENARIOS.get(scenario, {})
	var tlen := term_days - term_start
	var n := 2 if tlen <= 365 else (3 if tlen <= 730 else 4)
	for t in sc.get("force", []):
		if not (t in tramas):
			tramas.append(t)
	var pool := {}
	for t in SC.TRAMAS.keys():
		if t in tramas:
			continue
		var w := float(SC.TRAMAS[t].get("w", 1.0)) * Perfil.trama_factor(t)
		if t in sc.get("tramas", []):
			w *= 2.5
		pool[t] = w
	while tramas.size() < n and not pool.is_empty():
		var total := 0.0
		for t in pool.keys():
			total += float(pool[t])
		var r := rng.randf() * total
		var chosen: String = pool.keys().back()
		for t in pool.keys():
			r -= float(pool[t])
			if r <= 0.0:
				chosen = t
				break
		tramas.append(chosen)
		pool.erase(chosen)
	# Cada trama arranca en un momento distinto (la ventana se adapta a la duración)
	var scale := clampf(float(tlen - 60) / 670.0, 0.45, 2.0)
	for t in tramas:
		var td: Dictionary = SC.TRAMAS[t]
		var win: Array = td.get("window", [60, 300])
		var d := rng.randi_range(int(float(win[0]) * minf(scale, 1.0)), int(float(win[1]) * scale))
		schedule(td["start"], maxi(15, d))


# ================================================================== bucle

func _process(delta: float) -> void:
	if not active or game_ended:
		return
	if holds > 0 or speed == 0:
		return
	_acc += delta * SPEED_MULT[speed]
	while _acc >= DAY_SEC and holds == 0 and active and not game_ended:
		_acc -= DAY_SEC
		advance_day()
	# Llamadas: el teléfono deja de sonar si nadie contesta
	if calls.size() > 0:
		ringing_time += delta
		if ringing_time > RING_SECONDS * [1.4, 1.0, 0.8][difficulty]:
			ringing_time = 0.0
			var c: Dictionary = calls.pop_front()
			_missed_call(c)


## ¿Está disponible este sistema? (presentación progresiva en fácil y normal)
func is_unlocked(key: String) -> bool:
	return day >= int(unlocks.get(key, 0))


func days_to_unlock(key: String) -> int:
	return maxi(0, int(unlocks.get(key, 0)) - day)


## Deuda (% del PIB) a partir de la cual el país quiebra
func bankruptcy_limit() -> float:
	return [170.0, 155.0, 140.0][difficulty]


## Índice de la opción más favorable para el electorado: el "consejo del gabinete" en fácil
func recommend(choices: Array) -> int:
	var best := 0
	var bs := -INF
	for i in choices.size():
		var c: Dictionary = choices[i]
		var sc := _score_fx(c.get("fx", {})) + _score_fx(c.get("hidden", {}))
		if sc > bs:
			bs = sc
			best = i
	return best


func _score_fx(fx: Dictionary) -> float:
	var sc := 0.0
	for k in fx.keys():
		var v = fx[k]
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			if fac.has(k):
				sc += float(v) * (float(W.FACTION_INFO[k]["w"]) * 4.0 + 0.2)
			elif meters.has(k):
				sc += float(v) * 0.6
			else:
				match k:
					"money":
						sc += float(v) / 700.0
					"monthly":
						sc += float(v) / 60.0
					"pc":
						sc += float(v) * 0.15
					"corr":
						sc -= float(v) * 0.6
					"approval":
						sc += float(v) * 1.5
		elif k == "risk" and v is Dictionary:
			sc += _score_fx(v.get("fx", {})) * float(v.get("p", 0.5))
			if fx.has("else") and fx["else"] is Dictionary:
				sc += _score_fx(fx["else"].get("fx", {})) * (1.0 - float(v.get("p", 0.5)))
		elif k == "rel" and v is Dictionary:
			for c2 in v.keys():
				sc += float(v[c2]) * 0.08
		elif k == "party" and v is Dictionary:
			for p2 in v.keys():
				sc += float(v[p2]) * 0.1
	return sc


func hold() -> void:
	holds += 1


func release() -> void:
	holds = maxi(0, holds - 1)


func set_speed(s: int) -> void:
	speed = clampi(s, 0, 3)
	speed_changed.emit(speed)


func day_progress() -> float:
	return clampf(_acc / DAY_SEC, 0.0, 1.0)


func advance_day() -> void:
	day += 1
	var dd := UI.date_dict(day)
	_expire_mods()
	_update_targets()
	_drift()
	_economy_daily()
	_update_approval()
	stress = clampf(stress - 0.3 + 0.03 * (inbox.size() + visitors.size() + alerts.size() * 3), 0.0, 100.0)
	approval_bonus *= 0.97
	_weather_tick(dd)
	_check_deadlines()
	_run_scheduled()
	Promesas.tick()
	if day == term_start + (term_days - term_start) / 2 and not campaign:
		var mt := Promesas.midterm_event()
		if not mt.is_empty():
			spawn(mt)
	if not game_ended:
		_generate()
	if dd["day"] == 1:
		_monthly(dd)
	# Desgaste del poder: tras la luna de miel, cada dos meses el Gobierno pierde algo de apoyo
	var wear_cap: float = [7.0, 11.0, 14.0][difficulty] + 1.5 * float(term_index - 1)
	if day % 60 == 0 and day - term_start >= 120 and wear > -wear_cap:
		var step: float = [0.8, 1.2, 1.5][difficulty]
		wear -= step
		for f in ["trabajadores", "empresarios", "clase_media", "jovenes", "jubilados"]:
			mods.append({"k": f, "v": -step, "until": -1, "tag": "wear"})
		_recalc_mods()
	if approval >= 70.0:
		Perfil.unlock("idolo")
	if debt_ratio() < 80.0:
		Perfil.unlock("cuentas")
	_campaign_tick()
	if timers.has("control") and not campaign and day > 30:
		timers["control"] -= 1
		if timers["control"] <= 0:
			timers["control"] = rng.randi_range(40, 60)
			open_request.emit("control", {})
	if timers.has("summit") and day > 90:
		timers["summit"] -= 1
		if timers["summit"] <= 0:
			timers["summit"] = rng.randi_range(130, 190)
			var sid: String = DB.SUMMITS.keys().pick_random()
			spawn({"id": "cumbre_" + sid, "type": "advisor", "who": "exteriores", "gen": true, "title": "Invitación a una cumbre",
				"text": DB.SUMMITS[sid]["invite"],
				"choices": [{"t": "Asistiré personalmente.", "fx": {"summit": sid}, "rec": "exteriores"}, {"t": "Enviar al ministro de Exteriores.", "fx": {"prestigio": -2}}], "default": 1})
	day_passed.emit()
	stats_changed.emit()
	_check_end()


# ================================================================== simulación

func debt_ratio() -> float:
	return debt / gdp * 100.0


func growth() -> float:
	var g: float = 1.2 + (meters["economia"] - 50.0) * 0.08 + cycle * 0.8
	return g


func unemployment() -> float:
	return clampf(12.0 - (meters["economia"] - 50.0) * 0.2, 3.0, 30.0)


func interest_rate() -> float:
	var sens: float = [0.8, 1.0, 1.4][difficulty]
	var r := 2.8 + maxf(0.0, debt_ratio() - 90.0) * 0.06 * sens + maxf(0.0, 50.0 - meters["estabilidad"]) * 0.02
	if flags.has("prima"):
		r += 1.0
	return r


func revenue() -> float:
	var gm := gdp / 12.0
	var ef: float = 0.85 + meters["economia"] / 100.0 * 0.3
	return gm * (taxes["renta"] / 100.0 * 0.70 + taxes["sociedades"] / 100.0 * 0.18 + taxes["iva"] / 100.0 * 0.55 + 0.094) * ef


func spending() -> float:
	var s := 0.0
	for b in W.BUDGET.keys():
		s += W.BUDGET[b]["base"] * budget[b]
	# El gasto crece con la economía (salarios públicos, pensiones e inflación)
	return s * gdp / 1200000.0


func interest() -> float:
	return debt * interest_rate() / 100.0 / 12.0


func monthly_balance() -> float:
	return revenue() - spending() - interest() + monthly_adj + float(_trait_sums.get("_monthly", 0.0))


func _economy_daily() -> void:
	balance = monthly_balance()
	debt -= balance / 30.0
	var nominal := growth() + 1.6
	gdp *= 1.0 + nominal / 36500.0


func tax_burden() -> float:
	return (taxes["renta"] - 22.0) * 0.6 + (taxes["sociedades"] - 25.0) * 0.5 + (taxes["iva"] - 21.0) * 0.5


func supporting_seats() -> int:
	var s := 0
	for p in parties.keys():
		if p == pres["party"] or parties[p]["rel"] >= 55.0:
			s += int(parties[p]["seats"])
	return s


func treaty_count(kind: String = "") -> int:
	var n := 0
	for t in treaties:
		if kind == "" or t["type"] == kind:
			n += 1
	return n


func _update_targets() -> void:
	var b := budget
	var m := meters
	var diff: float = [4.0, 0.0, -4.0][difficulty]
	var tb := tax_burden()
	var econ_treaties := 0
	for t in treaties:
		if t["type"] in ["comercio", "inversion", "energia"]:
			econ_treaties += 1
	mtarget["economia"] = 50.0 + (b["infraestructura"] - 1.0) * 18.0 + (b["educacion"] - 1.0) * 5.0 - tb - maxf(0.0, debt_ratio() - 100.0) * 0.25 + (m["estabilidad"] - 50.0) * 0.12 + econ_treaties * 2.0 + cycle * 9.0 + (fac["empresarios"] - 50.0) * 0.12 + soft_mod("economia") + diff * 0.5
	mtarget["bienestar"] = 48.0 + (b["sanidad"] - 1.0) * 28.0 + (b["educacion"] - 1.0) * 14.0 + (b["social"] - 1.0) * 16.0 + (b["pensiones"] - 1.0) * 8.0 + (m["economia"] - 50.0) * 0.15 + soft_mod("bienestar") + diff * 0.5
	mtarget["seguridad"] = 52.0 + (b["seguridad"] - 1.0) * 32.0 + (b["defensa"] - 1.0) * 8.0 + (m["economia"] - 50.0) * 0.1 + (m["bienestar"] - 50.0) * 0.1 + soft_mod("seguridad") + diff * 0.5
	var support := (supporting_seats() - 175.0) / 350.0 * 40.0
	mtarget["estabilidad"] = 32.0 + approval * 0.35 + support + (m["seguridad"] - 50.0) * 0.1 + (fac["trabajadores"] - 50.0) * 0.06 - corruption * 0.2 + soft_mod("estabilidad") + diff * 0.5
	var avg_rel := 0.0
	for c in countries.keys():
		avg_rel += countries[c]["rel"]
	avg_rel /= maxf(1.0, countries.size())
	mtarget["prestigio"] = 46.0 + avg_rel * 0.2 + (m["economia"] - 50.0) * 0.15 + (b["defensa"] - 1.0) * 6.0 + treaties.size() * 1.5 + soft_mod("prestigio") + diff * 0.5
	mtarget["ambiente"] = 42.0 + (b["ambiente"] - 1.0) * 35.0 - (m["economia"] - 50.0) * 0.08 + soft_mod("ambiente")
	for k in METERS:
		mtarget[k] = clampf(mtarget[k], 2.0, 98.0)
	var t := taxes
	var bonus: Dictionary = W.PLAYER_PARTIES[pres["party"]]["bonus"]
	ftarget["trabajadores"] = 50.0 + (m["economia"] - 50.0) * 0.3 + (b["social"] - 1.0) * 25.0 + (b["sanidad"] - 1.0) * 10.0 + (b["infraestructura"] - 1.0) * 10.0 - (t["iva"] - 21.0) * 1.2 - (t["renta"] - 22.0) * 0.4
	ftarget["empresarios"] = 50.0 + (m["economia"] - 50.0) * 0.5 - (t["sociedades"] - 25.0) * 2.0 - (t["renta"] - 22.0) * 0.5 + (b["infraestructura"] - 1.0) * 10.0 + (m["estabilidad"] - 50.0) * 0.2
	ftarget["clase_media"] = 50.0 + (m["economia"] - 50.0) * 0.35 + (m["seguridad"] - 50.0) * 0.25 - (t["renta"] - 22.0) * 1.3 - (t["iva"] - 21.0) * 0.6 + (b["sanidad"] - 1.0) * 10.0 + (b["educacion"] - 1.0) * 10.0 - corruption * 0.15
	ftarget["jovenes"] = 50.0 + (b["educacion"] - 1.0) * 25.0 + (m["ambiente"] - 50.0) * 0.3 + (m["economia"] - 50.0) * 0.25 + (b["social"] - 1.0) * 12.0
	ftarget["jubilados"] = 50.0 + (b["pensiones"] - 1.0) * 40.0 + (b["sanidad"] - 1.0) * 20.0 + (m["seguridad"] - 50.0) * 0.25 - (t["iva"] - 21.0) * 0.8
	ftarget["militares"] = 50.0 + (b["defensa"] - 1.0) * 45.0 + (m["prestigio"] - 50.0) * 0.3 + (m["seguridad"] - 50.0) * 0.2
	for f in FACTIONS:
		ftarget[f] += bonus.get(f, 0.0) + soft_mod(f) + diff
		ftarget[f] = clampf(ftarget[f], 2.0, 98.0)


func _drift() -> void:
	for k in METERS:
		meters[k] = clampf(meters[k] + (mtarget[k] - meters[k]) * 0.03, 0.0, 100.0)
	for f in FACTIONS:
		fac[f] = clampf(fac[f] + (ftarget[f] - fac[f]) * 0.035, 0.0, 100.0)


func _update_approval() -> void:
	var s := 0.0
	var ws := 0.0
	for f in FACTIONS:
		var w: float = W.FACTION_INFO[f]["w"]
		s += fac[f] * w
		ws += w
	var honeymoon := (10.0 if term_index == 1 else 5.0) * maxf(0.0, 1.0 - float(day - term_start) / 120.0)
	var raw := s / ws + honeymoon + approval_bonus + float(_trait_sums.get("_approval", 0.0))
	# Cuanto más alto se vuela, más exigentes son los ciudadanos: por encima del 50 % cuesta más subir
	if raw > 50.0:
		raw = 50.0 + (raw - 50.0) * 0.75
	approval = clampf(raw, 0.0, 100.0)


func modsum(k: String) -> float:
	return float(_mod_sums.get(k, 0.0)) + float(_trait_sums.get(k, 0.0))


## Suma de modificadores con techo suave: los primeros puntos cuentan enteros y los siguientes, cada vez menos
func soft_mod(k: String) -> float:
	var x := modsum(k)
	return MOD_SOFTCAP * tanh(x / MOD_SOFTCAP)


# ================================================================== gabinete (rasgos y fichajes)

func _recalc_traits() -> void:
	_trait_sums = {}
	for k in ministers.keys():
		for t in ministers[k].get("traits", []):
			var td: Dictionary = W.TRAITS.get(t, {})
			for mk in td.get("mods", {}).keys():
				_trait_sums[mk] = float(_trait_sums.get(mk, 0.0)) + float(td["mods"][mk])
			if td.has("monthly"):
				_trait_sums["_monthly"] = float(_trait_sums.get("_monthly", 0.0)) + float(td["monthly"])
			if td.has("approval"):
				_trait_sums["_approval"] = float(_trait_sums.get("_approval", 0.0)) + float(td["approval"])
			if td.has("area") and W.MINISTRY_AREA.has(k):
				var area: String = W.MINISTRY_AREA[k]
				_trait_sums[area] = float(_trait_sums.get(area, 0.0)) + float(td["area"])


func has_trait(t: String) -> bool:
	for k in ministers.keys():
		if t in ministers[k].get("traits", []):
			return true
	return false


func gen_candidates(key: String) -> Array:
	var out := []
	var good := []
	var bad := []
	for t in W.TRAITS.keys():
		if W.TRAITS[t].get("good", true):
			good.append(t)
		else:
			bad.append(t)
	for i in 3:
		var g := "m" if rng.randf() < 0.5 else "f"
		var tr := [good.pick_random()]
		var r := rng.randf()
		if r < 0.45:
			var t2: String = good.pick_random()
			if not (t2 in tr):
				tr.append(t2)
		elif r < 0.8:
			tr.append(bad.pick_random())
		var role: String = ministers[key]["role"]
		role = role.replace("Ministro", "Ministra") if g == "f" else role.replace("Ministra", "Ministro")
		if key == "jefa":
			role = "Jefa de Gabinete" if g == "f" else "Jefe de Gabinete"
		out.append({"name": DB.rand_name(g), "role": role, "look": DB.rand_look(g), "traits": tr})
	return out


func hire_minister(key: String, cand: Dictionary) -> void:
	var old: String = ministers[key]["name"]
	counters["ceses"] = int(counters.get("ceses", 0)) + 1
	remember("cese", {"name": old, "role": str(ministers[key]["role"]), "key": key, "look": ministers[key].get("look", {})})
	ministers[key] = cand.duplicate(true)
	_recalc_traits()
	_update_targets()
	push_news("%s sustituye a %s como %s" % [cand["name"], old, String(cand["role"]).to_lower()], 2)
	log_history("Cambio en el Gobierno", "%s, nuevo/a %s" % [cand["name"], String(cand["role"]).to_lower()])
	Perfil.unlock("fichaje")
	stats_changed.emit()


func add_mod(k: String, v: float, dur: int) -> void:
	mods.append({"k": k, "v": v, "until": -1 if dur < 0 else day + dur})
	_recalc_mods()


## Modificador que se va olvidando: pierde la mitad de su fuerza cada `half_life` días
func add_memory(k: String, v: float, half_life: float = MEMORY_HALF_LIFE) -> void:
	mods.append({"k": k, "v": v, "t0": day, "hl": half_life, "until": -1})
	_recalc_mods()


func _mod_value(m: Dictionary) -> float:
	if m.has("hl"):
		return float(m["v"]) * pow(0.5, float(day - int(m["t0"])) / maxf(1.0, float(m["hl"])))
	return float(m["v"])


func _recalc_mods() -> void:
	_mod_sums = {}
	for m in mods:
		_mod_sums[m["k"]] = _mod_sums.get(m["k"], 0.0) + _mod_value(m)


func _expire_mods() -> void:
	var keep := []
	for m in mods:
		if int(m["until"]) >= 0 and int(m["until"]) <= day:
			continue
		if m.has("hl") and absf(_mod_value(m)) < 0.05:
			continue
		keep.append(m)
	mods = keep
	_recalc_mods()


func _monthly(dd: Dictionary) -> void:
	last_balance = monthly_balance()
	pc = clampf(pc + 4.0 + approval * 0.07 + meters["estabilidad"] * 0.04 + [1.5, 0.0, -1.0][difficulty], 0.0, 100.0)
	# La corrupción se diluye con el tiempo... salvo que alguien tire del hilo (ver escándalos)
	corruption = maxf(0.0, corruption * (0.93 if flags.has("transparencia") else 0.95) - 0.4)
	# Ciclo económico: paseo aleatorio que tiende a volver a la normalidad
	cycle = clampf(cycle * 0.93 + rng.randf_range(-0.16, 0.16), -1.0, 1.0)
	_sample_stats()
	month_passed.emit()
	# Presupuesto anual en enero
	if dd["month"] == 1 and budget_year_done < int(dd["year"]):
		budget_year_done = int(dd["year"])
		toast.emit("Nuevo año fiscal: revise los Presupuestos (carpeta de cuero)", "info", "dinero")
		flags["presupuesto_pendiente"] = true
	Perfil.note_game(used.keys(), tramas)
	# Lo que hizo hace meses vuelve: exministros, indultados, cartas, contratos, líderes que no olvidan...
	Memoria.monthly()
	# Periódico mensual
	open_request.emit("newspaper", {"month_day": day - 1})
	month_log = []
	save_game()


func _sample_stats() -> void:
	stat_hist["approval"].append(approval)
	for m in METERS:
		stat_hist[m].append(meters[m])
	stat_hist["debt"].append(debt_ratio())
	stat_hist["balance"].append(monthly_balance())


func _weather_tick(dd: Dictionary) -> void:
	weather_days -= 1
	if weather_days > 0:
		return
	weather_days = rng.randi_range(3, 8)
	var month: int = dd["month"]
	var winter := month in [12, 1, 2]
	var summer := month in [6, 7, 8]
	var bad := clampf((50.0 - approval) / 40.0, 0.0, 0.6)
	var r := rng.randf()
	var w := "clear"
	if winter:
		if r < 0.25:
			w = "snow"
		elif r < 0.45 + bad * 0.3:
			w = "rain"
		elif r < 0.7:
			w = "clouds"
	elif summer:
		if r < 0.08 + bad * 0.2:
			w = "storm"
		elif r < 0.25:
			w = "clouds"
	else:
		if r < 0.18 + bad * 0.3:
			w = "rain"
		elif r < 0.3 + bad * 0.3:
			w = "storm"
		elif r < 0.55:
			w = "clouds"
		elif r < 0.62:
			w = "fog"
	if w != weather:
		weather = w
		weather_changed.emit()


# ================================================================== condiciones

func value_of(key: String) -> float:
	if meters.has(key):
		return meters[key]
	if fac.has(key):
		return fac[key]
	match key:
		"approval":
			return approval
		"debt":
			return debt_ratio()
		"pc":
			return pc
		"stress":
			return stress
		"corr":
			return corruption
		"paro":
			return unemployment()
		"crecimiento":
			return growth()
		"left":
			return float(term_days - day)
	if key.begins_with("tax_"):
		return float(taxes.get(key.substr(4), 0.0))
	if key.begins_with("rel_"):
		var c := key.substr(4)
		if countries.has(c):
			return countries[c]["rel"]
	return 0.0


func check(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	if cond.has("min_day") and day < int(cond["min_day"]):
		return false
	if cond.has("max_day") and day > int(cond["max_day"]):
		return false
	if cond.has("months"):
		var mo: int = UI.date_dict(day)["month"]
		if not (mo in cond["months"]):
			return false
	if cond.has("flag"):
		var fl = cond["flag"]
		for f in (fl if fl is Array else [fl]):
			if not flags.has(f):
				return false
	if cond.has("noflag"):
		var nf = cond["noflag"]
		for f in (nf if nf is Array else [nf]):
			if flags.has(f):
				return false
	if cond.has("flag_event") and not used.has(cond["flag_event"]):
		return false
	if cond.has("policy") and not (cond["policy"] in policies):
		return false
	if cond.has("nopolicy") and (cond["nopolicy"] in policies):
		return false
	if cond.has("has_law") and policies.is_empty():
		return false
	if cond.has("lt"):
		for k in cond["lt"].keys():
			if value_of(k) >= float(cond["lt"][k]):
				return false
	if cond.has("gt"):
		for k in cond["gt"].keys():
			if value_of(k) <= float(cond["gt"][k]):
				return false
	if cond.has("trama") and not (cond["trama"] in tramas):
		return false
	if cond.has("scenario"):
		var scs = cond["scenario"]
		if not (scenario in (scs if scs is Array else [scs])):
			return false
	if cond.has("mode") and mode != str(cond["mode"]):
		return false
	if cond.has("left_gt") and term_days - day <= int(cond["left_gt"]):
		return false
	if cond.has("chance") and rng.randf() > float(cond["chance"]):
		return false
	return true


# ================================================================== eventos

func next_uid() -> int:
	uid_counter += 1
	return uid_counter


func schedule(id: String, delay: int) -> void:
	scheduled.append({"day": day + delay, "id": id})


func _run_scheduled() -> void:
	var due := []
	var keep := []
	for s in scheduled:
		if int(s["day"]) <= day:
			due.append(s)
		else:
			keep.append(s)
	scheduled = keep
	for s in due:
		var ev := DB.event(s["id"])
		if not ev.is_empty():
			spawn(ev)


func _generate() -> void:
	for kind in timers.keys():
		timers[kind] -= 1
		if timers[kind] > 0:
			continue
		var ok := _spawn_kind(kind)
		timers[kind] = _interval(kind) if ok else 3


func _interval(kind: String) -> int:
	var mult: float = [1.25, 1.0, 0.85][difficulty]
	match kind:
		"doc":
			return int(rng.randi_range(5, 10) * mult)
		"advisor":
			return int(rng.randi_range(8, 15) * mult)
		"call":
			return int(rng.randi_range(16, 28) * mult)
		"crisis":
			return int(rng.randi_range(60, 95) * mult)
		"press":
			return int(rng.randi_range(55, 80) * mult)
		"news":
			return rng.randi_range(3, 7)
	return 10


func _eligible(type: String) -> Array:
	var out := []
	for ev in DB.all_events:
		if ev["type"] != type or ev.get("chain_only", false):
			continue
		if ev.get("meme", false) and mode != "meme":
			continue
		var id: String = ev["id"]
		if ev.get("once", false) and used.has(id):
			continue
		if cooldowns.has(id) and day < int(cooldowns[id]):
			continue
		if _is_queued(id):
			continue
		if not check(ev.get("cond", {})):
			continue
		out.append(ev)
	return out


func _is_queued(id: String) -> bool:
	for q in [inbox, calls, visitors, alerts]:
		for it in q:
			if it["ev"].get("id", "") == id:
				return true
	return false


func _pick(list: Array) -> Dictionary:
	var ws := []
	var total := 0.0
	for e in list:
		# Lo que salió en tus últimas partidas sale menos: así no se repite siempre lo mismo
		var w := float(e.get("w", 1.0)) * Perfil.recent_factor(str(e.get("id", "")))
		if seen_terms.has(e.get("id", "")):
			w *= 0.35
		# En el modo meme, los eventos serios salen mucho menos
		if mode == "meme" and not e.get("meme", false):
			w *= 0.4
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in list.size():
		r -= float(ws[i])
		if r <= 0.0:
			return list[i]
	return list.back()


func _spawn_kind(kind: String) -> bool:
	if campaign and kind in ["press"]:
		return false
	match kind:
		"doc":
			if inbox.size() >= 6:
				return false
			var el := _eligible("doc")
			if el.size() > 0 and rng.randf() < 0.55:
				spawn(_pick(el))
			else:
				spawn(DB.gen_doc())
			return true
		"advisor":
			if visitors.size() >= 2:
				return false
			var el2 := _eligible("advisor")
			if el2.is_empty():
				return false
			spawn(_pick(el2))
			return true
		"call":
			if calls.size() >= 1:
				return false
			var el3 := _eligible("call")
			if el3.is_empty():
				return false
			spawn(_pick(el3))
			return true
		"crisis":
			if alerts.size() >= 1:
				return false
			var el4 := _eligible("crisis")
			if el4.is_empty():
				return false
			spawn(_pick(el4))
			return true
		"press":
			open_request.emit("press", {"mode": "rueda"})
			return true
		"news":
			var el5 := _eligible("news")
			if el5.is_empty():
				return false
			var n := _pick(el5)
			cooldowns[n["id"]] = day + int(n.get("cd", 200))
			push_news(n["title"], 1)
			if n.has("fx"):
				apply_fx(n["fx"], n["title"], false)
			return true
	return false


func spawn(ev: Dictionary) -> void:
	var item := {"uid": next_uid(), "ev": ev, "day": day}
	# Los escándalos de corrupción son los eventos que solo salen cuando la corrupción acumulada es alta
	if ev.get("scandal", false) or ev.get("cond", {}).get("gt", {}).has("corr"):
		scandals += 1
		counters["escandalos"] = int(counters.get("escandalos", 0)) + 1
		remember("escandalo", {"title": fmt(str(ev.get("title", "")))})
	match ev["type"]:
		"doc":
			item["deadline"] = day + int(DEADLINES["doc"][difficulty])
			inbox.append(item)
			Sfx.play("paper2", -4.0)
			toast.emit("Nuevo documento: %s" % fmt(ev["title"]), "info", "documento")
		"advisor":
			item["deadline"] = day + int(DEADLINES["advisor"][difficulty])
			visitors.append(item)
			Sfx.play("knock", -2.0)
			var ch := DB.character(ev.get("who", "jefa"))
			toast.emit("%s quiere verle: %s" % [ch.get("name", ""), fmt(ev["title"])], "info", "aprobacion")
		"call":
			calls.append(item)
			ringing_time = 0.0
		"crisis":
			item["deadline"] = day + int(DEADLINES["crisis"][difficulty])
			alerts.append(item)
			Sfx.play("alert", 0.0)
			toast.emit("¡CRISIS! %s" % fmt(ev["title"]), "bad", "alerta")
			push_news("ÚLTIMA HORA: %s" % fmt(ev["title"]), 3)
	queue_changed.emit()


func _remove_item(item: Dictionary) -> void:
	for q in [inbox, calls, visitors, alerts]:
		for i in range(q.size() - 1, -1, -1):
			if int(q[i]["uid"]) == int(item["uid"]):
				q.remove_at(i)
	queue_changed.emit()


func _mark_used(ev: Dictionary) -> void:
	var id: String = ev.get("id", "")
	if id == "" or ev.get("gen", false):
		return
	used[id] = day
	cooldowns[id] = day + int(ev.get("cd", 9999))


func _check_deadlines() -> void:
	for q in [inbox, visitors, alerts]:
		for i in range(q.size() - 1, -1, -1):
			var it: Dictionary = q[i]
			if day > int(it.get("deadline", 99999)):
				q.remove_at(i)
				_expire(it)
				queue_changed.emit()


func _expire(item: Dictionary) -> void:
	var ev: Dictionary = item["ev"]
	_mark_used(ev)
	match ev["type"]:
		"doc":
			if ev.has("options"):
				toast.emit("Concurso desierto: %s" % fmt(ev["title"]), "warn", "documento")
				apply_fx({"estabilidad": -1}, ev["title"])
			else:
				var ch: Dictionary = ev["choices"][int(ev.get("default", ev["choices"].size() - 1))]
				toast.emit("Documento caducado: %s" % fmt(ev["title"]), "warn", "documento")
				apply_fx(ch.get("fx", {}), ev["title"])
				if ch.has("hidden"):
					apply_fx(ch["hidden"], ev["title"], false)
		"advisor":
			var ch2: Dictionary = ev["choices"][int(ev.get("default", ev["choices"].size() - 1))]
			toast.emit("Sin respuesta presidencial: %s decidió por usted" % DB.character(ev.get("who", "jefa")).get("name", "el Gabinete"), "warn", "reloj")
			apply_fx(_strip_interactive(ch2.get("fx", {})), ev["title"])
			stress += 3.0
		"crisis":
			var cr: Dictionary = W.CRISES[ev["crisis"]]
			toast.emit("Ignoraste la crisis: %s" % cr["title"], "bad", "alerta")
			var bad: Dictionary = cr["bad"].duplicate(true)
			if cr.get("fatal", false):
				end_game("golpe")
				return
			apply_fx(bad, cr["title"])
			push_news(cr["news_bad"], 3)
			stress += 10.0


func _strip_interactive(fx: Dictionary) -> Dictionary:
	var out := fx.duplicate(true)
	for k in ["nego", "speech", "debate", "press"]:
		out.erase(k)
	return out


func _missed_call(item: Dictionary) -> void:
	var ev: Dictionary = item["ev"]
	_mark_used(ev)
	var who: String = ev.get("who", "")
	toast.emit("Llamada perdida: %s" % DB.character(who).get("name", "?"), "warn", "telefono")
	if countries.has(who):
		apply_fx({"rel": {who: -4}}, ev["title"])
		remember("llamada_perdida", {"who": who})
	queue_changed.emit()


# ================================================================== resolución

func resolve_choice(item: Dictionary, idx: int) -> Array:
	var ev: Dictionary = item["ev"]
	_remove_item(item)
	_mark_used(ev)
	var ch: Dictionary = ev["choices"][idx]
	var title := fmt(ev.get("title", ""))
	if ev.get("kind", "") == "indulto":
		var granted := str(ch.get("t", "")).begins_with("Conceder") or str(ch.get("t", "")).begins_with("Indultar")
		if granted:
			counters["indultos"] = int(counters.get("indultos", 0)) + 1
		var pname := title.get_slice(": ", 1) if ": " in title else title
		remember("indulto" if granted else "indulto_denegado", {"name": pname, "look": ev.get("prisoner", {})})
	elif ev.get("kind", "") == "carta" and not ev.get("memo", false) and title.begins_with("Carta de "):
		remember("carta_archivada" if idx == int(ev.get("default", 1)) else "carta_ayuda", {"from": title.trim_prefix("Carta de ")})
	if str(ev.get("id", "")).begins_with("cumbre_") and ev.get("gen", false) and idx == 1:
		var sid := str(ev["id"]).trim_prefix("cumbre_")
		if DB.SUMMITS.has(sid):
			for c in DB.SUMMITS[sid]["leaders"]:
				remember("cumbre_plantada", {"who": c, "summit": DB.SUMMITS[sid]["name"]})
	var out := apply_fx(ch.get("fx", {}), title)
	if ch.has("hidden"):
		out.append_array(apply_fx(ch["hidden"], title, false))
	if ch.has("news"):
		push_news(fmt(ch["news"]), 2)
	log_history(title, fmt(ch.get("t", "")))
	return out


func resolve_option(item: Dictionary, opt: Dictionary) -> Array:
	var ev: Dictionary = item["ev"]
	_remove_item(item)
	_mark_used(ev)
	var out := apply_fx(opt.get("fx", {}), ev["title"])
	var note := str(opt.get("small", ""))
	var tipo := "buena"
	if float(opt.get("fx", {}).get("corr", 0.0)) >= 3.0:
		tipo = "corrupta"
	elif "modificados" in note:
		tipo = "sobrecoste"
	elif "Sancionada" in note:
		tipo = "laboral"
	elif "Tsaing" in note or "Filial" in note:
		tipo = "extranjera"
	elif "local" in note:
		tipo = "local"
	remember("contrato", {"company": str(opt["name"]), "title": str(ev["title"]), "tipo": tipo})
	push_news("Adjudicado: %s a %s" % [ev["title"], opt["name"]], 1)
	log_history(ev["title"], "Seleccionado: %s" % opt["name"])
	return out


func postpone(_item: Dictionary) -> void:
	queue_changed.emit()


func dismiss(item: Dictionary) -> void:
	_remove_item(item)


func resolve_crisis(item: Dictionary, score: float, unit_fx: Dictionary, cost: float) -> Array:
	var ev: Dictionary = item["ev"]
	_remove_item(item)
	_mark_used(ev)
	var cr: Dictionary = W.CRISES[ev["crisis"]]
	var fx := {}
	if score >= 0.62:
		fx = cr["good"].duplicate(true)
		push_news(cr["news_good"], 3)
	elif score >= 0.38:
		for k in cr["bad"].keys():
			if typeof(cr["bad"][k]) == TYPE_DICTIONARY:
				continue
			fx[k] = float(cr["bad"][k]) * 0.4
		push_news("Gestión irregular de la crisis: %s" % cr["title"].to_lower(), 2)
	else:
		fx = cr["bad"].duplicate(true)
		push_news(cr["news_bad"], 3)
		if cr.get("fatal", false):
			end_game("golpe")
			return []
	for k in unit_fx.keys():
		fx[k] = float(fx.get(k, 0.0)) + float(unit_fx[k])
	fx["money"] = float(fx.get("money", 0.0)) - cost
	fx["stress"] = 8.0
	var out := apply_fx(fx, cr["title"])
	remember("crisis_ok" if score >= 0.62 else ("crisis_mal" if score < 0.38 else "crisis_regular"), {"crisis": str(cr["title"]).to_lower()})
	log_history(cr["title"], "Crisis gestionada (%d%%)" % int(score * 100))
	if score >= 0.62:
		Perfil.earn(Perfil.S.EARN["crisis"], "Crisis superada")
		if cr.get("fatal", false):
			Perfil.unlock("democracia")
	if score >= 0.9:
		Perfil.unlock("crisis_perfecta")
	return out


# ================================================================== efectos

func label_of(k: String) -> String:
	if W.METER_INFO.has(k):
		return W.METER_INFO[k]["name"]
	if W.FACTION_INFO.has(k):
		return W.FACTION_INFO[k]["name"]
	match k:
		"money":
			return "Tesoro"
		"monthly":
			return "Saldo mensual"
		"pc":
			return "Capital político"
		"stress":
			return "Estrés"
		"corr":
			return "Corrupción"
		"approval":
			return "Aprobación"
	if W.COUNTRIES.has(k):
		return W.COUNTRIES[k]["name"]
	if W.PARTIES.has(k):
		return W.PARTIES[k]["short"]
	return k


func icon_of(k: String) -> String:
	if W.METER_INFO.has(k):
		return W.METER_INFO[k]["icon"]
	if W.FACTION_INFO.has(k):
		return W.FACTION_INFO[k]["icon"]
	match k:
		"money", "monthly":
			return "dinero"
		"pc":
			return "capital"
		"stress":
			return "estres"
		"corr":
			return "candado"
	if W.COUNTRIES.has(k):
		return "bandera"
	if W.PARTIES.has(k):
		return "votar"
	return "info"


func apply_fx(fx: Dictionary, source: String = "", show: bool = true) -> Array:
	var out := []
	if fx.is_empty():
		return out
	if fx.has("risk"):
		var rk: Dictionary = fx["risk"]
		var sub := fx.duplicate(true)
		sub.erase("risk")
		sub.erase("else")
		out.append_array(apply_fx(sub, source, show))
		if rng.randf() < float(rk.get("p", 0.5)):
			out.append_array(apply_fx(rk.get("fx", {}), source, show))
			if rk.has("news"):
				push_news(fmt(rk["news"]), 3)
			if rk.has("text"):
				result_text.emit(fmt(rk["text"]))
		elif fx.has("else"):
			var el: Dictionary = fx["else"]
			out.append_array(apply_fx(el.get("fx", {}), source, show))
			if el.has("news"):
				push_news(fmt(el["news"]), 3)
			if el.has("text"):
				result_text.emit(fmt(el["text"]))
		return out
	for k in fx.keys():
		var v = fx[k]
		match k:
			"money":
				debt -= float(v)
				out.append({"k": "money", "v": float(v)})
				if float(v) > 0.0:
					Sfx.play("coin", -6.0)
			"monthly":
				monthly_adj += float(v)
				out.append({"k": "monthly", "v": float(v)})
			"pc":
				pc = clampf(pc + float(v), 0.0, 100.0)
				out.append({"k": "pc", "v": float(v)})
			"stress":
				stress = clampf(stress + float(v), 0.0, 100.0)
			"corr":
				corruption = maxf(0.0, corruption + float(v))
			"corr_mult":
				corruption = maxf(0.0, corruption * float(v))
			"unlock":
				Perfil.unlock(str(v))
			"fortune":
				fortune += float(v)
			"approval":
				approval_bonus += float(v)
				out.append({"k": "approval", "v": float(v)})
			"rel":
				for c in v.keys():
					if countries.has(c):
						countries[c]["rel"] = clampf(countries[c]["rel"] + float(v[c]), -100.0, 100.0)
						out.append({"k": c, "v": float(v[c])})
			"party":
				for p in v.keys():
					if parties.has(p):
						parties[p]["rel"] = clampf(parties[p]["rel"] + float(v[p]), 0.0, 100.0)
						out.append({"k": p, "v": float(v[p])})
			"flag":
				for f in (v if v is Array else [v]):
					flags[f] = day
			"unflag":
				for f in (v if v is Array else [v]):
					flags.erase(f)
			"chain":
				for c2 in (v if v is Array else [v]):
					schedule(c2["id"], int(c2.get("delay", 5)))
			"mods":
				for mk in v.keys():
					add_mod(mk, float(v[mk]), int(fx.get("dur", -1)))
			"dur", "news_only", "else":
				pass
			"tax":
				for tk in v.keys():
					taxes[tk] = clampf(taxes[tk] + float(v[tk]), W.TAXES[tk]["min"], W.TAXES[tk]["max"])
			"budget":
				for bk in v.keys():
					budget[bk] = clampf(budget[bk] + float(v[bk]), 0.5, 1.6)
			"treaty":
				pass
			"fire":
				_fire_minister(str(v))
			"reshuffle":
				var keys := ministers.keys()
				keys.erase("jefa")
				keys.shuffle()
				for i in mini(int(v), keys.size()):
					_fire_minister(keys[i])
			"crisis":
				var cev := {"id": "crisis_" + str(v), "type": "crisis", "crisis": str(v), "title": W.CRISES[str(v)]["title"], "text": W.CRISES[str(v)]["desc"], "gen": true}
				spawn(cev)
			"nego":
				open_request.emit("nego", v)
			"summit":
				open_request.emit("summit", {"summit": str(v)})
			"speech":
				open_request.emit("speech", {"occasion": v})
			"debate":
				open_request.emit("debate", {})
			"press":
				open_request.emit("press", {"mode": v})
			"skip":
				for i in int(v):
					advance_day()
			"term":
				term_days += int(v)
			"adelanto":
				# Elecciones anticipadas: la legislatura acaba dentro de v días
				term_days = mini(term_days, day + int(v))
				if term_days - day <= 60 and not campaign:
					term_days = day + 61
			"policy":
				if not (v in policies):
					policies.append(v)
			"promise":
				Promesas.add(str(v))
			"memo":
				if v is Dictionary:
					var md: Dictionary = v.duplicate(true)
					var mk := str(md.get("k", ""))
					md.erase("k")
					if mk != "":
						remember(mk, md)
			_:
				if meters.has(k):
					meters[k] = clampf(meters[k] + float(v), 0.0, 100.0)
					add_memory(k, float(v) * 0.5)
					out.append({"k": k, "v": float(v)})
				elif fac.has(k):
					fac[k] = clampf(fac[k] + float(v), 0.0, 100.0)
					add_memory(k, float(v) * 0.5)
					out.append({"k": k, "v": float(v)})
	_update_targets()
	_update_approval()
	if show and out.size() > 0:
		deltas.emit(out)
	stats_changed.emit()
	return out


func preview(fx: Dictionary) -> Array:
	# Lista de efectos visibles [{k, v}] para mostrar en las opciones (sin aplicar)
	var out := []
	for k in fx.keys():
		var v = fx[k]
		if k in ["rel", "party"]:
			for c in v.keys():
				out.append({"k": c, "v": float(v[c])})
		elif k in ["money", "monthly", "pc"] or meters.has(k) or fac.has(k):
			out.append({"k": k, "v": float(v)})
		elif k == "risk":
			out.append({"k": "risk", "v": float(v.get("p", 0.5))})
		elif k in ["nego", "speech", "debate", "press", "crisis"]:
			out.append({"k": k, "v": 0.0})
	return out


func _fire_minister(key: String) -> void:
	if not ministers.has(key):
		return
	var old: String = ministers[key]["name"]
	counters["ceses"] = int(counters.get("ceses", 0)) + 1
	remember("cese", {"name": old, "role": str(ministers[key]["role"]), "key": key, "look": ministers[key].get("look", {})})
	var g := "m" if randf() < 0.5 else "f"
	var nm := DB.rand_name(g)
	var role: String = ministers[key]["role"]
	if g == "f":
		role = role.replace("Ministro", "Ministra")
	else:
		role = role.replace("Ministra", "Ministro")
	var traits := [W.TRAITS.keys().pick_random()]
	if key == "jefa":
		role = "Jefa de Gabinete" if g == "f" else "Jefe de Gabinete"
	ministers[key] = {"name": nm, "role": role, "look": DB.rand_look(g), "traits": traits}
	_recalc_traits()
	push_news("%s sustituye a %s como %s" % [nm, old, role.to_lower()], 2)


func push_news(text: String, importance: int = 1) -> void:
	news_feed.push_front({"t": text, "day": day, "imp": importance})
	if news_feed.size() > 40:
		news_feed.resize(40)
	month_log.append({"t": text, "day": day, "imp": importance})
	headline.emit(text)


## Anota algo que el presidente ha hecho para que los personajes lo recuerden más adelante
func remember(kind: String, data: Dictionary = {}) -> void:
	memo.append({"k": kind, "d": data, "day": day})
	if memo.size() > 300:
		memo.pop_front()


func log_history(title: String, choice: String) -> void:
	history.push_front({"day": day, "title": title, "choice": choice})
	if history.size() > 200:
		history.resize(200)


func fmt(s: String) -> String:
	if not "{" in s:
		return s
	var opp: String = W.PLAYER_PARTIES[pres["party"]]["opp"]
	var d := {
		"pres": pres["name"], "pais": "Valdoria", "cap": "Santa Aurora",
		"opo": opo_name(), "opo_party": W.PARTIES[opp]["name"], "party": W.PARTIES[pres["party"]]["name"],
		"jefa": ministers.get("jefa", {}).get("name", ""), "min_eco": ministers.get("economia", {}).get("name", ""),
		"min_int": ministers.get("interior", {}).get("name", ""), "min_ext": ministers.get("exteriores", {}).get("name", ""),
		"min_def": ministers.get("defensa", {}).get("name", ""), "min_san": ministers.get("sanidad", {}).get("name", ""),
		"paro": UI.num(unemployment(), 1), "crec": UI.num(growth(), 1), "deuda": UI.num(debt_ratio(), 0), "aprob": UI.num(approval, 0),
		"term": "%d años" % ((term_days - term_start) / 365) if term_days - term_start >= 730 else "un año",
		"ultima_ley": W.LAWS[last_law]["name"] if last_law != "" else "última ley",
	}
	return s.format(d)


# ================================================================== leyes y votaciones

func law_available(id: String) -> bool:
	return not (id in policies) and not flags.has("law_pending_" + id)


## Coste en capital político: cada ley aprobada en la legislatura encarece la siguiente un 20 %
func law_cost(id: String) -> int:
	var base := float(W.LAWS[id]["pc"])
	return int(round(base * (1.0 + 0.2 * laws_term)))


func vote_forecast(law: Dictionary, lobby: Dictionary) -> Dictionary:
	# Devuelve {party: prob_si}
	var out := {}
	var ideo: float = law.get("ideo", 0.0)
	for p in parties.keys():
		var pi: float = W.PARTIES[p]["ideo"]
		var dist := absf(pi - ideo)
		var prob: float = 0.5 + (60.0 - dist) / 120.0 + (parties[p]["rel"] - 50.0) / 150.0
		if p == pres["party"]:
			prob = 0.97 - maxf(0.0, dist - 60.0) / 100.0
		else:
			# En difícil los socios exigen más; en fácil se dejan convencer antes
			prob -= [-0.04, 0.0, 0.07][difficulty]
		prob += float(lobby.get(p, 0.0))
		out[p] = clampf(prob, 0.02, 0.98)
	return out


func enact_law(id: String) -> Array:
	var law: Dictionary = W.LAWS[id]
	policies.append(id)
	last_law = id
	laws_term += 1
	Perfil.earn(Perfil.S.EARN["ley"], "Ley aprobada")
	Perfil.unlock("primera_ley")
	if policies.size() >= 5:
		Perfil.unlock("cinco_leyes")
	flags.erase("law_pending_" + id)
	var fx: Dictionary = law.get("fx", {}).duplicate(true)
	var out := apply_fx(fx, law["name"])
	for mk in law.get("mods", {}).keys():
		var lv := float(law["mods"][mk])
		# Los perjudicados se movilizan más que los beneficiados
		add_mod(mk, lv * (LAW_STRENGTH if lv > 0.0 else 1.0), -1)
	if law.has("monthly"):
		monthly_adj += float(law["monthly"])
	if law.has("flag"):
		flags[law["flag"]] = day
	if law.has("term"):
		term_days += int(law["term"])
	push_news("El Congreso aprueba la %s" % law["name"], 3)
	log_history(law["name"], "Ley aprobada")
	remember("ley", {"law": id})
	_update_targets()
	return out


func law_rejected(id: String) -> void:
	flags.erase("law_pending_" + id)
	var law: Dictionary = W.LAWS[id]
	apply_fx({"estabilidad": -4, "pc": -3}, law["name"])
	push_news("Revés parlamentario: el Congreso tumba la %s" % law["name"], 3)
	log_history(law["name"], "Ley rechazada")
	remember("ley_tumbada", {"law": id})


func add_treaty(country: String, type: String) -> void:
	for t in treaties:
		if t["c"] == country and t["type"] == type:
			return
	treaties.append({"c": country, "type": type, "day": day})


# ================================================================== fin de partida

func _check_end() -> void:
	if game_ended:
		return
	if approval < 15.0:
		low_approval_days += 1
		if low_approval_days == 30:
			toast.emit("La calle exige su dimisión. Recupere apoyo o caerá.", "bad", "alerta")
			spawn({"id": "crisis_disturbios_x", "type": "crisis", "crisis": "disturbios", "title": "Revuelta popular", "text": "Protestas masivas exigen la dimisión del presidente.", "gen": true})
		if low_approval_days >= 60:
			end_game("revolucion")
			return
	else:
		low_approval_days = maxi(0, low_approval_days - 2)
	if debt_ratio() > bankruptcy_limit():
		end_game("bancarrota")
		return
	if meters["estabilidad"] < [11.0, 15.0, 19.0][difficulty] and day > mocion_until and day > 60:
		mocion_until = day + 150
		open_request.emit("vote", {"mode": "mocion"})
		return
	var left := term_days - day
	if left == 60 and not campaign:
		campaign = true
		flags["campana"] = day
		campaign_acts = 3
		_campaign_days = 0
		toast.emit("¡Comienza la campaña electoral! Use el micrófono para organizar actos por las regiones.", "info", "votar")
		push_news("Arranca la campaña electoral", 3)
		Promesas.judge()
		Sfx.music("music_campaign")
		open_request.emit("campaign", {"intro": true})
	if left == 14 and not debate_done:
		debate_done = true
		open_request.emit("debate", {"electoral": true})
	if left <= 0:
		active = false
		open_request.emit("election", {})


## Tras la noche electoral: en el modo infinito, si gana, empieza otra legislatura
func after_election(res: Dictionary) -> void:
	if res.get("won", false):
		terms_won += 1
	if mode == "infinito" and res.get("won", false):
		_new_term(res)
	else:
		end_game("reelegido" if res.get("won", false) else "derrota")


func _new_term(res: Dictionary) -> void:
	term_index += 1
	term_start = day
	term_days = day + 4 * 365
	campaign = false
	debate_done = false
	campaign_bonus = 0.0
	region_bonus = {}
	campaign_acts = 0
	acts_done = 0
	_campaign_days = 0
	laws_term = 0
	flags.erase("campana")
	# El nuevo Congreso sale de las urnas
	var seats_res: Dictionary = res.get("seats", {})
	for p in parties.keys():
		if seats_res.has(p):
			parties[p]["seats"] = int(seats_res[p])
	for p in res.get("allies", []):
		if parties.has(p):
			parties[p]["rel"] = clampf(parties[p]["rel"] + 4.0, 0.0, 100.0)
	# El desgaste de esta legislatura se convierte en fatiga acumulada (más años, más difícil)
	var keep := []
	for m in mods:
		if m.get("tag", "") != "wear":
			keep.append(m)
	mods = keep
	wear = 0.0
	var fat: float = [2.0, 3.0, 4.0][difficulty]
	for f in ["trabajadores", "empresarios", "clase_media", "jovenes", "jubilados"]:
		mods.append({"k": f, "v": -fat, "until": -1, "tag": "fatiga"})
	_recalc_mods()
	# Los eventos vistos pueden volver, pero con menos frecuencia
	for id in used.keys():
		seen_terms[id] = true
	used = {}
	cooldowns = {}
	# La oposición derrotada suele cambiar de líder
	if rng.randf() < 0.6:
		var g := "m" if rng.randf() < 0.5 else "f"
		var opp: String = W.PLAYER_PARTIES[pres["party"]]["opp"]
		opo_override = {"name": DB.rand_name(g), "role": "Líder de la Oposición (%s)" % W.PARTIES[opp]["short"], "look": DB.rand_look(g)}
	_draw_tramas()
	schedule("nueva_legislatura", 2)
	spawn(Promesas.new_term_event(rng))
	timers["control"] = 45
	speech_until = day
	elections_result = res
	game_ended = false
	active = true
	Perfil.unlock_terms(terms_won, float(day) / 365.0)
	push_news("%s inicia su %s legislatura" % [pres["name"], ordinal(term_index)], 3)
	log_history("Elecciones generales", "Victoria · %s legislatura" % ordinal(term_index))
	_update_targets()
	_update_approval()
	stats_changed.emit()
	save_game()


func ordinal(n: int) -> String:
	var names := ["", "primera", "segunda", "tercera", "cuarta", "quinta", "sexta", "séptima", "octava", "novena", "décima"]
	return names[n] if n < names.size() else "%d.ª" % n


func opo_name() -> String:
	if not opo_override.is_empty():
		return str(opo_override["name"])
	var opp: String = W.PLAYER_PARTIES[pres["party"]]["opp"]
	return W.PARTIES[opp]["leader"]


func end_game(reason: String) -> void:
	if game_ended:
		return
	if mode == "infinito":
		Perfil.record_years(float(day) / 365.0)
	game_ended = true
	active = false
	delete_save()
	game_over.emit({"reason": reason})


# ================================================================== elecciones

## Intención de voto nacional del partido del presidente (sin ruido)
func vote_base() -> float:
	# Tras varias legislaturas, crecen las ganas de cambio
	var t := float(term_index - 1)
	var change := 2.5 * t + 0.6 * t * t
	return approval * 0.62 + 1.0 + campaign_bonus + [2.0, -1.0, -3.0][difficulty] - change


func compute_election() -> Dictionary:
	var own: String = pres["party"]
	var base := clampf(vote_base() + rng.randf_range(-2.5, 2.5), 8.0, 58.0)
	var shares := {}
	var rest := 100.0 - base
	var weights := {}
	var wsum := 0.0
	var opp: String = W.PLAYER_PARTIES[own]["opp"]
	for p in W.PARTIES.keys():
		if p == own:
			continue
		var w := float(W.SEATS[own][p])
		if p == opp:
			w *= 1.0 + (55.0 - approval) / 60.0
		w *= 0.8 + (100.0 - parties[p]["rel"]) / 250.0
		weights[p] = maxf(4.0, w)
		wsum += weights[p]
	for p in weights.keys():
		shares[p] = rest * weights[p] / wsum
	shares[own] = base
	# Resultados por región
	var regions := {}
	var seats := {}
	for p in W.PARTIES.keys():
		seats[p] = 0
	var total_seats := 350
	var assigned := 0
	var rkeys := W.REGIONS.keys()
	for i in rkeys.size():
		var rid: int = rkeys[i]
		var r: Dictionary = W.REGIONS[rid]
		var rs := {}
		var local := 0.0
		for f in r["demo"].keys():
			local += (fac[f] - approval) * float(r["demo"][f]) * 0.35
		local += region_boost(rid)
		var rsum := 0.0
		for p in shares.keys():
			var s: float = shares[p]
			if p == own:
				s = maxf(3.0, s + local + rng.randf_range(-3.0, 3.0))
			else:
				s = maxf(1.0, s * rng.randf_range(0.8, 1.2))
			if p == "CR":
				s *= 2.5 if rid == 8 else 0.7
			rs[p] = s
			rsum += s
		for p in rs.keys():
			rs[p] = rs[p] / rsum * 100.0
		var n := int(round(total_seats * float(r["pop"])))
		if i == rkeys.size() - 1:
			n = total_seats - assigned
		assigned += n
		var alloc := _dhondt(rs, n)
		for p in alloc.keys():
			seats[p] += alloc[p]
		var winner := ""
		var best := -1.0
		for p in rs.keys():
			if rs[p] > best:
				best = rs[p]
				winner = p
		regions[rid] = {"shares": rs, "winner": winner, "seats": alloc}
	var allies := 0
	var ally_list := []
	for p in seats.keys():
		# El principal partido rival nunca apoya al Gobierno
		if p == own or p == opp:
			continue
		var dist := absf(W.PARTIES[p]["ideo"] - W.PARTIES[own]["ideo"])
		if parties[p]["rel"] >= 60.0 and dist <= 50.0:
			allies += int(seats[p])
			ally_list.append(p)
	# Para presidir el Gobierno, su partido debe ser el más votado de su bloque
	var leads := true
	for p in ally_list:
		if int(seats[p]) > int(seats[own]):
			leads = false
	var won := int(seats[own]) + allies >= 176 and leads
	var first := own
	for p in seats.keys():
		if int(seats[p]) > int(seats[first]):
			first = p
	# Gobierno en minoría: primera fuerza y sin mayoría alternativa posible
	var rival := 0
	for p in seats.keys():
		if p == own or p in ally_list:
			continue
		var d_own := absf(W.PARTIES[p]["ideo"] - W.PARTIES[own]["ideo"])
		var d_opp := absf(W.PARTIES[p]["ideo"] - W.PARTIES[opp]["ideo"])
		if p == opp or d_opp <= d_own:
			rival += int(seats[p])
	var minority := false
	if not won and first == own and rival < 176:
		won = true
		minority = true
	elections_result = {"shares": shares, "seats": seats, "regions": regions, "won": won, "allies": ally_list, "own_seats": seats[own], "first": first, "minority": minority, "rival": rival}
	return elections_result


func region_boost(rid: int) -> float:
	return float(region_bonus.get(str(rid), 0.0))


func add_region_boost(rid: int, v: float) -> void:
	region_bonus[str(rid)] = region_boost(rid) + v


## Intención de voto estimada del partido del presidente en una región (sin ruido)
func region_estimate(rid: int) -> float:
	var base := clampf(vote_base(), 8.0, 58.0)
	var r: Dictionary = W.REGIONS[rid]
	var local := 0.0
	for f in r["demo"].keys():
		local += (fac[f] - approval) * float(r["demo"][f]) * 0.35
	return clampf(base + local + region_boost(rid), 3.0, 80.0)


func _campaign_tick() -> void:
	if not campaign:
		return
	_campaign_days += 1
	if _campaign_days % 8 == 0 and campaign_acts < 4:
		campaign_acts += 1
		toast.emit("Nuevo acto de campaña disponible (%d)" % campaign_acts, "info", "microfono")


func use_campaign_act(n: int = 1) -> bool:
	if campaign_acts < n:
		return false
	campaign_acts -= n
	acts_done += n
	Perfil.earn(Perfil.S.EARN["campana"] * n, "Acto de campaña")
	if acts_done >= 6:
		Perfil.unlock("campana")
	return true


func _dhondt(shares: Dictionary, n: int) -> Dictionary:
	var out := {}
	for p in shares.keys():
		out[p] = 0
	for i in n:
		var best := ""
		var bv := -1.0
		for p in shares.keys():
			if shares[p] < 3.0:
				continue
			var q: float = shares[p] / (out[p] + 1.0)
			if q > bv:
				bv = q
				best = p
		if best != "":
			out[best] += 1
	return out


func legacy_title() -> String:
	if mode == "meme":
		var mt := "El Presidente del Plasma"
		if flags.has("gato"):
			mt = "El Amigo de los Gatos"
		elif corruption > 20.0:
			mt = "El Señor de los Sobres"
		elif approval > 60.0:
			mt = "El Rey de la Sobremesa"
		elif approval < 30.0:
			mt = "El Presidente del 'Bueno... eso'"
		elif meters["economia"] > 65.0:
			mt = "El de la Champions League de la Economía"
		return mt
	var t := "El Superviviente"
	if corruption > 25.0:
		t = "El Presidente de los Sobres"
	elif flags.has("ley_medios") and "ampliar_mandato" in policies:
		t = "El Autócrata"
	elif meters["economia"] > 70.0:
		t = "El Arquitecto del Milagro Económico"
	elif meters["bienestar"] > 70.0:
		t = "El Padre del Estado del Bienestar"
	elif meters["prestigio"] > 72.0:
		t = "El Estadista Global"
	elif meters["ambiente"] > 70.0:
		t = "El Presidente Verde"
	elif meters["seguridad"] > 72.0:
		t = "El Presidente de Hierro"
	elif approval > 65.0:
		t = "El Presidente del Pueblo"
	elif debt_ratio() > 130.0:
		t = "El Gran Endeudador"
	elif approval < 30.0:
		t = "El Presidente Olvidable"
	return t


# ================================================================== guardado

const SAVE_PATH := "user://partida.json"
## Los tests usan otro archivo para no tocar la partida guardada del jugador
var save_path := SAVE_PATH
const SAVE_KEYS := ["day", "pres", "difficulty", "term_days", "meters", "fac", "approval", "approval_bonus", "pc", "stress", "gdp", "debt", "taxes", "budget", "monthly_adj",
	"parties", "countries", "treaties", "policies", "mods", "flags", "history", "news_feed", "month_log", "inbox", "visitors", "alerts", "scheduled", "cooldowns", "used", "timers",
	"ministers", "corruption", "fortune", "stat_hist", "uid_counter", "speech_until", "weather", "celebrate_until", "low_approval_days", "mocion_until", "campaign_bonus", "campaign",
	"debate_done", "last_law", "tutorial", "budget_year_done", "wear", "region_bonus", "campaign_acts", "acts_done", "laws_term", "cycle", "scandals", "unlocks", "mode", "scenario", "tramas", "term_index", "term_start", "terms_won", "opo_override", "seen_terms",
	"promises", "counters", "memo", "cast", "memo_used"]


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


var no_save := false


func save_game() -> void:
	if not active or game_ended or no_save:
		return
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	d["inbox"] = _serial_queue(inbox)
	d["visitors"] = _serial_queue(visitors)
	d["alerts"] = _serial_queue(alerts)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


func _serial_queue(q: Array) -> Array:
	var out := []
	for it in q:
		var c: Dictionary = it.duplicate(true)
		if not it["ev"].get("gen", false):
			c["ev"] = {"ref": it["ev"]["id"]}
		out.append(c)
	return out


func _deserial_queue(q: Array) -> Array:
	var out := []
	for it in q:
		var c: Dictionary = it
		if c["ev"].has("ref"):
			var ev := DB.event(c["ev"]["ref"])
			if ev.is_empty():
				continue
			c["ev"] = ev
		out.append(c)
	return out


func load_game() -> bool:
	if not has_save():
		return false
	var txt := FileAccess.get_file_as_string(save_path)
	var d = JSON.parse_string(txt)
	if not (d is Dictionary):
		return false
	unlocks = {}
	mode = "clasico"
	term_index = 1
	term_start = 0
	terms_won = 0
	opo_override = {}
	seen_terms = {}
	promises = []
	counters = {"ceses": 0, "indultos": 0, "escandalos": 0}
	memo = []
	cast = {}
	memo_used = {}
	for k in SAVE_KEYS:
		if d.has(k):
			set(k, d[k])
	day = int(day)
	difficulty = int(difficulty)
	term_days = int(term_days)
	uid_counter = int(uid_counter)
	speech_until = int(speech_until)
	celebrate_until = int(celebrate_until)
	low_approval_days = int(low_approval_days)
	mocion_until = int(mocion_until)
	budget_year_done = int(budget_year_done)
	for k in timers.keys():
		timers[k] = int(timers[k])
	inbox = _deserial_queue(inbox)
	pres["look"] = Perfil.apply_outfit(pres.get("look", {}))
	campaign_acts = int(campaign_acts)
	acts_done = int(acts_done)
	laws_term = int(laws_term)
	term_index = int(term_index)
	term_start = int(term_start)
	terms_won = int(terms_won)
	scandals = int(scandals)
	cycle = float(cycle)
	if not timers.has("control"):
		timers["control"] = 30
	if not timers.has("summit"):
		timers["summit"] = 100
	_recalc_traits()
	visitors = _deserial_queue(visitors)
	alerts = _deserial_queue(alerts)
	calls = []
	holds = 0
	speed = 1
	game_ended = false
	_recalc_mods()
	_update_targets()
	_update_approval()
	active = true
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
