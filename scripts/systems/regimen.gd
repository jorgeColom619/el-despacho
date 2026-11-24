extends RefCounted
## Reglas del régimen político del país que se gobierna (ver regimenes_data.gd).
##
## Estado en GS.regimen: {"lealtad": 0-100 del pilar del poder, "amano": puntos de amaño para las próximas
##   elecciones, "censura_until", "calma_until", "cd": {acción: día}, "heredero", "transicion",
##   "aviso": día del último aviso de golpe, "mitad": elecciones de mitad de mandato ya celebradas en esta legislatura}

const RD := preload("res://scripts/data/regimenes_data.gd")
const PD := preload("res://scripts/data/paises_data.gd")
const W := preload("res://scripts/data/world_data.gd")


static func tipo(p := "") -> String:
	var f: Dictionary = PD.PAISES.get(p if p != "" else GS.pais, PD.PAISES["valdoria"])
	return String(f.get("regimen", "parlamentaria"))


static func def(p := "") -> Dictionary:
	return RD.REGIMENES[tipo(p)]


static func nuevo() -> Dictionary:
	return {"lealtad": 62.0, "amano": 0.0, "censura_until": 0, "calma_until": 0, "cd": {}, "heredero": false, "transicion": false, "aviso": -999, "mitad": false}


static func _r() -> Dictionary:
	if GS.regimen.is_empty() or not GS.regimen.has("lealtad"):
		GS.regimen = nuevo()
	return GS.regimen


## Cómo se llama la aprobación en este régimen (Aprobación, Legitimidad, Apoyo popular)
static func etiqueta() -> String:
	return String(def().get("aprobacion", "Aprobación"))


static func lealtad() -> float:
	return float(_r()["lealtad"])


static func tiene_pilar() -> bool:
	return String(def().get("pilar", "")) != ""


static func censura() -> bool:
	return GS.day < int(_r()["censura_until"])


static func calma() -> bool:
	return GS.day < int(_r()["calma_until"])


## Probabilidad de que un escándalo llegue a publicarse (libertad de prensa; con censura, mucho menos)
static func prensa() -> float:
	return float(def().get("prensa", 1.0)) * (0.35 if censura() else 1.0)


static func hay_mocion() -> bool:
	return bool(def().get("mocion", true))


static func elecciones() -> String:
	if _r().get("transicion", false):
		return "libres"
	return String(def().get("elecciones", "libres"))


## Puntos de más el día de las elecciones: el control de los medios y el amaño
static func bonus_eleccion() -> float:
	if elecciones() != "controladas":
		return 0.0
	return 6.0 + float(_r()["amano"])


# ------------------------------------------------------------------ cada mes

static func monthly() -> void:
	var r := _r()
	var d := def()
	_mitad_de_mandato()
	if not tiene_pilar():
		return
	var target := 55.0 + (GS.approval - 50.0) * 0.35 + (float(GS.meters["economia"]) - 50.0) * 0.25
	match String(d["pilar"]):
		"militares", "generales":
			target += (float(GS.fac["militares"]) - 50.0) * 0.45 + (float(GS.meters["seguridad"]) - 50.0) * 0.15
		"oligarcas":
			target += (float(GS.fac["empresarios"]) - 50.0) * 0.35 + minf(GS.corruption, 30.0) * 0.15
		"politburo":
			target += GS.growth() * 2.5 + (float(GS.meters["estabilidad"]) - 50.0) * 0.2
		"familia":
			target += (float(GS.meters["estabilidad"]) - 50.0) * 0.3 + (6.0 if r.get("heredero", false) else 0.0)
	if r.get("transicion", false):
		target -= 12.0
	r["lealtad"] = clampf(float(r["lealtad"]) + (target - float(r["lealtad"])) * 0.15 + GS.rng.randf_range(-2.0, 2.0), 0.0, 100.0)
	_golpe()


