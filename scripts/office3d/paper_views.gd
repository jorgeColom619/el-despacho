extends Control
## Lienzos 2D que se pintan en texturas del despacho 3D: portada del periódico, hoja del calendario,
## bandera nacional, fondo del retrato oficial y mascotas.

const Flags := preload("res://scripts/ui/flags.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")

const DIARY_JOBS := ["Taxista", "Jubilado", "Jubilada", "Enfermera", "Comerciante", "Estudiante",
	"Profesor", "Camionero", "Panadera", "Bombero", "Cajera", "Albañil", "Repartidora", "Funcionario"]
const DIARY_GOOD := [
	"«Por fin se nota que las cosas mejoran.»",
	"«Yo antes no confiaba, pero ahora veo cambios de verdad.»",
	"«Se vive mejor que hace un año, se lo digo yo.»",
	"«Al menos este gobierno escucha a la gente de la calle.»",
	"«Mis hijos tienen más oportunidades que antes.»",
	"«No todo es perfecto, pero vamos por buen camino.»",
]
const DIARY_BAD := [
	"«Esto va de mal en peor, que alguien haga algo.»",
	"«Cada vez llego peor a fin de mes.»",
	"«Ya no sé a quién votar si esto sigue así.»",
	"«Prometieron cambios y seguimos esperando.»",
	"«La gente está harta, se nota en la calle.»",
	"«Si esto no cambia pronto, lo vamos a pagar caro.»",
]
const DIARY_MID := [
	"«Ni bien ni mal, el país sigue su marcha.»",
	"«Hay cosas buenas y otras que no tanto.»",
	"«Habrá que esperar para ver si esto cuaja.»",
	"«Un día se vive mejor, otro peor. Como siempre.»",
	"«No me quejo, pero tampoco me cuadran las cuentas.»",
	"«Algo se mueve, aunque despacio.»",
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
	draw_rect(Rect2(12, py, w * 0.55, 110), Color(0.55, 0.55, 0.57))
	for i in 9:
		draw_line(Vector2(12 + i * 18, py), Vector2(12 + i * 18 + 60, py + 110), Color(1, 1, 1, 0.06), 6.0)
	for k in 12:
		var x0 := w * 0.55 + 22.0
		draw_line(Vector2(x0, py + 4 + k * 9), Vector2(w - 12, py + 4 + k * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	for k2 in 4:
		draw_line(Vector2(12, py + 124 + k2 * 9), Vector2(w - 12, py + 124 + k2 * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	if GS.news_feed.size() > 1:
		draw_string(UI.f_serif_b, Vector2(12, h - 14), GS.news_feed[1]["t"], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color(0.1, 0.1, 0.1))


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
