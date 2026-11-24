extends Node
## Prueba del comercio y la mesa de negociación con la IA: godot --headless --path . -- --negotest [--pais=valdoria]
##   1. Sin tocar nada, el saldo del comercio es el de antes (perfil × desvío del precio).
##   2. Producir más o menos mueve el precio mundial y el saldo; los métodos tienen efectos; las obras amplían.
##   3. La IA acepta lo justo, contraoferta lo que se queda corto y rechaza lo absurdo, explicando por qué.
##   4. Amenazas: pesan según la credibilidad y el carácter; cumplirlas o no mueve la credibilidad.
##   5. Contratos: dinero cada mes, se rompen con penalización; la IA propone cosas con sentido.
##   6. Todo se guarda y se carga.

const Mercado := preload("res://scripts/systems/mercado.gd")
const N := preload("res://scripts/systems/negociacion.gd")
const R := preload("res://scripts/data/recursos_data.gd")
const W := preload("res://scripts/data/world_data.gd")

var fallos := 0


func _ok(cond: bool, txt: String) -> void:
	print(("  OK   " if cond else "  FALLO ") + txt)
	if not cond:
		fallos += 1


func run() -> void:
	var pais := "valdoria"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pais="):
			pais = a.substr(7)
	GS.save_path = "user://negotest.json"
	GS.new_game({"name": "Test", "party": "MP", "difficulty": 1, "years": 2, "mode": "clasico", "look": {}, "pais": pais, "seed": 1234})
	print("== País: %s" % W.COUNTRY_NAME)
	# 1. sin tocar nada, como antes
	print("\n== 1. Sin tocar nada")
	for r in R.RECURSOS.keys():
		var p := float(GS.mercado["precios"][r])
		var antes := float(R.PERFILES[GS.pais].get(r, 0)) * (p - 100.0) / 100.0 * 0.004 * 1200000.0 / 12.0
		_ok(absf(Mercado.saldo_de(r) - antes) < 0.5, "%s: saldo %.1f (fórmula de antes %.1f) · produce %.1f, consume %.1f, capacidad %.1f de %.1f" % [r, Mercado.saldo_de(r), antes, Mercado.nivel(r), Mercado.consumo(r), float(Mercado.prod(r)["cap"]), Mercado.techo(GS.pais, r, String(Mercado.prod(r)["met"]))])
	var efs := 0.0
	for k in GS.METERS + GS.FACTIONS:
		efs += absf(Mercado.efecto(k))
	_ok(efs < 0.001, "sin cambios de método, ningún efecto en medidores (%.3f)" % efs)
	# 2. producción y precios
	print("\n== 2. Producción y precio mundial")
	var r0 := "alimentos" if Mercado.perfil("alimentos") > 1.0 else _mayor_export()
	var eq0 := Mercado.equilibrio(r0)
	var cap0 := float(Mercado.prod(r0)["cap"])
	Mercado.fijar_objetivo(r0, cap0)
	for i in 4:
		_mes()
	print("  %s: objetivo %.1f, nivel %.1f · equilibrio %.0f → %.0f · precio %.0f" % [r0, cap0, Mercado.nivel(r0), eq0, Mercado.equilibrio(r0), float(GS.mercado["precios"][r0])])
	_ok(Mercado.equilibrio(r0) < eq0 or cap0 <= Mercado.base_prod(GS.pais, r0) + 0.01, "producir más de %s baja el precio de equilibrio" % r0)
	Mercado.fijar_objetivo(r0, maxf(0.0, Mercado.base_prod(GS.pais, r0) - 2.0))
	for i2 in 3:
		_mes()
	_ok(Mercado.equilibrio(r0) > eq0, "recortar %s sube el precio de equilibrio (%.0f)" % [r0, Mercado.equilibrio(r0)])
	Mercado.fijar_objetivo(r0, Mercado.base_prod(GS.pais, r0))
	for i3 in 3:
		_mes()
	# método
	var amb0 := Mercado.efecto("ambiente")
	var dinero0 := GS.debt
	var rm := "industria"
	var otro := String((R.METODOS[rm] as Dictionary).keys()[2])
	Mercado.cambiar_metodo(rm, otro)
	_ok(GS.debt > dinero0, "cambiar de método cuesta dinero (%s)" % UI.money(GS.debt - dinero0))
	print("  %s con «%s»: efectos %s · saldo %s/mes" % [rm, otro, str(_efectos()), UI.money(Mercado.saldo_de(rm))])
	_ok(absf(Mercado.efecto("trabajadores")) > 0.1 or absf(Mercado.efecto("prestigio")) > 0.1, "el método nuevo se nota en los grupos")
	Mercado.cambiar_metodo(rm, Mercado.metodo_inicial(GS.pais, rm))
	_ok(absf(Mercado.efecto("ambiente") - amb0) < 0.01, "volver al método de siempre deshace los efectos")
	# obras
	var ro := "tecnologia"
	var c1 := float(Mercado.prod(ro)["cap"])
	var e := Mercado.ampliar(ro)
	_ok(e == "", "empiezan las obras de %s %s" % [ro, e])
	_ok(Mercado.ampliar(ro) != "", "no se pueden empezar otras obras del mismo recurso a la vez")
	for i4 in 11:
		_mes()
	_ok(float(Mercado.prod(ro)["cap"]) > c1, "al acabar las obras hay más capacidad (%.1f → %.1f)" % [c1, float(Mercado.prod(ro)["cap"])])
	# 3. la IA en la mesa
	print("\n== 3. La IA en la mesa")
	var vend := _vendedor_de_lo_que_nos_falta()
	if vend.is_empty():
		print("  (este país no importa nada que venda la IA: se salta)")
	else:
		var c: String = vend[0]
		var r: String = vend[1]
		GS.countries[c]["rel"] = 20.0
		var pm := N.precio_mercado(r)
		var justo := {"da": [], "pide": [{"tipo": "venta", "r": r, "vol": 1.0, "precio": roundf(pm * 1.06), "meses": 12}], "amenaza": {}}
		print("  %s (%s, poder %d) nos vende %s a precio de mercado+6 (%d): neto %.0f · pronóstico %s" % [N.nombre(c), GS.country_pers(c), int(N.poder(c)), r, int(pm * 1.06), float(N.evaluar(c, justo, false)["neto"]), N.pronostico(c, justo)])
		N.proponer(c, justo)
		var ms := N.mesa(c)
		_ok(String(ms["estado"]) == "aceptada" or (String(ms["autor"]) == "ellos" and String(ms["estado"]) == "abierta"), "propuesta justa: %s" % _ultimo(c))
		var contratos := Mercado.contratos_con(c).size()
		_ok(String(ms["estado"]) != "aceptada" or contratos > 0, "si acepta, hay contrato (%d)" % contratos)
		var corta := {"da": [], "pide": [{"tipo": "venta", "r": r, "vol": 1.0, "precio": roundf(pm * 0.8), "meses": 12}], "amenaza": {}}
		print("  ...ahora al 80 %% del mercado: neto %.0f · pronóstico %s" % [float(N.evaluar(c, corta, false)["neto"]), N.pronostico(c, corta)])
		N.proponer(c, corta)
		_ok(String(ms["autor"]) == "ellos" and String(ms["estado"]) == "abierta" or String(ms["estado"]) == "rechazada", "propuesta baja: contraoferta o rechazo → %s" % _ultimo(c))
		if String(ms["autor"]) == "ellos" and String(ms["estado"]) == "abierta":
			var precio_co := 0.0
			for cl in ms["prop"]["pide"]:
				if cl["tipo"] == "venta":
					precio_co = float(cl["precio"])
			_ok(precio_co > roundf(pm * 0.8) or not (ms["prop"]["da"] as Array).is_empty(), "la contraoferta sube el precio (%.0f) o pide algo más" % precio_co)
			N.aceptar(c)
			_ok(String(ms["estado"]) == "aceptada", "aceptamos su contraoferta y queda firmada")
		var absurda := {"da": [], "pide": [{"tipo": "venta", "r": r, "vol": 4.0, "precio": 45.0, "meses": 36}, {"tipo": "dinero", "m": 9000.0}], "amenaza": {}}
		N.proponer(c, absurda)
		_ok(String(ms["estado"]) == "rechazada", "propuesta absurda: rechazo → %s" % _ultimo(c))
	# tratados según la relación
	var amigo := _pais_rel(true)
	var enemigo := _pais_rel(false)
	GS.countries[amigo]["rel"] = 55.0
	GS.countries[enemigo]["rel"] = -60.0
	var tr := {"da": [], "pide": [{"tipo": "tratado", "k": "inversion"}], "amenaza": {}}
	_ok(N.pronostico(amigo, tr) == "acepta", "un amigo (%s) firma un acuerdo de inversión: %s" % [N.nombre(amigo), N.pronostico(amigo, tr)])
	_ok(N.pronostico(enemigo, tr) == "rechaza", "un enemigo (%s) no: %s" % [N.nombre(enemigo), N.pronostico(enemigo, tr)])
	# 4. amenazas
	print("\n== 4. Amenazas")
	var vic := _pais_debil()
	GS.countries[vic]["rel"] = 0.0
	var pide := {"da": [], "pide": [{"tipo": "dinero", "m": 400.0}], "amenaza": {}}
	var con_am := pide.duplicate(true)
	con_am["amenaza"] = {"k": "sanciones"}
	GS.diplo["cred"] = 90.0
	var sin := float(N.evaluar(vic, pide, false)["neto"])
	var con := float(N.evaluar(vic, con_am, false)["neto"])
	print("  %s (%s, poder %d frente a %d): pedir 400 M sin amenaza %.0f · con sanciones y credibilidad 90: %.0f" % [N.nombre(vic), GS.country_pers(vic), int(N.poder(vic)), int(N.mi_poder()), sin, con])
	_ok(con > sin or GS.country_pers(vic) == "agresivo", "una amenaza creíble pesa (salvo a los agresivos fuertes)")
	GS.diplo["cred"] = 10.0
	var poco := float(N.evaluar(vic, con_am, false)["neto"])
	_ok(poco < con, "con poca credibilidad, la amenaza pesa menos (%.0f)" % poco)
	# cumplir o echarse atrás
	GS.diplo["cred"] = 50.0
	N.mesa(vic)["amenaza"] = {"k": "embajador"}
	var rel0 := float(GS.countries[vic]["rel"])
	N.fx_amenaza({"cumplir": vic})
	_ok(N.credibilidad() > 50.0 and float(GS.countries[vic]["rel"]) < rel0, "cumplir la amenaza: credibilidad %.0f, relación %.0f → %.0f" % [N.credibilidad(), rel0, float(GS.countries[vic]["rel"])])
	N.mesa(vic)["amenaza"] = {"k": "sanciones"}
	var c0 := N.credibilidad()
	N.fx_amenaza({"retirar": vic})
	_ok(N.credibilidad() < c0 - 10.0, "echarse atrás hunde la credibilidad (%.0f → %.0f)" % [c0, N.credibilidad()])
	# 5. contratos y dinero
	print("\n== 5. Contratos")
	var cc := _vendedor_de_lo_que_nos_falta()
	var rr := "gas" if cc.is_empty() else String(cc[1])
	var socio := "norland" if cc.is_empty() else String(cc[0])
	var s0 := Mercado.saldo()
	var k := Mercado.nuevo_contrato("test-1", socio, rr, 1.0, N.precio_mercado(rr) - 10.0, false, 6)
	_ok(Mercado.saldo() > s0 + 30.0, "comprar 1 u. 10 puntos por debajo del mercado ahorra unos 40 M al mes (%s)" % UI.money(Mercado.saldo() - s0, true))
	var debt0 := GS.debt
	N.romper("test-1")
	_ok(Mercado.contrato("test-1").is_empty() and GS.debt > debt0, "romperlo cuesta una indemnización (%s)" % UI.money(GS.debt - debt0))
	var p2 := Mercado.nuevo_pago("test-2", socio, 150.0, 3)
	_ok(absf(Mercado.pagos() - 150.0) < 0.1, "los pagos mensuales cuentan en el saldo")
	for i5 in 4:
		_mes()
	_ok(Mercado.contrato("test-2").is_empty(), "y caducan a su hora")
	# la IA propone
	var n_of := 0
	var tipos := {}
	for c3 in W.COUNTRIES.keys():
		var of := N._oferta_ia(c3)
		if not of.is_empty():
			n_of += 1
			tipos[c3] = N.resumen(of).left(70)
	print("  ofertas que haría la IA ahora: %s" % str(tipos))
	_ok(n_of > 0, "la IA tiene cosas que proponer (%d países)" % n_of)
	# exigencia con amenaza de un país duro
	var duro := ""
	for c4 in R.ARMAS.keys():
		if GS.countries.has(c4) and GS.country_pers(c4) in ["agresivo", "volatil"] and String(R.ARMAS[c4]) != "agua" and Mercado.perfil(String(R.ARMAS[c4])) < -0.5:
			duro = c4
	if duro != "":
		GS.countries[duro]["rel"] = -40.0
		var ex := N._oferta_ia(duro)
		_ok(not (ex.get("amenaza", {}) as Dictionary).is_empty(), "%s, enfadado, exige con amenaza: %s · %s" % [N.nombre(duro), N.resumen(ex), N.texto_amenaza(ex.get("amenaza", {}))])
	# 6. guardar y cargar
	print("\n== 6. Guardar y cargar")
	N.mesa(socio)["hist"].append({"de": "yo", "tipo": "texto", "t": "prueba", "dia": GS.day})
	Mercado.nuevo_contrato("test-3", socio, rr, 0.5, 99.0, true, 12)
	var nivel0 := float(Mercado.prod("tecnologia")["cap"])
	GS.active = true
	GS.no_save = false
	GS.save_game()
	print("  guardada: %s · contratos antes de cargar: %d" % [FileAccess.file_exists(GS.save_path), (GS.mercado["contratos"] as Array).size()])
	GS.mercado = {}
	GS.diplo = {}
	GS.load_game()
	print("  contratos tras cargar: %s" % str(GS.mercado.get("contratos", [])))
	_ok(not Mercado.contrato("test-3").is_empty(), "el contrato sigue tras cargar")
	_ok(absf(float(Mercado.prod("tecnologia")["cap"]) - nivel0) < 0.01, "la capacidad sigue tras cargar")
	_ok((N.mesa(socio)["hist"] as Array).size() > 0, "la mesa de negociación sigue tras cargar")
	_ok(absf(Mercado.saldo()) < 100000.0, "el saldo se calcula tras cargar (%s)" % UI.money(Mercado.saldo(), true))
	# un año entero sin errores, tocando cosas
	for i6 in 12:
		_mes()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://negotest.json"))
	print("\nNEGOCIACIÓN: %s (%d fallos)" % ["OK" if fallos == 0 else "FALLOS", fallos])
	get_tree().quit()


