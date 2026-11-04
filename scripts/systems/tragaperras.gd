extends RefCounted
## Tragaperras de tres rodillos y una línea de premio (ver las tiras y los premios en casino_data.gd).
## Sin interfaz: casino_3d.gd hace girar los rodillos hasta las posiciones que salen aquí.

const D := preload("res://scripts/data/casino_data.gd")

var bet := 25.0
## Posición de cada rodillo (índice en su tira: el símbolo que queda en la línea)
var stops := [0, 0, 0]
## Jugada «arreglada» por el anfitrión: sale el gran premio
var rigged := false


func symbol(reel: int, idx: int) -> String:
	var s: Array = D.STRIPS[reel]
	return s[posmod(idx, s.size())]


func line() -> Array:
	return [symbol(0, stops[0]), symbol(1, stops[1]), symbol(2, stops[2])]


## Gira: devuelve {"stops", "line", "x" (veces la apuesta), "back" (fichas que vuelven)}
func spin(rng: RandomNumberGenerator) -> Dictionary:
	for r in 3:
		if rigged:
			stops[r] = (D.STRIPS[r] as Array).find("sello")
		else:
			stops[r] = rng.randi() % (D.STRIPS[r] as Array).size()
	rigged = false
	var l := line()
	var x := pay_of(l)
	return {"stops": stops.duplicate(), "line": l, "x": x, "back": bet * x}


static func pay_of(l: Array) -> int:
	for p in D.PAYTABLE:
		var ok := true
		for i in 3:
			if p["combo"][i] != "*" and p["combo"][i] != l[i]:
				ok = false
				break
		if ok:
			return int(p["x"])
	return 0


## Lo que devuelve la máquina a la larga (para comprobar los premios): suma de premio × probabilidad
static func rtp() -> float:
	var t := 0.0
	var n0: int = D.STRIPS[0].size()
	var n1: int = D.STRIPS[1].size()
	var n2: int = D.STRIPS[2].size()
	for a in n0:
		for b in n1:
			for c in n2:
				t += pay_of([D.STRIPS[0][a], D.STRIPS[1][b], D.STRIPS[2][c]])
	return t / float(n0 * n1 * n2)
