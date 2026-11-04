extends RefCounted
## El Gran Casino: invitaciones, la noche con dinero público y lo que viene después (el agujero, los favores que se
## cobran los anfitriones y el escándalo cuando sale a la luz). La noche en sí la juega casino_overlay.gd.
## El estado vive en GS.casino:
##   next          día de la próxima invitación
##   visits        noches en el casino · declined: invitaciones rechazadas
##   exposure      0..100: lo cerca que está alguien de tirar del hilo (cada mes puede salir todo)
##   hidden        M€ perdidos y escondidos con contabilidad creativa (cada mes suben la exposición)
##   lost          M€ de dinero público perdidos en total · gambled: M€ sacados para jugar · stash: M€ en Qadar
##   pending       [{"day", "kind", "host", ...}] lo que vuelve: favores de los anfitriones, el exministro que habla
##   discovered    ya salió a la luz (una vez por partida: luego solo queda pagar)
##   witness       el ministro cesado que sabe la verdad

const D := preload("res://scripts/data/casino_data.gd")


static func _c() -> Dictionary:
	if not (GS.casino is Dictionary) or GS.casino.is_empty():
		GS.casino = _fresh()
	return GS.casino


static func _fresh() -> Dictionary:
	return {"next": -1, "visits": 0, "declined": 0, "exposure": 0.0, "hidden": 0.0, "lost": 0.0, "gambled": 0.0,
		"stash": 0.0, "pending": [], "discovered": false, "witness": "", "last_host": ""}


## Nueva partida: la primera invitación llega después de los primeros meses
static func start(rng: RandomNumberGenerator) -> void:
	GS.casino = _fresh()
	var meme := GS.mode == "meme"
	var lo := 95 if meme else 140
	var hi := 170 if meme else 250
	if GS.term_days <= 365:
		lo = 70
		hi = 150
	GS.casino["next"] = rng.randi_range(lo, hi)


static func hosts_for_mode() -> Array:
	var out := []
	for h in D.HOSTS.keys():
		var m: String = D.HOSTS[h]["mode"]
		if m == "todos" or (m == "meme") == (GS.mode == "meme"):
			out.append(h)
	return out


static func sources_for_mode() -> Array:
	var out := []
	for s in D.SOURCES.keys():
		var m: String = D.SOURCES[s]["mode"]
		if m == "todos" or (m == "meme") == (GS.mode == "meme"):
			out.append(s)
	return out


## Datos del anfitrión como personaje (para que entre en el despacho o llame por teléfono)
static func cast_key(host: String) -> String:
	var hd: Dictionary = D.HOSTS.get(host, {})
	var c: String = hd.get("country", "")
	# los líderes extranjeros llaman como líderes; el resto, como personaje propio
	if c != "" and W_LEADER.has(host):
		return c
	var k := "casino_" + host
	if not GS.cast.has(k) and not hd.is_empty():
		GS.cast[k] = {"name": hd["name"], "role": hd["role"], "look": hd["look"]}
	return k


## Los anfitriones que son el líder de su país (Drogan, el Emir)
const W_LEADER := {"emir": true, "drogan": true}


# ------------------------------------------------------------------ día a día

static func tick() -> void:
	var c := _c()
	if GS.game_ended:
		return
	# lo que vuelve (favores, el exministro...)
	var keep := []
	for p in c.get("pending", []):
		if int(p.get("day", 0)) <= GS.day:
			_fire(p)
		else:
			keep.append(p)
	c["pending"] = keep
	if int(c.get("next", -1)) < 0:
		c["next"] = GS.day + GS.rng.randi_range(120, 240)
	if GS.day >= int(c["next"]) and not GS.campaign and GS.term_days - GS.day > 75:
		if GS.visitors.size() < 2 and not _queued():
			invite()
			var meme := GS.mode == "meme"
			c["next"] = GS.day + (GS.rng.randi_range(130, 220) if meme else GS.rng.randi_range(230, 380))
		else:
			c["next"] = GS.day + 5


static func _queued() -> bool:
	for it in GS.visitors:
		if str(it["ev"].get("id", "")).begins_with("casino_"):
			return true
	return false


