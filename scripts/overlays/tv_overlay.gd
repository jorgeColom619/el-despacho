extends "res://scripts/ui/overlay.gd"
## Canal 24: archivo de titulares y barómetro de opinión.

const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.93)
	var head := title_bar("Canal 24 Noticias", "Hemeroteca y barómetro", "tv")
	head.position = Vector2(80, 120)
	root.add_child(head)
	var lp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.4), 20)
	lp.position = Vector2(80, 220)
	lp.custom_minimum_size = Vector2(980, 760)
	lp.size = Vector2(980, 760)
	root.add_child(lp)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 720)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(scroll)
	var v := UI.vbox(10)
	scroll.add_child(v)
	v.add_child(UI.lbl("ÚLTIMOS TITULARES", UI.f_sans_b, 14, UI.GOLD))
	for n in GS.news_feed:
		var h := UI.hbox(14)
		var d := UI.lbl(UI.date_short(int(n["day"])), UI.f_mono, 15, UI.DIM)
		d.custom_minimum_size = Vector2(120, 0)
		h.add_child(d)
		var imp := int(n.get("imp", 1))
		var t := UI.lbl(n["t"], UI.f_sans_b if imp >= 3 else UI.f_sans_m, 18, UI.TEXT if imp >= 2 else Color(UI.TEXT, 0.75))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(780, 0)
		h.add_child(t)
		v.add_child(h)
	var rp := UI.panel(Color(0.035, 0.05, 0.085, 0.96), 12, Color(UI.GOLD, 0.4), 20)
	rp.position = Vector2(1090, 220)
	rp.custom_minimum_size = Vector2(760, 760)
	root.add_child(rp)
	var rv := UI.vbox(12)
	rp.add_child(rv)
	rv.add_child(UI.lbl("BARÓMETRO DE OPINIÓN", UI.f_sans_b, 14, UI.GOLD))
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(720, 260)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(func():
		var s: Array = GS.stat_hist["approval"].duplicate()
		s.append(GS.approval)
		if s.size() < 2:
			s.insert(0, s[0])
		chart.draw_line(Vector2(0, 130), Vector2(720, 130), Color(1, 1, 1, 0.15), 1.0)
		Widgets.draw_line_chart(chart, Rect2(0, 10, 720, 240), s, UI.GOLD, 0.0, 100.0, 3.0)
		chart.draw_string(UI.f_cond_b, Vector2(0, 50), UI.num(GS.approval, 0) + "% aprueba al Gobierno", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.color_for(GS.approval)))
	rv.add_child(chart)
	rv.add_child(Widgets.section("Intención de voto estimada"))
	var own: String = GS.pres["party"]
	var est := clampf(GS.approval * 0.62 + 6.0 + GS.campaign_bonus, 8.0, 58.0)
	var opp: String = W.PLAYER_PARTIES[own]["opp"]
	var opp_est := clampf((100.0 - est) * 0.45, 10.0, 50.0)
	for row in [[own, est], [opp, opp_est], ["otros", 100.0 - est - opp_est]]:
		var h2 := UI.hbox(12)
		var nm: String = W.PARTIES[row[0]]["name"] if row[0] != "otros" else "Resto de partidos"
		var l := UI.lbl(nm, UI.f_sans_m, 18, UI.TEXT)
		l.custom_minimum_size = Vector2(260, 0)
		h2.add_child(l)
		var col := Color(W.PARTIES[row[0]]["color"]) if row[0] != "otros" else Color(0.5, 0.5, 0.55)
		h2.add_child(Widgets.bar(float(row[1]) * 1.6, 300, 16, col))
		h2.add_child(UI.lbl(UI.pct(float(row[1]), 1), UI.f_cond_b, 20, UI.TEXT))
		rv.add_child(h2)
	var note := UI.lbl("Para ganar necesita una mayoría de 176 escaños con su partido y sus socios.", UI.f_sans, 15, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(720, 0)
	rv.add_child(note)
	var cb := close_button("Apagar la televisión")
	cb.position = Vector2(1620, 1000)
	root.add_child(cb)


func on_escape() -> void:
	close()
