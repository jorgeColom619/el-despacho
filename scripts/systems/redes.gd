extends RefCounted
## El móvil del presidente: la red social «Pío» y los chats privados. Estado en GS.social:
## {followers, feed: [publicaciones], trends: [tendencias], posts: [las del presidente], chats: [conversaciones],
##  last_post, chat_cd, seen_feed (cuántas había al abrir el móvil por última vez)}
##
## Chats: una conversación por persona, como en cualquier móvil: {who, name, role, msgs: [{me, t, day}],
##  state ("nuevo": le han preguntado algo y espera respuesta · "respondido" · "visto" · "charla"),
##  id (el mensaje con respuestas preparadas que espera respuesta), pregunta (su texto), deadline, day (última
##  actividad), unread, mood (cómo le cae el presidente, -10..10), fx_day}

const D := preload("res://scripts/data/social_data.gd")
const W := preload("res://scripts/data/world_data.gd")
const Pais := preload("res://scripts/systems/pais.gd")
const Charla := preload("res://scripts/systems/charla.gd")

const FEED_MAX := 60
const POST_COOLDOWN := 6
const CHAT_DAYS := 6
const MSGS_MAX := 80
const CHATS_MAX := 30


static func start(rng: RandomNumberGenerator) -> void:
	GS.social = {"followers": rng.randi_range(380, 620) * 1000, "feed": [], "trends": [], "posts": [], "chats": [],
		"last_post": -99, "chat_cd": rng.randi_range(6, 12), "seen_feed": 0, "trend_day": -99, "hilos": true}
	# los personajes del móvil: su madre y su jefe/a de comunicación
	var g := "f" if rng.randf() < 0.5 else "m"
	var mlook := DB.rand_look("f")
	mlook["age"] = 2
	mlook["hc"] = 6
	GS.cast["madre"] = {"name": "Mamá", "role": "Su madre", "look": mlook}
	GS.cast["comunicacion"] = {"name": DB.rand_name(g), "role": "Jefa de Comunicación" if g == "f" else "Jefe de Comunicación", "look": DB.rand_look(g)}
	var cg := "f" if rng.randf() < 0.5 else "m"
	GS.cast["ciudadano"] = {"name": "Número desconocido", "role": "Ciudadano" if cg == "m" else "Ciudadana", "look": DB.rand_look(cg)}
	_refresh_trends(true)


static func on() -> bool:
	return GS.social is Dictionary and GS.social.has("feed")


# ------------------------------------------------------------------ cuentas y publicaciones de la gente

static func random_handle() -> Array:
	if randf() < 0.18:
		var f: Array = D.FAMOUS.pick_random()
		return [f[0], f[1], f[2]]
	var a: String = D.HANDLE_FIRST.pick_random()
	var b: String = D.HANDLE_TAIL.pick_random()
	return ["@" + a + b, a.replace("_", " "), "persona"]


static func add_post(text: String, mood: String = "neu", who: Array = [], big: bool = false) -> void:
	if not on():
		return
	if who.is_empty():
		who = random_handle()
	var base := randi_range(3, 60) * (20 if big else 1)
	if who[2] in ["medio", "influencer", "humor"]:
		base *= 8
	GS.social["feed"].push_front({"h": who[0], "n": who[1], "k": who[2], "t": text, "mood": mood, "day": GS.day,
		"likes": base * randi_range(4, 30), "rt": base * randi_range(1, 8)})
	while GS.social["feed"].size() > FEED_MAX:
		GS.social["feed"].pop_back()


