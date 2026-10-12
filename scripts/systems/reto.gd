extends RefCounted
## Reto del día: la misma partida para todos cada día (sale del número de día del calendario real).

const D := preload("res://scripts/data/reto_data.gd")
const SC := preload("res://scripts/data/scenarios_data.gd")
const Promesas := preload("res://scripts/systems/promesas.gd")


static func today() -> int:
	return Perfil.today_index()


## Todo lo que define el reto de un día: partido, escenario, reglas, promesas, nombre y aspecto
static func spec(idx: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 104729 + 7
	var party: String = ["MP", "CC", "AR"][rng.randi() % 3]
	var scen_keys: Array = SC.SCENARIOS.keys()
	scen_keys.sort()
	var scenario: String = scen_keys[rng.randi() % scen_keys.size()]
	var rule_keys: Array = D.RULES.keys()
	rule_keys.sort()
	var rules := []
	var guard := 0
	while rules.size() < 2 and guard < 50:
		guard += 1
		var r: String = rule_keys[rng.randi() % rule_keys.size()]
		if r in rules or _clash(r, rules):
			continue
		rules.append(r)
	var mode := "meme" if "meme" in rules else "clasico"
	var offered := Promesas.offer(rng, party, mode)
	var promises: Array = offered.slice(3, 6) if "promesas_duras" in rules else [offered[0], offered[1], offered[3]]
	var name: String = D.NAMES[rng.randi() % D.NAMES.size()]
	var g := "f" if name.split(" ")[0] in ["Lucía", "Clara", "Elena", "Irene"] else "m"
	return {"idx": idx, "party": party, "scenario": scenario, "rules": rules, "mode": mode, "promises": promises, "name": name, "g": g,
		"seed": idx * 7919 + 1}


static func _clash(r: String, chosen: Array) -> bool:
	for pair in D.CLASH:
		if r in pair:
			for c in chosen:
				if c in pair and c != r:
					return true
	return false


## Opciones de nueva partida para jugar el reto de hoy
static func game_opts(idx: int) -> Dictionary:
	var s := spec(idx)
	var keep := randi()
	seed(int(s["seed"]) + 11)
	var look := DB.rand_look(s["g"])
	seed(keep)
	look["glasses"] = 0 if look.get("glasses", 0) == 2 and s["g"] == "f" else look.get("glasses", 0)
	return {"name": s["name"], "party": s["party"], "difficulty": 1, "years": 1, "mode": s["mode"], "scenario": s["scenario"],
		"look": look, "promises": s["promises"], "seed": s["seed"], "daily": idx, "rules": s["rules"]}


## Aplica las reglas del día (al final de GS.new_game, antes de las promesas)
static func apply(rules: Array) -> void:
	var own: String = GS.pres["party"]
	for r in rules:
		match r:
			"congreso_hostil":
				for p in GS.parties.keys():
					if p != own:
						GS.parties[p]["rel"] = clampf(GS.parties[p]["rel"] - 15.0, 0.0, 100.0)
			"herencia":
				GS.debt += GS.gdp * 0.2
			"sin_luna":
				for f in GS.FACTIONS:
					GS.fac[f] = clampf(GS.fac[f] - 6.0, 0.0, 100.0)
					GS.add_memory(f, -6.0, 200.0)
			"crisis_cadena":
				GS.flags["reto_crisis"] = 0
				GS.timers["crisis"] = 22
			"ministros_discolos":
				var bad := []
				for t in GS.W.TRAITS.keys():
					if not GS.W.TRAITS[t].get("good", true):
						bad.append(t)
				var i := 0
				for k in GS.ministers.keys():
					var tr: Array = GS.ministers[k].get("traits", [])
					var b: String = bad[i % bad.size()]
					i += 1
					if not (b in tr):
						tr.append(b)
					GS.ministers[k]["traits"] = tr
				GS._recalc_traits()
			"bonanza":
				GS.cycle = 0.8
				GS.meters["economia"] = clampf(GS.meters["economia"] + 8.0, 0.0, 100.0)
				GS.add_memory("economia", 8.0, 250.0)
			"mundo_hostil":
				for c in GS.countries.keys():
					GS.countries[c]["rel"] = clampf(GS.countries[c]["rel"] - 20.0, -100.0, 100.0)
			"plazos":
				GS.flags["reto_plazos"] = 0
			"pc_cero":
				GS.pc = 5.0
			"anticipadas":
				GS.term_days = 270
			"jovenes", "jubilados", "militares", "empresarios", "trabajadores":
				GS.fac[r] = clampf(GS.fac[r] - 15.0, 0.0, 100.0)
				GS.add_memory(r, -15.0, 240.0)
			"sobres":
				GS.corruption = 16.0
			"prima":
				GS.flags["prima"] = 0
			"sequia":
				GS.meters["ambiente"] = clampf(GS.meters["ambiente"] - 12.0, 0.0, 100.0)
				GS.add_memory("ambiente", -12.0, 250.0)
				GS.fac["trabajadores"] = clampf(GS.fac["trabajadores"] - 4.0, 0.0, 100.0)
				GS.push_news("Los embalses de Valdoria, al 18 %: el peor año de sequía en décadas", 3)
	GS._update_targets()
	GS._update_approval()


## Guarda la puntuación del reto: devuelve {best, new_best, streak}
static func record(idx: int, score: float) -> Dictionary:
	var bests: Dictionary = Perfil.stats.get("reto_best", {})
	var key := str(idx)
	var prev := float(bests.get(key, -1.0))
	var new_best := score > prev
	if new_best:
		bests[key] = int(round(score))
	# solo se guardan los últimos 30 días
	var keys := bests.keys()
	keys.sort()
	while keys.size() > 30:
		bests.erase(keys.pop_front())
	Perfil.stats["reto_best"] = bests
	var last := int(Perfil.stats.get("reto_last", -99))
	var streak := int(Perfil.stats.get("reto_streak", 0))
	if last == idx - 1:
		streak += 1
	elif last != idx:
		streak = 1
	Perfil.stats["reto_last"] = idx
	Perfil.stats["reto_streak"] = streak
	Perfil.save_profile()
	return {"best": int(bests.get(key, 0)), "new_best": new_best, "streak": streak}


static func best_today() -> int:
	return int(Perfil.stats.get("reto_best", {}).get(str(today()), -1))


static func streak() -> int:
	var last := int(Perfil.stats.get("reto_last", -99))
	if last < today() - 1:
		return 0
	return int(Perfil.stats.get("reto_streak", 0))
