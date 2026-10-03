extends "res://scripts/ui/overlay.gd"
## Un asesor entra en el despacho con un dilema.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")

var item: Dictionary
var ev: Dictionary
var ch: Dictionary
var tw: RichTextLabel
var choices_box: VBoxContainer
var timer: Control
var decided := false
var visitor: Control
var reaction: Label


func _init() -> void:
	super._init()
	dim_alpha = 0.0


func build() -> void:
	item = data.get("item", {})
	ev = item.get("ev", {})
	ch = DB.character(ev.get("who", "jefa"))
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.01, 0.02, 0.04, 0.0))
	gr.set_color(1, Color(0.01, 0.02, 0.04, 0.92))
	gr.add_point(0.45, Color(0.01, 0.02, 0.04, 0.25))
	gt.gradient = gr
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	if main != null and main.office != null:
		main.office.enter_visitor(ch.get("look", {}))
		visitor = main.office.visitor
	# ficha del asesor
	var panel := UI.panel(Color(0.035, 0.05, 0.085, 0.95), 12, Color(UI.GOLD, 0.55), 26)
	panel.position = Vector2(1150, 130)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.size = Vector2(720, 10)
	root.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	var hh := UI.hbox(14)
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(70, 70)
	pc.clip_contents = true
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mini_p := Portrait.new()
	mini_p.position = Vector2(-8, -6)
	mini_p.size = Vector2(86, 104)
	mini_p.track_mouse = false
	mini_p.breathe = false
	pc.add_child(mini_p)
	mini_p.setup(ch.get("look", {}), false)
	hh.add_child(pc)
	var nv := UI.vbox(0)
	nv.add_child(UI.lbl(ch.get("name", ""), UI.f_serif_b, 26, UI.TEXT))
	nv.add_child(UI.lbl(ch.get("role", "").to_upper(), UI.f_sans_b, 13, UI.GOLD))
	hh.add_child(nv)
	v.add_child(hh)
	v.add_child(Widgets.section("Asunto"))
	var title := UI.lbl(GS.fmt(ev.get("title", "")), UI.f_serif_b, 34, UI.CREAM)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(668, 0)
	v.add_child(title)
	tw = Typewriter.new()
	tw.custom_minimum_size = Vector2(668, 0)
	tw.add_theme_font_size_override("normal_font_size", 21)
	tw.add_theme_color_override("default_color", Color(UI.TEXT, 0.92))
	v.add_child(tw)
	timer = TimerBar.new()
	timer.custom_minimum_size = Vector2(668, 8)
	timer.visible = false
	v.add_child(UI.spacer(0, 4))
	v.add_child(timer)
	choices_box = UI.vbox(10)
	v.add_child(choices_box)
	reaction = UI.lbl("", UI.f_serif, 24, UI.GOLD_L)
	reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reaction.custom_minimum_size = Vector2(668, 0)
	v.add_child(reaction)
	tw.typed.connect(_show_choices)
	UI.pop_in(panel)
	await get_tree().create_timer(0.55).timeout
	if visitor != null:
		visitor.talking = true
	tw.play(GS.fmt(ev.get("text", "")), 60.0)


func _process(_delta: float) -> void:
	if visitor != null and tw != null:
		visitor.talking = tw.is_running()


func _show_choices() -> void:
	if choices_box.get_child_count() > 0 or decided:
		return
	var choices: Array = ev.get("choices", [])
	for i in choices.size():
		choices_box.add_child(_choice_card(i, choices[i]))
	if ev.has("urgent"):
		timer.visible = true
		timer.start(float(ev["urgent"]) * (0.8 if GS.stress > 75 else 1.0) * [1.5, 1.0, 0.8][GS.difficulty], "DECISIÓN URGENTE")
		timer.timeout.connect(func():
			if not decided:
				_decide(int(ev.get("default", choices.size() - 1)), true))


func _choice_card(i: int, c: Dictionary) -> Control:
	var v := UI.vbox(8)
	var h := UI.hbox(10)
	var num := UI.lbl(str(i + 1), UI.f_cond_b, 22, UI.GOLD)
	num.custom_minimum_size = Vector2(22, 0)
	h.add_child(num)
	var t := UI.lbl(GS.fmt(c.get("t", "")), UI.f_sans_m, 20, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(600, 0)
	h.add_child(t)
	v.add_child(h)
	var chips := Widgets.effect_chips(GS.preview(c.get("fx", {})), 15, 7)
	chips.custom_minimum_size = Vector2(620, 0)
	var ch2 := UI.hbox(0)
	ch2.add_child(UI.spacer(32, 0))
	ch2.add_child(chips)
	v.add_child(ch2)
	if c.has("rec"):
		var rc := DB.character(c["rec"])
		var rl := UI.lbl("★ Recomendado por %s" % rc.get("name", ""), UI.f_sans_b, 14, UI.GOLD_L)
		var rh := UI.hbox(0)
		rh.add_child(UI.spacer(32, 0))
		rh.add_child(rl)
		v.add_child(rh)
	var advised := GS.difficulty == 0 and i == GS.recommend(ev.get("choices", []))
	if advised:
		v.add_child(Widgets.advice_tag())
	var b := Widgets.click_card(v, func(): _decide(i, false), 14, Color(0.07, 0.15, 0.12, 0.95) if advised else Color(0.08, 0.12, 0.19, 0.95), Color(UI.GREEN, 0.8) if advised else Color(1, 1, 1, 0.1))
	b.custom_minimum_size = Vector2(668, 0)
	UI.pop_in(b, 0.3)
	return b


func _unhandled_key_input(event: InputEvent) -> void:
	if decided or choices_box.get_child_count() == 0:
		return
	if event is InputEventKey and event.pressed:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < choices_box.get_child_count():
			_decide(n, false)


func _decide(i: int, timeout: bool) -> void:
	if decided:
		return
	decided = true
	timer.stop()
	Sfx.play("click", -2.0)
	for c in choices_box.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.35
	if i < choices_box.get_child_count():
		choices_box.get_child(i).modulate.a = 1.0
	var out := GS.resolve_choice(item, i)
	var s := 0.0
	for o in out:
		if GS.fac.has(o["k"]) or GS.meters.has(o["k"]):
			s += float(o["v"])
	if visitor != null:
		visitor.mood = clampf(s / 8.0, -0.8, 0.8)
		visitor.anger = 0.6 if s < -8 else 0.0
	var lines_ok := ["Entendido, presidente. Me pongo con ello.", "Muy bien. Lo comunicaré de inmediato.", "Sabia decisión. Manos a la obra.", "Así se hará."]
	var lines_bad := ["Como usted diga... aunque no me convence.", "Espero que sepa lo que hace, presidente.", "Lo haré. Pero esto nos va a costar caro."]
	if timeout:
		reaction.text = "«Se acabó el tiempo, presidente. He tenido que decidir yo.»"
	else:
		reaction.text = "«%s»" % (lines_ok.pick_random() if s >= 0 else lines_bad.pick_random())
	UI.pop_in(reaction)
	await get_tree().create_timer(1.6).timeout
	if main != null and main.office != null:
		main.office.exit_visitor()
	close()


func on_escape() -> void:
	pass