## La Jefa de Gabinete trae la invitación
static func invite(host: String = "") -> void:
	var c := _c()
	if host == "":
		var hs := hosts_for_mode()
		if hs.size() > 1:
			hs.erase(str(c.get("last_host", "")))
		host = hs[GS.rng.randi() % hs.size()]
	c["last_host"] = host
	var hd: Dictionary = D.HOSTS[host]
	var ev := {"id": "casino_inv_" + host, "type": "advisor", "who": "jefa", "gen": true, "title": hd["title"], "text": hd["invite"],
		"choices": [
			{"t": "Ir al casino. Una noche es una noche.", "fx": {"casino": host}},
			{"t": "Excusarse: «Tengo un compromiso de Estado».", "fx": hd["decline"].duplicate(true), "rec": "jefa"},
		], "default": 1}
	GS.spawn(ev)


## Ha rechazado la invitación (desde casino_overlay o desde la elección de la visita)
static func declined(host: String) -> void:
	var c := _c()
	c["declined"] = int(c.get("declined", 0)) + 1


# ------------------------------------------------------------------ la noche

## Cuentas de la noche: lo que vuelve a cada sitio. night: {"taken", "credit", "chips"}
static func cash_out(night: Dictionary) -> Dictionary:
	var taken := float(night.get("taken", 0.0))
	var credit := float(night.get("credit", 0.0))
	var chips := maxf(0.0, float(night.get("chips", 0.0)))
	var paid_host := minf(chips, credit)
	var owed := credit - paid_host
	var rest := chips - paid_host
	var net := rest - taken
	return {"taken": taken, "credit": credit, "chips": chips, "owed": owed, "profit": maxf(0.0, net), "hole": maxf(0.0, -net), "net": net}


## Cierra la noche: aplica lo ganado o lo perdido según lo que se elija en la caja. Devuelve los efectos (para el
## rótulo final). profit_choice: "tesoro" / "ong" / "cuenta"; cover: "contabilidad" / "recorte" / "culpar" / "prestamo"
static func settle(night: Dictionary, profit_choice: String = "", cover: String = "") -> Array:
	var c := _c()
	var host: String = night.get("host", "magnate")
	var hd: Dictionary = D.HOSTS.get(host, D.HOSTS["magnate"])
	var src: Dictionary = D.SOURCES.get(night.get("source", "reservados"), D.SOURCES["reservados"])
	var r := cash_out(night)
	var fx := {}
	var exp := 4.0 + float(night.get("exposure_add", 0.0))
	var corr := float(night.get("corr_add", 0.0))
	c["visits"] = int(c.get("visits", 0)) + 1
	c["gambled"] = float(c.get("gambled", 0.0)) + float(r["taken"])
	var country: String = hd.get("country", "")
	# el anfitrión dejó ganar: eso se cobra
	if night.get("bribe", "") == "aceptado":
		corr += 4.0
		exp += 5.0
		_schedule({"kind": "favor", "host": host, "strong": false}, 30, 80)
	elif night.get("bribe", "") == "rechazado" and country != "":
		fx["rel"] = {country: -3}
	# crédito sin devolver: una deuda que no es de dinero
	if float(r["owed"]) > 0.0:
		corr += 2.0 + float(r["owed"]) / 300.0
		exp += 4.0
		_schedule({"kind": "favor", "host": host, "strong": true, "amount": r["owed"]}, 25, 70)
	var news := ""
	if float(r["profit"]) > 0.0:
		var p := float(r["profit"])
		match profit_choice:
			"ong":
				fx["approval"] = clampf(p / 150.0, 1.0, 4.0)
				fx["bienestar"] = clampf(p / 300.0, 0.5, 2.0)
				exp += 6.0 + p / 100.0
				news = "El presidente dona %s a la Fundación Cocinas Solidarias: «Un regalo anónimo»" % UI.money(p)
			"cuenta":
				corr += clampf(p / 120.0, 2.0, 12.0)
				c["stash"] = float(c.get("stash", 0.0)) + p
				exp += 4.0
			_:
				fx["money"] = p
				exp += 2.0
	elif float(r["hole"]) > 0.0:
		var h := float(r["hole"])
		var k := clampf(h / 500.0, 0.5, 2.5)
		match cover:
			"recorte":
				fx["money"] = -h
				for key in src["cut"].keys():
					fx[key] = float(fx.get(key, 0.0)) + float(src["cut"][key]) * k
				c["lost"] = float(c.get("lost", 0.0)) + h
				exp += 3.0 + h / 400.0
				news = "Recorte inesperado en %s: «Ajustes técnicos», dice Hacienda" % String(src["name"]).to_lower()
			"culpar":
				fx["money"] = -h
				c["lost"] = float(c.get("lost", 0.0)) + h
				corr += 1.0
				exp += 2.0
				var mk: String = src.get("minister", "economia")
				if GS.ministers.has(mk):
					c["witness"] = str(GS.ministers[mk]["name"])
					c["witness_role"] = str(GS.ministers[mk]["role"])
					c["witness_look"] = GS.ministers[mk].get("look", {})
					fx["fire"] = mk
					news = "Cesado %s por «un grave desfase en las cuentas» de %s" % [GS.ministers[mk]["name"], String(src["name"]).to_lower()]
				_schedule({"kind": "exministro", "source": night.get("source", "")}, 70, 210)
			"prestamo":
				corr += 3.0 + h / 250.0
				exp += 4.0
				if country != "":
					fx["rel"] = {country: 4}
				_schedule({"kind": "favor", "host": host, "strong": true, "amount": h}, 30, 90)
				c["lost"] = float(c.get("lost", 0.0)) + h * 0.5
			_:
				# contabilidad creativa: no cuesta nada... todavía
				corr += 2.0 + h / 300.0
				c["hidden"] = float(c.get("hidden", 0.0)) + h
				exp += 8.0 + h / 80.0
	if corr > 0.0:
		fx["corr"] = corr
	var won := float(r["net"]) >= 0.0
	fx["stress"] = -6.0 if won else 7.0
	c["exposure"] = clampf(float(c.get("exposure", 0.0)) + exp, 0.0, 100.0)
	var out := GS.apply_fx(fx, "Noche en el casino")
	if news != "":
		GS.push_news(news, 2)
	GS.log_history("Noche en el casino (%s)" % hd["name"], ("Ganó %s" % UI.money(float(r["net"]))) if won else ("Perdió %s de dinero público" % UI.money(-float(r["net"]))))
	GS.remember("casino", {"host": hd["name"], "net": float(r["net"]), "source": src["name"]})
	if float(r["net"]) >= 500.0:
		Perfil.unlock("casino_banca")
	return out