## Si el pilar del poder deja de apoyarle: primero rumores (y un aviso), luego el golpe
static func _golpe() -> void:
	var r := _r()
	var l := float(r["lealtad"])
	var fragil := tipo() == "fragil"
	# en una democracia frágil, además, el país tiene que estar desordenado
	if fragil and float(GS.meters["estabilidad"]) > 35.0:
		return
	if l < 30.0 and GS.day - int(r["aviso"]) > 120 and not GS._is_queued("aviso_golpe"):
		r["aviso"] = GS.day
		_aviso()
		return
	if l < 15.0 and GS.rng.randf() < 0.35:
		GS.end_game(final_caida())


static func final_caida() -> String:
	match tipo():
		"partido_unico":
			return "purgado"
		"monarquia":
			return "golpe_palacio"
		"junta":
			return "contragolpe"
	return "golpe"


static func _aviso() -> void:
	var d := def()
	var titulo := "Ruido de sables"
	var texto := "Presidente, el servicio de inteligencia avisa: varios generales se reúnen a escondidas. Hablan de «salvar a la patria». Si no hacemos algo, el próximo comunicado lo leerán ellos en la televisión."
	match tipo():
		"autoritaria":
			titulo = "Los oligarcas conspiran"
			texto = "Presidente, los grandes empresarios que le apoyaban se reúnen en sus yates. Sus televisiones ya no le tratan igual y en los servicios de seguridad hay quien escucha. Si se ponen de acuerdo, le dejarán caer."
		"partido_unico":
			titulo = "Murmullos en el Politburó"
			texto = "Presidente, en el Politburó se forma una mayoría contra usted. Le reprochan el rumbo y los errores. En el Partido, quien pierde la confianza de los suyos acaba purgado."
		"monarquia":
			titulo = "Intrigas en palacio"
			texto = "Majestad, sus primos y tíos se reúnen sin usted. Los clérigos dudan y la guardia real escucha a quien paga más. En esta familia, los golpes de palacio no son una leyenda."
	GS.spawn({"id": "aviso_golpe", "type": "advisor", "who": "interior", "gen": true, "title": titulo, "text": texto,
		"choices": [
			{"t": "Comprar lealtades: dinero y cargos.", "fx": {"money": -1200, "corr": 4, "regimen": {"lealtad": 18}}, "rec": "interior"},
			{"t": "Golpear primero: detenciones y destituciones.", "fx": {"estabilidad": -5, "prestigio": -4, "regimen": {"lealtad": 12}}},
			{"t": "Ceder: dar más poder a %s." % String(d.get("pilar_name", "los descontentos")).to_lower().replace("lealtad de ", "").replace("confianza del ", "").replace("paciencia del ", ""), "fx": {"pc": -10, "estabilidad": 2, "regimen": {"lealtad": 10}}},
			{"t": "Son rumores. No hacer nada.", "fx": {}}],
		"default": 3})


## Elecciones de mitad de mandato (república presidencial): a los dos años se renueva el Congreso
static func _mitad_de_mandato() -> void:
	var r := _r()
	if not bool(def().get("mitad", false)) or r.get("mitad", false) or GS.day < GS.term_start + 730 or GS.term_days - GS.day < 200:
		return
	r["mitad"] = true
	var res: Dictionary = GS.compute_election()
	var own: String = GS.pres["party"]
	var antes := int(GS.parties[own]["seats"])
	for p in GS.parties.keys():
		if res.get("seats", {}).has(p):
			GS.parties[p]["seats"] = int(res["seats"][p])
	var ahora := int(GS.parties[own]["seats"])
	var nm: String = W.PARTIES[own]["name"]
	if ahora < antes:
		GS.push_news("Elecciones de mitad de mandato: %s pierde %d escaños en el Congreso" % [nm, antes - ahora], 3)
	else:
		GS.push_news("Elecciones de mitad de mandato: %s gana %d escaños en el Congreso" % [nm, ahora - antes], 3)
	GS.toast.emit("Elecciones de mitad de mandato: su partido tiene ahora %d escaños" % ahora, "info", "votar")
	GS.log_history("Elecciones de mitad de mandato", "%d → %d escaños" % [antes, ahora])


