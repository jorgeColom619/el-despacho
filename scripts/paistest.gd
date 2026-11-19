extends Node
## Prueba de los países jugables: aplica cada país y busca en todos los textos de datos restos de Valdoria que no
## deberían quedar (gentilicios, capital, regiones, partidos, personajes), y cuenta lo que se aparta por no tener
## sentido en ese país. Uso: godot --headless --path . -- --paistest

const PD := preload("res://scripts/data/paises_data.gd")
const Pais := preload("res://scripts/systems/pais.gd")
const W := preload("res://scripts/data/world_data.gd")


func run() -> void:
	var fallos := 0
	for p in PD.ORDEN:
		GS.usar_pais(p)
		var ap: Dictionary = Pais.apartados
		print("== %s · eventos al azar: %d (apartados %d) · tramas apartadas: %s · escenarios apartados: %s · cumbres apartadas: %s" % [
			p, DB.all_events.size(), ap.get("eventos", {}).size(), ap.get("tramas", []), ap.get("escenarios", []), ap.get("cumbres", [])])
		if p == "valdoria":
			continue
		var prohibidas := _prohibidas()
		var restos := []
		for path in Pais.DATOS.keys():
			var s: GDScript = load(path)
			for n in Pais.DATOS[path]:
				_buscar(s.get(n), prohibidas, "%s:%s" % [path.get_file(), n], restos)
		print("   restos de Valdoria en los textos: %d" % restos.size())
		# MUESTRA=1: unas frases adaptadas, para leerlas
		if OS.get_environment("MUESTRA") != "":
			var muestra := []
			for path in Pais.DATOS.keys():
				var s2: GDScript = load(path)
				for n in Pais.DATOS[path]:
					_muestras(s2.get(n), muestra)
			muestra.shuffle()
			for m in muestra.slice(0, int(OS.get_environment("MUESTRA"))):
				print("   » ", m)
		for r in restos.slice(0, 40):
			print("   · ", r)
		fallos += restos.size()
		print("   países extranjeros: ", W.COUNTRIES.keys())
		print("   partidos: ", W.PARTIES.values().map(func(x): return "%s (%s, %s)" % [x["name"], x["short"], x["leader"]]))
		print("   regiones: ", W.REGIONS.values().map(func(x): return x["name"]))
	GS.usar_pais("valdoria")
	print("PAISTEST %s" % ("SIN RESTOS" if fallos == 0 else "CON %d RESTOS" % fallos))
	get_tree().quit()


## Palabras de Valdoria que en otro país no deberían aparecer (Valdoria sí puede: es un país extranjero más)
func _prohibidas() -> Array:
	var v: Dictionary = PD.PAISES["valdoria"]
	var out := []
	for g in v["gent"]:
		out.append(g)
		out.append(String(g).capitalize())
	for k in v["regions"].keys():
		out.append(v["regions"][k])
	for k in v["parties"].keys():
		out.append(v["parties"][k]["name"])
		out.append(v["parties"][k]["leader"])
	for k in v["cast"].keys():
		out.append(v["cast"][k])
	# la moneda, si el país tiene otra
	if String(PD.PAISES[Pais.actual].get("currency", "€")) != "€":
		out.append("€")
	return out


func _muestras(val, out: Array) -> void:
	if val is String:
		if val.length() > 40 and (val.contains("Valdoria") or val.contains("Norland") or val.contains("Fairhaven") or val.contains("norland")):
			out.append(val.substr(0, 220))
	elif val is Array:
		for x in val:
			_muestras(x, out)
	elif val is Dictionary:
		for k in val.keys():
			_muestras(val[k], out)


func _buscar(val, prohibidas: Array, donde: String, out: Array) -> void:
	if val is String:
		for w in prohibidas:
			# las erratas del teleprompter cambian a propósito el gentilicio por el del rival
			if String(w) in val and not (w == "Puerto Alba" and donde.ends_with("TOPICS")) and not donde.begins_with("conversaciones_data.gd:TELEPROMPTER_SWAPS"):
				out.append("%s → «%s» en: %s" % [donde, w, val.substr(maxi(0, val.find(w) - 50), 130)])
				return
	elif val is Array:
		for x in val:
			_buscar(x, prohibidas, donde, out)
	elif val is Dictionary:
		for k in val.keys():
			_buscar(val[k], prohibidas, donde, out)
			if k is String:
				_buscar(k, prohibidas, donde + "[clave]", out)