static func _schedule(p: Dictionary, lo: int, hi: int) -> void:
	var c := _c()
	p["day"] = GS.day + GS.rng.randi_range(lo, hi)
	c["pending"].append(p)


# ------------------------------------------------------------------ lo que vuelve

static func _fire(p: Dictionary) -> void:
	match str(p.get("kind", "")):
		"favor":
			_favor(p)
		"exministro":
			_exminister(p)
		"mocion":
			if GS.day > GS.mocion_until and not GS.campaign:
				GS.mocion_until = GS.day + 150
				GS.push_news("La oposición registra una moción de censura por el escándalo del casino", 3)
				GS.open_request.emit("vote", {"mode": "mocion"})


## El anfitrión se cobra el favor (la jugada arreglada, el crédito, el préstamo)
static func _favor(p: Dictionary) -> void:
	var host: String = p.get("host", "magnate")
	var hd: Dictionary = D.HOSTS.get(host, D.HOSTS["magnate"])
	var f: Dictionary = hd["favor"]
	var strong: bool = p.get("strong", false)
	var country: String = hd.get("country", "")
	var who := cast_key(host)
	var yes := {"corr": 4.0 if strong else 3.0}
	var no := {}
	match host:
		"magnate":
			yes.merge({"empresarios": 3, "trabajadores": -4, "ambiente": -3, "rel": {"norland": 6}})
			no = {"rel": {"norland": -6}, "empresarios": -2}
		"emir":
			yes.merge({"money": 1500, "trabajadores": -2, "rel": {"qadar": 8}})
			no = {"rel": {"qadar": -10}}
		"drogan":
			yes.merge({"prestigio": -6, "rel": {"kharovia": 10, "union": -10, "norland": -6}})
			no = {"rel": {"kharovia": -14}}
		_:
			yes.merge({"prestigio": -3, "jovenes": 2, "jubilados": 2})
			no = {"jubilados": -2}
	var leak := 24.0 if strong else 14.0
	no["casino_leak"] = leak
	var ev := {"id": "casino_favor_" + host, "type": "call" if W_LEADER.has(host) else "advisor", "who": who, "gen": true,
		"title": f["title"], "text": f["text"] + ("\n\nY no se le olvida lo que le prestó aquella noche." if strong else ""),
		"choices": [
			{"t": "Concedérselo. Hoy por ti...", "fx": yes, "news": "El Gobierno concede a %s lo que pedía" % hd["name"]},
			{"t": "Negarse en redondo.", "fx": no},
		], "default": 1}
	GS.spawn(ev)