## Cada titular genera reacciones (más cuanto más importante es la noticia)
static func on_news(text: String, imp: int) -> void:
	if not on() or text == "":
		return
	var n := 0
	match imp:
		3:
			n = randi_range(1, 3)
		2:
			n = 1 if randf() < 0.55 else 0
		_:
			n = 1 if randf() < 0.18 else 0
	if n == 0:
		return
	var mood := news_mood(text)
	var h := text.left(110)
	for i in n:
		var m := mood
		var r := randf()
		if r < 0.25:
			m = "humor"
		elif r < 0.4:
			m = "neu"
		elif r < 0.5 and mood != "neu":
			# siempre hay quien opina lo contrario
			m = "pos" if mood == "neg" else "neg"
		add_post((D.REACT[m] as Array).pick_random().format({"h": h}), m, [], imp >= 3)
	if imp >= 3:
		_trend_from_news(text, mood)


## ¿La noticia es buena o mala para el Gobierno? (por palabras clave)
static func news_mood(text: String) -> String:
	var t := text.to_lower()
	for w in ["crisis", "última hora", "dimisión", "escándalo", "tumba", "fracasan", "rota", "quiebra", "huelga", "muertos", "víctimas",
			"disturbios", "acorrala", "pierde", "derrota", "cancela", "esquiva", "polémica", "investiga", "detenido", "incumple", "desastrosa", "revés", "malestar", "represalia"]:
		if w in t:
			return "neg"
	for w in ["aprueba", "acuerdo", "gana", "récord", "inaugura", "crece", "se impone", "brillante", "rescata", "salva", "celebra", "condecora", "levanta", "firma", "cumplidas"]:
		if w in t:
			return "pos"
	return "neu"


# ------------------------------------------------------------------ tendencias

static func _tag(text: String) -> String:
	var skip := ["el", "la", "los", "las", "de", "del", "en", "y", "a", "un", "una", "con", "por", "para", "su", "sus", "al", "que", "se", "lo"]
	var words := text.replace("«", "").replace("»", "").replace(":", " ").replace(",", " ").replace(".", " ").split(" ", false)
	var out := ""
	var n := 0
	for w in words:
		var lw := String(w).to_lower()
		if lw in skip or lw.length() < 3:
			continue
		out += lw.left(1).to_upper() + lw.substr(1)
		n += 1
		if n >= 3:
			break
	return "#" + out if out != "" else "#" + W.COUNTRY_NAME


static func _trend_from_news(text: String, mood: String) -> void:
	var t := text.to_lower()
	var kind := "evento"
	if "crisis" in t or "última hora" in t or "víctimas" in t:
		kind = "crisis"
	elif "ley" in t or "congreso aprueba" in t:
		kind = "ley"
	elif "escándalo" in t or "investiga" in t or "corrup" in t:
		kind = "escandalo"
	elif "promesa" in t:
		kind = "promesa"
	elif "acuerdo" in t or "cumbre" in t or "sanciones" in t or "embajador" in t:
		kind = "internacional"
	elif "control" in t or "debate" in t or GS.opo_name().to_lower() in t:
		kind = "oposicion"
	_push_trend(_tag(text.trim_prefix("ÚLTIMA HORA: ")), kind, -1.0 if mood == "neg" else (1.0 if mood == "pos" else 0.0), text)


static func _push_trend(tag: String, kind: String, mood: float, about: String = "") -> void:
	var trends: Array = GS.social["trends"]
	for tr in trends:
		if tr["tag"] == tag:
			tr["n"] = int(tr["n"]) + randi_range(5000, 30000)
			return
	trends.push_front({"tag": tag, "kind": kind, "mood": mood, "n": randi_range(8, 95) * 1000, "day": GS.day, "about": about})
	while trends.size() > 6:
		trends.pop_back()


