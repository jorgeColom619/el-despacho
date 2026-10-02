extends "res://scripts/ui/overlay.gd"
## Votación en el Congreso: leyes, presupuestos y mociones de censura.

const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")

const CENTER := Vector2(560, 880)
const R0 := 170.0
const R1 := 440.0

var mode := "law"
var law_id := ""
var law: Dictionary
var seats := []
var lobby := {}
var used := {}
var needed := 176
var hemi: Control
var party_box: VBoxContainer
var forecast: Control
var vote_btn: Button
var voting := false
var done := false
var reveal_n := 0
var yes := 0
var no := 0
var abst := 0
var _t := 0.0
var _tick_t := 0.0
var result_lbl: Label
var counters: Label
var cap_lbl: Label


func build() -> void:
	dim.color = Color(0.015, 0.02, 0.035, 0.96)
	mode = data.get("mode", "law")
	law_id = data.get("law", "")
	if mode == "law":
		law = W.LAWS[law_id]
		if law.get("super", false):
			needed = 234
	elif mode == "mocion":
		law = {"name": "Moción de censura", "desc": "La oposición ha presentado una moción de censura contra su Gobierno. Si obtiene 176 votos a favor, caerá usted y su Gobierno. Consiga que los grupos voten en contra.", "ideo": 0.0}
	elif mode == "budget":
		law = {"name": "Presupuestos Generales del Estado", "desc": data.get("desc", "Proyecto de Presupuestos para el próximo ejercicio."), "ideo": data.get("ideo", 0.0)}
	_build_seats()
	# cabecera
	var head := title_bar(law["name"], "Congreso de los Diputados · Votación", "mazo")
	head.position = Vector2(70, 120)
	root.add_child(head)
	var d := UI.lbl(law.get("desc", ""), UI.f_sans, 19, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(1000, 0)
	d.position = Vector2(70, 205)
	d.size = Vector2(1000, 60)
	root.add_child(d)
	if mode == "law":
		var chips := Widgets.effect_chips(GS.preview(law.get("mods", {})), 15, 8)
		chips.position = Vector2(70, 268)
		chips.size = Vector2(1000, 30)
		root.add_child(chips)
	# hemiciclo
	hemi = Control.new()
	UI.full(hemi)
	hemi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hemi.draw.connect(_draw_hemi)
	root.add_child(hemi)
	counters = UI.lbl("", UI.f_cond_b, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	counters.position = Vector2(260, 900)
	counters.size = Vector2(600, 40)
	root.add_child(counters)
	result_lbl = UI.lbl("", UI.f_cond_b, 72, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	result_lbl.position = Vector2(160, 700)
	result_lbl.size = Vector2(800, 90)
	result_lbl.pivot_offset = Vector2(400, 45)
	root.add_child(result_lbl)
	# grupos parlamentarios
	var right := UI.vbox(10)
	right.position = Vector2(1150, 120)
	right.size = Vector2(720, 900)
	root.add_child(right)
	right.add_child(Widgets.section("Grupos parlamentarios · negocie los apoyos"))
	var cap := UI.lbl("Capital político: %d   ·   Enmiendas: −8 CP (+20%%)   ·   Inversión regional: −1.500 M€ (+25%%)   ·   Presión: −5 CP (+10%%, relación ▼)" % int(GS.pc), UI.f_sans, 14, UI.DIM)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(720, 0)
	cap_lbl = cap
	right.add_child(cap)
	party_box = UI.vbox(6)
	right.add_child(party_box)
	forecast = Control.new()
	forecast.custom_minimum_size = Vector2(720, 70)
	forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forecast.draw.connect(_draw_forecast)
	right.add_child(forecast)
	var bh := UI.hbox(14)
	right.add_child(bh)
	if mode == "law":
		var wd := UI.btn("Retirar el proyecto", "ghost", 18)
		wd.pressed.connect(func():
			if voting:
				return
			GS.flags.erase("law_pending_" + law_id)
			GS.pc += float(law["pc"]) * 0.5
			GS.toast.emit("Proyecto retirado. Recupera la mitad del capital político.", "info", "ley")
			close())
		bh.add_child(wd)
	bh.add_child(UI.spacer(0, 0, true))
	vote_btn = UI.btn("INICIAR VOTACIÓN", "gold", 22)
	vote_btn.pressed.connect(_start_vote)
	bh.add_child(vote_btn)
	_build_parties()


func _build_seats() -> void:
	var rows := 12
	var radii := []
	var total_r := 0.0
	for i in rows:
		var r := lerpf(R0, R1, float(i) / (rows - 1))
		radii.append(r)
		total_r += r
	var pos := []
	var assigned := 0
	for i in rows:
		var n := int(round(350.0 * radii[i] / total_r))
		if i == rows - 1:
			n = 350 - assigned
		assigned += n
		for k in n:
			var a := PI - PI * (k + 0.5) / n
			pos.append({"p": CENTER + Vector2(cos(a), -sin(a)) * radii[i], "a": a})
	pos.sort_custom(func(x, y): return x["a"] > y["a"])
	var idx := 0
	for p in W.PARTY_ORDER:
		var n2: int = int(GS.parties[p]["seats"])
		for k in n2:
			if idx < pos.size():
				seats.append({"p": pos[idx]["p"], "party": p, "vote": 0, "shown": false})
			idx += 1


func _prob() -> Dictionary:
	var out := {}
	if mode == "mocion":
		for p in GS.parties.keys():
			var rel: float = GS.parties[p]["rel"]
			var pr := clampf(1.05 - rel / 70.0, 0.02, 0.97)
			if p == GS.pres["party"]:
				pr = 0.02
			pr -= float(lobby.get(p, 0.0))
			out[p] = clampf(pr, 0.01, 0.99)
		return out
	var base := GS.vote_forecast(law, lobby)
	if mode == "budget":
		var bal := GS.monthly_balance()
		for p in base.keys():
			if p != GS.pres["party"]:
				base[p] = clampf(base[p] - (0.1 if bal < -4000 else 0.0), 0.02, 0.98)
	return base


func _sharp(p: float) -> float:
	var a := pow(p, 2.2)
	var b := pow(1.0 - p, 2.2)
	return a / (a + b)


func _expected_yes() -> float:
	var pr := _prob()
	var e := 0.0
	for p in GS.parties.keys():
		e += float(GS.parties[p]["seats"]) * _sharp(pr[p])
	return e


func _build_parties() -> void:
	for c in party_box.get_children():
		c.queue_free()
	var pr := _prob()
	for p in W.PARTY_ORDER:
		var pd: Dictionary = W.PARTIES[p]
		var col := Color(pd["color"])
		var h := UI.hbox(12)
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(8, 46)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		var nv := UI.vbox(0)
		nv.custom_minimum_size = Vector2(228, 0)
		var own := " (su partido)" if p == GS.pres["party"] else ""
		nv.add_child(UI.lbl(pd["name"] + own, UI.f_sans_b, 17, UI.TEXT))
		nv.add_child(UI.lbl("%d escaños · relación %d" % [int(GS.parties[p]["seats"]), int(GS.parties[p]["rel"])], UI.f_sans, 13, UI.DIM))
		h.add_child(nv)
		var prob: float = pr[p]
		var verb := "a favor" if mode != "mocion" else "a favor de la moción"
		var pl := UI.lbl("%d%% %s" % [int(prob * 100), verb], UI.f_cond_b, 18, UI.color_for(prob * 100.0 if mode != "mocion" else (1.0 - prob) * 100.0))
		pl.custom_minimum_size = Vector2(112, 0)
		h.add_child(pl)
		if p != GS.pres["party"] and not voting:
			for act in [["enmienda", "Enmiendas"], ["inversion", "Inversión"], ["presion", "Presión"]]:
				var b := UI.btn(act[1], "normal", 14)
				b.custom_minimum_size = Vector2(90, 36)
				var key: String = p + act[0]
				b.disabled = used.has(key)
				var a_id: String = act[0]
				b.pressed.connect(func(): _lobby(p, a_id))
				h.add_child(b)
		party_box.add_child(h)
	forecast.queue_redraw()
	if cap_lbl != null:
		cap_lbl.text = "Capital político: %d   ·   Enmiendas: −8 CP (+20%%)   ·   Inversión regional: −1.500 M€ (+25%%)   ·   Presión: −5 CP (+10%%, relación ▼)" % int(GS.pc)


func _lobby(p: String, act: String) -> void:
	var key := p + act
	if used.has(key) or voting:
		return
	match act:
		"enmienda":
			if GS.pc < 8:
				GS.toast.emit("No tiene capital político suficiente", "warn", "capital")
				return
			GS.pc -= 8
			lobby[p] = lobby.get(p, 0.0) + 0.2
		"inversion":
			GS.apply_fx({"money": -1500}, "Inversión regional", false)
			lobby[p] = lobby.get(p, 0.0) + (0.37 if p == "CR" else 0.25)
		"presion":
			if GS.pc < 5:
				GS.toast.emit("No tiene capital político suficiente", "warn", "capital")
				return
			GS.pc -= 5
			lobby[p] = lobby.get(p, 0.0) + 0.1
			GS.parties[p]["rel"] = clampf(GS.parties[p]["rel"] - 5.0, 0.0, 100.0)
	used[key] = true
	Sfx.play("coin" if act == "inversion" else "paper2", -4.0)
	GS.stats_changed.emit()
	_build_parties()


func _draw_forecast() -> void:
	var w := forecast.size.x
	var e := _expected_yes()
	forecast.draw_string(UI.f_sans_b, Vector2(0, 16), "PREVISIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	forecast.draw_rect(Rect2(0, 26, w, 22), Color(1, 1, 1, 0.08))
	var good := e >= needed if mode != "mocion" else e < 176
	forecast.draw_rect(Rect2(0, 26, w * e / 350.0, 22), UI.GREEN if good else UI.RED)
	var nx := w * needed / 350.0
	forecast.draw_line(Vector2(nx, 20), Vector2(nx, 54), Color.WHITE, 2.0)
	forecast.draw_string(UI.f_sans_b, Vector2(nx + 6, 66), "Mayoría: %d" % needed, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT)
	forecast.draw_string(UI.f_cond_b, Vector2(0, 66), "≈ %d votos a favor" % int(e), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.GREEN if good else UI.RED)


func _draw_hemi() -> void:
	hemi.draw_arc(CENTER, R1 + 22, PI, TAU, 96, Color(UI.GOLD, 0.25), 2.0, true)
	hemi.draw_arc(CENTER, R0 - 22, PI, TAU, 64, Color(UI.GOLD, 0.25), 2.0, true)
	for s in seats:
		var col := Color(W.PARTIES[s["party"]]["color"])
		if voting or done:
			if s["shown"]:
				col = Color(0.55, 0.57, 0.6)
				if s["vote"] == 1:
					col = UI.GREEN
				elif s["vote"] == -1:
					col = UI.RED
			else:
				col = col.darkened(0.6)
		hemi.draw_circle(s["p"], 8.5, col)
		hemi.draw_circle(s["p"] + Vector2(-2, -2), 3.0, Color(1, 1, 1, 0.18))
	# tribuna
	hemi.draw_rect(Rect2(CENTER + Vector2(-70, -40), Vector2(140, 40)), Color("3a2012"))
	hemi.draw_rect(Rect2(CENTER + Vector2(-70, -40), Vector2(140, 5)), UI.GOLD)


func _start_vote() -> void:
	if voting:
		return
	voting = true
	vote_btn.disabled = true
	_build_parties()
	var pr := _prob()
	for s in seats:
		var p: float = _sharp(pr[s["party"]])
		var r := randf()
		var ab := 0.06 * (1.0 - absf(p * 2.0 - 1.0))
		if r < p:
			s["vote"] = 1
		elif r < p + ab:
			s["vote"] = 0
		else:
			s["vote"] = -1
	seats.shuffle()
	Sfx.play("gavel", -2.0)


func _process(delta: float) -> void:
	_t += delta
	if voting and not done:
		_tick_t += delta
		var per := 350.0 / 3.6
		var target := mini(350, int(_tick_t * per))
		while reveal_n < target:
			var s: Dictionary = seats[reveal_n]
			s["shown"] = true
			match int(s["vote"]):
				1:
					yes += 1
				-1:
					no += 1
				0:
					abst += 1
			reveal_n += 1
			if reveal_n % 6 == 0:
				Sfx.play("vote_tick", -8.0, randf_range(0.9, 1.2))
		counters.text = "SÍ %d    ·    NO %d    ·    ABST. %d" % [yes, no, abst]
		if reveal_n >= 350:
			_conclude()
	hemi.queue_redraw()


func _conclude() -> void:
	done = true
	var passed := yes >= needed
	await get_tree().create_timer(0.5).timeout
	Sfx.play("gavel", 0.0)
	var text := ""
	var good := false
	match mode:
		"law":
			good = passed
			text = "APROBADA" if passed else "RECHAZADA"
			if passed:
				GS.enact_law(law_id)
				for p in GS.parties.keys():
					var agree := 0
					for s in seats:
						if s["party"] == p and s["vote"] == 1:
							agree += 1
					if agree * 2 < int(GS.parties[p]["seats"]):
						GS.parties[p]["rel"] = clampf(GS.parties[p]["rel"] - 2.0, 0.0, 100.0)
			else:
				GS.law_rejected(law_id)
		"mocion":
			good = not passed
			text = "MOCIÓN RECHAZADA" if not passed else "MOCIÓN APROBADA"
			if passed:
				GS.push_news("La moción de censura triunfa: cae el Gobierno de %s" % GS.pres["name"], 3)
			else:
				GS.apply_fx({"estabilidad": 8, "pc": 5}, "Moción de censura")
				GS.push_news("El Gobierno sobrevive a la moción de censura", 3)
		"budget":
			good = passed
			text = "PRESUPUESTOS APROBADOS" if passed else "PRESUPUESTOS RECHAZADOS"
			if passed:
				var b: Dictionary = data.get("budget", {})
				for k in b.keys():
					GS.budget[k] = b[k]
				var t: Dictionary = data.get("taxes", {})
				for k in t.keys():
					GS.taxes[k] = t[k]
				GS.flags.erase("presupuesto_pendiente")
				GS.push_news("El Congreso aprueba los Presupuestos Generales", 3)
				GS.apply_fx({"estabilidad": 3}, "Presupuestos")
			else:
				GS.flags.erase("presupuesto_pendiente")
				GS.push_news("Revés: el Congreso tumba los Presupuestos del Gobierno", 3)
				GS.apply_fx({"estabilidad": -6, "pc": -5}, "Presupuestos")
	result_lbl.text = text
	result_lbl.add_theme_color_override("font_color", UI.GREEN if good else UI.RED)
	result_lbl.scale = Vector2(2.2, 2.2)
	result_lbl.rotation = deg_to_rad(-4)
	result_lbl.create_tween().tween_property(result_lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("applause" if good else "fail", -3.0)
	await get_tree().create_timer(2.2).timeout
	if mode == "mocion" and passed:
		GS.end_game("censura")
		return
	var b2 := UI.btn("Volver al despacho", "gold", 20)
	b2.position = Vector2(400, 980)
	b2.pressed.connect(func(): close())
	root.add_child(b2)
	UI.pop_in(b2)


func on_escape() -> void:
	if done:
		close()
