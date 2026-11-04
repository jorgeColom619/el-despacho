extends RefCounted
## Blackjack con seis barajas: la banca se planta con 17 (también blando), el blackjack paga 3 a 2, se puede doblar
## con dos cartas (también tras dividir), dividir una vez (los ases reciben una sola carta) y asegurarse cuando la
## banca enseña un as. La banca mira su carta tapada si enseña un as o un diez.
## Sin interfaz: cada acción devuelve la lista de cartas que salen ({"to": "p"/"d", "hand", "card", "down"}) para
## que casino_3d.gd las reparta en la mesa.
## Cartas: 0..51, palo = c / 13 (picas, corazones, diamantes, tréboles), valor = c % 13 (0 as, 1..9 = 2..10, 10 J,
## 11 Q, 12 K).

const DECKS := 6

var shoe: Array = []
## Manos del jugador: {"cards", "bet", "done", "doubled", "split", "res", "back"}
var hands: Array = []
var dealer: Array = []
var active := 0
## "idle", "insurance", "player", "dealer", "done"
var phase := "idle"
var insurance := 0.0
var dealer_bj := false
var _rng: RandomNumberGenerator
## Jugada «arreglada» por el anfitrión: el jugador saca blackjack y la banca se pasa
var rigged := false


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_shuffle()


func _shuffle() -> void:
	shoe.clear()
	for d in DECKS:
		for c in 52:
			shoe.append(c)
	for i in range(shoe.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = shoe[i]
		shoe[i] = shoe[j]
		shoe[j] = t


## ¿Hay que barajar? (la carta de corte, a tres cuartos del sabot)
func needs_shuffle() -> bool:
	return shoe.size() < DECKS * 52 / 4


func _draw() -> int:
	if shoe.is_empty():
		_shuffle()
	return shoe.pop_back()


## Saca del sabot la primera carta que cumpla f (para la jugada arreglada); si no hay, la de arriba
func _draw_where(f: Callable) -> int:
	for i in range(shoe.size() - 1, -1, -1):
		if f.call(int(shoe[i])):
			var c: int = shoe[i]
			shoe.remove_at(i)
			return c
	return _draw()


static func rank(c: int) -> int:
	return c % 13


static func points(c: int) -> int:
	var r := rank(c)
	if r == 0:
		return 11
	return mini(10, r + 1)


static func label(c: int) -> String:
	var r := rank(c)
	return ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][r]


## [total, blando] de unas cartas
static func value(cards: Array) -> Array:
	var t := 0
	var aces := 0
	for c in cards:
		t += points(int(c))
		if rank(int(c)) == 0:
			aces += 1
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return [t, aces > 0]


static func is_bj(cards: Array) -> bool:
	return cards.size() == 2 and int(value(cards)[0]) == 21


## Empieza la mano con la apuesta bet. Devuelve las cartas repartidas (jugador, banca, jugador, banca tapada)
func deal(bet: float) -> Array:
	if needs_shuffle():
		_shuffle()
	hands = [{"cards": [], "bet": bet, "done": false, "doubled": false, "split": false, "res": "", "back": 0.0}]
	dealer = []
	active = 0
	insurance = 0.0
	dealer_bj = false
	var ev := []
	var p1: int
	var d1: int
	var p2: int
	var d2: int
	if rigged:
		# el jugador recibe un as y una figura; la banca, un 6 y un 10 (y luego se pasa)
		p1 = _draw_where(func(c): return rank(c) == 0)
		d1 = _draw_where(func(c): return rank(c) == 5)
		p2 = _draw_where(func(c): return rank(c) >= 9)
		d2 = _draw_where(func(c): return rank(c) >= 9)
	else:
		p1 = _draw()
		d1 = _draw()
		p2 = _draw()
		d2 = _draw()
	hands[0]["cards"].append(p1)
	ev.append({"to": "p", "hand": 0, "card": p1})
	dealer.append(d1)
	ev.append({"to": "d", "card": d1})
	hands[0]["cards"].append(p2)
	ev.append({"to": "p", "hand": 0, "card": p2})
	dealer.append(d2)
	ev.append({"to": "d", "card": d2, "down": true})
	dealer_bj = is_bj(dealer)
	if rank(d1) == 0:
		phase = "insurance"
	else:
		_after_peek()
	return ev


## Tras ofrecer el seguro (o si la banca no enseña un as): si la banca tiene blackjack, se acaba la mano
func _after_peek() -> void:
	var up := points(int(dealer[0]))
	if (up == 11 or up == 10) and dealer_bj:
		phase = "done"
		return
	if is_bj(hands[0]["cards"]):
		hands[0]["done"] = true
		phase = "done"
		return
	phase = "player"


func can_insure() -> bool:
	return phase == "insurance"


