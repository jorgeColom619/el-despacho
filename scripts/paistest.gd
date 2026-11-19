extends Node
## Prueba de los países jugables: aplica cada país y busca en todos los textos de datos restos de Valdoria que no
## deberían quedar (gentilicios, capital, regiones, partidos, personajes), y cuenta lo que se aparta por no tener
## sentido en ese país. Uso: godot --headless --path . -- --paistest

const PD := preload("res://scripts/data/paises_data.gd")
const Pais := preload("res://scripts/systems/pais.gd")
const W := preload("res://scripts/data/world_data.gd")
const M := preload("res://scripts/systems/mercado.gd")


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


## --mercadotest: precios, cortes de suministro, decisiones y embargo con cada país
func mercado() -> void:

	var fallos := 0
	for p in PD.ORDEN:
		GS.new_game({"name": "Prueba", "party": "MP", "difficulty": 1, "years": 2, "look": {}, "pais": p})
		GS.no_save = true
		GS.set_speed(0)
		var base := GS.monthly_balance()
		print("== %s · precios iniciales %s · comercio %s" % [p, GS.mercado["precios"], UI.money(M.saldo())])
		# subida del gas: quien lo compra pierde, quien lo vende gana
		GS.mercado["precios"]["gas"] = 160.0
		print("   gas a 160: comercio %s · economía %s · inflación %s" % [UI.money(M.saldo(), true), UI.num(M.economia_mod(), 1), UI.num(M.inflacion_mod(), 1)])
		if (M.perfil("gas") < 0.0) != (M.saldo() < 0.0):
			print("   FALLO: el signo del comercio no cuadra con el perfil del gas")
			fallos += 1
		# el proveedor del recurso que más importamos se enfada y nos lo corta
		var objetivo := ""
		for c in M.R.ARMAS.keys():
			var r: String = M.R.ARMAS[c]
			if GS.countries.has(c) and r != "agua" and M.perfil(r) < 0.0:
				objetivo = c
				break
		if objetivo == "":
			print("   (nadie puede cortarnos nada)")
		else:
			var rr: String = M.R.ARMAS[objetivo]
			GS.countries[objetivo]["rel"] = -90.0
			var antes: float = M.precio(rr)
			var meses := 0
			while not GS.mercado["cortes"].has(rr) and meses < 60:
				for i in 30:
					GS.advance_day()
				meses += 1
				for q in [GS.inbox, GS.calls, GS.visitors, GS.alerts]:
					q.clear()
			if not GS.mercado["cortes"].has(rr):
				print("   FALLO: %s no corta %s ni con la relación a -90" % [objetivo, rr])
				fallos += 1
			else:
				print("   %s corta %s tras %d meses · precio para nosotros %d → %d" % [objetivo, rr, meses, int(antes), int(M.precio(rr))])
				GS.apply_fx({"mercado": {"diversificar": rr}}, "prueba", false)
				print("   otros proveedores: precio %d · %s" % [int(M.precio(rr)), GS.mercado["cortes"]])
				GS.apply_fx({"mercado": {"fin_corte": rr}}, "prueba", false)
				if GS.mercado["cortes"].has(rr):
					print("   FALLO: el corte no termina al negociar")
					fallos += 1
		# embargo a Kharovia (o Tsaing)
		var emb := "kharovia" if GS.countries.has("kharovia") else "tsaing"
		var fx: Dictionary = M.embargar(emb)
		print("   embargo a %s: %s · cortes ahora %s" % [emb, fx, GS.mercado["cortes"].keys()])
		# un año entero con el mercado moviéndose
		GS.countries[objetivo if objetivo != "" else "union"]["rel"] = 20.0
		for i in 365:
			GS.advance_day()
			for q in [GS.inbox, GS.calls, GS.visitors, GS.alerts]:
				q.clear()
		print("   un año después: precios %s · comercio %s · inflación %s %%" % [GS.mercado["precios"], UI.money(M.saldo(), true), UI.num(GS.inflation, 1)])
		print("   saldo mensual al empezar %s, ahora %s" % [UI.money(base, true), UI.money(GS.monthly_balance(), true)])
	print("MERCADOTEST %s" % ("SIN FALLOS" if fallos == 0 else "CON %d FALLOS" % fallos))
	get_tree().quit()
