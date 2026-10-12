extends Control
## Pantalla final: portada histórica, legado y puntuación.

const Backdrop := preload("res://scripts/screens/backdrop.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")
const Promesas := preload("res://scripts/systems/promesas.gd")

var main: Node
var data: Dictionary = {}

const HEADS := {
	"reelegido": ["¡%s REVALIDA LA PRESIDENCIA!", "Los valdorianos le dan otros cuatro años para culminar su proyecto."],
	"derrota": ["%s PIERDE LAS ELECCIONES", "El presidente reconoce la derrota y felicita a su rival: «El pueblo ha hablado»."],
	"revolucion": ["EL PRESIDENTE %s HUYE DEL PALACIO", "Tras semanas de protestas masivas, un helicóptero saca al presidente de Santa Aurora."],
	"censura": ["CAE EL GOBIERNO DE %s", "El Congreso aprueba la moción de censura. La oposición toma el poder."],
	"golpe": ["GOLPE DE ESTADO: DETENIDO %s", "Una junta militar toma el control del país y suspende la Constitución."],
	"bancarrota": ["VALDORIA, EN QUIEBRA: DIMITE %s", "El país suspende pagos. El Fondo Monetario Global toma el control de las cuentas."],
}


func _ready() -> void:
	UI.full(self)
	add_child(Backdrop.new())
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.78)
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var reason: String = data.get("reason", "derrota")
	var good := reason == "reelegido"
	Sfx.music("", 0.5)
	Sfx.play("sting_win" if good else "sting_lose", -2.0)
	get_tree().create_timer(4.0).timeout.connect(func(): Sfx.music("music_menu", 2.0))
	# portada
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UI.sb(Color(0.93, 0.9, 0.82), 2, Color(0, 0, 0, 0), 0, 30, 30))
	paper.position = Vector2(110, 90)
	paper.custom_minimum_size = Vector2(900, 900)
	paper.rotation = deg_to_rad(-1.5)
	add_child(paper)
	var ink := Color("1a1a1c")
	var pv := UI.vbox(10)
	paper.add_child(pv)
	pv.add_child(UI.lbl("El Diario de la República", UI.f_goth, 64, ink, HORIZONTAL_ALIGNMENT_CENTER))
	var rule := ColorRect.new()
	rule.color = ink
	rule.custom_minimum_size = Vector2(0, 3)
	pv.add_child(rule)
	pv.add_child(UI.lbl("EDICIÓN HISTÓRICA · %s" % UI.date_long(GS.day).to_upper(), UI.f_sans_b, 14, ink, HORIZONTAL_ALIGNMENT_CENTER))
	var h: Array = HEADS.get(reason, HEADS["derrota"])
	if GS.mode == "infinito" and GS.terms_won > 0 and reason != "reelegido":
		var yrs := int(floor(float(GS.day) / 365.0))
		h = ["FIN DE UNA ERA: %s DEJA EL PODER TRAS " + str(yrs) + " AÑOS", "Tras %d legislaturas, el presidente se despide del Palacio. %s" % [GS.term_index, h[1]]]
	var hl := UI.lbl(h[0] % GS.pres["name"].to_upper(), UI.f_serif_k, 50, ink, HORIZONTAL_ALIGNMENT_CENTER)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(840, 0)
	pv.add_child(hl)
	var sl := UI.lbl(h[1], UI.f_serif, 22, Color(ink, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(840, 0)
	pv.add_child(sl)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(840, 420)
	pf.clip_contents = true
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.draw.connect(func(): pf.draw_rect(Rect2(0, 0, 840, 420), Color(0.55, 0.56, 0.58)))
	var p := Portrait.new()
	p.position = Vector2(250, 20)
	p.size = Vector2(340, 408)
	p.track_mouse = false
	pf.add_child(p)
	p.setup(GS.pres["look"], true)
	p.mood = 0.8 if good else -0.6
	pf.modulate = Color(0.85, 0.85, 0.85)
	pv.add_child(pf)
	pv.add_child(UI.lbl("Pasará a la historia como «%s»" % GS.legacy_title(), UI.f_serif_b, 24, ink, HORIZONTAL_ALIGNMENT_CENTER))
	# balance
	var right := UI.vbox(14)
	right.position = Vector2(1090, 110)
	right.size = Vector2(740, 880)
	add_child(right)
	right.add_child(UI.lbl("FIN DE LA PARTIDA", UI.f_sans_b, 16, UI.GOLD))
	right.add_child(UI.lbl("Balance de su presidencia", UI.f_serif_b, 44, UI.CREAM))
	var score := _score(reason)
	var grade := "S" if score >= 90 else ("A" if score >= 75 else ("B" if score >= 60 else ("C" if score >= 45 else "D")))
	var gh := UI.hbox(24)
	var gl := UI.lbl(grade, UI.f_serif_k, 120, UI.GOLD_L)
	gh.add_child(gl)
	var gv := UI.vbox(2)
	gv.add_child(UI.lbl("PUNTUACIÓN", UI.f_sans_b, 14, UI.DIM))
	gv.add_child(UI.lbl("%d / 100" % int(score), UI.f_cond_b, 44, UI.TEXT))
	gv.add_child(UI.lbl("%d días en el cargo" % GS.day, UI.f_sans_m, 18, UI.DIM))
	gh.add_child(gv)
	right.add_child(gh)
	var reward := int(score * 1.5) + (100 if good else 0)
	Perfil.earn(reward, "Fin de la legislatura")
	Perfil.unlock("primera_partida")
	Perfil.add_stat("partidas")
	if good:
		Perfil.add_stat("victorias")
	var rw := UI.hbox(10)
	rw.add_child(UI.icon_rect("laurel", 28, UI.GOLD_L))
	rw.add_child(UI.lbl("+%d Laureles para la Tienda del Palacio" % reward, UI.f_sans_b, 20, UI.GOLD_L))
	right.add_child(rw)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	var laws := GS.policies.size()
	var stats := [
		["Aprobación final", UI.pct(GS.approval, 0)],
		["Economía", UI.num(GS.meters["economia"], 0) + " / 100"],
		["Bienestar", UI.num(GS.meters["bienestar"], 0) + " / 100"],
		["Seguridad", UI.num(GS.meters["seguridad"], 0) + " / 100"],
		["Prestigio internacional", UI.num(GS.meters["prestigio"], 0) + " / 100"],
		["Deuda pública", UI.pct(GS.debt_ratio(), 1) + " del PIB"],
		["Paro", UI.pct(GS.unemployment(), 1)],
		["Leyes aprobadas", str(laws)],
		["Años en el poder", UI.num(float(GS.day) / 365.0, 1)],
		["Tratados internacionales", str(GS.treaty_count())],
	]
	if GS.mode == "infinito":
		stats.append(["Legislaturas", str(GS.term_index)])
		stats.append(["Récord personal", "%s años" % UI.num(float(Perfil.stats.get("record_anios", 0.0)), 1)])
	var ps := Promesas.score()
	if int(ps[1]) > 0:
		stats.append(["Promesas cumplidas", "%d de %d" % [ps[0], ps[1]]])
	if GS.corruption > 10:
		stats.append(["Escándalos acumulados", "Muchos"])
	if GS.fortune > 0:
		stats.append(["Patrimonio en Qadar", "Sin comentarios"])
	for s in stats:
		grid.add_child(UI.lbl(s[0], UI.f_sans, 19, UI.DIM))
		grid.add_child(UI.lbl(s[1], UI.f_cond_b, 22, UI.TEXT))
	if laws > 0:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for l in GS.policies:
			flow.add_child(Widgets.chip(W.LAWS[l]["icon"], W.LAWS[l]["name"], UI.GOLD_L, 14))
		right.add_child(flow)
	right.add_child(UI.spacer(0, 10))
	var bh := UI.hbox(16)
	var again := UI.btn("Nueva legislatura", "gold", 22)
	again.pressed.connect(func(): main.show_new_game())
	bh.add_child(again)
	var menu := UI.btn("Menú principal", "normal", 20)
	menu.pressed.connect(func(): main.transition(func(): main.show_menu()))
	bh.add_child(menu)
	right.add_child(bh)
	paper.pivot_offset = Vector2(450, 450)
	paper.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(paper, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", -4.0)


func _score(reason: String) -> float:
	var s := GS.approval * 0.35
	var avg := 0.0
	for m in GS.METERS:
		avg += GS.meters[m]
	avg /= GS.METERS.size()
	s += avg * 0.3
	s += clampf((120.0 - GS.debt_ratio()) * 0.3, -10.0, 10.0)
	s -= GS.corruption * 0.3
	# cumplir la palabra dada también cuenta
	var ps := Promesas.score()
	s += float(ps[0]) * 3.0 - float(int(ps[1]) - int(ps[0])) * 2.0
	match reason:
		"reelegido":
			s += 30.0
		"derrota":
			s += 8.0
		_:
			s -= 10.0
	if GS.mode == "infinito":
		s += minf(20.0, float(GS.terms_won) * 6.0)
	else:
		s *= clampf(float(GS.day) / maxf(1.0, GS.term_days), 0.3, 1.0)
	return clampf(s, 0.0, 100.0)
