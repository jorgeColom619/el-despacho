extends Control
## El despacho presidencial: centro del juego.

signal request(kind: String, data: Dictionary)

const OfficeArt := preload("res://scripts/office/office_art.gd")
const WindowView := preload("res://scripts/office/window_view.gd")
const TvView := preload("res://scripts/office/tv_view.gd")
const MonitorView := preload("res://scripts/office/monitor_view.gd")
const DeskObject := preload("res://scripts/office/desk_object.gd")
const Hud := preload("res://scripts/office/hud.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")
const W := preload("res://scripts/data/world_data.gd")
const Redes := preload("res://scripts/systems/redes.gd")

var scene: Control
var window_view: Control
var tv: Control
var monitor: Control
var hud: Control
var door_l: TextureRect
var door_r: TextureRect
var visitor: Control
var light: ColorRect
var light_mat: ShaderMaterial
var objs := {}
var globe_mat: ShaderMaterial
var tip: PanelContainer
var tip_lbl: Label
var clock_ctrl: Control
var _t := 0.0
var _knock_t := 0.0
var _coffee_cd := 0.0
var _door_open := 0.0
var _last_alert := false
var pet_kind := ""
var _pet_cd := 0.0
var _pet_happy := 0.0
var _parrot_line := ""
var _parrot_t := 12.0
const PARROT := ["¡Dimisión! ¡Dimisión!", "¡Viva Valdoria!", "¡Más presupuesto!", "¡Recortes no!", "¡Orden! ¡Orden!", "¡Elecciones ya!", "Rrrr... ¡Corrupción!", "¡Presidente guapo!",
	"¡Siguiente pregunta!", "¡Sin comentarios!", "¡Lo que diga la ministra!", "¡Pío, pío, que no se diga!", "¡Café! ¡Café!", "¡Que hable la oposición!", "¡Señorías!", "¡Esto lo arreglamos!", "¡Hasta las urnas!", "¡Prima de riesgo!", "¡Gracias, Valdoria!", "¡Rueda de prensa! ¡Rrrueda!"]
