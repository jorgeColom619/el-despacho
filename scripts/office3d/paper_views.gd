extends Control
## Lienzos 2D que se pintan en texturas del despacho 3D: portada del periódico, hoja del calendario,
## bandera nacional, fondo del retrato oficial y mascotas.

const Flags := preload("res://scripts/ui/flags.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")

const DIARY_JOBS := ["Taxista", "Jubilado", "Jubilada", "Enfermera", "Comerciante", "Estudiante",
	"Profesor", "Camionero", "Panadera", "Bombero", "Cajera", "Albañil", "Repartidora", "Funcionario",
	"Agricultora", "Pescador", "Camarera", "Ingeniera", "Peluquero", "Farmacéutica", "Conductor de autobús", "Fontanero",
	"Abogada", "Cocinero", "Kiosquera", "Electricista", "Cuidadora", "Mecánico", "Investigadora", "Barrendero"]
const DIARY_GOOD := [
	"«Por fin se nota que las cosas mejoran.»",
	"«Yo antes no confiaba, pero ahora veo cambios de verdad.»",
	"«Se vive mejor que hace un año, se lo digo yo.»",
	"«Al menos este gobierno escucha a la gente de la calle.»",
	"«Mis hijos tienen más oportunidades que antes.»",
	"«No todo es perfecto, pero vamos por buen camino.»",
	"«Hacía años que no veía tanta obra en mi barrio.»",
	"«Mi nieto ha encontrado trabajo aquí. No se ha tenido que ir.»",
	"«Este mes me ha sobrado algo. No me pasaba desde hace años.»",
	"«La gente está de mejor humor. Se nota en la calle.»",
	"«He vuelto a abrir la persiana del negocio con ganas.»",
	"«Por fin han arreglado el centro de salud del pueblo.»",
	"«No me gusta su partido, pero reconozco que lo hacen bien.»",
	"«Este año sí que nos vamos de vacaciones.»",
	"«Hay cosas que funcionan. Que no se tuerzan.»",
	"«Mis clientes vuelven a gastar. Eso es buena señal.»",
]
const DIARY_BAD := [
	"«Esto va de mal en peor, que alguien haga algo.»",
	"«Cada vez llego peor a fin de mes.»",
	"«Ya no sé a quién votar si esto sigue así.»",
	"«Prometieron cambios y seguimos esperando.»",
	"«La gente está harta, se nota en la calle.»",
	"«Si esto no cambia pronto, lo vamos a pagar caro.»",
	"«Los políticos viven en otro planeta.»",
	"«El alquiler se me come el sueldo entero.»",
	"«En el ambulatorio me han dado cita para dentro de un mes.»",
	"«Mis hijos están pensando en irse a Norland.»",
	"«Cada vez más persianas cerradas en mi calle.»",
	"«Ya no me fío de nadie, ni de unos ni de otros.»",
	"«Trabajo más que nunca y vivo peor que mis padres.»",
	"«La luz, el gas, la compra... no hay manera.»",
	"«Me prometieron un tren y sigo cogiendo tres autobuses.»",
	"«Que alguien en el Palacio baje a la calle de vez en cuando.»",
]
const DIARY_MID := [
	"«Ni bien ni mal, el país sigue su marcha.»",
	"«Hay cosas buenas y otras que no tanto.»",
	"«Habrá que esperar para ver si esto cuaja.»",
	"«Un día se vive mejor, otro peor. Como siempre.»",
	"«No me quejo, pero tampoco me cuadran las cuentas.»",
	"«Algo se mueve, aunque despacio.»",
	"«Yo, mientras no me suban la luz, contento.»",
	"«La política me da igual; el fútbol, no.»",
	"«Hay días buenos y días malos, como en todas partes.»",
	"«Ni me va mejor ni me va peor: me va igual.»",
	"«Lo importante es que los críos estén bien.»",
	"«Ya veremos en las elecciones. Todavía no lo tengo claro.»",
	"«Que hagan menos ruido y más cosas.»",
	"«Me entero de las noticias por el grupo de la familia. Imagínese.»",
	"«Aquí en el pueblo las cosas van a otro ritmo.»",
	"«Cuando llueve, los del Gobierno no tienen la culpa. Creo.»",
]
const DIARY_TOPIC_GOOD := {
	"economia": "«Al menos los precios ya no suben como antes.»",
	"bienestar": "«La sanidad y los colegios han mejorado, eso sí lo noto.»",
	"seguridad": "«Ahora salgo de noche más tranquila.»",
	"estabilidad": "«Qué gusto no abrir el periódico y encontrar un lío político nuevo.»",
	"prestigio": "«Hasta en el extranjero hablan bien de Valdoria ahora.»",
	"ambiente": "«El aire se respira mejor desde que cuidan el río.»",
}
const DIARY_TOPIC_BAD := {
	"economia": "«La compra cada semana más cara, no llego a nada.»",
	"bienestar": "«Para una cita en el ambulatorio hay que esperar media vida.»",
	"seguridad": "«Ya no se puede caminar tranquilo por mi barrio.»",
	"estabilidad": "«No hay semana sin un escándalo nuevo en el Congreso.»",
	"prestigio": "«Qué vergüenza cuando salimos en las noticias de fuera.»",
	"ambiente": "«El río, cada día más sucio, y nadie hace nada.»",
}