## Cada semana, las tendencias se renuevan según cómo está el país
static func _refresh_trends(force: bool = false) -> void:
	if not force and GS.day - int(GS.social.get("trend_day", -99)) < 7:
		return
	GS.social["trend_day"] = GS.day
	var trends: Array = GS.social["trends"]
	# las viejas se apagan
	var keep := []
	for tr in trends:
		if GS.day - int(tr.get("day", 0)) < 14:
			keep.append(tr)
	GS.social["trends"] = keep
	if GS.approval < 35.0:
		_push_trend("#DimisionYa", "oposicion", -1.0)
	elif GS.approval > 62.0:
		_push_trend("#Orgullo" + Pais.gent(0).capitalize(), "orgullo", 1.0)
	if GS.corruption > 15.0:
		_push_trend("#LosSobres", "escandalo", -1.0)
	if GS.Promesas.broken().size() > 0:
		_push_trend("#PromesaRota", "promesa", -1.0)
	if GS.campaign:
		_push_trend("#Elecciones%d" % int(UI.date_dict(GS.term_days)["year"]), "oposicion", 0.0)
	if GS.weather in ["storm", "snow"]:
		_push_trend("#Temporal" if GS.weather == "storm" else "#NieveEnSantaAurora", "evento", 0.0)
	if GS.meters.get("economia", 50.0) < 38.0:
		_push_trend("#NoLlegoAFinDeMes", "economia", -1.0)
	elif GS.meters.get("economia", 50.0) > 66.0:
		_push_trend("#BuenasNoticias", "economia", 1.0)
	var filler: Array = (D.FILLER_TRENDS_MEME + D.FILLER_TRENDS) if GS.mode == "meme" else D.FILLER_TRENDS
	while (GS.social["trends"] as Array).size() < 5:
		_push_trend(filler.pick_random(), "meme", 0.0)


# ------------------------------------------------------------------ día a día

static func tick() -> void:
	if not on():
		return
	_unificar()
	_refresh_trends()
	# alguna publicación suelta según el ambiente
	if randf() < 0.35:
		var mood := "good" if GS.approval > 56.0 else ("bad" if GS.approval < 40.0 else "mid")
		add_post((D.AMBIENT[mood] as Array).pick_random(), {"good": "pos", "bad": "neg", "mid": "neu"}[mood])
	# los chats que se quedan en visto caducan
	for c in GS.social["chats"]:
		if c["state"] == "nuevo" and GS.day > int(c["deadline"]):
			_expire_chat(c)
	# llega un mensaje nuevo de vez en cuando
	GS.social["chat_cd"] = int(GS.social.get("chat_cd", 10)) - 1
	if int(GS.social["chat_cd"]) <= 0:
		GS.social["chat_cd"] = randi_range(13, 24)
		new_chat()
	# los seguidores siguen a la aprobación
	GS.social["followers"] = maxi(10000, int(GS.social["followers"]) + int((GS.approval - 45.0) * randf_range(20.0, 120.0)))


## Conversaciones con algo sin leer (o una pregunta sin contestar)
static func unread() -> int:
	if not on():
		return 0
	_unificar()
	var n := 0
	for c in GS.social["chats"]:
		if c["state"] == "nuevo" or int(c.get("unread", 0)) > 0:
			n += 1
	return n


static func new_posts() -> int:
	if not on():
		return 0
	var n := 0
	for p in GS.social["feed"]:
		if int(p.get("day", 0)) > int(GS.social.get("seen_day", -1)):
			n += 1
	return n


# ------------------------------------------------------------------ chats

static func new_chat(force_id: String = "") -> void:
	var pool := _chat_pool(force_id, false)
	if pool.is_empty():
		# ya han salido todos: vuelven los más antiguos
		pool = _chat_pool(force_id, true)
	if pool.is_empty():
		return
	_send_chat(_weighted(pool))


static func _weighted(pool: Array) -> Dictionary:
	var total := 0.0
	for e in pool:
		total += float(e[1])
	var r := randf() * total
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return pool.back()[0]


static func _chat_pool(force_id: String, reuse: bool) -> Array:
	var pool := []
	var used: Dictionary = GS.social.get("used_chats", {})
	for c in D.CHATS + D.CHATS2:
		if force_id != "" and c["id"] != force_id:
			continue
		if used.has(c["id"]) and (c.get("once", false) or not reuse or GS.day - int(used[c["id"]]) < 300):
			continue
		if not GS.check(c.get("cond", {})):
			continue
		if c["who"] == "periodista_inc" and not GS.cast.has("periodista_inc"):
			continue
		var w := float(c.get("w", 1.0)) * Perfil.recent_factor("chat_" + str(c["id"]))
		pool.append([c, w])
	return pool