const PARROT_MEME := ["¡Un vaso es un vaso!", "¡Sé fuerte!", "¡Con cebolla!", "¡Sin cebolla!", "¡Me gusta la fruta!", "¡Plasma! ¡Plasma!", "¡Bueno... eso!", "¡Es muy difícil todo esto!"]


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_PASS
	scene = Control.new()
	UI.full(scene)
	scene.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scene)
	# ventana (detrás de la pared)
	window_view = WindowView.new()
	window_view.position = Vector2(96, 126)
	window_view.size = Vector2(408, 470)
	scene.add_child(window_view)
	# habitación
	var room := TextureRect.new()
	room.texture = OfficeArt.tex("room")
	room.position = Vector2.ZERO
	room.size = Vector2(1920, 1080)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(room)
	# reloj (péndulo y agujas)
	clock_ctrl = Control.new()
	clock_ctrl.position = Vector2(1196, 190)
	clock_ctrl.size = Vector2(120, 400)
	clock_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_ctrl.draw.connect(_draw_clock)
	scene.add_child(clock_ctrl)
	# puertas
	door_l = _door_leaf(Vector2(840, 178), false)
	door_r = _door_leaf(Vector2(960, 178), true)
	# visitante
	visitor = Portrait.new()
	visitor.position = Vector2(700, 190)
	visitor.size = Vector2(520, 624)
	visitor.visible = false
	scene.add_child(visitor)
	# TV
	tv = TvView.new()
	tv.position = Vector2(1402, 162)
	tv.size = Vector2(376, 226)
	scene.add_child(tv)
	var tv_hot := _object("tv", Rect2(1390, 150, 400, 252), null, "Televisión · Canal 24 Noticias")
	tv_hot.glow_color = Color(0.6, 0.8, 1.0)
	# puerta como objeto
	var door_hot := _object("door", Rect2(840, 178, 240, 500), null, "Puerta del despacho")
	door_hot.glow_color = Color(1.0, 0.9, 0.6)
	# reloj como objeto (pausa)
	var clock_hot := _object("clock", Rect2(1196, 190, 120, 480), null, "Reloj · clic para pausar/reanudar")
	clock_hot.glow_color = Color(1.0, 0.85, 0.5)
	# escritorio
	var desk := TextureRect.new()
	desk.texture = OfficeArt.tex("desk")
	desk.position = Vector2(0, 640)
	desk.size = Vector2(1920, 440)
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(desk)
	# brillos aditivos
	_glow(Vector2(390, 760), Vector2(620, 360), Color(1.0, 0.8, 0.45, 0.35))
	_glow(Vector2(1410, 700), Vector2(460, 300), Color(0.4, 0.6, 1.0, 0.18))
	# objetos del escritorio
	_object("lamp", Rect2(290, 600, 200, 240), OfficeArt.tex("lamp"), "Lámpara")
	var rp := _object("redphone", Rect2(90, 792, 200, 150), OfficeArt.tex("redphone"), "Teléfono rojo · Gabinete de crisis")
	rp.glow_color = Color(1.0, 0.3, 0.25)
	var ph := _object("phone", Rect2(300, 852, 230, 160), OfficeArt.tex("phone"), "Teléfono")
	ph.extra_draw = _draw_phone_lcd
	var tray := _object("tray", Rect2(540, 790, 270, 170), null, "Bandeja de documentos")
	tray.extra_draw = _draw_tray
	var news := _object("newspaper", Rect2(810, 930, 220, 130), null, "Periódico del día")
	news.extra_draw = _draw_newspaper
	var fold := _object("folder", Rect2(1050, 935, 220, 130), OfficeArt.tex("folder"), "Presupuestos Generales")
	fold.extra_draw = _draw_folder
	var mic := _object("mic", Rect2(1112, 690, 120, 200), OfficeArt.tex("mic"), "Micrófono · Dirigirse a la nación")
	mic.extra_draw = _draw_mic
	var mon := _object("monitor", Rect2(1238, 548, 340, 320), OfficeArt.tex("monitor"), "Ordenador · SIGEP")
	mon.glow_color = Color(0.5, 0.75, 1.0)
	monitor = MonitorView.new()
	monitor.position = Vector2(20, 20)
	monitor.size = Vector2(300, 192)
	mon.add_child(monitor)
	var cal := _object("calendar", Rect2(1592, 830, 120, 112), null, "Agenda")
	cal.extra_draw = _draw_calendar
	var globe := _object("globe", Rect2(1664, 586, 240, 300), OfficeArt.tex("globe_stand"), "Globo terráqueo · Diplomacia")
	var sphere := ColorRect.new()
	sphere.position = Vector2(28, 30)
	sphere.size = Vector2(184, 184)
	sphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_mat = ShaderMaterial.new()
	globe_mat.shader = load("res://shaders/globe.gdshader")
	globe_mat.set_shader_parameter("map_tex", load("res://art/maps/world_ids.png"))
	sphere.material = globe_mat
	globe.add_child(sphere)
	globe.move_child(sphere, 0)
	# el móvil del presidente, boca arriba entre la carpeta y el café
	var movil := _object("movil", Rect2(1290, 896, 196, 158), null, "Móvil · Pío y mensajes")
	movil.extra_draw = _draw_movil
	movil.glow_color = Color(0.45, 0.72, 1.0)
	var mug := _object("mug", Rect2(1500, 918, 100, 110), OfficeArt.tex("mug"), "Café")
	mug.extra_draw = _draw_steam
	mug.animated = true
	mic.animated = true
	ph.animated = true
	GS.headline.connect(_on_headline_news)
	GS.day_passed.connect(_on_day_redraw)
	globe_mat.set_shader_parameter("style", 1 if Perfil.equipped_data("globo").get("globe", "") == "nocturno" else 0)
	# mascota
	pet_kind = Perfil.equipped_data("mascota").get("pet", "")
	if pet_kind != "":
		var pr: Rect2 = {"gato": Rect2(590, 975, 210, 105), "perro": Rect2(0, 920, 210, 160), "loro": Rect2(1208, 118, 96, 96), "pez": Rect2(478, 770, 86, 86), "tortuga": Rect2(860, 776, 170, 124)}[pet_kind]
		var pet := _object("pet", pr, null, {"gato": "Decreto, el gato", "perro": "Tribuno, el perro", "loro": "Senador, el loro", "pez": "El pez dorado", "tortuga": "Trámite, la tortuga"}[pet_kind])
		pet.extra_draw = _draw_pet
		pet.animated = true
		pet.glow_color = Color(1.0, 0.9, 0.7)
	# iluminación
	light = ColorRect.new()
	UI.full(light)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mat = ShaderMaterial.new()
	light_mat.shader = load("res://shaders/office_light.gdshader")
	light.material = light_mat
	add_child(light)
	# HUD
	hud = Hud.new()
	add_child(hud)
	hud.menu_pressed.connect(func(): request.emit("pause", {}))
	# tooltip flotante
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.05, 0.09, 0.94), 6, Color(UI.GOLD, 0.6), 1, 8, 10))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_lbl = UI.lbl("", UI.f_sans_m, 17, UI.TEXT)
	tip.add_child(tip_lbl)
	tip.visible = false
	add_child(tip)
	GS.queue_changed.connect(_refresh)
	GS.weather_changed.connect(_on_weather)
	window_view.weather = GS.weather
	_refresh()