var kind := ""
var pet_kind := ""
var pet_happy := false
var diary_seed := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if kind == "pet":
		_t += delta
		queue_redraw()


func _draw() -> void:
	match kind:
		"newspaper":
			_newspaper()
		"diary":
			_diary()
		"calendar":
			_calendar()
		"flag":
			Flags.draw_valdoria(self, Rect2(Vector2.ZERO, size), Flags.current_style())
		"portrait_bg":
			var top := Color("3a2a1c")
			var bot := Color("120c08")
			for i in 24:
				draw_rect(Rect2(0, size.y * i / 24.0, size.x, size.y / 24.0 + 1), top.lerp(bot, i / 24.0))
			draw_circle(size * Vector2(0.5, 0.42), size.x * 0.42, Color(1, 0.85, 0.6, 0.05))
		"pet":
			PetArt.draw(self, pet_kind, _t, pet_happy, "")


func _newspaper() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.93, 0.9, 0.82))
	draw_string(UI.f_goth, Vector2(0, 52), "El Diario", HORIZONTAL_ALIGNMENT_CENTER, w, 46, Color(0.08, 0.08, 0.08))
	draw_string(UI.f_sans_b, Vector2(0, 70), "DE LA REPÚBLICA", HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(12, 78), Vector2(w - 12, 78), Color(0.1, 0.1, 0.1), 2.0)
	draw_string(UI.f_sans, Vector2(12, 92), UI.date_long(GS.day) if GS.active else "", HORIZONTAL_ALIGNMENT_LEFT, w - 24, 10, Color(0.2, 0.2, 0.2))
	draw_line(Vector2(12, 98), Vector2(w - 12, 98), Color(0.1, 0.1, 0.1), 1.0)
	var hl := "Nuevo Gobierno en Valdoria"
	if GS.news_feed.size() > 0:
		hl = GS.news_feed[0]["t"]
	draw_multiline_string(UI.f_serif_b, Vector2(12, 128), hl, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 25, 4, Color(0.06, 0.06, 0.06))
	var py := 250.0
	_news_photo(Rect2(12, py, w * 0.55, 110), hl)
	for k in 12:
		var x0 := w * 0.55 + 22.0
		draw_line(Vector2(x0, py + 4 + k * 9), Vector2(w - 12, py + 4 + k * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	for k2 in 4:
		draw_line(Vector2(12, py + 124 + k2 * 9), Vector2(w - 12, py + 124 + k2 * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	if GS.news_feed.size() > 1:
		draw_string(UI.f_serif_b, Vector2(12, h - 14), GS.news_feed[1]["t"], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color(0.1, 0.1, 0.1))


## Foto en blanco y negro de la portada, según el titular (fuego, protesta, Congreso, acuerdo, temporal o el
## Palacio), con su trama de puntos de papel de periódico
func _news_photo(r: Rect2, hl: String) -> void:
	var t := hl.to_lower()
	var kind := "palacio"
	var keys := {"fuego": ["incend", "fuego", "arde", "llamas"],
		"temporal": ["temporal", "nieve", "lluvia", "inunda", "sequía", "terremoto", "riada", "dana", "tormenta"],
		"multitud": ["huelga", "disturb", "protest", "calle", "manifest", "revuelta", "marcha", "concentra"],
		"congreso": ["congreso", "ley", "moción", "presupuesto", "diputad", "votación", "escaño"],
		"acuerdo": ["acuerdo", "cumbre", "tratado", "norland", "unión", "kharovia", "tsaing", "sarvenia", "qadar", "aldora", "visita"]}
	for k in keys:
		for word in keys[k]:
			if word in t:
				kind = k
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hl)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	var g := func(v: float) -> Color: return Color(v, v, v)
	# cielo / fondo
	for i in 10:
		var c0: float = 0.78 - i * 0.025 if kind != "fuego" else 0.32 + i * 0.02
		draw_rect(Rect2(x0, y0 + h * i / 10.0, w, h / 10.0 + 1.0), g.call(c0))
	match kind:
		"fuego":
			for i in 14:
				draw_circle(Vector2(x0 + rng.randf() * w, y0 + rng.randf() * h * 0.5), rng.randf_range(10, 24), Color(0.15, 0.15, 0.15, 0.35))
			for i in 9:
				var fx := x0 + rng.randf() * w
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 12, y0 + h), Vector2(fx, y0 + h * rng.randf_range(0.35, 0.65)), Vector2(fx + 12, y0 + h)]), g.call(0.93))
			for i in 6:
				var tx := x0 + rng.randf() * w
				draw_rect(Rect2(tx, y0 + h * 0.62, 3, h * 0.38), g.call(0.06))
				draw_circle(Vector2(tx + 1.5, y0 + h * 0.6), 9, g.call(0.08))
		"temporal":
			for i in 8:
				draw_circle(Vector2(x0 + rng.randf() * w, y0 + rng.randf() * h * 0.3), rng.randf_range(14, 26), g.call(0.48))
			draw_rect(Rect2(x0, y0 + h * 0.72, w, h * 0.28), g.call(0.85))
			for i in 7:
				var hx := x0 + 6 + i * w / 7.0
				var hh := rng.randf_range(18, 34)
				draw_rect(Rect2(hx, y0 + h * 0.72 - hh, w / 9.0, hh), g.call(0.3))
				draw_colored_polygon(PackedVector2Array([Vector2(hx - 3, y0 + h * 0.72 - hh), Vector2(hx + w / 18.0, y0 + h * 0.72 - hh - 10), Vector2(hx + w / 9.0 + 3, y0 + h * 0.72 - hh)]), g.call(0.22))
			for i in 40:
				var sx := x0 + rng.randf() * w
				var sy := y0 + rng.randf() * h * 0.7
				draw_line(Vector2(sx, sy), Vector2(sx - 3, sy + 8), Color(1, 1, 1, 0.5), 1.0)
		"multitud":
			draw_rect(Rect2(x0, y0 + h * 0.18, w, h * 0.45), g.call(0.55))
			for i in 9:
				draw_rect(Rect2(x0 + 6 + i * w / 9.0, y0 + h * 0.24, w / 22.0, h * 0.1), g.call(0.35))
			for i in 60:
				var px := x0 + rng.randf() * w
				var pyy := y0 + h * 0.55 + rng.randf() * h * 0.45
				var s := 0.6 + (pyy - y0 - h * 0.55) / (h * 0.45) * 0.7
				draw_circle(Vector2(px, pyy - 9 * s), 4.5 * s, g.call(0.1))
				draw_rect(Rect2(px - 5 * s, pyy - 5 * s, 10 * s, 18 * s), g.call(0.13))
				if rng.randf() < 0.12:
					draw_rect(Rect2(px - 9 * s, pyy - 30 * s, 18 * s, 11 * s), g.call(0.95))
		"congreso":
			draw_rect(Rect2(x0, y0, w, h), g.call(0.42))
			for i in 6:
				draw_rect(Rect2(x0 + 8 + i * w / 6.0, y0 + 6, 8, h * 0.45), g.call(0.78))
			draw_rect(Rect2(x0, y0 + 4, w, 6), g.call(0.75))
			for row in 4:
				var ry := y0 + h * 0.58 + row * 12
				var n := 12 + row * 3
				for i in n:
					var a := PI * (0.08 + 0.84 * float(i) / float(n - 1))
					var cx := x0 + w * 0.5 - cos(a) * (w * 0.32 + row * 14)
					draw_circle(Vector2(cx, ry - sin(a) * 10), 3.2, g.call(0.12 + row * 0.03))
		"acuerdo":
			for i in 2:
				var fx2 := x0 + w * (0.12 + i * 0.68)
				draw_line(Vector2(fx2, y0 + 6), Vector2(fx2, y0 + h), g.call(0.3), 2.0)
				draw_rect(Rect2(fx2 + 1, y0 + 8, 22, 30), g.call(0.55 + i * 0.2))
			for sx in [0.36, 0.64]:
				var cx2: float = x0 + w * float(sx)
				draw_circle(Vector2(cx2, y0 + h * 0.3), 11, g.call(0.82))
				draw_rect(Rect2(cx2 - 17, y0 + h * 0.42, 34, h * 0.58), g.call(0.13))
				draw_rect(Rect2(cx2 - 3, y0 + h * 0.42, 6, 14), g.call(0.9))
			draw_line(Vector2(x0 + w * 0.42, y0 + h * 0.66), Vector2(x0 + w * 0.58, y0 + h * 0.66), g.call(0.8), 8.0)
		_:
			# fachada del Palacio con su bandera
			draw_rect(Rect2(x0 + w * 0.1, y0 + h * 0.36, w * 0.8, h * 0.5), g.call(0.86))
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + w * 0.06, y0 + h * 0.37), Vector2(x0 + w * 0.5, y0 + h * 0.16), Vector2(x0 + w * 0.94, y0 + h * 0.37)]), g.call(0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + w * 0.2, y0 + h * 0.34), Vector2(x0 + w * 0.5, y0 + h * 0.22), Vector2(x0 + w * 0.8, y0 + h * 0.34)]), g.call(0.62))
			for i in 7:
				var cx3 := x0 + w * (0.16 + i * 0.113)
				draw_rect(Rect2(cx3, y0 + h * 0.4, 6, h * 0.42), g.call(0.97))
				draw_rect(Rect2(cx3 + 6, y0 + h * 0.4, 2, h * 0.42), g.call(0.55))
			draw_rect(Rect2(x0 + w * 0.06, y0 + h * 0.84, w * 0.88, h * 0.06), g.call(0.7))
			draw_rect(Rect2(x0, y0 + h * 0.9, w, h * 0.1), g.call(0.6))
			draw_line(Vector2(x0 + w * 0.5, y0 + h * 0.17), Vector2(x0 + w * 0.5, y0 + h * 0.02), g.call(0.25), 1.5)
			draw_rect(Rect2(x0 + w * 0.5, y0 + h * 0.03, 16, 10), g.call(0.4))
			for i in 5:
				var px2 := x0 + rng.randf_range(0.05, 0.95) * w
				draw_circle(Vector2(px2, y0 + h * 0.86), 3, g.call(0.12))
				draw_rect(Rect2(px2 - 3, y0 + h * 0.87, 6, 10), g.call(0.15))
	# trama de puntos (papel de periódico) y marco
	var step := 4.0
	var yy := 0.0
	while yy < h:
		var xx := fmod(yy, step * 2.0) * 0.5
		while xx < w:
			draw_circle(Vector2(x0 + xx, y0 + yy), 0.8, Color(0, 0, 0, 0.12))
			xx += step
		yy += step
	draw_rect(r, Color(0.1, 0.1, 0.1), false, 1.0)


