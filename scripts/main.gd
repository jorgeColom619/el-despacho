extends Control
## Controlador principal: pantallas, superposiciones, transiciones y atajos.

const Office := preload("res://scripts/office/office.gd")
const Office3D := preload("res://scripts/office3d/office_3d.gd")
const Tex3D := preload("res://scripts/office3d/tex3d.gd")
const Stage3D := preload("res://scripts/stages3d/stage_3d.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const Toasts := preload("res://scripts/ui/toasts.gd")

const OVERLAYS := {
	"doc": "res://scripts/overlays/doc_overlay.gd",
	"advisor": "res://scripts/overlays/advisor_overlay.gd",
	"call": "res://scripts/overlays/call_overlay.gd",
	"nego": "res://scripts/overlays/nego_overlay.gd",
	"summit": "res://scripts/overlays/nego_overlay.gd",
	"control": "res://scripts/overlays/control_overlay.gd",
	"campaign": "res://scripts/overlays/campaign_overlay.gd",
	"phonebook": "res://scripts/overlays/phonebook_overlay.gd",
	"crisis": "res://scripts/overlays/crisis_overlay.gd",
	"vote": "res://scripts/overlays/vote_overlay.gd",
	"press": "res://scripts/overlays/press_overlay.gd",
	"speech": "res://scripts/overlays/speech_overlay.gd",
	"debate": "res://scripts/overlays/debate_overlay.gd",
	"budget": "res://scripts/overlays/budget_overlay.gd",
	"dashboard": "res://scripts/overlays/dashboard_overlay.gd",
	"world": "res://scripts/overlays/world_overlay.gd",
	"newspaper": "res://scripts/overlays/newspaper_overlay.gd",
	"diary": "res://scripts/overlays/diary_overlay.gd",
	"tv": "res://scripts/overlays/tv_overlay.gd",
	"cabinet": "res://scripts/overlays/cabinet_overlay.gd",
	"pause": "res://scripts/overlays/pause_overlay.gd",
	"election": "res://scripts/overlays/election_overlay.gd",
	"tutorial": "res://scripts/overlays/tutorial_overlay.gd",
}

const TIPS := {
	"doc": "Arrastre uno de los sellos sobre el papel para decidir. Active la lupa (tecla L) y pásela por el anexo: la letra pequeña esconde trampas... y a veces corrupción.",
	"advisor": "Cada opción muestra sus efectos previstos (▲ mejora, ▼ empeora). Puede pulsar 1-4 para elegir. Si hay cuenta atrás y se agota, el ministro decidirá por usted.",
	"call": "Atienda las llamadas antes de que dejen de sonar: una llamada perdida enfría la relación con ese país.",
	"nego": "Arrastre su oferta por la regla: en verde la aceptarán, en ámbar su límite está en esa franja y en rojo la rechazarán. Tiene tres intentos y tres comodines de un solo uso; aceptar su propuesta es la salida segura.",
	"crisis": "Arrastre las unidades del panel derecho a las regiones en rojo. Puede redistribuirlas arrastrándolas de nuevo o retirarlas con clic derecho. Algunas unidades tienen efectos secundarios en la opinión pública.",
	"vote": "Antes de votar, negocie con los grupos: enmiendas, inversión regional o presión. Necesita 176 votos a favor.",
	"press": "Elija el tono de cada respuesta. Los medios hostiles castigan la evasión; el humor es una apuesta arriesgada. Si se queda callado, lo pagará.",
	"speech": "Primero elija la frase. Después pulse ESPACIO justo cuando cada palabra dorada cruce la línea para darle énfasis.",
	"budget": "Mueva los deslizadores y vigile el saldo mensual y la reacción de cada grupo. Presentarlo al Congreso es gratis pero pueden tumbarlo.",
	"world": "Haga clic en un país para ver sus acciones diplomáticas. Los tratados comerciales y de inversión impulsan la economía.",
	"dashboard": "En «Agenda legislativa» puede presentar leyes: son la herramienta más poderosa para cambiar el país. En «Congreso» puede reunirse con los grupos para ganar socios.",
	"debate": "Elija la réplica adecuada: datos contra cifras, empatía contra emoción, elegancia contra ataques personales y realismo contra promesas imposibles.",
}

var bg: ColorRect
var screen_holder: Control
var overlay_layer: Control
var toasts: Control
var grain: ColorRect
var fade: ColorRect
var screen: Control
var office: Control
var current_overlay: Control
var queue := []
var debug_shot := ""
var debug_open := ""


func _ready() -> void:
	theme = UI.theme
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg = ColorRect.new()
	bg.color = UI.NAVY
	UI.full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	screen_holder = Control.new()
	UI.full(screen_holder)
	screen_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_holder)
	overlay_layer = Control.new()
	UI.full(overlay_layer)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	toasts = Toasts.new()
	add_child(toasts)
	grain = ColorRect.new()
	UI.full(grain)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grain.gdshader")
	grain.material = gm
	grain.visible = Sfx.settings.get("grain", true)
	add_child(grain)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	UI.full(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot") or a.begins_with("--autotest"):
			GS.no_save = true
	if "--check" in args:
		_check_scripts()
		return
	# texturas del despacho 3D: se preparan en segundo plano mientras se ve el menú
	Tex3D.prewarm(Tex3D.default_specs(OfficeArt.THEMES.get(Perfil.office_theme(), OfficeArt.THEMES["clasico"]), Perfil.wood()) + Stage3D.tex_specs())
	for a in args:
		if a.begins_with("--shot="):
			debug_shot = a.substr(7)
		elif a.begins_with("--open="):
			debug_open = a.substr(7)
		elif a.begins_with("--autotest"):
			var AutoTest = load("res://scripts/autotest.gd")
			var at = AutoTest.new()
			add_child(at)
			at.run(int(a.substr(11)) if a.length() > 11 else 730)
			return
	GS.open_request.connect(_on_request)
	GS.deltas.connect(_on_deltas)
	GS.game_over.connect(_on_game_over)
	GS.result_text.connect(func(t): GS.toast.emit(t, "info", "info"))
	Perfil.earned.connect(_on_earned)
	Perfil.achievement.connect(_on_achievement)
	if "--fps" in args:
		var tm := Timer.new()
		tm.wait_time = 2.0
		tm.autostart = true
		tm.timeout.connect(func(): print("FPS: ", Engine.get_frames_per_second()))
		add_child(tm)
	if "--nograin" in args:
		grain.visible = false
	if "--uitest" in args:
		GS.no_save = true
		var UT = load("res://scripts/uitest.gd")
		var ut = UT.new()
		add_child(ut)
		ut.run(self)
		return
	if debug_shot != "":
		_debug_start()
		if "--nolight" in args and office != null:
			office.light.visible = false
	else:
		show_menu()


# ------------------------------------------------------------------ pantallas

func change_screen(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	screen_holder.add_child(c)
	# el despacho 3D se ve a través del fondo 2D
	bg.visible = c.get("is_3d") != true


func transition(callable: Callable) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.35)
	t.tween_callback(callable)
	t.tween_property(fade, "color:a", 0.0, 0.45)


func show_menu() -> void:
	GS.active = false
	_clear_overlays()
	Sfx.loop_stop("room")
	Sfx.loop_stop("ring")
	Sfx.loop_stop("red")
	Sfx.loop_stop("rain")
	var MainMenu = load("res://scripts/screens/main_menu.gd")
	var m = MainMenu.new()
	m.main = self
	change_screen(m)
	office = null
	Sfx.music("music_menu")


func show_shop() -> void:
	var SH = load("res://scripts/screens/shop.gd")
	var s = SH.new()
	s.main = self
	transition(func(): change_screen(s))


func _on_earned(amount: int, reason: String) -> void:
	toasts.push("+%d Laureles · %s" % [amount, reason], "good", "laurel")


func _on_achievement(id: String) -> void:
	var a: Dictionary = Perfil.S.ACHIEVEMENTS[id]
	toasts.push("¡Logro desbloqueado! %s · +%d Laureles" % [a["name"], int(a["reward"])], "good", "trofeo")
	Sfx.play("success", -2.0)


func show_new_game() -> void:
	var NG = load("res://scripts/screens/new_game.gd")
	var n = NG.new()
	n.main = self
	transition(func(): change_screen(n))


func start_new(opts: Dictionary) -> void:
	transition(func():
		GS.new_game(opts)
		_show_office()
		GS.set_speed(0)
		open_overlay("newspaper", {"intro": true})
		if GS.visitors.size() > 0:
			open_overlay("advisor", {"item": GS.visitors[0]}))


func continue_game() -> void:
	transition(func():
		if GS.load_game():
			_show_office()
			GS.set_speed(0)
			GS.toast.emit("Partida cargada. Pulse ▶ para continuar.", "info", "guardar")
		else:
			show_menu())


func _show_office() -> void:
	_clear_overlays()
	_make_office()
	Sfx.music("music_campaign" if GS.campaign else "music_office")
	Sfx.loop_start("room", "room", -14.0, "Amb")


func _make_office() -> void:
	office = Office3D.new() if Sfx.settings.get("view3d", true) else Office.new()
	if "main" in office:
		office.main = self
	office.request.connect(open_overlay)
	change_screen(office)


## Cambia entre el despacho 2D y el 3D sin cerrar las pantallas abiertas (desde Opciones)
func swap_office() -> void:
	if office == null or not GS.active:
		return
	var want3d: bool = Sfx.settings.get("view3d", true)
	if (office.get("is_3d") == true) == want3d:
		return
	_make_office()


func _clear_overlays() -> void:
	queue.clear()
	for c in overlay_layer.get_children():
		c.queue_free()
	if current_overlay != null:
		current_overlay = null
		GS.holds = 0


# ------------------------------------------------------------------ superposiciones

func open_overlay(kind: String, data: Dictionary = {}) -> void:
	if kind == "newspaper" and data.has("month_day"):
		GS.toast.emit("Ya está en su mesa la nueva edición de El Diario de la República", "info", "prensa")
		if office != null:
			office.objs["newspaper"].pulse = true
		return
	if current_overlay != null:
		queue.append([kind, data])
		return
	var path: String = OVERLAYS.get(kind, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Overlay no disponible: " + kind)
		return
	var scr = load(path)
	var o = scr.new()
	o.main = self
	o.data = data.duplicate(true)
	if kind == "nego":
		o.data["nego"] = true
	current_overlay = o
	if o.pauses_time:
		GS.hold()
	overlay_layer.add_child(o)
	o.closed.connect(_on_overlay_closed.bind(o))
	var tip_key := "nego" if data.get("nego", false) or kind == "nego" else kind
	if TIPS.has(tip_key) and not GS.tutorial.has(tip_key) and GS.active and (debug_shot == "" or debug_shot == "start"):
		GS.tutorial[tip_key] = true
		_add_tip(o, TIPS[tip_key])
	if kind == "newspaper" and office != null:
		office.objs["newspaper"].pulse = false


func _add_tip(o: Control, text: String) -> void:
	var p := PanelContainer.new()
	var st := UI.sb(Color(0.08, 0.1, 0.16, 0.97), 10, UI.GOLD, 2, 16, 16)
	p.add_theme_stylebox_override("panel", st)
	p.position = Vector2(560, 1080)
	p.custom_minimum_size = Vector2(800, 0)
	var h := UI.hbox(14)
	p.add_child(h)
	h.add_child(UI.icon_rect("info", 30, UI.GOLD_L))
	var v := UI.vbox(4)
	v.add_child(UI.lbl("CONSEJO", UI.f_sans_b, 13, UI.GOLD))
	var l := UI.lbl(text, UI.f_sans_m, 18, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	v.add_child(l)
	h.add_child(v)
	var b := UI.btn("Entendido", "gold", 16)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	o.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var target := 1080.0 - p.size.y - 24.0
	var t := p.create_tween()
	t.tween_property(p, "position:y", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.pressed.connect(func():
		var t2 := p.create_tween()
		t2.tween_property(p, "position:y", 1100.0, 0.25)
		t2.tween_callback(p.queue_free))
	Sfx.play("notify", -8.0)


func _on_overlay_closed(_result, o: Control) -> void:
	if o.pauses_time:
		GS.release()
	if current_overlay == o:
		current_overlay = null
	if office != null:
		office._refresh()
	if queue.size() > 0 and not GS.game_ended:
		var nxt: Array = queue.pop_front()
		call_deferred("open_overlay", nxt[0], nxt[1])


func _on_request(kind: String, data: Dictionary) -> void:
	open_overlay(kind, data)


func _on_deltas(items: Array) -> void:
	if office == null:
		return
	const GOOD := Color("a9cf78")
	const BAD := Color("e2705e")
	for it in items:
		var k: String = it["k"]
		var v: float = it["v"]
		var pos: Vector2 = office.hud.anchor_for(k)
		var fmt := func(x: float) -> String: return UI.signed(x, 0)
		var good := GOOD
		if k == "money":
			fmt = func(x: float) -> String: return UI.money(x, true)
		elif k == "monthly":
			fmt = func(x: float) -> String: return UI.money(x, true) + "/mes"
		elif GS.countries.has(k):
			# relaciones con países: junto al globo
			var lbl: String = GS.label_of(k)
			fmt = func(x: float) -> String: return "%s %s" % [lbl, UI.signed(x, 0)]
			pos = office.screen_anchor("globe", Vector2(1784, 560)) if office.has_method("screen_anchor") else Vector2(1784, 560)
		elif GS.parties.has(k):
			# relaciones con partidos: junto al ordenador
			var lbl2: String = GS.label_of(k)
			fmt = func(x: float) -> String: return "%s %s" % [lbl2, UI.signed(x, 0)]
			pos = office.screen_anchor("monitor", Vector2(1410, 520)) if office.has_method("screen_anchor") else Vector2(1410, 520)
		elif k == "pc":
			good = UI.GOLD_L
		toasts.float_delta(k, pos, v, fmt, good, BAD)


func _on_game_over(data: Dictionary) -> void:
	queue.clear()
	Sfx.loop_stop("ring")
	Sfx.loop_stop("red")
	var ES = load("res://scripts/screens/ending.gd")
	var e = ES.new()
	e.main = self
	e.data = data
	transition(func():
		_clear_overlays()
		office = null
		Sfx.loop_stop("room")
		change_screen(e))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_F11:
		Sfx.set_setting("fullscreen", not Sfx.settings["fullscreen"])
		return
	if office == null or not GS.active:
		return
	if current_overlay != null:
		if k == KEY_ESCAPE and current_overlay.has_method("on_escape"):
			current_overlay.on_escape()
		return
	match k:
		KEY_SPACE:
			GS.set_speed(1 if GS.speed == 0 else 0)
		KEY_1:
			GS.set_speed(1)
		KEY_2:
			GS.set_speed(2)
		KEY_3:
			GS.set_speed(3)
		KEY_ESCAPE:
			open_overlay("pause", {})


# ------------------------------------------------------------------ depuración (capturas)

func _check_scripts() -> void:
	var files := []
	_scan("res://scripts", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			print("FALLO: ", f)
			bad += 1
	print("Scripts revisados: %d · con errores: %d" % [files.size(), bad])
	get_tree().quit()


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			_scan(dir + "/" + n, out)
		elif n.ends_with(".gd"):
			out.append(dir + "/" + n)
		n = d.get_next()


## Opciones de partida para las capturas: --dmode=meme --ddiff=0 --dscen=recesion
func _debug_opts() -> Dictionary:
	var o := {"name": "Alejandro Ríos", "party": "MP", "difficulty": 1, "years": 2, "look": {"g": "m", "skin": 1, "hair": "side", "hc": 1}}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dmode="):
			o["mode"] = a.substr(8)
		elif a.begins_with("--ddiff="):
			o["difficulty"] = int(a.substr(8))
		elif a.begins_with("--dscen="):
			o["scenario"] = a.substr(8)
	return o


func _debug_start() -> void:
	if debug_shot == "menu":
		show_menu()
		return
	if debug_shot == "shop":
		show_shop()
		return
	if debug_shot == "start":
		start_new(_debug_opts())
		return
	if debug_shot == "newgame":
		var NG = load("res://scripts/screens/new_game.gd")
		var n = NG.new()
		n.main = self
		change_screen(n)
		return
	GS.new_game(_debug_opts())
	GS.used["bienvenida"] = 0
	GS.scheduled.clear()
	GS.day = 95
	GS.stat_hist["approval"] = [55.0, 52.0, 49.0, 51.0]
	_show_office()
	GS.set_speed(0)
	GS.push_news("El Gobierno aprueba el plan de digitalización", 2)
	match debug_open:
		"diary":
			open_overlay("diary", {"seed": 1})
		"":
			GS.spawn(DB.event("doc_honor"))
			GS.spawn(DB.event("fabrica_cierre"))
			GS.spawn(DB.event("call_kade_acero"))
		"doc":
			GS.spawn(DB.event(OS.get_environment("DOC") if OS.get_environment("DOC") != "" else "doc_honor"))
			open_overlay("doc", {})
		"contract":
			GS.spawn(DB.event("doc_contrato_cazas"))
			open_overlay("doc", {})
		"advisor":
			GS.spawn(DB.event("banco_quiebra"))
			open_overlay("advisor", {"item": GS.visitors[0]})
		"call":
			GS.spawn(DB.event("call_kade_acero"))
			open_overlay("call", {"item": GS.calls[0]})
		"nego":
			open_overlay("nego", {"who": "norland", "topic": "comercio"})
		"summit":
			open_overlay("summit", {"summit": "clima"})
		"campaign":
			GS.campaign = true
			GS.campaign_acts = 4
			GS.add_region_boost(3, 2.5)
			open_overlay("campaign", {})
		"control":
			open_overlay("control", {})
		"controlreply", "controlzasca":
			open_overlay("control", {})
			current_overlay.intro.queue_free()
			current_overlay._next()
			var ov = current_overlay
			var best := debug_open == "controlzasca"
			get_tree().create_timer(1.5).timeout.connect(func(): ov._answer(ov.best_reply() if best else DB.P.DEBATE_REPLIES[0]))
		"controlrun":
			open_overlay("control", {})
			current_overlay.intro.queue_free()
			current_overlay._next()
		"hire":
			open_overlay("cabinet", {})
			current_overlay._open_picker("economia", GS.gen_candidates("economia"))
		"crisis":
			GS.spawn(DB.event("crisis_incendios"))
			open_overlay("crisis", {"item": GS.alerts[0]})
		"crisisrun":
			GS.spawn(DB.event("crisis_incendios"))
			open_overlay("crisis", {"item": GS.alerts[0], "autostart": true})
		"vote":
			open_overlay("vote", {"law": "vivienda"})
		"interview":
			open_overlay("press", {"mode": "entrevista"})
		"interviewrun":
			open_overlay("press", {"mode": "entrevista"})
			current_overlay.intro_panel.queue_free()
			current_overlay._next()
		"pressrun":
			open_overlay("press", {"mode": "rueda"})
			current_overlay.intro_panel.queue_free()
			current_overlay._next()
		"press":
			open_overlay("press", {"mode": "rueda"})
		"speech":
			open_overlay("speech", {"occasion": "nacion"})
		"debate":
			open_overlay("debate", {"electoral": true})
		"live":
			GS.timers["press"] = 9999
			GS.set_speed(3)
		"night":
			GS.campaign = true
			GS.day = GS.term_days - 10
			GS.weather = "storm"
			GS.weather_changed.emit()
			GS.approval = 30.0
			office.window_view.tod = 0.78
			office.window_view.protest = 0.9
		"ending":
			GS.policies = ["vivienda", "transparencia"]
			_on_game_over({"reason": "reelegido"})
		"election":
			GS.day = GS.term_days
			open_overlay("election", {})
		_:
			open_overlay(debug_open, {})