## Seguro: la mitad de la apuesta; paga 2 a 1 si la banca tiene blackjack
func set_insurance(take: bool) -> void:
	if phase != "insurance":
		return
	insurance = float(hands[0]["bet"]) * 0.5 if take else 0.0
	_after_peek()


func hand() -> Dictionary:
	return hands[active] if active < hands.size() else {}


func can_double() -> bool:
	if phase != "player":
		return false
	var h := hand()
	return h["cards"].size() == 2 and not h["doubled"] and not (h["split"] and rank(int(h["cards"][0])) == 0)


func can_split() -> bool:
	if phase != "player" or hands.size() > 1:
		return false
	var cs: Array = hand()["cards"]
	return cs.size() == 2 and points(int(cs[0])) == points(int(cs[1]))


func hit() -> Array:
	if phase != "player":
		return []
	var c := _draw()
	var h := hand()
	h["cards"].append(c)
	var ev := [{"to": "p", "hand": active, "card": c}]
	if int(value(h["cards"])[0]) >= 21:
		h["done"] = true
		_next_hand()
	return ev


func stand() -> Array:
	if phase != "player":
		return []
	hand()["done"] = true
	_next_hand()
	return []


## Dobla la apuesta, recibe una sola carta y se planta
func double() -> Array:
	if not can_double():
		return []
	var h := hand()
	h["bet"] = float(h["bet"]) * 2.0
	h["doubled"] = true
	var c := _draw()
	h["cards"].append(c)
	h["done"] = true
	var ev := [{"to": "p", "hand": active, "card": c, "sideways": true}]
	_next_hand()
	return ev


## Divide la pareja en dos manos con la misma apuesta; cada una recibe su segunda carta
func split() -> Array:
	if not can_split():
		return []
	var h: Dictionary = hands[0]
	var second: int = h["cards"].pop_back()
	var h2 := {"cards": [second], "bet": h["bet"], "done": false, "doubled": false, "split": true, "res": "", "back": 0.0}
	h["split"] = true
	hands.append(h2)
	var ev := [{"to": "split"}]
	for i in 2:
		var c := _draw()
		hands[i]["cards"].append(c)
		ev.append({"to": "p", "hand": i, "card": c})
	# con ases divididos, una carta para cada uno y se acabó
	if rank(int(h["cards"][0])) == 0:
		for x in hands:
			x["done"] = true
		_next_hand()
	return ev


func _next_hand() -> void:
	while active < hands.size() and hands[active]["done"]:
		active += 1
	if active >= hands.size():
		phase = "dealer"


## Juega la banca: destapa y pide hasta 17. Si todas las manos se han pasado, solo destapa
func dealer_turn() -> Array:
	var ev := [{"to": "flip"}]
	# (si todas las manos se han pasado o son blackjack, la banca no necesita pedir)
	var alive := false
	for h in hands:
		var natural: bool = is_bj(h["cards"]) and not h["split"]
		if int(value(h["cards"])[0]) <= 21 and not natural:
			alive = true
	if alive and not dealer_bj:
		var guard := 0
		while int(value(dealer)[0]) < 17 and guard < 12:
			guard += 1
			var c: int
			if rigged:
				# la banca (16) se pasa
				c = _draw_where(func(x): return points(x) >= 6 and points(x) <= 10)
			else:
				c = _draw()
			dealer.append(c)
			ev.append({"to": "d", "card": c})
	phase = "done"
	return ev


## Resultado de cada mano: "blackjack", "gana", "empate", "pierde", "se_pasa"; back = fichas que vuelven
func settle() -> Dictionary:
	var dv := int(value(dealer)[0])
	var back := 0.0
	var staked := insurance
	for h in hands:
		staked += float(h["bet"])
		var pv := int(value(h["cards"])[0])
		var bet := float(h["bet"])
		var natural: bool = is_bj(h["cards"]) and not h["split"]
		if pv > 21:
			h["res"] = "se_pasa"
			h["back"] = 0.0
		elif dealer_bj:
			h["res"] = "empate" if natural else "pierde"
			h["back"] = bet if natural else 0.0
		elif natural:
			h["res"] = "blackjack"
			h["back"] = bet * 2.5
		elif dv > 21 or pv > dv:
			h["res"] = "gana"
			h["back"] = bet * 2.0
		elif pv == dv:
			h["res"] = "empate"
			h["back"] = bet
		else:
			h["res"] = "pierde"
			h["back"] = 0.0
		back += float(h["back"])
	var ins_back := insurance * 3.0 if dealer_bj else 0.0
	back += ins_back
	rigged = false
	return {"back": back, "staked": staked, "dealer": dv, "dealer_bj": dealer_bj, "insurance_back": ins_back}