func _on_headline_news(_t2: String) -> void:
	objs["newspaper"].queue_redraw()


func _on_day_redraw() -> void:
	objs["calendar"].queue_redraw()
	if not GS.unlocks.is_empty() and GS.day <= 120:
		_refresh()


func _on_weather() -> void:
	window_view.weather = GS.weather


func _door_leaf(pos: Vector2, flip: bool) -> TextureRect:
	var d := TextureRect.new()
	d.texture = OfficeArt.tex("door_leaf")
	d.position = pos
	d.size = Vector2(120, 522)
	d.flip_h = flip
	d.pivot_offset = Vector2(120, 0) if flip else Vector2(0, 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(d)
	return d


func _glow(center: Vector2, sz: Vector2, col: Color) -> void:
	var g := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	gt.width = 128
	gt.height = 128
	g.texture = gt
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.position = center - sz * 0.5
	g.size = sz
	g.modulate = col
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(g)


func _object(key: String, r: Rect2, t: Texture2D, title: String) -> Control:
	var o := DeskObject.new()
	o.position = r.position
	o.size = r.size
	o.tex = t
	o.tex_rect = Rect2(Vector2.ZERO, r.size)
	o.title = title
	o.activated.connect(_on_object.bind(key))
	o.mouse_entered.connect(func(): _show_tip(key))
	o.mouse_exited.connect(func(): tip.visible = false)
	objs[key] = o
	scene.add_child(o)
	return o


func _show_tip(key: String) -> void:
	if not objs.has(key) or tip == null:
		return
	var o: Control = objs[key]
	var txt: String = o.title
	if o.status != "":
		txt += "\n" + o.status
	tip_lbl.text = txt
	tip.visible = true
	tip.reset_size()


func _refresh() -> void:
	if objs.is_empty():
		return
	var tray: Control = objs["tray"]
	tray.badge = str(GS.inbox.size()) if GS.inbox.size() > 0 else ""
	tray.status = "%d documentos pendientes" % GS.inbox.size() if GS.inbox.size() > 0 else "Sin documentos pendientes"
	tray.pulse = GS.inbox.size() > 0
	var ph: Control = objs["phone"]
	ph.ringing = GS.calls.size() > 0
	if GS.calls.size() > 0:
		var who: String = GS.calls[0]["ev"].get("who", "")
		ph.status = "Llamada entrante: %s" % DB.character(who).get("name", "")
		Sfx.loop_start("ring", "ring", -6.0)
	else:
		ph.status = "Llamar a un líder o interlocutor"
		Sfx.loop_stop("ring")
	var rp: Control = objs["redphone"]
	rp.ringing = GS.alerts.size() > 0
	if GS.alerts.size() > 0:
		rp.status = "¡CRISIS! %s" % GS.fmt(GS.alerts[0]["ev"]["title"])
		rp.badge = "!"
		if not _last_alert:
			Sfx.loop_start("red", "ring_red", -8.0)
		_last_alert = true
	else:
		rp.status = "Línea directa del Gabinete de Crisis"
		rp.badge = ""
		Sfx.loop_stop("red")
		_last_alert = false
	tv.alert = GS.alerts.size() > 0
	var door: Control = objs["door"]
	door.pulse = GS.visitors.size() > 0
	door.badge = str(GS.visitors.size()) if GS.visitors.size() > 0 else ""
	door.badge_color = UI.AMBER
	if GS.visitors.size() > 0:
		var ch := DB.character(GS.visitors[0]["ev"].get("who", "jefa"))
		door.status = "%s espera: %s" % [ch.get("name", ""), GS.fmt(GS.visitors[0]["ev"]["title"])]
	else:
		door.status = "No hay nadie esperando"
	var fold: Control = objs["folder"]
	fold.pulse = GS.flags.has("presupuesto_pendiente")
	fold.badge = "!" if GS.flags.has("presupuesto_pendiente") else ""
	fold.badge_color = UI.GOLD_D
	var mic: Control = objs["mic"]
	var cd := GS.speech_until - GS.day
	mic.status = "Disponible" if cd <= 0 else "Disponible en %d días" % cd
	if GS.campaign:
		mic.status = "Mitin de campaña · " + mic.status
	var mv: Control = objs["movil"]
	var unread := Redes.unread()
	mv.badge = str(unread) if unread > 0 else ""
	mv.badge_color = Color(0.11, 0.6, 0.94)
	mv.pulse = unread > 0
	mv.status = ("%d mensaje%s sin leer" % [unread, "" if unread == 1 else "s"]) if unread > 0 else "Lo que dice la calle en Pío"
	objs["newspaper"].status = "Última edición"
	objs["monitor"].status = "Datos, leyes, Congreso y gabinete"
	objs["globe"].status = "Relaciones internacionales y acuerdos"
	objs["calendar"].status = "Próximos acontecimientos"
	objs["folder"].status = "Gasto por partidas e impuestos"
	for k in ["globe", "folder", "mic", "phone"]:
		var lk := _lock_key(k)
		var locked := lk != "" and not GS.is_unlocked(lk)
		objs[k].modulate = Color(0.62, 0.62, 0.66) if locked else Color.WHITE
		if locked:
			objs[k].status = "Disponible en %d días" % GS.days_to_unlock(lk)
	for o in objs.values():
		o.queue_redraw()


## Objetos que se presentan poco a poco (fácil y normal) y el sistema del que dependen
const LOCKS := {"globe": "diplomacia", "folder": "presupuestos", "mic": "discurso"}


func _lock_key(key: String) -> String:
	if key == "phone" and GS.calls.is_empty():
		return "diplomacia"
	if key == "mic" and GS.campaign:
		return ""
	return LOCKS.get(key, "")


## Si el objeto aún no está disponible, avisa y devuelve true
func _blocked(key: String) -> bool:
	var lk := _lock_key(key)
	if lk == "" or GS.is_unlocked(lk):
		return false
	var n := GS.days_to_unlock(lk)
	GS.toast.emit("%s: su gabinete se lo presentará en %d día%s. De momento, céntrese en documentos, visitas y llamadas." % [GS.UNLOCK_INFO[lk]["name"], n, "" if n == 1 else "s"], "info", "candado")
	Sfx.play("click", -6.0, 0.7)
	return true


func _on_object(key: String) -> void:
	tip.visible = false
	if _blocked(key):
		return
	match key:
		"tray":
			if GS.inbox.is_empty():
				GS.toast.emit("La bandeja está vacía. ¡Buen trabajo!", "info", "documento")
			else:
				request.emit("doc", {})
		"phone":
			if GS.calls.size() > 0:
				Sfx.loop_stop("ring")
				request.emit("call", {"item": GS.calls[0]})
			else:
				request.emit("phonebook", {})
		"redphone":
			if GS.alerts.size() > 0:
				Sfx.loop_stop("red")
				request.emit("crisis", {"item": GS.alerts[0]})
			else:
				GS.toast.emit("El Gabinete de Crisis informa: sin incidencias graves.", "good", "seguridad")
		"door":
			if GS.visitors.size() > 0:
				request.emit("advisor", {"item": GS.visitors[0]})
			else:
				request.emit("cabinet", {})
		"tv":
			request.emit("tv", {})
		"monitor":
			request.emit("dashboard", {})
		"calendar":
			request.emit("dashboard", {"tab": "agenda"})
		"globe":
			request.emit("world", {})
		"newspaper":
			request.emit("newspaper", {"latest": true})
		"movil":
			request.emit("movil", {})
		"folder":
			request.emit("budget", {})
		"mic":
			if GS.campaign:
				request.emit("campaign", {})
			elif GS.day < GS.speech_until:
				GS.toast.emit("Demasiado pronto para otro discurso (%d días)." % (GS.speech_until - GS.day), "warn", "microfono")
			else:
				request.emit("speech", {"occasion": "campana" if GS.campaign else "nacion"})
		"mug":
			if _coffee_cd <= 0.0:
				_coffee_cd = 25.0
				GS.stress = maxf(0.0, GS.stress - 4.0)
				Sfx.play("paper2", -10.0, 0.6)
				GS.toast.emit("Un café solo. Estrés −4.", "info", "cafe")
			else:
				GS.toast.emit("Ya ha tomado demasiado café.", "warn", "cafe")
		"clock":
			GS.set_speed(1 if GS.speed == 0 else 0)
		"lamp":
			Sfx.play("click", -2.0, 0.7)
		"pet":
			_pet_happy = 2.5
			if _pet_cd <= 0.0:
				_pet_cd = 20.0
				GS.stress = maxf(0.0, GS.stress - 3.0)
				GS.toast.emit({"gato": "Decreto ronronea. Estrés −3.", "perro": "Tribuno mueve la cola. Estrés −3.", "loro": "Senador: «¡Presidente guapo!». Estrés −3.", "pez": "El pez da una vuelta. Estrés −3.", "tortuga": "Trámite echa burbujas de alegría. Estrés −3."}.get(pet_kind, ""), "good", "bienestar")
			if pet_kind == "loro":
				_parrot_line = (PARROT_MEME if GS.mode == "meme" and randf() < 0.7 else PARROT).pick_random()
				_parrot_t = 4.0
			Sfx.play("notify", -10.0, 1.6 if pet_kind != "perro" else 0.7)


func enter_visitor(look: Dictionary) -> void:
	visitor.setup(look, true)
	visitor.mood = 0.0
	visitor.visible = true
	visitor.modulate.a = 0.0
	visitor.position = Vector2(700, 230)
	Sfx.play("door", -2.0)
	var t := create_tween()
	t.tween_property(self, "_door_open", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(visitor, "modulate:a", 1.0, 0.5).set_delay(0.2)
	t.parallel().tween_property(visitor, "position:y", 190.0, 0.6).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_door_open", 0.0, 0.5).set_delay(0.2)


func exit_visitor() -> void:
	if not visitor.visible:
		return
	var t := create_tween()
	t.tween_property(self, "_door_open", 1.0, 0.4)
	t.parallel().tween_property(visitor, "modulate:a", 0.0, 0.45).set_delay(0.1)
	t.parallel().tween_property(visitor, "position:y", 230.0, 0.45).set_delay(0.1)
	t.tween_callback(func(): visitor.visible = false)
	t.tween_property(self, "_door_open", 0.0, 0.4)
	Sfx.play("door", -4.0, 0.9)


func _process(delta: float) -> void:
	_t += delta
	_coffee_cd = maxf(0.0, _coffee_cd - delta)
	_pet_cd = maxf(0.0, _pet_cd - delta)
	_pet_happy = maxf(0.0, _pet_happy - delta)
	if pet_kind == "loro":
		_parrot_t -= delta
		if _parrot_t <= 0.0:
			if _parrot_line == "":
				_parrot_line = (PARROT_MEME if GS.mode == "meme" and randf() < 0.7 else PARROT).pick_random()
				_parrot_t = 3.5
			else:
				_parrot_line = ""
				_parrot_t = randf_range(18.0, 35.0)
	if tip.visible:
		tip.position = get_global_mouse_position() + Vector2(22, 18)
		if tip.position.x + tip.size.x > 1900:
			tip.position.x = get_global_mouse_position().x - tip.size.x - 12
	# puerta
	door_l.scale.x = 1.0 - _door_open * 0.82
	door_r.scale.x = 1.0 - _door_open * 0.82
	# llamadas a la puerta periódicas
	if GS.visitors.size() > 0 and GS.holds == 0 and GS.speed > 0:
		_knock_t += delta
		if _knock_t > 11.0:
			_knock_t = 0.0
			Sfx.play("knock", -8.0)
	else:
		_knock_t = 0.0
	# ambiente
	var alert := GS.alerts.size() > 0
	var tod := 0.06
	if alert:
		tod = 0.62
	if GS.campaign and GS.term_days - GS.day < 20:
		tod = 0.78
	var celebrate := GS.flags.has("fiesta") and GS.day - int(GS.flags["fiesta"]) < 6
	if celebrate:
		tod = maxf(tod, 0.7)
	window_view.tod_target = tod
	window_view.celebrate = celebrate
	var protest := clampf((48.0 - GS.approval) / 26.0, 0.0, 1.0)
	for a in GS.alerts:
		if a["ev"].get("crisis", "") in ["disturbios", "huelga_general", "huelga_sanitaria"]:
			protest = maxf(protest, 0.85)
	window_view.protest_target = protest
	light_mat.set_shader_parameter("night", clampf((window_view.tod - 0.3) * 1.4, 0.0, 0.85))
	light_mat.set_shader_parameter("alert", 1.0 if alert else 0.0)
	globe_mat.set_shader_parameter("rot", _t * 0.08)
	globe_mat.set_shader_parameter("highlight", objs["globe"]._hv)
	clock_ctrl.queue_redraw()


func _draw_clock() -> void:
	var c := Vector2(60, 72)
	var now := Time.get_time_dict_from_system()
	var hr := (float(now["hour"] % 12) + float(now["minute"]) / 60.0) / 12.0 * TAU - PI / 2.0
	var mn := float(now["minute"]) / 60.0 * TAU - PI / 2.0
	clock_ctrl.draw_line(c, c + Vector2(cos(hr), sin(hr)) * 20.0, Color(0.1, 0.08, 0.06), 3.5, true)
	clock_ctrl.draw_line(c, c + Vector2(cos(mn), sin(mn)) * 29.0, Color(0.1, 0.08, 0.06), 2.2, true)
	clock_ctrl.draw_circle(c, 3.5, Color(0.72, 0.58, 0.3))
	var sw := sin(_t * PI / 1.0) * 0.28
	var pivot := Vector2(60, 176)
	var bob := pivot + Vector2(sin(sw), cos(sw)) * 170.0
	clock_ctrl.draw_line(pivot, bob, Color(0.75, 0.6, 0.3), 2.5, true)
	clock_ctrl.draw_circle(bob, 15.0, Color(0.82, 0.66, 0.32))
	clock_ctrl.draw_circle(bob + Vector2(-4, -4), 5.0, Color(1, 0.92, 0.7, 0.6))
	clock_ctrl.draw_rect(Rect2(34, 176, 56, 208), Color(1, 1, 1, 0.04))
	clock_ctrl.draw_line(Vector2(44, 180), Vector2(54, 370), Color(1, 1, 1, 0.07), 6.0)


func _draw_tray(o: Control) -> void:
	var w := o.size.x
	# bandeja de madera (perspectiva)
	var back := PackedVector2Array([Vector2(28, 40), Vector2(w - 28, 40), Vector2(w - 8, 120), Vector2(8, 120)])
	o.draw_colored_polygon(back, Color("3a2012"))
	var n := mini(GS.inbox.size(), 8)
	for i in n:
		var y := 112.0 - i * 6.0
		var off := Vector2(sin(i * 1.7) * 6.0, 0)
		var sheet := PackedVector2Array([Vector2(34, y - 64) + off, Vector2(w - 34, y - 64) + off, Vector2(w - 20, y) + off, Vector2(20, y) + off])
		o.draw_colored_polygon(sheet, Color(0.95, 0.93, 0.87).darkened(0.03 * (n - i)))
		o.draw_polyline(PackedVector2Array([sheet[0], sheet[1], sheet[2], sheet[3], sheet[0]]), Color(0, 0, 0, 0.15), 1.0)
		if i == n - 1:
			for k in 5:
				o.draw_line(Vector2(60, y - 50 + k * 9) + off, Vector2(w - 70 - (k % 2) * 40, y - 50 + k * 9) + off, Color(0.2, 0.2, 0.25, 0.35), 2.0)
			var ev: Dictionary = GS.inbox[GS.inbox.size() - 1]["ev"]
			if ev.get("kind", "") in ["informe"]:
				o.draw_rect(Rect2(Vector2(w * 0.5 - 40, y - 60) + off, Vector2(80, 16)), Color(0.75, 0.1, 0.1, 0.8))
	var front := PackedVector2Array([Vector2(4, 116), Vector2(w - 4, 116), Vector2(w, 150), Vector2(0, 150)])
	o.draw_polygon(front, PackedColorArray([Color("6e3f25"), Color("6e3f25"), Color("40220f"), Color("40220f")]))
	o.draw_line(Vector2(4, 116), Vector2(w - 4, 116), Color("a8744c"), 2.0)
	o.draw_string(UI.f_sans_b, Vector2(0, 142), "ENTRADA", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.85, 0.7, 0.4, 0.8))


func _draw_newspaper(o: Control) -> void:
	var w := o.size.x
	var h := o.size.y
	var poly := PackedVector2Array([Vector2(14, 10), Vector2(w - 8, 0), Vector2(w, h - 12), Vector2(0, h)])
	o.draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(6, 8), poly[1] + Vector2(6, 8), poly[2] + Vector2(6, 8), poly[3] + Vector2(6, 8)]), Color(0, 0, 0, 0.35))
	o.draw_colored_polygon(poly, Color(0.93, 0.9, 0.82))
	o.draw_set_transform(Vector2(14, 10), -0.045, Vector2.ONE)
	o.draw_string(UI.f_goth, Vector2(0, 26), "El Diario", HORIZONTAL_ALIGNMENT_CENTER, w - 20, 24, Color(0.1, 0.1, 0.1))
	o.draw_line(Vector2(4, 32), Vector2(w - 24, 32), Color(0.1, 0.1, 0.1), 1.0)
	var hl := "Nuevo Gobierno en Valdoria"
	if GS.news_feed.size() > 0:
		hl = GS.news_feed[0]["t"]
	o.draw_multiline_string(UI.f_serif_b, Vector2(4, 50), hl, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 13, 3, Color(0.08, 0.08, 0.08))
	for k in 4:
		o.draw_line(Vector2(4, 96 + k * 6), Vector2(w - 30, 96 + k * 6), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	o.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_folder(o: Control) -> void:
	o.draw_string(UI.f_serif_b, Vector2(0, 64), "PRESUPUESTOS", HORIZONTAL_ALIGNMENT_CENTER, o.size.x, 16, Color(0.9, 0.75, 0.42))
	o.draw_string(UI.f_sans_b, Vector2(0, 84), "GENERALES DEL ESTADO", HORIZONTAL_ALIGNMENT_CENTER, o.size.x, 9, Color(0.9, 0.75, 0.42, 0.8))


func _draw_mic(o: Control) -> void:
	var ready := GS.day >= GS.speech_until
	var c := Color(1, 0.2, 0.15) if ready else Color(0.3, 0.1, 0.1)
	o.draw_circle(Vector2(60, 140), 5, c)
	if ready:
		o.draw_circle(Vector2(60, 140), 10, Color(1, 0.2, 0.15, 0.25 + 0.15 * sin(_t * 4.0)))


func _draw_phone_lcd(o: Control) -> void:
	var r := Rect2(92, 44, 106, 24)
	if GS.calls.size() > 0:
		var on := int(_t * 3.0) % 2 == 0
		o.draw_rect(r, Color(0.45, 0.85, 0.5) if on else Color(0.2, 0.45, 0.25))
		o.draw_string(UI.f_mono, Vector2(r.position.x, r.position.y + 17), "ENTRANTE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(0.05, 0.1, 0.05))
	else:
		o.draw_string(UI.f_mono, Vector2(r.position.x + 4, r.position.y + 17), "LÍNEA LIBRE", HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, Color(0.5, 0.8, 0.55, 0.7))


## El móvil, tumbado sobre la mesa: la pantalla se enciende cuando hay mensajes sin leer
func _draw_movil(o: Control) -> void:
	var lift: float = -4.0 * float(o.get("_hv"))
	var pts := PackedVector2Array([Vector2(52, 14), Vector2(124, 8), Vector2(156, 138), Vector2(62, 148)])
	for i in pts.size():
		pts[i].y += lift
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(7, 6 - lift))
	o.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	o.draw_colored_polygon(pts, Color("16171b"))
	o.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.55, 0.57, 0.62, 0.6), 1.5, true)
	var c := (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
	var scr := PackedVector2Array()
	for p in pts:
		scr.append(c + (p - c) * 0.86)
	var unread := Redes.unread()
	o.draw_colored_polygon(scr, Color("1d3d68") if unread > 0 else Color("0b111c"))
	if unread > 0:
		# avisos en la pantalla
		for k in mini(unread, 3):
			var t := 0.3 + k * 0.17
			var a := scr[0].lerp(scr[3], t) + (scr[1] - scr[0]) * 0.08
			var b := scr[1].lerp(scr[2], t) - (scr[1] - scr[0]) * 0.08
			o.draw_line(a, b, Color(1, 1, 1, 0.55), 7.0)
		var glow: float = 0.5 + 0.5 * sin(float(o.get("_t")) * 3.0)
		o.draw_colored_polygon(scr, Color(0.3, 0.6, 1.0, 0.12 * glow))
	else:
		o.draw_line(scr[0].lerp(scr[3], 0.18) + (scr[1] - scr[0]) * 0.3, scr[1].lerp(scr[2], 0.18) - (scr[1] - scr[0]) * 0.3, Color(1, 1, 1, 0.18), 3.0)


func _draw_calendar(o: Control) -> void:
	var w := o.size.x
	var h := o.size.y
	o.draw_colored_polygon(PackedVector2Array([Vector2(10, h), Vector2(w - 10, h), Vector2(w - 20, 20), Vector2(20, 20)]), Color(0.2, 0.12, 0.08))
	o.draw_rect(Rect2(14, 6, w - 28, h - 16), Color(0, 0, 0, 0.3))
	o.draw_rect(Rect2(10, 2, w - 28, h - 16), Color(0.97, 0.96, 0.93))
	o.draw_rect(Rect2(10, 2, w - 28, 24), Color("b3261e"))
	var d := UI.date_dict(GS.day)
	o.draw_string(UI.f_sans_b, Vector2(10, 20), UI.MONTHS_SHORT[d["month"] - 1] + " " + str(d["year"]), HORIZONTAL_ALIGNMENT_CENTER, w - 28, 13, Color.WHITE)
	o.draw_string(UI.f_cond_b, Vector2(10, 70), str(d["day"]), HORIZONTAL_ALIGNMENT_CENTER, w - 28, 40, Color(0.12, 0.12, 0.14))
	o.draw_string(UI.f_sans_m, Vector2(10, 88), UI.WEEKDAYS[d["weekday"]], HORIZONTAL_ALIGNMENT_CENTER, w - 28, 11, Color(0.35, 0.35, 0.4))
	for i in 2:
		o.draw_circle(Vector2(30 + i * (w - 68), 3), 4, Color(0.6, 0.6, 0.62))


func _draw_pet(o: Control) -> void:
	PetArt.draw(o, pet_kind, _t, _pet_happy > 0.0, _parrot_line)


func _ell(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _draw_steam(o: Control) -> void:
	for i in 3:
		var pts := PackedVector2Array()
		for k in 10:
			var y := 20.0 - k * 6.0
			pts.append(Vector2(36 + i * 10 + sin(_t * 2.0 + k * 0.6 + i) * 4.0, y))
		o.draw_polyline(pts, Color(1, 1, 1, 0.12), 3.0, true)
