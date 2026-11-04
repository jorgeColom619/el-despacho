extends "res://scripts/ui/overlay.gd"
## Una noche en el Gran Casino con dinero público. Empieza en la caja (de qué partida sale el dinero y cuánto), sigue
## en el salón (ruleta, blackjack y tragaperras, en 3D y sin ventanas) y acaba en la caja: con lo ganado o con el
## agujero, y lo que se decida hacer con ello (casino.gd). Por el camino, el anfitrión ofrece una jugada arreglada y
## crédito si se acaban las fichas, puede colarse un fotógrafo y, a las 3:00, llama la Jefa de Gabinete.

const D := preload("res://scripts/data/casino_data.gd")
const Stage := preload("res://scripts/stages3d/casino_3d.gd")
const Ruleta := preload("res://scripts/systems/ruleta.gd")
const Blackjack := preload("res://scripts/systems/blackjack.gd")
const Tragaperras := preload("res://scripts/systems/tragaperras.gd")
const Casino := preload("res://scripts/systems/casino.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Layout := preload("res://scripts/ui/roulette_layout.gd")

var stage
var host := "magnate"
var hd: Dictionary
## La noche: host, source, taken, credit, chips, minutes, rounds, exposure_add, corr_add, bribe ("", "aceptado",
## "rechazado"), bribe_offered, photo_done, credit_offered, settled
var night := {}
## "caja", "vestibulo", "ruleta", "blackjack", "slot"
var where := ""
var busy := false
var rng := RandomNumberGenerator.new()
var ruleta := Ruleta.new()
var bj: Blackjack
var slot := Tragaperras.new()
var slot_i := 0
## Ficha elegida para apostar en la ruleta
var chip_sel := 25
## La próxima jugada está arreglada (el anfitrión)
var rigged_next := false

var _hud: Control
var _lbl_chips: Label
var _lbl_info: Label
var _lbl_clock: Label
var _btn_leave: Button
var _rack_nodes: Array = []
var _rack_picks: Array = []
var _table_picks: Array = []
var _bet_nodes := {}
var _bj_bet := 0.0
var _bj_last := 0.0
var _bj_cards := {}
var _bj_hole: Node3D
var _bj_stacks: Array = []
var _bj_dealt := false
## Puntos de los botones de la tragaperras en la que se juega
var _spots: Array = []


func build() -> void:
	dim.color = Color(0, 0, 0, 0)
	rng.randomize()
	bj = Blackjack.new(rng)
	host = str(data.get("host", ""))
	if not D.HOSTS.has(host):
		var hs := Casino.hosts_for_mode()
		host = hs[rng.randi() % hs.size()]
	hd = D.HOSTS[host]
	night = {"host": host, "source": "", "taken": 0.0, "credit": 0.0, "chips": 0.0, "minutes": D.NIGHT_START, "rounds": 0,
		"exposure_add": 0.0, "corr_add": 0.0, "bribe": "", "bribe_offered": false, "photo_done": false, "credit_offered": false, "settled": false}
	stage = Stage.new()
	stage.meme = GS.mode == "meme"
	stage.set_host(hd["look"], hd["name"])
	root.add_child(stage)
	stage.picked.connect(_on_pick)
	stage.layout.place.connect(_on_place)
	stage.layout.unplace.connect(_on_unplace)
	stage.layout.action.connect(_on_layout_action)
	stage.layout.game = ruleta
	stage.layout.enabled = false
	_build_hud()
	Sfx.music("music_casino", 2.0)
	Sfx.loop_start("casino", "casino_amb", -14.0, "Amb")
	var skip := str(data.get("skip", ""))
	if skip != "":
		_fund(Casino.sources_for_mode()[0], 2)
		_go_lobby(false)
		match skip:
			"ruleta":
				_enter_roulette()
			"blackjack":
				_enter_blackjack()
			"slot":
				_enter_slot(1)
			"caja":
				_to_cashier(false)
		if data.get("demo", false):
			_demo(skip)
		return
	_intro()


## Capturas de prueba (--open=casinoruleta con DEMO=1): apuesta y juega sola, sin sorpresas por el camino
func _demo(skip: String) -> void:
	night["bribe_offered"] = true
	night["photo_done"] = true
	match skip:
		"ruleta":
			_after(0.6, func():
				chip_sel = 100
				_on_place("pleno", [17], stage.layout.cell_center(17))
				chip_sel = 25
				_on_place("rojo", Ruleta.outside_nums("rojo"), Vector2(500, 645))
				_on_place("docena", Ruleta.outside_nums("docena", 1), Vector2(690, 555))
				_on_place("cuadro", [17, 18, 20, 21], Vector2(Layout.GX + 6 * Layout.CW, Layout.GY + Layout.CH))
				_after(1.5, _spin))
		"blackjack":
			_after(0.6, func():
				_bj_add(100)
				_after(1.0, _bj_deal))
		"slot":
			_after(1.0, _slot_spin)


## f dentro de sec segundos, si la noche sigue abierta
func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(func():
		if not closing:
			f.call())


func _names(who: String) -> String:
	match who:
		"croupier", "dealer":
			return "Crupier"
		"cashier":
			return "Cajera"
		"host":
			return "%s · %s" % [hd["name"], hd["role"]]
		"jefa":
			return "%s · %s" % [DB.character("jefa").get("name", "Jefa de Gabinete"), "Jefa de Gabinete"]
	return ""


func _say(who: String, text: String, hold := 0.6) -> void:
	var col := UI.GOLD
	if who == "host":
		col = Color("e9a94a")
	elif who == "jefa":
		col = Color("7fb2e6")
	stage.say(_names(who), text, col, stage.people.get(who), hold)


# ------------------------------------------------------------------ marcador

func _build_hud() -> void:
	_hud = Control.new()
	UI.full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	var p := UI.panel(Color(0.03, 0.035, 0.06, 0.86), 10, Color(UI.GOLD, 0.55), 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(360, 0)
	p.position = Vector2(1920 - 360 - 28, 26)
	_hud.add_child(p)
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := UI.hbox(10)
	top.add_child(UI.lbl("FICHAS", UI.f_sans_b, 14, UI.GOLD))
	top.add_child(UI.spacer(0, 0, true))
	_lbl_clock = UI.lbl("22:30", UI.f_cond_b, 22, UI.CREAM)
	top.add_child(_lbl_clock)
	v.add_child(top)
	_lbl_chips = UI.lbl("0 M€", UI.f_serif_b, 40, UI.CREAM)
	v.add_child(_lbl_chips)
	_lbl_info = UI.lbl("", UI.f_sans, 15, UI.DIM)
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_info.custom_minimum_size = Vector2(328, 0)
	v.add_child(_lbl_info)
	_btn_leave = UI.btn("Volver al salón", "normal", 18)
	_btn_leave.position = Vector2(28, 1080 - 76)
	_btn_leave.visible = false
	_btn_leave.pressed.connect(_leave_table)
	_hud.add_child(_btn_leave)
	_refresh()


func _refresh() -> void:
	if _lbl_chips == null:
		return
	_lbl_chips.text = UI.money(float(night["chips"]))
	var m := int(night["minutes"])
	_lbl_clock.text = "%02d:%02d" % [(m / 60) % 24, m % 60]
	_lbl_clock.add_theme_color_override("font_color", UI.RED if m >= D.NIGHT_END - 30 else UI.CREAM)
	var src: Dictionary = D.SOURCES.get(night["source"], {})
	var info := ""
	if not src.is_empty():
		info = "Dinero público en juego: %s\n(%s)" % [UI.money(float(night["taken"])), src["name"]]
		if float(night["credit"]) > 0.0:
			info += "\nCrédito de %s: %s" % [hd["name"], UI.money(float(night["credit"]))]
		var net := float(night["chips"]) + _on_table() - float(night["taken"]) - float(night["credit"])
		info += "\nBalance de la noche: %s" % UI.money(net, true)
	if where == "ruleta" and ruleta.total() > 0.0:
		info += "\nEn el paño: %s" % UI.money(ruleta.total())
	elif where == "blackjack" and _bj_bet > 0.0:
		info += "\nApuesta: %s" % UI.money(_bj_bet)
	elif where == "slot":
		info += "\nApuesta por tirada: %s" % UI.money(slot.bet)
	_lbl_info.text = info


## Fichas que están ahora sobre la mesa (apostadas)
func _on_table() -> float:
	if where == "ruleta":
		return ruleta.total()
	if where == "blackjack" and not _bj_dealt:
		return _bj_bet
	return 0.0


func _show_leave(on: bool) -> void:
	_btn_leave.visible = on


# ------------------------------------------------------------------ tarjetas de elección

## Superficie donde se reparten las tarjetas de elección según dónde está el presidente: [centro, normal, hueco, tamaño]
func _surface(small := false) -> Array:
	match where:
		"caja":
			return [Stage.CAJA + Vector3(0, 1.142, 0.24), Vector3.UP, 0.29, Vector2(0.26, 0.17)]
		"vestibulo":
			return [Stage.LOBBY_TABLE + Vector3(0, 1.072, 0.02), Vector3.UP, 0.23, Vector2(0.21, 0.135)]
		"ruleta":
			return [Stage.RT + Vector3(0.38, Stage.TOP + 0.012, -0.02), Vector3.UP, 0.26, Vector2(0.23, 0.15)]
		"blackjack":
			if small:
				return [Stage.BJ + Stage.BJ_ACTIONS + Vector3(0.02, 0.002, 0.02), Vector3.UP, 0.165, Vector2(0.15, 0.1)]
			return [Stage.BJ + Vector3(0, Stage.TOP + 0.004, 0.06), Vector3.UP, 0.24, Vector2(0.21, 0.135)]
		"slot":
			var r: Node3D = stage.slots[slot_i]["root"]
			return [r.global_position + Vector3(0, 0.962, 0.312), Vector3(0, 0.894, 0.447), 0.2, Vector2(0.18, 0.115)]
	return [Stage.LOBBY_TABLE + Vector3(0, 1.072, 0.02), Vector3.UP, 0.23, Vector2(0.21, 0.135)]


func _cards(specs: Array, on_pick: Callable, small := false) -> void:
	var s := _surface(small)
	stage.deal_cards(specs, s[0], s[1], s[2], on_pick, s[3])


# ------------------------------------------------------------------ la caja: de dónde sale el dinero

func _intro() -> void:
	where = "caja"
	busy = true
	stage.title_card(hd["title"], "Gran Casino de Santa Aurora", "La noche empieza a las 22:30 y a las 3:00 le llamará la Jefa de Gabinete. Todo lo que juegue será dinero público.", 6.0)
	_say("host", hd["greet"][rng.randi() % hd["greet"].size()], 0.8)
	_say("cashier", "Buenas noches, señor presidente. ¿De qué partida sacamos el dinero para las fichas?", 0.3)
	stage.after_lines(_offer_sources)


func _offer_sources() -> void:
	if closing:
		return
	stage.hide_title()
	var srcs := Casino.sources_for_mode()
	var specs := []
	for s in srcs:
		var sd: Dictionary = D.SOURCES[s]
		specs.append({"tag": "Dinero público", "title": sd["name"], "desc": "%s Hasta %s." % [sd["desc"], UI.money(float(sd["amounts"].back()))], "col": UI.RED_D, "icon": sd["icon"], "desc_k": 0.068})
	specs.append({"tag": "Sin jugar", "title": "Una copa y a casa", "desc": "Saludar al anfitrión y marcharse sin tocar una ficha.", "col": UI.GREEN_D, "icon": "salir", "desc_k": 0.07})
	stage.notice("Elija de dónde sale el dinero: haga clic en una tarjeta o pulse 1-%d" % specs.size())
	_cards(specs, func(i: int):
		if i >= srcs.size():
			_no_play()
		else:
			_offer_amounts(srcs[i]))


func _offer_amounts(src: String) -> void:
	var sd: Dictionary = D.SOURCES[src]
	var specs := []
	var labels := ["Con prudencia", "Una noche seria", "A lo grande"]
	for i in 3:
		var a := float(sd["amounts"][i])
		specs.append({"tag": labels[i], "title": UI.money(a), "desc": "En fichas, de %s." % String(sd["name"]).to_lower(), "col": UI.GOLD if i < 2 else UI.RED, "icon": "dinero", "title_k": 0.17})
	specs.append({"tag": "Pensándolo mejor", "title": "Otra partida", "desc": "Volver a elegir de dónde sale el dinero.", "col": UI.NAVY3, "icon": "ceder"})
	stage.notice("¿Cuánto? (1-4)")
	_cards(specs, func(i: int):
		if i == 3:
			_offer_sources()
			return
		_fund(src, i)
		_say("cashier", "Aquí tiene: %s en fichas. Suerte, señor presidente." % UI.money(float(night["taken"])), 0.3)
		var st: Node3D = stage.chip_stack(float(night["taken"]), Stage.CAJA + Vector3(0, 1.142, 0.18), stage.world)
		Sfx.play("chips", -2.0)
		_after(1.4, func():
			stage.slide(st, stage.cam_pos + Vector3(0, -0.6, -0.3), 0.6)
			_after(0.6, func(): _go_lobby(true))))


func _fund(src: String, idx: int) -> void:
	var sd: Dictionary = D.SOURCES[src]
	night["source"] = src
	night["taken"] = float(sd["amounts"][idx])
	night["chips"] = float(sd["amounts"][idx])
	_refresh()


func _no_play() -> void:
	night["source"] = Casino.sources_for_mode()[0]
	night["taken"] = 0.0
	night["chips"] = 0.0
	_say("host", "¿Ya se va? Bueno... la foto ya nos la hemos hecho.", 0.4)
	stage.after_lines(func(): _settle("tesoro", ""))


# ------------------------------------------------------------------ el salón

func _go_lobby(talk: bool) -> void:
	where = "vestibulo"
	busy = false
	stage.go("vestibulo")
	stage.clear_cards()
	_show_leave(false)
	stage.host_to("vestibulo")
	stage.notice("Elija dónde jugar: haga clic en la ruleta, en el blackjack, en una tragaperras... o en la caja para irse")
	if talk:
		_say("host", "Las mesas son suyas, presidente. Y si necesita algo, ya sabe dónde estoy.", 0.4)
	_refresh()


func _on_pick(what: String, arg: int) -> void:
	if busy or where != "vestibulo":
		return
	match what:
		"ruleta":
			_enter_roulette()
		"blackjack":
			_enter_blackjack()
		"slot":
			_enter_slot(arg)
		"caja":
			_to_cashier(false)


func _leave_table() -> void:
	if busy or not (where in ["ruleta", "blackjack", "slot"]):
		return
	_cleanup_table()
	_go_lobby(false)


func on_escape() -> void:
	_leave_table()


func _cleanup_table() -> void:
	for pk in _table_picks:
		stage.remove_pick(pk)
	_table_picks.clear()
	for s in _spots:
		if is_instance_valid(s):
			s.queue_free()
	_spots.clear()
	_clear_rack()
	stage.clear_cards()
	stage.caption("", "")
	match where:
		"ruleta":
			night["chips"] = float(night["chips"]) + ruleta.clear()
			for k in _bet_nodes.keys():
				if is_instance_valid(_bet_nodes[k]):
					_bet_nodes[k].queue_free()
			_bet_nodes.clear()
			stage.layout.enabled = false
			stage.layout.clear_hover()
		"blackjack":
			if not _bj_dealt:
				night["chips"] = float(night["chips"]) + _bj_bet
				_bj_bet = 0.0
			_bj_clear_table()
	_refresh()


## Montones de fichas del presidente en la mesa: uno por valor; on_click(v) al pulsar uno
func _rack(base: Vector3, step: Vector3, on_click: Callable, tip: String) -> void:
	_clear_rack()
	var chips := float(night["chips"])
	var i := 0
	for ch in D.CHIPS:
		var v := int(ch["v"])
		var n := mini(14, int(chips / v))
		var root := Node3D.new()
		stage.world.add_child(root)
		root.global_position = base + step * i
		for j in n:
			var c: MeshInstance3D = stage.chip(v)
			root.add_child(c)
			c.position = Vector3(randf_range(-0.001, 0.001), j * Stage.CHIP_H, randf_range(-0.001, 0.001))
			c.rotation.y = randf() * TAU
		if n > 0 and v == chip_sel and where == "ruleta":
			root.position.y += 0.012
		_rack_nodes.append(root)
		if n > 0:
			var vv := v
			var pk = stage.add_pick(root, AABB(Vector3(-0.026, -0.005, -0.026), Vector3(0.052, maxf(0.03, n * Stage.CHIP_H + 0.01), 0.052)), tip % UI.money(v), func(): on_click.call(vv))
			_rack_picks.append(pk)
		i += 1


func _clear_rack() -> void:
	for pk in _rack_picks:
		stage.remove_pick(pk)
	_rack_picks.clear()
	for n in _rack_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_rack_nodes.clear()


# ------------------------------------------------------------------ ruleta

func _enter_roulette() -> void:
	where = "ruleta"
	stage.go("ruleta")
	_show_leave(true)
	stage.layout.enabled = true
	stage.layout.win = -1
	_roulette_rack()
	var pk = stage.add_pick(stage.wheel, AABB(Vector3(-0.42, 0.0, -0.42), Vector3(0.84, 0.16, 0.84)), "Lanzar la bola (o pulse espacio)", _spin)
	_table_picks.append(pk)
	_say("croupier", D.CROUPIER["bets"][rng.randi() % D.CROUPIER["bets"].size()], 0.3)
	stage.notice("Elija ficha (sus montones, abajo) y haga clic en el paño · clic derecho: quitar · clic en la rueda o espacio: lanzar")
	_refresh()


func _roulette_rack() -> void:
	_rack(Stage.RT + Stage.RT_BANK, Vector3(0.075, 0, 0), func(v: int):
		chip_sel = v
		Sfx.play("chips", -10.0, 1.3)
		_roulette_rack(), "Apostar fichas de %s")


func _on_place(kind: String, nums: Array, at: Vector2) -> void:
	if where != "ruleta" or busy:
		return
	var v := float(chip_sel)
	if float(night["chips"]) < v:
		stage.notice("No le quedan fichas de ese valor: elija una ficha más pequeña o vuelva a la caja")
		return
	var key := Ruleta.key_of(kind, nums)
	if ruleta.on_key(key) + v > float(D.LIMITS["ruleta"][1]):
		stage.notice("Límite de la mesa: %s por apuesta" % UI.money(float(D.LIMITS["ruleta"][1])))
		return
	ruleta.add(kind, nums, v, at)
	night["chips"] = float(night["chips"]) - v
	_bet_stack(key)
	Sfx.play("chips", -6.0, 1.0, 0.12)
	_roulette_rack()
	_refresh()


func _on_unplace(kind: String, nums: Array) -> void:
	if where != "ruleta" or busy:
		return
	var key := Ruleta.key_of(kind, nums)
	var a := ruleta.take(key, float(chip_sel))
	if a <= 0.0:
		a = ruleta.take(key, 1e9)
	if a <= 0.0:
		return
	night["chips"] = float(night["chips"]) + a
	_bet_stack(key)
	Sfx.play("chips", -9.0, 1.2)
	_roulette_rack()
	_refresh()


func _on_layout_action(name: String) -> void:
	if where != "ruleta" or busy:
		return
	if name == "borrar":
		night["chips"] = float(night["chips"]) + ruleta.clear()
		for k in _bet_nodes.keys():
			if is_instance_valid(_bet_nodes[k]):
				_bet_nodes[k].queue_free()
		_bet_nodes.clear()
	elif name == "repetir":
		if ruleta.last_bets.is_empty():
			stage.notice("Todavía no hay ninguna jugada que repetir")
			return
		for k in ruleta.last_bets:
			var b: Dictionary = ruleta.last_bets[k]
			var a := float(b["amount"])
			if float(night["chips"]) < a:
				stage.notice("No le llega para repetir toda la jugada")
				break
			ruleta.add(b["kind"], b["nums"], a, b["at"])
			night["chips"] = float(night["chips"]) - a
			_bet_stack(k)
	Sfx.play("chips", -6.0)
	_roulette_rack()
	_refresh()


func _bet_stack(key: String) -> void:
	if _bet_nodes.has(key) and is_instance_valid(_bet_nodes[key]):
		_bet_nodes[key].queue_free()
	_bet_nodes.erase(key)
	if ruleta.bets.has(key):
		var b: Dictionary = ruleta.bets[key]
		_bet_nodes[key] = stage.chip_stack(float(b["amount"]), stage.layout_point(b["at"]), stage.world)


func _spin() -> void:
	if busy or where != "ruleta":
		return
	if ruleta.total() <= 0.0:
		stage.notice("Haga su apuesta antes de lanzar la bola")
		return
	busy = true
	stage.layout.enabled = false
	stage.layout.clear_hover()
	stage.layout.win = -1
	_say("croupier", D.CROUPIER["close"][rng.randi() % D.CROUPIER["close"].size()], 0.2)
	var n: int = ruleta.best_number() if rigged_next else rng.randi() % 37
	rigged_next = false
	stage.notice("")
	stage.go("rueda")
	stage.spin_wheel(n, _on_wheel.bind(n))


func _on_wheel(n: int) -> void:
	if closing:
		return
	var col := Ruleta.color_of(n)
	stage.put_dolly(n)
	stage.layout.win = n
	var res := ruleta.settle(n)
	var words := "Cero." if n == 0 else "%d, %s%s." % [n, col, ", par" if n % 2 == 0 else ", impar"]
	_say("croupier", words, 0.4)
	Sfx.play("ball_drop", -4.0)
	_after(1.6, func():
		stage.go("ruleta")
		_after(0.9, _roulette_pay.bind(res)))


func _roulette_pay(res: Dictionary) -> void:
	var croupier: Vector3 = Stage.RT + Vector3(-0.4, Stage.TOP + 0.02, -0.62)
	var bank: Vector3 = Stage.RT + Stage.RT_BANK + Vector3(0.1, 0.02, 0)
	for k in res["losers"]:
		if _bet_nodes.has(k):
			stage.slide(_bet_nodes[k], croupier, 0.55)
	var pleno := false
	for k in res["winners"]:
		var b: Dictionary = ruleta.bets[k]
		if b["kind"] == "pleno":
			pleno = true
		var win := float(b["amount"]) * float(D.BETS[b["kind"]]["pay"])
		var at: Vector3 = stage.layout_point(b["at"])
		var paid: Node3D = stage.chip_stack(win, croupier, stage.world)
		var stake: Node3D = _bet_nodes.get(k)
		var t := paid.create_tween()
		t.tween_property(paid, "global_position", at + Vector3(0.045, 0, 0), 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.5)
		t.tween_callback(func():
			stage.slide(paid, bank, 0.5)
			if is_instance_valid(stake):
				stage.slide(stake, bank, 0.5))
	_bet_nodes.clear()
	ruleta.bets.clear()
	var back := float(res["back"])
	var net := back - float(res["staked"])
	night["chips"] = float(night["chips"]) + back
	if back > 0.0:
		Sfx.play("chips", -2.0)
		stage.big_text("+%s" % UI.money(net) if net > 0.0 else "RECUPERA %s" % UI.money(back), UI.GREEN.lightened(0.2), 96)
		if net > float(res["staked"]) * 3.0:
			Sfx.play("applause", -10.0)
	else:
		stage.big_text("LA BANCA GANA", UI.RED.lightened(0.15), 90)
	if pleno:
		Perfil.unlock("casino_pleno")
	_after(1.4, func():
		_roulette_rack()
		_refresh()
		_after_round("ruleta"))


func _resume_roulette() -> void:
	busy = false
	stage.layout.enabled = true
	_roulette_rack()
	_say("croupier", D.CROUPIER["bets"][rng.randi() % D.CROUPIER["bets"].size()], 0.2)
	stage.notice("Apueste en el paño · clic derecho: quitar · clic en la rueda o espacio: lanzar")


# ------------------------------------------------------------------ blackjack

func _enter_blackjack() -> void:
	where = "blackjack"
	stage.go("blackjack")
	_show_leave(true)
	_bj_dealt = false
	_bj_rack()
	_say("dealer", D.CROUPIER["bj_hello"][rng.randi() % D.CROUPIER["bj_hello"].size()], 0.3)
	if _bj_last > 0.0 and float(night["chips"]) >= _bj_last:
		_bj_add(int(_bj_last), true)
	_bj_offer()


func _bj_rack() -> void:
	_rack(Stage.BJ + Stage.BJ_BANK, Vector3(-0.0, 0, 0.0) + Vector3(0.06, 0, -0.025), func(v: int): _bj_add(v), "Añadir %s a la apuesta")


## Añade fichas a la apuesta de la casilla (antes de repartir)
func _bj_add(v: int, quiet := false) -> void:
	if busy or _bj_dealt or where != "blackjack":
		return
	var limit := float(D.LIMITS["blackjack"][1])
	var a := minf(float(v), limit - _bj_bet)
	if a <= 0.0:
		stage.notice("Límite de la mesa: %s" % UI.money(limit))
		return
	if float(night["chips"]) < a:
		stage.notice("No le quedan fichas suficientes")
		return
	var first := _bj_bet <= 0.0
	_bj_bet += a
	night["chips"] = float(night["chips"]) - a
	_bj_bet_stack()
	if not quiet:
		Sfx.play("chips", -6.0, 1.0, 0.12)
	_bj_rack()
	_refresh()
	if first and not quiet:
		_bj_offer()
	else:
		stage.notice("Apuesta: %s · Repartir cuando quiera (o espacio)" % UI.money(_bj_bet))


func _bj_bet_stack() -> void:
	for n in _bj_stacks:
		if is_instance_valid(n):
			n.queue_free()
	_bj_stacks.clear()
	if _bj_bet > 0.0:
		_bj_stacks.append(stage.chip_stack(_bj_bet, Stage.BJ + Stage.BJ_BET, stage.world))


func _bj_offer() -> void:
	if closing:
		return
	if _bj_bet <= 0.0:
		stage.clear_cards()
		stage.notice("Haga clic en sus fichas para apostar (mínimo %s)" % UI.money(float(D.LIMITS["blackjack"][0])))
		return
	stage.notice("Apuesta: %s · Repartir cuando quiera (o espacio)" % UI.money(_bj_bet))
	_cards([{"tag": "Blackjack", "title": "Repartir", "col": UI.GOLD, "icon": "check", "title_k": 0.2},
		{"tag": "Apuesta", "title": "Quitar la apuesta", "col": UI.NAVY3, "icon": "ceder", "title_k": 0.15}], func(i: int):
		if i == 0:
			_bj_deal()
		else:
			night["chips"] = float(night["chips"]) + _bj_bet
			_bj_bet = 0.0
			_bj_bet_stack()
			_bj_rack()
			_refresh()
			_bj_offer(), true)


func _bj_deal() -> void:
	if busy or _bj_dealt or _bj_bet < float(D.LIMITS["blackjack"][0]):
		if _bj_bet > 0.0 and _bj_bet < float(D.LIMITS["blackjack"][0]):
			stage.notice("La apuesta mínima es de %s" % UI.money(float(D.LIMITS["blackjack"][0])))
			_bj_offer()
		return
	busy = true
	_bj_dealt = true
	stage.clear_cards()
	stage.notice("")
	_clear_rack()
	_bj_cards = {"p0": [], "p1": [], "d": []}
	bj.rigged = rigged_next
	rigged_next = false
	_bj_last = _bj_bet
	var ev := bj.deal(_bj_bet)
	_bj_anim(ev, _bj_next)


func _pcard_pos(hand: int, j: int) -> Vector3:
	var x0 := 0.0 if bj.hands.size() < 2 else (-0.17 if hand == 0 else 0.17)
	return Stage.BJ + Stage.BJ_PCARDS + Vector3(x0 + j * 0.02, 0.0006 * j, -j * 0.03)


func _dcard_pos(j: int) -> Vector3:
	return Stage.BJ + Stage.BJ_DCARDS + Vector3(-0.04 + j * 0.072, 0.0006 * j, 0)


## Reparte en la mesa las cartas que han salido (una detrás de otra) y luego llama a done
func _bj_anim(events: Array, done: Callable) -> void:
	var delay := 0.0
	for e in events:
		match str(e["to"]):
			"p":
				var h := int(e["hand"])
				var j: int = (_bj_cards["p%d" % h] as Array).size()
				var yaw := PI / 2.0 if e.get("sideways", false) else 0.0
				var n: Node3D = stage.deal_card(int(e["card"]), _pcard_pos(h, j), true, delay, yaw)
				_bj_cards["p%d" % h].append(n)
				delay += 0.42
			"d":
				var j2: int = (_bj_cards["d"] as Array).size()
				var down: bool = e.get("down", false)
				var n2: Node3D = stage.deal_card(int(e["card"]), _dcard_pos(j2), not down, delay)
				_bj_cards["d"].append(n2)
				if down:
					_bj_hole = n2
				delay += 0.42
			"split":
				var second: Node3D = (_bj_cards["p0"] as Array).pop_back()
				_bj_cards["p1"] = [second]
				var first: Node3D = _bj_cards["p0"][0]
				stage.slide(first, _pcard_pos(0, 0), 0.3, false)
				stage.slide(second, _pcard_pos(1, 0), 0.3, false)
				_bj_stacks.append(stage.chip_stack(float(bj.hands[1]["bet"]), Stage.BJ + Stage.BJ_BET + Vector3(0.17, 0, 0), stage.world))
				if is_instance_valid(_bj_stacks[0]):
					stage.slide(_bj_stacks[0], Stage.BJ + Stage.BJ_BET + Vector3(-0.17, 0, 0), 0.3, false)
				delay += 0.45
			"flip":
				var hole := _bj_hole
				var hc := int(bj.dealer[1])
				_after(delay, func(): stage.flip(hole, hc))
				delay += 0.5
	_after(delay + 0.45, done)


func _hand_text() -> String:
	var parts := []
	for i in bj.hands.size():
		var h: Dictionary = bj.hands[i]
		var v: Array = Blackjack.value(h["cards"])
		var t := ("%d" % int(v[0])) if not (bool(v[1]) and int(v[0]) < 21) else "%d o %d" % [int(v[0]) - 10, int(v[0])]
		if bj.hands.size() > 1:
			t = ("▶ " if i == bj.active and bj.phase == "player" else "") + "Mano %d: %s" % [i + 1, t]
		else:
			t = "Su mano: " + t
		parts.append(t)
	var up := Blackjack.points(int(bj.dealer[0]))
	return "%s · La banca enseña %s" % [" · ".join(parts), "un as" if up == 11 else str(up)]


func _bj_next() -> void:
	if closing:
		return
	match bj.phase:
		"insurance":
			var ins := float(bj.hands[0]["bet"]) * 0.5
			stage.notice(_hand_text() + " · ¿Seguro?")
			var specs := [{"tag": "Seguro", "title": "Asegurarse", "desc": "%s. Paga 2 a 1 si la banca tiene blackjack." % UI.money(ins), "col": UI.AMBER, "icon": "seguridad"},
				{"tag": "Seguro", "title": "No asegurarse", "col": UI.NAVY3, "icon": "cruz"}]
			busy = false
			_cards(specs, func(i: int):
				busy = true
				var take := i == 0 and float(night["chips"]) >= ins
				if take:
					night["chips"] = float(night["chips"]) - ins
					_bj_stacks.append(stage.chip_stack(ins, Stage.BJ + Vector3(0, Stage.TOP, 0.08), stage.world))
				bj.set_insurance(take)
				_refresh()
				_after(0.3, _bj_next), true)
		"player":
			var h: Dictionary = bj.hand()
			var specs2 := [{"tag": "Jugada", "title": "Pedir", "col": UI.GREEN_D, "icon": "arriba", "title_k": 0.2},
				{"tag": "Jugada", "title": "Plantarse", "col": UI.RED_D, "icon": "pausa", "title_k": 0.2}]
			var acts := ["pedir", "plantarse"]
			if bj.can_double() and float(night["chips"]) >= float(h["bet"]):
				specs2.append({"tag": "Jugada", "title": "Doblar", "desc": "+%s y una sola carta" % UI.money(float(h["bet"])), "col": UI.AMBER, "icon": "dinero"})
				acts.append("doblar")
			if bj.can_split() and float(night["chips"]) >= float(h["bet"]):
				specs2.append({"tag": "Jugada", "title": "Dividir", "desc": "+%s: dos manos" % UI.money(float(h["bet"])), "col": UI.BLUE, "icon": "ceder"})
				acts.append("dividir")
			stage.notice(_hand_text())
			busy = false
			_cards(specs2, func(i: int): _bj_act(acts[i]), true)
		"dealer":
			busy = true
			stage.notice(_hand_text())
			_bj_anim(bj.dealer_turn(), _bj_settle)
		_:
			busy = true
			# la mano se acabó antes de tiempo (blackjack): se destapa la carta de la banca
			_bj_anim([{"to": "flip"}], _bj_settle)


func _bj_act(a: String) -> void:
	if closing:
		return
	busy = true
	match a:
		"pedir":
			_bj_anim(bj.hit(), _bj_next)
		"plantarse":
			bj.stand()
			_after(0.2, _bj_next)
		"doblar":
			var h: Dictionary = bj.hand()
			night["chips"] = float(night["chips"]) - float(h["bet"])
			var at := Stage.BJ + Stage.BJ_BET + (Vector3.ZERO if bj.hands.size() < 2 else Vector3(-0.17 if bj.active == 0 else 0.17, 0, 0))
			_bj_stacks.append(stage.chip_stack(float(h["bet"]), at + Vector3(0.05, 0, 0.02), stage.world))
			_refresh()
			_bj_anim(bj.double(), _bj_next)
		"dividir":
			night["chips"] = float(night["chips"]) - float(bj.hands[0]["bet"])
			_refresh()
			_bj_anim(bj.split(), _bj_next)


func _bj_settle() -> void:
	if closing:
		return
	var res := bj.settle()
	var back := float(res["back"])
	var net := back - float(res["staked"])
	night["chips"] = float(night["chips"]) + back
	var lines := {"blackjack": "bj_bj", "gana": "bj_win", "empate": "bj_push", "pierde": "bj_lose", "se_pasa": "bj_bust"}
	var r0: String = bj.hands[0]["res"]
	var key: String = lines.get(r0, "bj_lose")
	if int(res["dealer"]) > 21 and r0 == "gana":
		key = "bj_dealer_bust"
	var pool: Array = D.CROUPIER[key]
	_say("dealer", pool[rng.randi() % pool.size()], 0.3)
	stage.notice(_hand_text() + " · La banca tiene %d" % int(res["dealer"]))
	var tray: Vector3 = Stage.BJ + Vector3(0, Stage.TOP + 0.03, -0.29)
	var bank: Vector3 = Stage.BJ + Stage.BJ_BANK + Vector3(0.08, 0.02, 0)
	if back > 0.0:
		var paid: Node3D = stage.chip_stack(back, tray, stage.world)
		var t := paid.create_tween()
		t.tween_property(paid, "global_position", Stage.BJ + Stage.BJ_BET + Vector3(0.06, 0, -0.03), 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.5)
		t.tween_callback(func(): stage.slide(paid, bank, 0.45))
		for n in _bj_stacks:
			if is_instance_valid(n):
				var nn: Node3D = n
				_after(1.0, func(): stage.slide(nn, bank, 0.45))
		Sfx.play("chips", -3.0)
	else:
		for n in _bj_stacks:
			stage.slide(n, tray, 0.5)
	_bj_stacks.clear()
	if r0 == "blackjack":
		stage.big_text("¡BLACKJACK!", UI.GOLD_L, 120)
		Sfx.play("success", -4.0)
	elif net > 0.0:
		stage.big_text("+%s" % UI.money(net), UI.GREEN.lightened(0.2), 96)
	elif net < 0.0:
		stage.big_text("LA BANCA GANA" if r0 != "se_pasa" else "SE HA PASADO", UI.RED.lightened(0.15), 90)
	else:
		stage.big_text("EMPATE", UI.AMBER, 90)
	_bj_bet = 0.0
	_refresh()
	_after(2.2, func():
		_bj_clear_table()
		_bj_dealt = false
		_bj_rack()
		_after(0.5, func(): _after_round("blackjack")))


func _bj_clear_table() -> void:
	var all := []
	for k in _bj_cards.keys():
		all.append_array(_bj_cards[k])
	stage.sweep(all, Stage.BJ + Stage.BJ_DISCARD)
	_bj_cards = {"p0": [], "p1": [], "d": []}
	_bj_hole = null
	for n in _bj_stacks:
		if is_instance_valid(n):
			n.queue_free()
	_bj_stacks.clear()


func _resume_blackjack() -> void:
	busy = false
	if _bj_last > 0.0 and float(night["chips"]) >= _bj_last and _bj_bet <= 0.0:
		_bj_add(int(_bj_last), true)
	_bj_offer()


# ------------------------------------------------------------------ tragaperras

func _enter_slot(i: int) -> void:
	where = "slot"
	slot_i = i
	stage.go("slot%d" % i)
	_show_leave(true)
	var s: Dictionary = stage.slots[i]
	var lever: Node3D = s["lever"]
	var root: Node3D = s["root"]
	_table_picks.append(stage.add_pick(lever, AABB(Vector3(-0.04, -0.06, -0.06), Vector3(0.16, 0.56, 0.12)), "Tirar de la palanca (o pulse espacio)", _slot_spin))
	# los tres botones del pupitre (un punto vacío en cada uno: al señalarlo no brilla la máquina entera)
	var btns := [[0.15, "Girar", _slot_spin], [-0.17, "Cambiar la apuesta (5, 25 o 100 M€)", _slot_bet.bind(false)], [-0.02, "Apuesta máxima (100 M€)", _slot_bet.bind(true)]]
	for bdef in btns:
		var spot := Node3D.new()
		root.add_child(spot)
		spot.position = Vector3(float(bdef[0]), 0.955, 0.31)
		_spots.append(spot)
		_table_picks.append(stage.add_pick(spot, AABB(Vector3(-0.045, -0.035, -0.045), Vector3(0.09, 0.07, 0.09)), bdef[1], bdef[2]))
	stage.slot_sign(i, "GRAN PREMIO", "APUESTA %s" % UI.money(slot.bet))
	stage.notice("Tire de la palanca (o espacio) · botón izquierdo: cambiar la apuesta · el del medio: apuesta máxima")
	_refresh()


func _slot_bet(maxbet: bool) -> void:
	if busy:
		return
	if maxbet:
		slot.bet = float(D.SLOT_BETS.back())
	else:
		var k := D.SLOT_BETS.find(int(slot.bet))
		slot.bet = float(D.SLOT_BETS[(k + 1) % D.SLOT_BETS.size()])
	Sfx.play("click", -4.0)
	stage.slot_sign(slot_i, "GRAN PREMIO", "APUESTA %s" % UI.money(slot.bet))
	_refresh()


func _slot_spin() -> void:
	if busy or where != "slot":
		return
	if float(night["chips"]) < slot.bet:
		if float(night["chips"]) >= float(D.SLOT_BETS[0]):
			slot.bet = float(D.SLOT_BETS[0])
			stage.slot_sign(slot_i, "GRAN PREMIO", "APUESTA %s" % UI.money(slot.bet))
		else:
			stage.notice("No le quedan fichas para jugar")
			return
	busy = true
	night["chips"] = float(night["chips"]) - slot.bet
	_refresh()
	slot.rigged = rigged_next
	rigged_next = false
	var res := slot.spin(rng)
	stage.slot_sign(slot_i, "SUERTE...", "APUESTA %s" % UI.money(slot.bet))
	stage.spin_slot(slot_i, res["stops"], Callable(), _slot_done.bind(res))


func _slot_done(res: Dictionary) -> void:
	if closing:
		return
	var x := int(res["x"])
	var back := float(res["back"])
	night["chips"] = float(night["chips"]) + back
	if x > 0:
		stage.slot_win(slot_i, 4.0 if x >= 100 else 2.2)
		stage.slot_sign(slot_i, "¡PREMIO!" if x < 100 else "¡¡GRAN PREMIO!!", "+%s" % UI.money(back))
		stage.big_text("+%s" % UI.money(back - slot.bet) if x > 1 else "RECUPERA %s" % UI.money(back), UI.GOLD_L if x >= 100 else UI.GREEN.lightened(0.2), 110 if x >= 100 else 92)
		Sfx.play("jackpot" if x >= 100 else "slot_win", -2.0)
		if x >= 100:
			stage.shake(0.3)
	else:
		stage.slot_sign(slot_i, "GRAN PREMIO", "APUESTA %s" % UI.money(slot.bet))
	_refresh()
	_after(1.0 if x == 0 else 2.0, func(): _after_round("tragaperras"))


# ------------------------------------------------------------------ el paso de la noche

func _after_round(game: String) -> void:
	if closing:
		return
	night["rounds"] = int(night["rounds"]) + 1
	night["minutes"] = int(night["minutes"]) + int(D.MINUTES.get(game, 5))
	_refresh()
	if int(night["minutes"]) >= D.NIGHT_END:
		_jefa_call()
		return
	if float(night["chips"]) < float(D.CHIPS[0]["v"]):
		if not night["credit_offered"] and float(night["taken"]) > 0.0:
			_event_credit()
		else:
			_say("cashier" if where == "caja" else ("dealer" if where == "blackjack" else "croupier"), "Se ha quedado sin fichas, señor.", 0.3)
			stage.after_lines(func(): _to_cashier(true))
		return
	if _maybe_event():
		return
	_resume()


func _resume() -> void:
	match where:
		"ruleta":
			_resume_roulette()
		"blackjack":
			_resume_blackjack()
		_:
			busy = false


func _maybe_event() -> bool:
	if int(night["rounds"]) >= 2 and not night["bribe_offered"] and night["bribe"] == "" and rng.randf() < 0.42:
		_event_bribe()
		return true
	if not night["photo_done"] and int(night["rounds"]) >= 1 and rng.randf() < 0.16:
		_event_photo()
		return true
	return false


## El anfitrión se acerca: la próxima jugada, arreglada
func _event_bribe() -> void:
	night["bribe_offered"] = true
	busy = true
	stage.clear_cards()
	stage.host_to(where)
	_after(1.6, func():
		_say("host", hd["bribe"], 0.5)
		stage.after_lines(func():
			_cards([{"tag": hd["name"], "title": "Aceptar la jugada", "desc": "La próxima saldrá a su favor... y algún día se la cobrará.", "col": UI.RED, "icon": "candado"},
				{"tag": hd["name"], "title": "Rechazarla", "desc": "«Yo juego limpio.»", "col": UI.GREEN_D, "icon": "check"}], func(i: int):
				if i == 0:
					night["bribe"] = "aceptado"
					rigged_next = true
					_say("host", "Así me gusta. Apueste fuerte, presidente.", 0.3)
					stage.notice("La próxima jugada está arreglada: apueste fuerte")
				else:
					night["bribe"] = "rechazado"
					Perfil.unlock("casino_limpio")
					_say("host", "Como quiera. Un hombre de principios... qué cosa más rara.", 0.3)
				stage.after_lines(func():
					stage.host_to("vestibulo")
					_resume()))))


## Un fotógrafo en la sala
func _event_photo() -> void:
	night["photo_done"] = true
	busy = true
	stage.clear_cards()
	for i in 3:
		_after(0.15 + i * 0.22, func(): stage.flash(stage.cam_pos + Vector3(randf_range(-1.5, 1.5), randf_range(-0.2, 0.3), -2.0)))
	var P: Dictionary = D.PHOTOGRAPHER
	stage.say("", P["text"], UI.CREAM, null, 0.4)
	stage.after_lines(func():
		var specs := []
		var chs: Array = P["choices"]
		for c in chs:
			specs.append({"tag": "El fotógrafo", "title": c["t"], "col": UI.AMBER, "icon": "prensa", "title_k": 0.105})
		_cards(specs, func(i: int):
			var c: Dictionary = chs[i]
			if float(c.get("chips", 0.0)) < 0.0 and float(night["chips"]) < -float(c["chips"]):
				c = chs[1]
			night["chips"] = float(night["chips"]) + float(c.get("chips", 0.0))
			night["corr_add"] = float(night["corr_add"]) + float(c.get("corr", 0.0))
			night["exposure_add"] = float(night["exposure_add"]) + float(c.get("exposure", 0.0))
			if c.get("press", false):
				GS.push_news("Un fotógrafo, expulsado del Gran Casino durante una visita del presidente", 2)
			_refresh()
			_after(0.4, _resume)))


## Sin fichas: el anfitrión ofrece crédito (doble o nada)
func _event_credit() -> void:
	night["credit_offered"] = true
	busy = true
	stage.clear_cards()
	var amount := snappedf(maxf(50.0, float(night["taken"]) * 0.5), 5.0)
	stage.host_to(where)
	_after(1.4, func():
		_say("host", hd["credit"], 0.5)
		stage.after_lines(func():
			_cards([{"tag": "Doble o nada", "title": "Aceptar %s" % UI.money(amount), "desc": "Fichas de %s. Hay que devolverlas... o pagarlas de otra manera." % hd["name"], "col": UI.RED, "icon": "dinero"},
				{"tag": "Basta por hoy", "title": "No, gracias", "desc": "Ir a la caja y acabar la noche.", "col": UI.NAVY3, "icon": "salir"}], func(i: int):
				stage.host_to("vestibulo")
				if i == 0:
					night["credit"] = float(night["credit"]) + amount
					night["chips"] = float(night["chips"]) + amount
					Sfx.play("chips", -2.0)
					_refresh()
					if where == "ruleta":
						_roulette_rack()
					elif where == "blackjack":
						_bj_rack()
					_after(0.4, _resume)
				else:
					_to_cashier(true))))


## Las tres de la mañana: llama la Jefa de Gabinete y se acabó
func _jefa_call() -> void:
	busy = true
	stage.clear_cards()
	Sfx.play("ring", -6.0)
	stage.notice("Le vibra el móvil: la Jefa de Gabinete")
	_after(1.2, func():
		_say("jefa", D.JEFA_CALL[rng.randi() % D.JEFA_CALL.size()], 0.6)
		stage.after_lines(func(): _to_cashier(true)))


# ------------------------------------------------------------------ la caja: cuentas y fin de la noche

func _to_cashier(forced: bool) -> void:
	if closing:
		return
	if where in ["ruleta", "blackjack", "slot"]:
		_cleanup_table()
	where = "caja"
	busy = false
	_show_leave(false)
	stage.go("caja")
	stage.clear_cards()
	var r := Casino.cash_out(night)
	var src: Dictionary = D.SOURCES.get(night["source"], D.SOURCES["reservados"])
	_say("cashier", D.CROUPIER["cashier"][rng.randi() % D.CROUPIER["cashier"].size()], 0.2)
	var line := "Sacó %s de %s. Vuelve con %s en fichas." % [UI.money(float(r["taken"])), String(src["name"]).to_lower(), UI.money(float(r["chips"]))]
	if float(r["credit"]) > 0.0:
		line += " Le debe %s a %s." % [UI.money(float(r["credit"])), hd["name"]]
	stage.caption("La cuenta de la noche", line, UI.GOLD)
	var specs := []
	var keys := []
	var can_go_on: bool = not forced and int(night["minutes"]) < D.NIGHT_END and float(night["chips"]) >= float(D.CHIPS[0]["v"])
	if can_go_on:
		specs.append({"tag": "La noche es joven", "title": "Seguir jugando", "col": UI.NAVY3, "icon": "ceder"})
		keys.append("seguir")
	if float(r["profit"]) > 0.0:
		stage.notice("Ha ganado %s. El dinero público vuelve a su partida: ¿qué hace con el beneficio?" % UI.money(float(r["profit"])))
		for k in D.PROFITS.keys():
			var pd: Dictionary = D.PROFITS[k]
			specs.append({"tag": "Beneficio: %s" % UI.money(float(r["profit"])), "title": pd["name"], "desc": pd["desc"], "col": UI.GREEN_D if k != "cuenta" else UI.RED_D, "icon": pd["icon"], "desc_k": 0.072})
			keys.append("p_" + k)
	elif float(r["hole"]) > 0.0:
		stage.notice("Faltan %s de %s. ¿Cómo se tapa el agujero?" % [UI.money(float(r["hole"])), String(src["name"]).to_lower()])
		for k in D.COVERS.keys():
			var cd: Dictionary = D.COVERS[k]
			var desc: String = cd["desc"]
			if k == "culpar" and GS.ministers.has(src.get("minister", "")):
				desc = "Se cesa a %s y se le echa la culpa del desfase. Él sabe la verdad." % GS.ministers[src["minister"]]["name"]
			elif k == "prestamo":
				desc = "%s lo cubre con un préstamo «entre amigos». Sin rastro en las cuentas... y con una deuda que no es de dinero." % hd["name"]
			specs.append({"tag": "Agujero: %s" % UI.money(float(r["hole"])), "title": cd["name"], "desc": desc, "col": UI.RED_D, "icon": cd["icon"], "desc_k": 0.064})
			keys.append("c_" + k)
	else:
		stage.notice("Ni gana ni pierde: el dinero vuelve entero a su partida")
		specs.append({"tag": "Tablas", "title": "Devolverlo todo y marcharse", "col": UI.GOLD, "icon": "check"})
		keys.append("p_tesoro")
	_cards(specs, func(i: int):
		var k: String = keys[i]
		if k == "seguir":
			stage.caption("", "")
			_go_lobby(false)
		elif k.begins_with("p_"):
			_settle(k.substr(2), "")
		else:
			_settle("", k.substr(2)))


func _settle(profit_choice: String, cover: String) -> void:
	if night["settled"]:
		return
	night["settled"] = true
	busy = true
	stage.clear_cards()
	stage.caption("", "")
	var r := Casino.cash_out(night)
	var out: Array = Casino.settle(night, profit_choice, cover)
	var src: Dictionary = D.SOURCES.get(night["source"], D.SOURCES["reservados"])
	var title := ""
	var col := UI.AMBER
	var line := ""
	if float(r["taken"]) <= 0.0:
		title = "UNA COPA Y A CASA"
		col = UI.CREAM
		line = "No ha tocado una ficha. Pero le han visto entrar."
	elif float(r["profit"]) > 0.0:
		title = "GANA %s" % UI.money(float(r["profit"])).to_upper()
		col = UI.GREEN
		line = {"tesoro": "El beneficio va al Tesoro sin hacer ruido.", "ong": "El beneficio va a una ONG, con foto.", "cuenta": "El beneficio, a una cuenta en Qadar. Nadie lo sabrá nunca. Probablemente."}.get(profit_choice, "")
	elif float(r["hole"]) > 0.0:
		title = "UN AGUJERO DE %s" % UI.money(float(r["hole"])).to_upper()
		col = UI.RED
		line = "%s en %s. %s" % [D.COVERS[cover]["name"] if D.COVERS.has(cover) else "", String(src["name"]).to_lower(), "Ahora, a esperar que nadie tire del hilo."]
	else:
		title = "TABLAS"
		line = "El dinero vuelve entero a su partida."
	if float(r["owed"]) > 0.0:
		line += " Y le debe %s a %s." % [UI.money(float(r["owed"])), hd["name"]]
	Sfx.play("sting_win" if float(r["net"]) > 0.0 else "close", -6.0)
	stage.end_card(title, col, line, Widgets.effect_chips(out, 16, 8), "Volver al Palacio", func(): close())


func close(result = null) -> void:
	if closing:
		return
	if not night.get("settled", false) and float(night.get("taken", 0.0)) > 0.0:
		# (no debería pasar: la noche se cierra en la caja) lo perdido queda escondido
		Casino.settle(night, "tesoro", "contabilidad")
	Sfx.loop_stop("casino")
	Sfx.loop_stop("ball")
	Sfx.loop_stop("reels")
	Sfx.music("music_campaign" if GS.campaign else "music_office", 1.5)
	super(result)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or closing:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		match where:
			"ruleta":
				_spin()
			"slot":
				_slot_spin()
			"blackjack":
				if not _bj_dealt and _bj_bet > 0.0:
					_bj_deal()
		get_viewport().set_input_as_handled()