## El ministro cesado (al que se le echó la culpa) cuenta la verdad
static func _exminister(_p: Dictionary) -> void:
	var c := _c()
	var nm: String = c.get("witness", "")
	if nm == "" or c.get("discovered", false):
		return
	if GS.rng.randf() > 0.7:
		return
	GS.push_news("%s, exministro cesado: «Sé adónde fue el dinero que me hicieron cargar»" % nm, 3)
	c["exposure"] = clampf(float(c.get("exposure", 0.0)) + 35.0, 0.0, 100.0)
	if GS.rng.randf() < 0.5:
		discover("exministro")


## Efecto especial de algunas respuestas: el anfitrión despechado lo cuenta a la prensa
static func leak(v: float) -> void:
	var c := _c()
	c["exposure"] = clampf(float(c.get("exposure", 0.0)) + v, 0.0, 100.0)
	if c.get("discovered", false):
		return
	GS.push_news("Fuentes cercanas al presidente admiten «noches de casino» en plena legislatura", 2)
	if GS.rng.randf() < v / 60.0:
		discover("filtracion")


## Cada mes: el dinero escondido pesa y alguien puede tirar del hilo
static func monthly() -> void:
	var c := _c()
	if c.get("discovered", false) or int(c.get("visits", 0)) == 0:
		return
	var hidden := float(c.get("hidden", 0.0))
	var e := float(c.get("exposure", 0.0))
	e += hidden / 150.0
	# sin dinero escondido, la gente se va olvidando de aquella noche
	if hidden <= 0.0:
		e *= 0.92
	if GS.flags.has("transparencia"):
		e += 2.0
	c["exposure"] = clampf(e, 0.0, 100.0)
	var p: float = clampf(e / 100.0, 0.0, 0.9) * float([0.09, 0.13, 0.18][GS.difficulty])
	if GS.flags.has("ley_medios"):
		p *= 0.6
	if GS.rng.randf() < p:
		discover("prensa")


## Cuánto dinero público se jugó y se perdió (lo que sale en los titulares)
static func scandal_amount() -> float:
	var c := _c()
	return float(c.get("lost", 0.0)) + float(c.get("hidden", 0.0)) + float(c.get("stash", 0.0))


static func level() -> int:
	var amt := scandal_amount()
	for i in D.SCANDAL_LEVELS.size():
		if amt <= float(D.SCANDAL_LEVELS[i]["max"]):
			return i
	return D.SCANDAL_LEVELS.size() - 1


