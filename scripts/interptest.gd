extends Node
## Prueba del intérprete de respuestas escritas: godot --headless --path . -- --interptest
## Pasa frases típicas por varios dilemas reales y muestra qué entiende el juego.

const Interprete := preload("res://scripts/systems/interprete.gd")

const CASES := [
	["fabrica_cierre", ["Que el Estado entre en el capital y salve los empleos", "Busquemos un comprador extranjero", "Es el mercado, no podemos hacer nada",
		"la primera", "Rescátala, pero sin gastar mucho", "Déjame pensarlo unos días", "Quiero un informe antes de decidir", "Lo que usted considere, confío en usted",
		"vale", "NO PIENSO RESCATAR A NADIE!!!", "jajaja qué follón", "eres un inútil", "Que se encargue mi cuñado y me lleve una comisión", "patata"]],
	["banco_quiebra", ["Hay que rescatarlo, no podemos dejar caer el sistema", "Que quiebre, no vamos a pagar con dinero público", "Negocie una fusión con otro banco", "dame tiempo"]],
]


func run() -> void:
	GS.new_game({"name": "Test", "party": "MP", "difficulty": 1, "years": 2, "mode": "clasico", "look": {}})
	for c in CASES:
		var ev := DB.event(c[0])
		print("\n== %s: %s" % [c[0], ev.get("title", "")])
		var i := 0
		for ch in ev.get("choices", []):
			print("   [%d] %s%s" % [i, ch["t"], "  (por defecto)" if i == int(ev.get("default", -1)) else ""])
			i += 1
		for phrase in c[1]:
			var r := Interprete.interpret(phrase, ev)
			var what: String = r["kind"]
			if what == "elige":
				what = "elige [%d]" % int(r["idx"])
			print("   «%s»  →  %s · tono %s · «%s»" % [phrase, what, r["tone"], r["reply"]])
	# coherencia: escribir el texto de una opción (sin el punto final) tiene que elegir esa opción
	var ok := 0
	var n := 0
	var fails := []
	for e in DB.all_events:
		if e["type"] != "advisor":
			continue
		var chs: Array = e.get("choices", [])
		for i in chs.size():
			var txt := GS.fmt(str(chs[i]["t"])).trim_suffix(".")
			var r := Interprete.interpret(txt, e)
			n += 1
			if r["kind"] == "elige" and int(r["idx"]) == i:
				ok += 1
			elif fails.size() < 12:
				fails.append("%s [%d] «%s» → %s %d" % [e["id"], i, txt, r["kind"], int(r["idx"])])
	print("
Coherencia: %d de %d opciones reconocidas (%d %%)" % [ok, n, int(100.0 * ok / maxf(1.0, n))])
	for f in fails:
		print("   fallo: ", f)
	get_tree().quit()
