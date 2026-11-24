extends Control
## Sala de la partida en línea («Países rivales»): cada jugador elige nombre, país y partido; uno crea la partida
## (abre el puerto solo, por UPnP) y los demás se unen con su IP. El anfitrión elige dificultad, duración y modo.

const Backdrop := preload("res://scripts/screens/backdrop.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")
const PD := preload("res://scripts/data/paises_data.gd")

var main: Node
var es_sala := true
var name_edit: LineEdit
var ip_edit: LineEdit
var pais_lbl: Label
var pais_info: Label
var flag: Control
var party_btns := {}
var estado_lbl: Label
var ips_lbl: Label
var lista: VBoxContainer
var cfg_box: HBoxContainer
var cfg_btns := {}
var go_btn: Button
var crear_btn: Button
var unir_btn: Button
var espera_lbl: Label


func _ready() -> void:
	UI.full(self)
	add_child(Backdrop.new())
	var dimr := ColorRect.new()
	dimr.color = Color(0.01, 0.02, 0.04, 0.66)
	UI.full(dimr)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimr)
	var head := UI.vbox(0)
	head.position = Vector2(120, 50)
	add_child(head)
	head.add_child(UI.lbl("PAÍSES RIVALES", UI.f_sans_b, 16, UI.GOLD))
	head.add_child(UI.lbl("Partida en línea", UI.f_serif_b, 56, UI.CREAM))
	if Red.yo["name"] == "":
		Red.yo["name"] = String(PD.PAISES[Red.yo["pais"]]["pres_m"])
	GS.usar_pais(String(Red.yo["pais"]))
	# --- columna izquierda: el jugador
	var left := UI.vbox(12)
	left.position = Vector2(120, 180)
	left.size = Vector2(700, 800)
	add_child(left)
	left.add_child(Widgets.section("Su nombre"))
	name_edit = LineEdit.new()
	name_edit.text = String(Red.yo["name"])
	name_edit.max_length = 28
	name_edit.custom_minimum_size = Vector2(560, 50)
	name_edit.add_theme_font_override("font", UI.f_serif_b)
	name_edit.text_submitted.connect(func(_t): _enviar_yo())
	name_edit.focus_exited.connect(_enviar_yo)
	left.add_child(name_edit)
	left.add_child(Widgets.section("Su país"))
	var prow := UI.hbox(12)
	left.add_child(prow)
	var pprev := UI.btn("◀", "normal", 18)
	pprev.custom_minimum_size = Vector2(48, 50)
	pprev.pressed.connect(func(): _cycle_pais(-1))
	prow.add_child(pprev)
	flag = Control.new()
	flag.custom_minimum_size = Vector2(84, 52)
	flag.draw.connect(func():
		Flags.draw_flag(flag, String(Red.yo["pais"]), Rect2(0, 0, 84, 52))
		flag.draw_rect(Rect2(0, 0, 84, 52), Color(1, 1, 1, 0.35), false, 1.0))
	prow.add_child(flag)
	pais_lbl = UI.lbl("", UI.f_serif_b, 32, UI.CREAM)
	pais_lbl.custom_minimum_size = Vector2(400, 0)
	prow.add_child(pais_lbl)
	var pnext := UI.btn("▶", "normal", 18)
	pnext.custom_minimum_size = Vector2(48, 50)
	pnext.pressed.connect(func(): _cycle_pais(1))
	prow.add_child(pnext)
	pais_info = UI.lbl("", UI.f_sans, 16, UI.DIM)
	pais_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pais_info.custom_minimum_size = Vector2(680, 0)
	left.add_child(pais_info)
	left.add_child(Widgets.section("Su partido"))
	var ph := UI.vbox(8)
	left.add_child(ph)
	for p in ["MP", "CC", "AR"]:
		var b := UI.btn("", "normal", 18)
		b.custom_minimum_size = Vector2(680, 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pk: String = p
		b.pressed.connect(func():
			Sfx.play("click", -4.0)
			Red.cambiar_yo({"party": pk})
			_refresh())
		ph.add_child(b)
		party_btns[p] = b
	# --- columna derecha: la conexión y la sala
	var right := UI.vbox(12)
	right.position = Vector2(900, 180)
	right.size = Vector2(900, 800)
	add_child(right)
	right.add_child(Widgets.section("Crear o unirse"))
	var ch := UI.hbox(12)
	right.add_child(ch)
	crear_btn = UI.btn("Crear partida", "gold", 20)
	crear_btn.custom_minimum_size = Vector2(240, 52)
	crear_btn.pressed.connect(func():
		_enviar_yo()
		Red.crear()
		_refresh())
	ch.add_child(crear_btn)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP del anfitrión (p. ej. 85.12.34.56)"
	ip_edit.custom_minimum_size = Vector2(380, 52)
	ip_edit.text_submitted.connect(func(_t): _unirse())
	ch.add_child(ip_edit)
	unir_btn = UI.btn("Unirse", "normal", 20)
	unir_btn.custom_minimum_size = Vector2(150, 52)
	unir_btn.pressed.connect(_unirse)
	ch.add_child(unir_btn)
	estado_lbl = UI.lbl("Cree una partida y pase su IP a sus amigos, o escriba la IP del anfitrión para unirse. El puerto (%d) se abre solo en la mayoría de routers." % Red.PUERTO, UI.f_sans_m, 16, UI.GOLD_L)
	estado_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado_lbl.custom_minimum_size = Vector2(880, 0)
	right.add_child(estado_lbl)
	ips_lbl = UI.lbl("", UI.f_sans, 15, UI.DIM)
	ips_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ips_lbl.custom_minimum_size = Vector2(880, 0)
	right.add_child(ips_lbl)
	right.add_child(Widgets.section("Jugadores"))
	lista = UI.vbox(8)
	right.add_child(lista)
	right.add_child(Widgets.section("Partida (la elige el anfitrión)"))
	cfg_box = UI.hbox(12)
	right.add_child(cfg_box)
	for spec in [["difficulty", "Dificultad"], ["years", "Duración"], ["mode", "Modo"]]:
		var b2 := UI.btn("", "normal", 17)
		b2.custom_minimum_size = Vector2(280, 48)
		var key: String = spec[0]
		b2.pressed.connect(func(): _cycle_cfg(key))
		cfg_box.add_child(b2)
		cfg_btns[key] = b2
	right.add_child(UI.spacer(0, 10))
	var bottom := UI.hbox(20)
	right.add_child(bottom)
	var back := UI.btn("← Volver", "ghost", 22)
	back.pressed.connect(func():
		Red.salir()
		main.transition(func(): main.show_menu()))
	bottom.add_child(back)
	bottom.add_child(UI.spacer(0, 0, true))
	espera_lbl = UI.lbl("", UI.f_sans_m, 17, UI.DIM)
	bottom.add_child(espera_lbl)
	go_btn = UI.btn("EMPEZAR", "gold", 26)
	go_btn.custom_minimum_size = Vector2(300, 66)
	go_btn.pressed.connect(func():
		_enviar_yo()
		Red.empezar())
	bottom.add_child(go_btn)
	Red.sala_cambiada.connect(_refresh)
	Red.estado.connect(func(t: String): estado_lbl.text = t)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _exit_tree() -> void:
	if Red.sala_cambiada.is_connected(_refresh):
		Red.sala_cambiada.disconnect(_refresh)


func _enviar_yo() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		nm = String(PD.PAISES[Red.yo["pais"]]["pres_m"])
	if nm != String(Red.yo["name"]) or Red.activo():
		Red.cambiar_yo({"name": nm})


func _unirse() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		estado_lbl.text = "Escriba la IP del anfitrión."
		return
	_enviar_yo()
	var puerto := Red.PUERTO
	if ":" in ip:
		puerto = int(ip.get_slice(":", 1))
		ip = ip.get_slice(":", 0)
	Red.unirse(ip, puerto)
	_refresh()


func _cycle_pais(d: int) -> void:
	var antes: Dictionary = PD.PAISES[Red.yo["pais"]]
	var p: String = PD.ORDEN[wrapi(PD.ORDEN.find(Red.yo["pais"]) + d, 0, PD.ORDEN.size())]
	Sfx.play("click", -4.0)
	GS.usar_pais(p)
	if name_edit.text.strip_edges() in [String(antes["pres_m"]), String(antes["pres_f"]), ""]:
		name_edit.text = String(PD.PAISES[p]["pres_m"])
	Red.yo["name"] = name_edit.text.strip_edges()
	Red.cambiar_yo({"pais": p, "name": Red.yo["name"]})
	_refresh()


func _cycle_cfg(key: String) -> void:
	if not Red.anfitrion():
		return
	Sfx.play("click", -4.0)
	var c := Red.config.duplicate()
	match key:
		"difficulty":
			c["difficulty"] = wrapi(int(c["difficulty"]) + 1, 0, 3)
		"years":
			c["years"] = {1: 2, 2: 4, 4: 1}.get(int(c["years"]), 2)
		"mode":
			c["mode"] = "infinito" if String(c["mode"]) == "clasico" else "clasico"
	Red.cambiar_config(c)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var p := String(Red.yo["pais"])
	if GS.Pais.actual != p:
		GS.usar_pais(p)
	var f: Dictionary = PD.PAISES[p]
	pais_lbl.text = String(f["full"])
	pais_info.text = "%s · Capital: %s · %s" % [f["regime"], f["cap"], f["desc"]]
	flag.queue_redraw()
	for k in party_btns.keys():
		var b: Button = party_btns[k]
		b.text = "  %s (%s)" % [W.PARTIES[k]["name"], W.PARTIES[k]["short"]]
		var on: bool = String(Red.yo.get("party", "MP")) == String(k)
		b.add_theme_color_override("font_color", UI.GOLD_L if on else UI.TEXT)
		b.add_theme_stylebox_override("normal", UI.sb(Color(UI.GOLD, 0.16), 8, UI.GOLD, 2) if on else UI.sb(Color(0.06, 0.09, 0.15, 0.85), 8, Color(1, 1, 1, 0.12), 1))
	# conexión
	crear_btn.disabled = Red.activo()
	unir_btn.disabled = Red.activo()
	ip_edit.editable = not Red.activo()
	var ips := "Sus IP en esta red: %s" % ", ".join(Red.ips_locales())
	if Red.ip_publica != "":
		ips += "   ·   IP pública: %s" % Red.ip_publica
	ips_lbl.text = ips if Red.anfitrion() else ""
	# jugadores
	for c in lista.get_children():
		c.queue_free()
	if Red.jugadores.is_empty():
		lista.add_child(UI.lbl("Todavía no hay nadie: cree una partida o únase a una.", UI.f_sans, 16, UI.DIM))
	for id in Red.jugadores.keys():
		var j: Dictionary = Red.jugadores[id]
		var row := UI.hbox(12)
		var fl := Control.new()
		fl.custom_minimum_size = Vector2(60, 38)
		var jp := String(j["pais"])
		fl.draw.connect(func(): Flags.draw_flag(fl, jp, Rect2(0, 0, 60, 38)))
		row.add_child(fl)
		var txt := "%s · %s" % [j["name"], PD.PAISES[jp]["name"]]
		if int(id) == 1:
			txt += "  (anfitrión)"
		if int(id) == Red.mi_id():
			txt += "  ← usted"
		row.add_child(UI.lbl(txt, UI.f_sans_b, 19, UI.TEXT))
		lista.add_child(row)
	# configuración
	var cfg := Red.config
	cfg_btns["difficulty"].text = "Dificultad: %s" % ["Fácil", "Normal", "Difícil"][int(cfg["difficulty"])]
	cfg_btns["years"].text = "Duración: %d %s" % [int(cfg["years"]), "año" if int(cfg["years"]) == 1 else "años"]
	cfg_btns["mode"].text = "Modo: %s" % ("Infinito" if String(cfg["mode"]) == "infinito" else "Clásico")
	for b3 in cfg_btns.values():
		(b3 as Button).disabled = not Red.anfitrion()
	var motivo := Red.motivo_no_empezar()
	go_btn.visible = Red.anfitrion()
	go_btn.disabled = motivo != ""
	espera_lbl.text = motivo if Red.anfitrion() else ("Esperando a que el anfitrión empiece..." if Red.activo() else "")