static func _send_chat(pick: Dictionary) -> void:
	var used: Dictionary = GS.social.get("used_chats", {})
	used[pick["id"]] = GS.day
	GS.social["used_chats"] = used
	GS.used["chat_" + str(pick["id"])] = GS.day
	var who := str(pick["who"])
	var chat := hilo(who)
	# si le había preguntado otra cosa y sigue sin contestar, eso se queda en visto
	if chat["state"] == "nuevo":
		_expire_chat(chat)
	var ch := DB.character(who)
	chat["name"] = ch.get("name", chat["name"])
	chat["role"] = ch.get("role", chat["role"])
	var text := _fmt(str((pick["text"] as Array).pick_random() if pick["text"] is Array else pick["text"]))
	chat["msgs"].append({"me": false, "t": text, "day": GS.day})
	chat["id"] = pick["id"]
	chat["pregunta"] = text
	chat["state"] = "nuevo"
	chat["deadline"] = GS.day + CHAT_DAYS
	chat["unread"] = int(chat.get("unread", 0)) + 1
	_al_dia(chat)
	Sfx.play("notify", -6.0, 1.3)
	GS.toast.emit("Mensaje de %s: «%s»" % [chat["name"], text.left(60) + ("…" if text.length() > 60 else "")], "info", "movil")
	GS.queue_changed.emit()


## La conversación con una persona: una sola por persona (la crea si no existe y crear es true)
static func hilo(who: String, crear := true) -> Dictionary:
	_unificar()
	for c in GS.social["chats"]:
		if String(c["who"]) == who:
			return c
	if not crear:
		return {}
	var ch := DB.character(who)
	var t := {"who": who, "uid": GS.next_uid(), "name": ch.get("name", "?"), "role": ch.get("role", ""), "msgs": [], "state": "charla",
		"id": "", "pregunta": "", "deadline": 0, "day": GS.day, "unread": 0, "mood": 0.0}
	GS.social["chats"].push_front(t)
	while GS.social["chats"].size() > CHATS_MAX:
		GS.social["chats"].pop_back()
	return t


## Conversación con movimiento: arriba del todo y sin pasarse de mensajes
static func _al_dia(t: Dictionary) -> void:
	t["day"] = GS.day
	var msgs: Array = t["msgs"]
	if msgs.size() > MSGS_MAX:
		t["msgs"] = msgs.slice(msgs.size() - MSGS_MAX)
	var chats: Array = GS.social["chats"]
	var i := chats.find(t)
	if i > 0:
		chats.remove_at(i)
		chats.push_front(t)


## Partidas de antes: cada mensaje abría una conversación nueva (salían tres chats de «Mamá»). Se juntan en una
## por persona, con los mensajes en orden. Solo la pregunta más reciente sigue esperando respuesta.
static func _unificar() -> void:
	if not on() or GS.social.get("hilos", false):
		return
	GS.social["hilos"] = true
	var por := {}
	var orden := []
	for c in GS.social["chats"]:
		var w := String(c["who"])
		if not por.has(w):
			por[w] = []
			orden.append(w)
		por[w].append(c)
	var out := []
	for w in orden:
		var lst: Array = por[w]
		lst.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))
		var t: Dictionary = (lst.back() as Dictionary).duplicate(true)
		var msgs := []
		for c in lst:
			msgs.append_array(c.get("msgs", []))
		t["msgs"] = msgs.slice(maxi(0, msgs.size() - MSGS_MAX))
		t["pregunta"] = String((lst.back()["msgs"] as Array)[0]["t"]) if t["state"] == "nuevo" and not (lst.back()["msgs"] as Array).is_empty() else ""
		if t["state"] != "nuevo":
			t["id"] = ""
		t["unread"] = 1 if t["state"] == "nuevo" else 0
		t["mood"] = 0.0
		out.append(t)
	GS.social["chats"] = out