func _mes() -> void:
	for i in 30:
		GS.advance_day()
		if GS.game_ended:
			GS.game_ended = false


func _efectos() -> Dictionary:
	var out := {}
	for k in GS.METERS + GS.FACTIONS:
		var e := Mercado.efecto(k)
		if absf(e) >= 0.05:
			out[k] = snappedf(e, 0.01)
	return out


func _mayor_export() -> String:
	var best := "alimentos"
	var bv := -99.0
	for r in R.RECURSOS.keys():
		if Mercado.perfil(r) > bv:
			bv = Mercado.perfil(r)
			best = r
	return best


func _vendedor_de_lo_que_nos_falta() -> Array:
	for r in R.RECURSOS.keys():
		if Mercado.perfil(r) < -0.5:
			for c in W.COUNTRIES.keys():
				if N.perfil_de(c, r) >= 2.0 and GS.countries.has(c):
					return [c, r]
	return []


func _pais_rel(amigo: bool) -> String:
	var keys := W.COUNTRIES.keys()
	return String(keys[0] if amigo else keys[keys.size() - 1])


func _pais_debil() -> String:
	var best := ""
	var bp := 999.0
	for c in W.COUNTRIES.keys():
		if GS.country_pers(c) != "agresivo" and N.poder(c) < bp:
			bp = N.poder(c)
			best = c
	return best


func _ultimo(c: String) -> String:
	var h: Array = N.mesa(c)["hist"]
	if h.is_empty():
		return "(nada)"
	var e: Dictionary = h.back()
	return "%s %s: %s" % [e["de"], e["tipo"], String(e.get("t", "")).left(120)]
