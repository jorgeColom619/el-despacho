extends "res://scripts/ui/overlay.gd"
## Agenda telefónica: llamar a líderes e interlocutores para negociar.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const W := preload("res://scripts/data/world_data.gd")


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.93)
	var head := title_bar("Agenda telefónica", "Línea presidencial", "telefono")
	head.position = Vector2(80, 120)
	root.add_child(head)
	var sub := UI.lbl("Llame a un líder para abrir una negociación. Cada tema tiene un periodo de espera tras negociarlo.", UI.f_sans, 18, UI.DIM)
	sub.position = Vector2(80, 200)
	root.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 240)
	scroll.size = Vector2(1760, 740)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for c in W.COUNTRIES.keys():
		var topics := []
		for t in W.TOPICS.get(c, []):
			var cd := int(GS.countries[c]["cd"].get(t["id"], 0)) - GS.day
			topics.append({"id": t["id"], "name": t["name"], "cd": cd})
		grid.add_child(_contact(c, DB.character(c), topics, GS.countries[c]["rel"]))
	for who in ["sindicato", "patronal", "opo", "islas"]:
		if who == "islas" and not (GS.used.has("islas_protestas") or GS.flags.has("islas_tension")):
			continue
		var topics2 := []
		for tid in DB.DOMESTIC[who]["topics"].keys():
			var cd2 := int(GS.cooldowns.get("nego_%s_%s" % [who, tid], 0)) - GS.day
			topics2.append({"id": tid, "name": DB.DOMESTIC[who]["topics"][tid]["name"], "cd": cd2})
		grid.add_child(_contact(who, DB.character(who), topics2, DB.counterpart(who)["rel"]))
	var cb := close_button("Colgar")
	cb.position = Vector2(1700, 1000)
	root.add_child(cb)


func _contact(who: String, ch: Dictionary, topics: Array, rel: float) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.08, 0.13, 0.96), 10, Color(1, 1, 1, 0.1), 1, 0, 14))
	card.custom_minimum_size = Vector2(570, 0)
	var v := UI.vbox(8)
	card.add_child(v)
	var h := UI.hbox(14)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(76, 76)
	pf.clip_contents = true
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Portrait.new()
	p.position = Vector2(-8, -4)
	p.size = Vector2(92, 110)
	p.track_mouse = false
	p.breathe = false
	pf.add_child(p)
	p.setup(ch.get("look", {}), false)
	h.add_child(pf)
	var nv := UI.vbox(2)
	nv.add_child(UI.lbl(ch.get("name", ""), UI.f_serif_b, 22, UI.TEXT))
	var role := UI.lbl(ch.get("role", ""), UI.f_sans, 14, UI.GOLD)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.custom_minimum_size = Vector2(440, 0)
	nv.add_child(role)
	nv.add_child(UI.lbl("Relación: %s" % UI.signed(rel, 0), UI.f_sans_m, 14, UI.color_for(50.0 + rel * 0.5)))
	h.add_child(nv)
	v.add_child(h)
	for t in topics:
		var b := UI.btn("  " + t["name"] + ("" if t["cd"] <= 0 else "  (en %d días)" % t["cd"]), "normal", 16)
		b.icon = UI.icon("telefono", 32)
		b.add_theme_constant_override("icon_max_width", 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = t["cd"] > 0
		var tid: String = t["id"]
		b.pressed.connect(func():
			close()
			if main != null:
				main.call_deferred("open_overlay", "nego", {"who": who, "topic": tid}))
		v.add_child(b)
	return card


func on_escape() -> void:
	close()