## Sale todo a la luz: la Jefa de Gabinete entra con la portada de mañana
static func discover(how: String = "prensa") -> void:
	var c := _c()
	if c.get("discovered", false) or GS.game_ended:
		return
	c["discovered"] = true
	var amt := maxf(scandal_amount(), float(c.get("gambled", 0.0)) * 0.25)
	var lv := level()
	var L: Dictionary = D.SCANDAL_LEVELS[lv]
	var head: String = L["head"] % UI.money(amt)
	var base: Dictionary = L["fx"]
	var why: String = {"prensa": "El Heraldo publica mañana las cuentas de sus noches en el casino.",
		"exministro": "El exministro %s lo ha contado todo en una entrevista que sale mañana." % c.get("witness", ""),
		"filtracion": "Alguien ha filtrado a la prensa sus noches en el casino, con fotos."}.get(how, "")
	var text := "%s Titular: «%s».%s" % [why, head, "" if float(c.get("hidden", 0.0)) <= 0.0 else " Y la Intervención del Estado ya busca los %s escondidos en «gastos de representación»." % UI.money(float(c["hidden"]))]
	var face := _scale(base, 0.6)
	face["money"] = -float(c.get("hidden", 0.0))
	face["corr_mult"] = 0.5
	face["casino_face"] = true
	var deny := _scale(base, 0.4)
	deny["risk"] = {"p": 0.45 + 0.1 * lv, "fx": _scale(base, 1.3), "news": "Aparecen las fotos: el presidente, con fichas en la mano"}
	var choices := [
		{"t": "Dar la cara: comparecer, pedir perdón y devolver lo escondido.", "fx": face, "news": "El presidente pide perdón: «Fue un error y lo voy a reparar»", "rec": "jefa"},
		{"t": "Negarlo todo: «Es una campaña de la oposición».", "fx": deny, "news": "El presidente niega haber jugado dinero público"},
	]
	var hd: Dictionary = D.HOSTS.get(str(c.get("last_host", "")), {})
	if not hd.is_empty() and hd.get("country", "") != "":
		var blame := _scale(base, 0.8)
		blame["rel"] = {hd["country"]: -18}
		choices.append({"t": "Culpar a %s: «Fue una encerrona»." % hd["name"], "fx": blame, "news": "El presidente acusa a %s de tenderle una trampa" % hd["name"]})
	if lv >= 1:
		choices.append({"t": "Dimitir.", "fx": {"casino_dimision": true}})
	GS.spawn({"id": "casino_escandalo", "type": "advisor", "who": "jefa", "gen": true, "scandal": true, "front": true,
		"title": "Lo del casino ha salido a la luz", "text": text, "choices": choices, "default": 1})
	GS.push_news(head, 3)
	if GS.Redes.on():
		GS.Redes._push_trend("#PresiEnElCasino", "escandalo", -1.0, head)
	c["exposure"] = 0.0
	# con un escándalo grande, la oposición presenta una moción de censura
	if lv >= 2:
		_schedule({"kind": "mocion"}, 4, 10)


static func _scale(fx: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in fx.keys():
		out[key] = float(fx[key]) * k
	return out


## Efectos propios del casino que llegan por apply_fx (ver game_state.gd)
static func special(key: String, v) -> void:
	var c := _c()
	match key:
		"casino_leak":
			leak(float(v))
		"casino_face":
			# lo escondido se devuelve (el dinero va en la misma respuesta) y ya no hay nada que buscar
			c["hidden"] = 0.0
			c["exposure"] = 0.0
		"casino_dimision":
			GS.end_game("casino")


# ------------------------------------------------------------------ pruebas sin interfaz

## La noche entera, sin interfaz (autotest.gd): saca dinero, juega a la ruleta a sencillas y decide en la caja
static func simulate(host: String, rng: RandomNumberGenerator, careful: bool) -> Dictionary:
	var srcs := sources_for_mode()
	var source: String = srcs[rng.randi() % srcs.size()]
	var amounts: Array = D.SOURCES[source]["amounts"]
	var taken := float(amounts[0 if careful else rng.randi() % amounts.size()])
	var night := {"host": host, "source": source, "taken": taken, "credit": 0.0, "chips": taken, "exposure_add": 0.0, "corr_add": 0.0, "bribe": ""}
	var rounds := rng.randi_range(5, 20)
	for i in rounds:
		var chips := float(night["chips"])
		if chips < 5.0:
			if not careful and rng.randf() < 0.5 and float(night["credit"]) == 0.0:
				night["credit"] = taken * 0.5
				night["chips"] = chips + taken * 0.5
				continue
			break
		# apuestas fijas (una parte de lo que sacó), como hace casi todo el mundo
		var bet := minf(chips, maxf(5.0, snappedf(taken * rng.randf_range(0.05, 0.2), 5.0)))
		if night["bribe"] == "" and i == 3 and rng.randf() < (0.2 if careful else 0.6):
			night["bribe"] = "aceptado"
			night["chips"] = chips + bet
			continue
		night["chips"] = chips + (bet if rng.randf() < 18.0 / 37.0 else -bet)
	var r := cash_out(night)
	var profit_choice: String = ["tesoro", "ong", "cuenta"][rng.randi() % 3]
	var cover: String = ["contabilidad", "recorte", "culpar", "prestamo"][rng.randi() % 4]
	if careful:
		profit_choice = "tesoro"
		cover = "recorte"
	settle(night, profit_choice, cover)
	return r