# ------------------------------------------------------------------ final del mandato

## Al acabar el mandato. Devuelve true si el régimen se ocupa (no hay elecciones normales).
static func fin_de_mandato() -> bool:
	var lim := int(def().get("limite", 0))
	if lim > 0 and GS.term_index >= lim and elecciones() == "libres":
		GS.push_news("%s se despide tras %d mandatos: la Constitución no permite más" % [GS.pres["name"], lim], 3)
		GS.end_game("limite")
		return true
	if elecciones() != "ninguna":
		return false
	# sin elecciones: decide el Partido, la familia real o la Junta
	var score := GS.approval * 0.5 + lealtad() * 0.5 + GS.rng.randf_range(-8.0, 8.0)
	var quien := String(def().get("revision", "la cúpula del régimen"))
	if score >= 45.0:
		GS.terms_won += 1
		GS.push_news("%s renueva su confianza en %s" % [quien.capitalize(), GS.pres["name"]], 3)
		if GS.mode == "infinito":
			GS._new_term({})
			_r()["mitad"] = false
		else:
			GS.end_game("consolidado")
	else:
		GS.push_news("%s retira su confianza a %s" % [quien.capitalize(), GS.pres["name"]], 3)
		GS.end_game(final_caida())
	return true


## Tras unas elecciones: un amaño grande se nota (protestas y condena exterior); una transición ganada es historia
static func tras_elecciones(res: Dictionary) -> bool:
	var r := _r()
	if float(r["amano"]) >= 8.0:
		GS.push_news("Los observadores internacionales denuncian un fraude masivo en las elecciones", 3)
		GS.apply_fx({"estabilidad": -6, "jovenes": -5, "prestigio": -4, "rel_democracias": -10}, "Fraude electoral", false)
	r["amano"] = 0.0
	if r.get("transicion", false) and res.get("won", false):
		GS.end_game("transicion")
		return true
	return false


# ------------------------------------------------------------------ poderes del régimen

static func acciones() -> Array:
	return def().get("acciones", [])


static func espera(id: String) -> int:
	return maxi(0, int(_r()["cd"].get(id, 0)) - GS.day)


static func usar(id: String) -> void:
	for a in acciones():
		if a["id"] != id or espera(id) > 0:
			continue
		var fx: Dictionary = a["fx"].duplicate(true)
		if fx.has("pc") and float(fx["pc"]) < 0.0 and GS.pc < -float(fx["pc"]):
			GS.toast.emit("No tiene capital político suficiente", "warn", "capital")
			return
		_r()["cd"][id] = GS.day + int(a["cd"])
		GS.apply_fx(fx, String(a["name"]))
		if String(a.get("news", "")) != "":
			GS.push_news(GS.fmt(String(a["news"])), 2)
		GS.log_history("Régimen", String(a["name"]))
		return


## Efectos «regimen» de las decisiones y acciones
static func fx(v: Dictionary) -> void:
	var r := _r()
	if v.has("lealtad"):
		r["lealtad"] = clampf(float(r["lealtad"]) + float(v["lealtad"]), 0.0, 100.0)
	if v.has("amano"):
		r["amano"] = minf(20.0, float(r["amano"]) + float(v["amano"]))
	if v.has("censura"):
		r["censura_until"] = GS.day + int(v["censura"])
	if v.get("calma", false):
		r["calma_until"] = GS.day + 90
		GS.low_approval_days = 0
	if v.get("heredero", false):
		r["heredero"] = true
	if v.get("transicion", false):
		r["transicion"] = true


## «rel_democracias»: cambio de relación con todos los países democráticos
static func rel_democracias(v: float) -> Dictionary:
	var out := {}
	for c in RD.DEMOCRACIAS:
		if GS.countries.has(c):
			out[c] = v
	return out
