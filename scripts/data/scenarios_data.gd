extends RefCounted
## Escenarios iniciales y tramas (historias de varios meses que se sortean en cada partida).
## Así dos partidas nunca empiezan igual ni cuentan la misma historia.

## Escenarios: cómo está el país el día que jura el cargo.
##   setup.meters / setup.fac: cambios iniciales (se mantienen un tiempo y se van diluyendo)
##   setup.debt: deuda extra en proporción al PIB · setup.cycle: ciclo económico inicial
##   setup.rel / setup.party_rel: relaciones con países y partidos · setup.own_seats: escaños propios ±
##   schedule: eventos guionizados [id, día] · tramas: tramas que este escenario hace más probables
const SCENARIOS := {
	"estable": {
		"name": "Legislatura tranquila", "icon": "sol", "w": 1.4,
		"desc": "Un país sin grandes sobresaltos. Por ahora.",
		"headline": "Valdoria estrena Gobierno en un clima de calma",
		"context": "Los analistas coinciden: el nuevo presidente hereda un país estable. El reto será no estropearlo.",
		"setup": {},
	},
	"recesion": {
		"name": "La gran recesión", "icon": "economia", "w": 1.0,
		"desc": "La economía cae, el paro se dispara y las cuentas no cuadran.",
		"headline": "El nuevo Gobierno hereda una economía en recesión",
		"context": "El paro roza el 17% y la economía encadena tres trimestres a la baja. Los sindicatos ya preparan movilizaciones.",
		"setup": {"meters": {"economia": -14, "bienestar": -4}, "fac": {"trabajadores": -6, "jovenes": -7, "clase_media": -4}, "debt": 0.08, "cycle": -0.85},
		"schedule": [["recesion_paro", 14], ["recesion_astilleros", 40]],
		"tramas": ["ia_empleo", "fusion_bancaria"],
	},
	"bonanza": {
		"name": "Viento de cola", "icon": "economia", "w": 1.0,
		"desc": "La economía vuela... quizá demasiado. Las expectativas, por las nubes.",
		"headline": "Valdoria crece al 4%: el nuevo Gobierno llega en plena bonanza",
		"context": "El empleo bate récords y la bolsa no para de subir. Algunos economistas ya hablan de burbuja.",
		"setup": {"meters": {"economia": 12}, "fac": {"empresarios": 6, "clase_media": 3}, "cycle": 0.85},
		"schedule": [["bonanza_superavit", 30]],
		"tramas": ["burbuja"],
		"force": ["burbuja"],
	},
	"minoria": {
		"name": "Gobierno en minoría", "icon": "votar", "w": 1.0,
		"desc": "Ganó por la mínima. Cada ley será una batalla y los socios lo saben.",
		"headline": "Investidura agónica: el presidente gobernará en minoría",
		"context": "Tras semanas de negociaciones, el presidente ha sido investido por un solo voto. Sus socios ya han pasado la factura.",
		"setup": {"own_seats": -26, "party_rel": {"*": -10}, "meters": {"estabilidad": -10}},
		"schedule": [["minoria_socios", 10], ["minoria_presupuestos", 110]],
		"tramas": ["conspiracion"],
	},
	"herencia": {
		"name": "La herencia envenenada", "icon": "candado", "w": 0.9,
		"desc": "El anterior Gobierno dejó cadáveres en el armario... y un agujero en las cuentas.",
		"headline": "El nuevo presidente promete «abrir las ventanas» tras años de escándalos",
		"context": "El anterior Gobierno cayó por la corrupción. La gente está harta y mirará con lupa cada paso del nuevo presidente.",
		"setup": {"debt": 0.06, "fac": {"clase_media": -5, "jovenes": -4}, "meters": {"estabilidad": -6}},
		"schedule": [["herencia_auditoria", 8], ["herencia_juicio", 150]],
		"tramas": ["expresidente"],
	},
	"dana": {
		"name": "Tras la catástrofe", "icon": "agua", "w": 0.9,
		"desc": "Una gota fría devastó la costa este días antes de su llegada. Toca reconstruir.",
		"headline": "El nuevo Gobierno jura el cargo entre el barro de Marvella",
		"context": "La peor gota fría en un siglo ha dejado pueblos enteros destruidos en la Costa Este. Los damnificados exigen ayudas ya.",
		"setup": {"meters": {"bienestar": -6, "economia": -5, "seguridad": -3}, "fac": {"clase_media": -4, "jubilados": -4}},
		"schedule": [["dana_reconstruccion", 3], ["dana_ayudas", 60], ["dana_aseguradoras", 25]],
		"tramas": ["guerra_agua"],
	},
	"islas": {
		"name": "Las Islas quieren votar", "icon": "bandera", "w": 0.9,
		"desc": "El independentismo isleño, crecido. Un referéndum en el horizonte.",
		"headline": "Quintana avisa al nuevo presidente: «Las Islas votarán»",
		"context": "El Parlamento de las Islas Cordales ha aprobado una hoja de ruta hacia la independencia. Medio país pide mano dura; la otra mitad, diálogo.",
		"setup": {"party_rel": {"CR": -18}, "meters": {"estabilidad": -7}, "flags": ["islas_tension"]},
		"schedule": [["islas_protestas", 20], ["islas_hoja_ruta", 75]],
	},
	"vientos_guerra": {
		"name": "Vientos de guerra", "icon": "ejercito", "w": 0.9,
		"desc": "Kharovia amenaza, Sarvenia rearma y Norland pide lealtad.",
		"headline": "Tensión militar en las fronteras el día de la toma de posesión",
		"context": "Sarvenia ha movilizado reservistas y Kharovia corta el gas a sus vecinos. Los aliados esperan saber de qué lado está el nuevo presidente.",
		"setup": {"rel": {"kharovia": -25, "sarvenia": -20, "norland": 8}, "fac": {"militares": 6}, "meters": {"seguridad": -4}},
		"schedule": [["guerra_gasto_defensa", 15], ["sarvenia_tropas", 45]],
		"tramas": ["injerencia", "pegaso"],
	},
	"energia": {
		"name": "Crisis energética", "icon": "rayo", "w": 0.9,
		"desc": "La luz y el gas, por las nubes. Las familias no llegan a fin de mes.",
		"headline": "La factura de la luz recibe al nuevo presidente: +60% en un año",
		"context": "El precio de la energía se ha disparado. La industria amenaza con parar y la inflación roza el 8%.",
		"setup": {"meters": {"economia": -6}, "fac": {"trabajadores": -5, "clase_media": -5, "empresarios": -4}, "cycle": -0.4, "flags": ["crisis_energia"]},
		"schedule": [["precio_luz", 12], ["energia_apagones", 50]],
		"tramas": ["ia_empleo"],
	},
}

