extends "res://scripts/ui/overlay.gd"
## Noche electoral: escrutinio en directo región a región.

const Widgets := preload("res://scripts/ui/widgets.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const W := preload("res://scripts/data/world_data.gd")
const Night := preload("res://scripts/stages3d/election_night_3d.gd")

const DURATION := 11.0

var res: Dictionary
var map: Control
var t := 0.0
var done := false
var order := []
var revealed := {}
var bars: Control
var pct_lbl: Label
var list_box: VBoxContainer
var banner: Label
var sub: Label
## Sede del partido en 3D: el escrutinio va en su pantalla gigante, en letra grande (big)
var stage: Control
var big := false


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.98)
	res = GS.compute_election()
	Sfx.music("music_tension", 1.0)
	if Night.enabled():
		_build_3d()
		return
	var head := title_bar("Noche electoral", "Elecciones generales · Escrutinio en directo", "votar")
	head.position = Vector2(70, 110)
	root.add_child(head)
	pct_lbl = UI.lbl("", UI.f_cond_b, 40, UI.GOLD_L, HORIZONTAL_ALIGNMENT_RIGHT)
	pct_lbl.position = Vector2(860, 130)
	pct_lbl.size = Vector2(260, 50)
	root.add_child(pct_lbl)
	map = MapView.new()
	map.position = Vector2(70, 210)
	map.size = Vector2(1050, 798)
	map.mode = 1
	root.add_child(map)
	map.set_mode(1)
	for i in range(1, 9):
		map.set_region(i, Color(0.18, 0.2, 0.24))
	var lbls := Control.new()
	lbls.position = map.position
	lbls.size = map.size
	lbls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbls.draw.connect(func():
		for id in range(1, 9):
			var c: Vector2 = map.centroids.get(id, Vector2.ZERO)
			lbls.draw_string(UI.f_sans_b, c + Vector2(-90, -8), W.REGIONS[id]["name"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color.WHITE)
			if revealed.has(id):
				var win: String = res["regions"][id]["winner"]
				var sh: float = res["regions"][id]["shares"][win]
				lbls.draw_string(UI.f_cond_b, c + Vector2(-90, 18), "%s %s%%" % [W.PARTIES[win]["short"], UI.num(sh, 1)], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color.WHITE))
	root.add_child(lbls)
	set_meta("lbls", lbls)
	var right := UI.vbox(10)
	right.position = Vector2(1170, 210)
	right.size = Vector2(700, 800)
	root.add_child(right)
	right.add_child(Widgets.section("Reparto de escaños"))
	bars = Control.new()
	bars.custom_minimum_size = Vector2(700, 90)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	right.add_child(bars)
	list_box = UI.vbox(8)
	right.add_child(list_box)
	banner = UI.lbl("", UI.f_cond_b, 64, UI.GOLD_L)
	right.add_child(banner)
	sub = UI.lbl("", UI.f_sans_m, 20, UI.TEXT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(700, 0)
	right.add_child(sub)
	order = [1, 2, 3, 4, 5, 6, 7, 8]
	order.shuffle()
	Sfx.play("news", -4.0)


## La sede del partido: la pantalla gigante lleva el escrutinio (mapa, escaños y porcentajes, en tamaño de televisión);
## el resultado final y el botón para seguir quedan delante, abajo
func _build_3d() -> void:
	big = true
	dim.color = Color(0, 0, 0, 0)
	stage = Night.new()
	stage.pres_look = Perfil.apply_outfit(GS.pres["look"])
	root.add_child(stage)
	var tv: Control = stage.ui_screen
	var top := ColorRect.new()
	top.color = Color(W.PARTIES[GS.pres["party"]]["color"]).darkened(0.35)
	top.position = Vector2(0, 0)
	top.size = Vector2(1920, 130)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(top)
	var ttl := UI.lbl("ELECCIONES GENERALES · NOCHE ELECTORAL", UI.f_sans_b, 54, Color.WHITE)
	ttl.position = Vector2(60, 30)
	tv.add_child(ttl)
	pct_lbl = UI.lbl("", UI.f_cond_b, 70, UI.GOLD_L, HORIZONTAL_ALIGNMENT_RIGHT)
	pct_lbl.position = Vector2(1180, 22)
	pct_lbl.size = Vector2(700, 90)
	tv.add_child(pct_lbl)
	map = MapView.new()
	map.position = Vector2(40, 160)
	map.size = Vector2(1000, 760)
	map.mode = 1
	tv.add_child(map)
	map.set_mode(1)
	for i in range(1, 9):
		map.set_region(i, Color(0.18, 0.2, 0.24))
	var lbls := Control.new()
	lbls.position = map.position
	lbls.size = map.size
	lbls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbls.draw.connect(func():
		for id in range(1, 9):
			var c: Vector2 = map.centroids.get(id, Vector2.ZERO)
			lbls.draw_string(UI.f_sans_b, c + Vector2(-120, -12), W.REGIONS[id]["name"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240, 24, Color.WHITE)
			if revealed.has(id):
				var win: String = res["regions"][id]["winner"]
				var sh: float = res["regions"][id]["shares"][win]
				lbls.draw_string(UI.f_cond_b, c + Vector2(-120, 26), "%s %s%%" % [W.PARTIES[win]["short"], UI.num(sh, 1)], HORIZONTAL_ALIGNMENT_CENTER, 240, 36, Color.WHITE))
	tv.add_child(lbls)
	set_meta("lbls", lbls)
	var right := UI.vbox(12)
	right.position = Vector2(1080, 160)
	right.size = Vector2(800, 880)
	tv.add_child(right)
	right.add_child(UI.lbl("ESCAÑOS", UI.f_sans_b, 30, UI.GOLD_L))
	bars = Control.new()
	bars.custom_minimum_size = Vector2(800, 120)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	right.add_child(bars)
	list_box = UI.vbox(10)
	right.add_child(list_box)
	# delante, abajo: el titular del resultado
	var foot := UI.vbox(6)
	foot.position = Vector2(80, 820)
	foot.size = Vector2(1500, 220)
	root.add_child(foot)
	banner = UI.lbl("", UI.f_cond_b, 84, UI.GOLD_L)
	foot.add_child(banner)
	sub = UI.lbl("", UI.f_sans_m, 24, UI.TEXT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(1380, 0)
	foot.add_child(sub)
	set_meta("foot", foot)
	order = [1, 2, 3, 4, 5, 6, 7, 8]
	order.shuffle()
	Sfx.play("news", -4.0)


func _frac() -> float:
	return clampf(t / DURATION, 0.0, 1.0)


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	var f := _frac()
	var ease_f := 1.0 - pow(1.0 - f, 2.0)
	pct_lbl.text = "Escrutado: %s%%" % UI.num(ease_f * 100.0, 1)
	var n := int(f * 8.99)
	for i in mini(n, order.size()):
		var id: int = order[i]
		if not revealed.has(id):
			revealed[id] = true
			var win: String = res["regions"][id]["winner"]
			map.set_region(id, Color(W.PARTIES[win]["color"]))
			Sfx.play("vote_tick", -2.0, 0.8)
	(get_meta("lbls") as Control).queue_redraw()
	bars.queue_redraw()
	_update_list(ease_f)
	if f >= 1.0:
		_conclude()


func _update_list(f: float) -> void:
	for c in list_box.get_children():
		c.queue_free()
	var parties: Array = W.PARTY_ORDER.duplicate()
	parties.sort_custom(func(a, b): return int(res["seats"][a]) > int(res["seats"][b]))
	for p in parties:
		var h := UI.hbox(12)
		var sw := ColorRect.new()
		sw.color = Color(W.PARTIES[p]["color"])
		sw.custom_minimum_size = Vector2(12 if big else 8, 58 if big else 34)
		h.add_child(sw)
		var l := UI.lbl(W.PARTIES[p]["name"] + (" ★" if p == GS.pres["party"] else ""), UI.f_sans_b if p == GS.pres["party"] else UI.f_sans_m, 30 if big else 18, UI.TEXT)
		l.custom_minimum_size = Vector2(430 if big else 330, 0)
		h.add_child(l)
		var vl := UI.lbl(UI.pct(float(res["shares"][p]) * clampf(f * 1.2, 0.0, 1.0) + float(res["shares"][p]) * 0.0, 1), UI.f_sans, 28 if big else 17, UI.DIM)
		vl.custom_minimum_size = Vector2(140 if big else 110, 0)
		h.add_child(vl)
		h.add_child(UI.lbl("%d" % int(round(float(res["seats"][p]) * f)) if big else "%d escaños" % int(round(float(res["seats"][p]) * f)), UI.f_cond_b, 44 if big else 22, UI.TEXT))
		list_box.add_child(h)


func _draw_bars() -> void:
	var w := bars.size.x
	var f := 1.0 - pow(1.0 - _frac(), 2.0)
	var x := 0.0
	var bh := 64.0 if big else 40.0
	for p in W.PARTY_ORDER:
		var sw := w * float(res["seats"][p]) / 350.0 * f
		bars.draw_rect(Rect2(x, 20, sw, bh), Color(W.PARTIES[p]["color"]))
		x += sw
	bars.draw_rect(Rect2(0, 20, w, bh), Color(1, 1, 1, 0.3), false, 1.0)
	var mx := w * 176.0 / 350.0
	bars.draw_line(Vector2(mx, 10), Vector2(mx, 30 + bh), Color.WHITE, 3.0 if big else 2.0)
	bars.draw_string(UI.f_sans_b, Vector2(mx + 8, 52 + bh), "Mayoría absoluta: 176", HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 13, UI.TEXT)


func _conclude() -> void:
	done = true
	_update_list(1.0)
	var won: bool = res["won"]
	var own: String = GS.pres["party"]
	var own_seats := int(res["seats"][own])
	banner.text = "¡REELEGIDO!" if won else "DERROTA ELECTORAL"
	banner.add_theme_color_override("font_color", UI.GREEN if won else UI.RED)
	if won:
		var allies: Array = res["allies"]
		var names := []
		for a in allies:
			names.append(W.PARTIES[a]["short"])
		sub.text = "%s obtiene %d escaños%s. %s seguirá siendo presidente." % [W.PARTIES[own]["name"], own_seats, (" y gobernará con el apoyo de " + ", ".join(PackedStringArray(names))) if names.size() > 0 and own_seats < 176 else "", GS.pres["name"]]
		if res.get("minority", false):
			sub.text = "%s gana con %d escaños. La oposición no suma una mayoría alternativa: %s gobernará en minoría." % [W.PARTIES[own]["name"], own_seats, GS.pres["name"]]
		Sfx.play("cheer", -2.0)
		Perfil.unlock("reelegido")
		if own_seats >= 176:
			Perfil.unlock("rodillo")
		Sfx.play("sting_win", -4.0)
	else:
		var first: String = res["first"]
		sub.text = "%s obtiene %d escaños. %s" % [W.PARTIES[own]["name"], own_seats, ("%s gana las elecciones y formará Gobierno." % W.PARTIES[first]["name"]) if first != own else "No alcanza apoyos suficientes para gobernar."]
		Sfx.play("sting_lose", -2.0)
	UI.pop_in(banner)
	if stage != null:
		stage.finish(won)
	var infinite := GS.mode == "infinito" and won
	var b := UI.btn("Empezar la %s legislatura" % GS.ordinal(GS.term_index + 1) if infinite else "Continuar", "gold", 22)
	b.pressed.connect(func():
		GS.after_election(res)
		if not GS.game_ended:
			close()
			if main != null:
				main.call_deferred("open_overlay", "newspaper", {"new_term": true}))
	if stage != null:
		b.position = Vector2(1580, 990)
		root.add_child(b)
	else:
		list_box.get_parent().add_child(b)


func on_escape() -> void:
	pass