## Elige nombre, oficio, cita y tono (favorable/tibio/crítico) de un vecino cualquiera según la
## aprobación y los medidores, de forma determinista a partir de `seed_v` (mismo diario hasta el
## siguiente clic). La usan tanto la textura 3D del diario como su lectura ampliada en 2D.
static func pick_opinion(seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var approval: float = GS.approval if GS.active else 50.0
	var mood := "mid"
	if approval >= 60.0:
		mood = "good"
	elif approval < 40.0:
		mood = "bad"
	var job: String = DIARY_JOBS[rng.randi() % DIARY_JOBS.size()]
	var who := "Vecino de Valdoria"
	if GS.active:
		who = DB.rand_name(["m", "f"][rng.randi() % 2])
	var quote := ""
	var topic := ""
	if GS.active and mood != "mid" and rng.randf() < 0.55:
		var pick_key := ""
		var pick_val := 0.0
		for k in GS.METERS:
			var v: float = GS.meters.get(k, 50.0)
			if pick_key == "" or (mood == "bad" and v < pick_val) or (mood == "good" and v > pick_val):
				pick_key = k
				pick_val = v
		quote = (DIARY_TOPIC_BAD if mood == "bad" else DIARY_TOPIC_GOOD).get(pick_key, "")
		topic = pick_key
	if quote == "":
		var pool: Array = {"good": DIARY_GOOD, "bad": DIARY_BAD, "mid": DIARY_MID}[mood]
		quote = pool[rng.randi() % pool.size()]
	return {"who": who, "job": job, "quote": quote, "mood": mood, "topic": topic}


## Pequeño diario de "lo que opina la calle": una cita de un ciudadano cualquiera, con el tono
## (favorable, crítico o tibio) y a veces el tema según cómo vaya el país (aprobación y medidores)
func _diary() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.9, 0.87, 0.78))
	draw_string(UI.f_goth, Vector2(0, 32), "La Voz del Pueblo", HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0.1, 0.1, 0.1))
	draw_line(Vector2(10, 40), Vector2(w - 10, 40), Color(0.1, 0.1, 0.1), 1.5)
	var op := pick_opinion(diary_seed)
	draw_string(UI.f_serif_b, Vector2(14, 64), "%s, %s" % [op["who"], op["job"]], HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15, Color(0.15, 0.15, 0.15))
	draw_multiline_string(UI.f_serif, Vector2(14, 92), op["quote"], HORIZONTAL_ALIGNMENT_LEFT, w - 28, 17, 6, Color(0.1, 0.1, 0.1))
	draw_string(UI.f_sans, Vector2(0, h - 12), "— encuesta de opinión improvisada, clic para leer mejor —", HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.4, 0.4, 0.4, 0.8))


func _calendar() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.97, 0.96, 0.93))
	draw_rect(Rect2(0, 0, w, 30), Color("b3261e"))
	var d := UI.date_dict(GS.day)
	draw_string(UI.f_sans_b, Vector2(0, 22), UI.MONTHS_SHORT[d["month"] - 1] + " " + str(d["year"]), HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color.WHITE)
	draw_string(UI.f_cond_b, Vector2(0, 92), str(d["day"]), HORIZONTAL_ALIGNMENT_CENTER, w, 58, Color(0.12, 0.12, 0.14))
	draw_string(UI.f_sans_m, Vector2(0, 114), UI.WEEKDAYS[d["weekday"]], HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.35, 0.35, 0.4))