## El presidente escribe con sus propias palabras y la persona le contesta a lo que ha dicho (ver Charla).
## Si le estaban preguntando algo y se entiende qué responde, cuenta como esa respuesta (con sus efectos).
## Devuelve {"t": respuesta, "out": efectos aplicados, "idx": respuesta preparada elegida o -1}
static func escribir(t: Dictionary, texto: String) -> Dictionary:
	texto = texto.strip_edges().substr(0, 280)
	if texto == "" or not on():
		return {}
	t["msgs"].append({"me": true, "t": texto, "day": GS.day})
	var pend := chat_def(String(t.get("id", ""))) if t.get("state", "") == "nuevo" else {}
	var r := Charla.responder(t, texto, pend)
	var out := []
	var idx := int(r.get("idx", -1))
	if idx >= 0:
		var rp: Dictionary = pend["replies"][idx]
		t["state"] = "respondido"
		out.append_array(GS.apply_fx(rp.get("fx", {}).duplicate(true), "Mensaje de " + str(t["name"])))
		GS.log_history("Mensaje de %s" % t["name"], texto)
	elif t.get("state", "") != "nuevo":
		t["state"] = "charla"
	if String(r.get("t", "")) != "":
		t["msgs"].append({"me": false, "t": String(r["t"]), "day": GS.day})
	var fx: Dictionary = r.get("fx", {})
	if not fx.is_empty():
		out.append_array(GS.apply_fx(fx, "Mensaje a " + str(t["name"])))
	if String(r.get("news", "")) != "":
		GS.push_news(String(r["news"]), 2)
	t["unread"] = 0
	_al_dia(t)
	GS.queue_changed.emit()
	return {"t": String(r.get("t", "")), "out": out, "idx": idx}


static func chat_def(id: String) -> Dictionary:
	for c in D.CHATS + D.CHATS2:
		if c["id"] == id:
			return c
	return {}


static func answer_chat(chat: Dictionary, idx: int) -> Array:
	var d := chat_def(chat["id"])
	var reps: Array = d.get("replies", [])
	if idx < 0 or idx >= reps.size() or chat["state"] != "nuevo":
		return []
	var rp: Dictionary = reps[idx]
	chat["state"] = "respondido"
	chat["unread"] = 0
	chat["msgs"].append({"me": true, "t": _fmt(str(rp["t"])), "day": GS.day})
	if str(rp.get("back", "")) != "":
		chat["msgs"].append({"me": false, "t": _fmt(str(rp["back"])), "day": GS.day})
	_al_dia(chat)
	var out := GS.apply_fx(rp.get("fx", {}).duplicate(true), "Mensaje de " + str(chat["name"]))
	GS.log_history("Mensaje de %s" % chat["name"], _fmt(str(rp["t"])))
	GS.queue_changed.emit()
	return out


static func _expire_chat(chat: Dictionary) -> void:
	var d := chat_def(chat["id"])
	chat["state"] = "visto"
	if str(d.get("expire_back", "")) != "":
		chat["msgs"].append({"me": false, "t": _fmt(str(d["expire_back"])), "day": GS.day})
	if not d.get("expire", {}).is_empty():
		GS.apply_fx(d["expire"].duplicate(true), "Mensaje sin contestar", false)
	GS.queue_changed.emit()


static func _fmt(s: String) -> String:
	var hijo := "hija" if str(GS.pres.get("look", {}).get("g", "m")) == "f" else "hijo"
	return GS.fmt(s.format({"hijo": hijo, "Hijo": hijo.capitalize()}))


# ------------------------------------------------------------------ publicar

static func can_post() -> bool:
	return on() and GS.day - int(GS.social.get("last_post", -99)) >= POST_COOLDOWN


