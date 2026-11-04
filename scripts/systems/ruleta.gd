extends RefCounted
## Ruleta europea (un solo cero): las apuestas que hay sobre el paño, el número que sale y lo que se paga.
## Sin interfaz: casino_overlay.gd dibuja el paño y casino_3d.gd hace girar la rueda.

const D := preload("res://scripts/data/casino_data.gd")

## clave -> {"kind", "nums": Array[int], "amount": float, "at": Vector2 (dónde están las fichas en el paño)}
var bets := {}
## Las apuestas de la jugada anterior (para «repetir»)
var last_bets := {}
## Últimos números que han salido (el más reciente al final)
var history: Array = []


static func color_of(n: int) -> String:
	if n == 0:
		return "verde"
	return "rojo" if n in D.REDS else "negro"


## Casilla de la rueda (posición en D.WHEEL) donde está el número n
static func pocket_of(n: int) -> int:
	return D.WHEEL.find(n)


static func key_of(kind: String, nums: Array) -> String:
	var s := nums.duplicate()
	s.sort()
	return "%s:%s" % [kind, ",".join(s.map(func(x): return str(x)))]


## Números que cubre una apuesta exterior
static func outside_nums(kind: String, arg: int = 0) -> Array:
	var out := []
	for n in range(1, 37):
		match kind:
			"docena":
				if (n - 1) / 12 == arg:
					out.append(n)
			"columna":
				if (n - 1) % 3 == arg:
					out.append(n)
			"rojo":
				if n in D.REDS:
					out.append(n)
			"negro":
				if not (n in D.REDS):
					out.append(n)
			"par":
				if n % 2 == 0:
					out.append(n)
			"impar":
				if n % 2 == 1:
					out.append(n)
			"falta":
				if n <= 18:
					out.append(n)
			"pasa":
				if n >= 19:
					out.append(n)
	return out


func total() -> float:
	var t := 0.0
	for k in bets:
		t += float(bets[k]["amount"])
	return t


func on_key(key: String) -> float:
	return float(bets[key]["amount"]) if bets.has(key) else 0.0


## Añade amount a la apuesta (la crea si no estaba). Devuelve su clave
func add(kind: String, nums: Array, amount: float, at := Vector2.ZERO) -> String:
	var k := key_of(kind, nums)
	if not bets.has(k):
		bets[k] = {"kind": kind, "nums": nums.duplicate(), "amount": 0.0, "at": at}
	bets[k]["amount"] = float(bets[k]["amount"]) + amount
	return k


## Quita hasta amount de esa apuesta; devuelve lo que se ha quitado
func take(key: String, amount: float) -> float:
	if not bets.has(key):
		return 0.0
	var a: float = minf(amount, float(bets[key]["amount"]))
	bets[key]["amount"] = float(bets[key]["amount"]) - a
	if float(bets[key]["amount"]) <= 0.001:
		bets.erase(key)
	return a


func clear() -> float:
	var t := total()
	bets.clear()
	return t


## Lo que pagaría la mesa (fichas devueltas, apuesta incluida) si saliera n
func payout_if(n: int) -> float:
	var p := 0.0
	for k in bets:
		var b: Dictionary = bets[k]
		if n in b["nums"]:
			p += float(b["amount"]) * (1.0 + float(D.BETS[b["kind"]]["pay"]))
	return p


## El número que más paga a las apuestas de la mesa (la jugada «arreglada» del anfitrión)
func best_number() -> int:
	var best := 0
	var bp := -1.0
	for n in 37:
		var p := payout_if(n)
		if p > bp:
			bp = p
			best = n
	return best


## Cierra la jugada con el número n: {"n", "back" (fichas que vuelven), "staked", "winners": [claves], "losers": [claves]}
func settle(n: int) -> Dictionary:
	var back := 0.0
	var winners := []
	var losers := []
	for k in bets:
		var b: Dictionary = bets[k]
		if n in b["nums"]:
			back += float(b["amount"]) * (1.0 + float(D.BETS[b["kind"]]["pay"]))
			winners.append(k)
		else:
			losers.append(k)
	var staked := total()
	last_bets = bets.duplicate(true)
	history.append(n)
	if history.size() > 12:
		history.pop_front()
	return {"n": n, "back": back, "staked": staked, "winners": winners, "losers": losers}