## Tramas: historias de varios meses. Cada partida sortea unas pocas y programa su primer evento.
##   start: primer evento (chain_only) · window: [día mínimo, día máximo] en una legislatura de 2 años
const TRAMAS := {
	"controladores": {"name": "La huelga de los controladores", "start": "controladores_aviso", "window": [60, 400], "w": 1.0},
	"pegaso": {"name": "Espías en el móvil", "start": "pegaso_descubierto", "window": [40, 350], "w": 1.0},
	"burbuja": {"name": "La burbuja inmobiliaria", "start": "burbuja_aviso", "window": [50, 250], "w": 0.8},
	"expresidente": {"name": "El yate del expresidente", "start": "expresidente_yate", "window": [40, 300], "w": 1.0},
	"conspiracion": {"name": "La conspiración interna", "start": "conspiracion_rumor", "window": [90, 380], "w": 1.0},
	"tesis": {"name": "La tesis del presidente", "start": "tesis_acusacion", "window": [50, 400], "w": 1.0},
	"ave_altamira": {"name": "El tren de Altamira", "start": "ave_proyecto", "window": [30, 200], "w": 1.0},
	"guerra_agua": {"name": "La guerra del agua", "start": "agua_trasvase", "window": [60, 350], "w": 0.9},
	"fusion_bancaria": {"name": "La gran fusión bancaria", "start": "fusion_anuncio", "window": [50, 350], "w": 0.9},
	"injerencia": {"name": "Bots extranjeros", "start": "injerencia_bots", "window": [80, 420], "w": 0.9},
	"rescate_mar": {"name": "El barco del Estrecho", "start": "barco_ong", "window": [50, 380], "w": 1.0},
	"ia_empleo": {"name": "Los robots llegan a las oficinas", "start": "ia_despidos", "window": [60, 400], "w": 1.0},
	"inquilinos": {"name": "La huelga de inquilinos", "start": "inquilinos_huelga", "window": [60, 380], "w": 1.0},
}