static func days_to_post() -> int:
	return maxi(0, POST_COOLDOWN - (GS.day - int(GS.social.get("last_post", -99))))


static func post_text(trend: Dictionary, tone: String) -> String:
	var lines: Array = D.POST_TEXT.get(tone, D.POST_TEXT["sincero"])
	return (lines[absi(hash(str(trend["tag"]) + tone)) % lines.size()] as String).format({"tema": trend["tag"]})


## Publica: devuelve {result, text, likes, rt, replies, out (efectos)}
static func publish(trend: Dictionary, tone: String, text: String = "") -> Dictionary:
	var kind := str(trend.get("kind", "evento"))
	var fit: Dictionary = D.TONE_FIT.get(kind, D.TONE_FIT["evento"])
	var s := float(fit.get(tone, 0.0)) + randf_range(-2.5, 2.5) + (GS.approval - 50.0) / 20.0
	if tone == "humor" and GS.mode == "meme":
		s += 1.5
	if text == "":
		text = post_text(trend, tone)
	var result := "nada"
	var fx := {}
	if s >= 4.0:
		result = "viral"
		fx = {"approval": 1.5, "jovenes": 2}
	elif s >= 1.5:
		result = "bien"
		fx = {"approval": 0.5, "jovenes": 1}
	elif s >= -1.0:
		result = "nada"
	elif s >= -3.5:
		result = "polemica"
		fx = {"approval": -1.0, "clase_media": -1, "jovenes": -1}
	else:
		result = "desastre"
		fx = {"approval": -2.5, "estabilidad": -2, "clase_media": -2}
	if tone == "ataque":
		fx["estabilidad"] = float(fx.get("estabilidad", 0.0)) - 1.0
		fx[W.PLAYER_PARTIES[GS.pres["party"]]["bonus"].keys()[0] if not W.PLAYER_PARTIES[GS.pres["party"]]["bonus"].is_empty() else "trabajadores"] = 1
	var f := int(GS.social["followers"])
	var mult: float = {"viral": 0.06, "bien": 0.02, "nada": 0.004, "polemica": 0.03, "desastre": 0.08}[result]
	var likes := int(f * mult * randf_range(0.6, 1.4) * (1.0 if result in ["viral", "bien", "nada"] else 0.35))
	var rt := int(likes * randf_range(0.15, 0.4))
	var replies := []
	for i in 3:
		replies.append((D.REPLIES_GOOD if result in ["viral", "bien"] or (result == "nada" and randf() < 0.5) else D.REPLIES_BAD).pick_random())
	GS.social["followers"] = f + int(f * {"viral": 0.04, "bien": 0.012, "nada": 0.002, "polemica": -0.004, "desastre": -0.01}[result])
	GS.social["last_post"] = GS.day
	var post := {"day": GS.day, "tag": trend["tag"], "tone": tone, "t": text, "result": result, "likes": likes, "rt": rt, "replies": replies}
	GS.social["posts"].push_front(post)
	GS.social["feed"].push_front({"h": "@Presidencia", "n": GS.pres["name"], "k": "pres", "t": text, "mood": "pres", "day": GS.day, "likes": likes, "rt": rt})
	var out := GS.apply_fx(fx, "Publicación en Pío")
	if result in ["viral", "desastre"]:
		GS.push_news(("El mensaje del presidente sobre %s arrasa en las redes" if result == "viral" else "El mensaje del presidente sobre %s incendia las redes") % trend["tag"], 2)
	if result in ["polemica", "desastre"]:
		GS.remember("tuit_polemico", {"t": text, "tag": trend["tag"]})
	elif result == "viral":
		GS.remember("tuit_viral", {"t": text, "tag": trend["tag"]})
	GS.log_history("Publicación en Pío", text)
	post["out"] = out
	post["msg"] = (D.POST_RESULT[result] as Array).pick_random()
	return post
