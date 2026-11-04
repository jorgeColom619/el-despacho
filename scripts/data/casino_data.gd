extends RefCounted
## El Gran Casino: quién invita, de dónde sale el dinero (siempre es público), las fichas, la ruleta, la tragaperras,
## lo que dicen el crupier y el anfitrión, y cómo se tapa (o no) el agujero. Ver scripts/systems/casino.gd.

## Anfitriones: invitan al presidente, le esperan en la sala y, si pierde, le prestan... a cambio de algo.
## country: el país con el que cambia la relación (y el que presta). mode: "meme" solo en ese modo, "serio" fuera de él
const HOSTS := {
	"magnate": {"name": "Byron Vance", "role": "Dueño de Vance Resorts", "country": "norland", "mode": "serio",
		"look": {"g": "m", "skin": 0, "hair": "slick", "hc": 6, "glasses": 0, "suit": "1c1c22", "shirt": "ffffff", "tie": "b08a3e", "age": 2, "beard": "none", "eyes": "4d6a80"},
		"title": "Inauguración del Gran Casino Vance",
		"invite": "Byron Vance, el magnate de Norland, inaugura esta noche el Gran Casino Vance de Santa Aurora y le ha reservado la mesa de honor. Quiere hablarle de «un proyecto que dará miles de empleos». Ir es un gesto con Norland... y un riesgo si alguien le ve con fichas en la mano.",
		"decline": {"rel": {"norland": -2}, "empresarios": -2},
		"greet": ["Señor presidente, bienvenido a mi casa. Esta noche la banca invita... o casi.", "¡Presidente! Las fichas ya están en su mesa. Aquí nadie hace preguntas."],
		"bribe": "Presidente, una cosa entre nosotros: la próxima jugada... digamos que está arreglada. Apueste fuerte. Ya hablaremos de mi licencia otro día.",
		"credit": "¿Una mala racha? Le adelanto lo que necesite. Entre amigos no hay intereses... hay favores.",
		"favor": {"title": "Vance quiere su licencia", "text": "Byron Vance le recuerda aquella noche en su casino. Quiere la licencia para un macrocasino en la costa, con permiso para fumar dentro y sin convenio laboral. «Usted me debe una, presidente»."}},
	"emir": {"name": "Faisal al-Rashid", "role": "Emir de Qadar", "country": "qadar", "mode": "serio",
		"look": {"g": "m", "skin": 3, "hair": "short", "hc": 0, "glasses": 0, "suit": "e9e4d8", "shirt": "ffffff", "tie": "", "age": 1, "beard": "full", "eyes": "2a1c14"},
		"title": "Una noche con el Emir",
		"invite": "El Emir de Qadar ha alquilado entero el Gran Casino de Santa Aurora para «una velada privada entre amigos». Le invita personalmente. Rechazarle sería un desaire... aceptarle, una foto que nadie debería ver.",
		"decline": {"rel": {"qadar": -4}},
		"greet": ["Mi querido presidente. Esta noche el casino es nuestro. Disfrute: Qadar invita.", "Bienvenido, amigo mío. Entre hermanos, el dinero no tiene importancia."],
		"bribe": "Amigo mío, permítame un regalo: la próxima jugada será suya. Solo le pido que recuerde a Qadar cuando se adjudiquen los contratos del puerto.",
		"credit": "¿Su suerte le abandona? Qadar no abandona a sus amigos. Tome lo que necesite.",
		"favor": {"title": "El Emir pide el puerto", "text": "El Emir le recuerda, con una sonrisa, la noche del casino. Quiere que el fondo soberano de Qadar se quede con la concesión del puerto de Santa Aurora... sin concurso."}},
	"drogan": {"name": "Viktor Drogan", "role": "Presidente de Kharovia", "country": "kharovia", "mode": "serio",
		"look": {"g": "m", "skin": 0, "hair": "balding", "hc": 4, "glasses": 0, "suit": "2a2c30", "shirt": "e0e0e0", "tie": "22262b", "age": 2, "beard": "none", "eyes": "6d8aa0"},
		"title": "Una partida con Drogan",
		"invite": "Viktor Drogan está de visita «privada» en Santa Aurora y ha reservado el Gran Casino. Le invita a una partida «entre presidentes». Sus guardaespaldas ya han cerrado la calle. No ir le ofenderá; ir puede salir muy caro.",
		"decline": {"rel": {"kharovia": -5}},
		"greet": ["Presidente. Siéntese. En Kharovia decimos que en la mesa se conoce a los hombres.", "Llega tarde, presidente. Mis hombres ya habían apostado a que no venía."],
		"bribe": "Le voy a hacer un favor, presidente. La próxima jugada es suya. Y cuando Kharovia necesite que Valdoria mire hacia otro lado... usted se acordará de esta noche.",
		"credit": "¿Sin fichas? Kharovia presta. Siempre presta. Y nunca olvida.",
		"favor": {"title": "Drogan cobra su favor", "text": "Viktor Drogan le llama y le recuerda la noche del casino. Quiere que Valdoria vote contra las sanciones a Kharovia en la Unión Continental. «Tengo fotos muy bonitas de aquella noche, presidente»."}},
	"galbana": {"name": "Eusebio Galbana", "role": "Expresidente de Valdoria", "country": "", "mode": "meme",
		"look": {"g": "m", "skin": 1, "hair": "balding", "hc": 6, "glasses": 1, "suit": "3a3020", "shirt": "f2f2f2", "tie": "7a1f2b", "age": 2, "beard": "mustache", "eyes": "3b2a20"},
		"title": "Timba con Galbana",
		"invite": "El expresidente Eusebio Galbana ha montado «una timba sana, entre amigos» en el Gran Casino y le ha mandado un SMS: «Presi, ven, que esta noche se juega lo que se juega, y lo que se juega es mucho, y mucho es lo que se juega». Media Valdoria sabe que no es buena idea.",
		"decline": {"jubilados": -1, "stress": 2},
		"greet": ["¡Presi! Siéntate, que la suerte es como la tortilla: o se cuaja, o no se cuaja.", "Bienvenido. Aquí se viene a ganar, y si no se gana, se viene igual, que es lo importante."],
		"bribe": "Presi, que me ha dicho el crupier, que es primo de mi cuñado, que la próxima sale lo que tú digas. Que esto no es trampa, es... colaboración público-privada.",
		"credit": "¿Sin fichas? Te presto yo, que para eso están los amigos. Y si no te los presto yo, te los presto igual.",
		"favor": {"title": "Galbana quiere una embajada", "text": "Galbana le escribe: «Presi, ¿te acuerdas de la timba? Pues ahora quiero ser embajador. En el Caribe. Que allí se juega bien»."}},
}

## Siempre es dinero público: de dónde sale cambia cuánto se puede sacar, cuánto se nota si falta y a quién le duele
## amounts: las tres cantidades que se ofrecen (M€). risk: lo fácil que es tirar del hilo. cut: lo que se nota si hay
## que recortar ahí para tapar el agujero. minister: a quién se puede echar la culpa
const SOURCES := {
	"reservados": {"name": "Fondos reservados", "icon": "candado", "mode": "todos", "amounts": [100, 200, 300], "risk": 0.6,
		"desc": "Poco dinero y difícil de rastrear: nadie sabe en qué se gastan.", "cut": {"seguridad": -3, "militares": -2}, "minister": "interior"},
	"infraestructuras": {"name": "Partida de Infraestructuras", "icon": "tren", "mode": "todos", "amounts": [300, 700, 1500], "risk": 1.0,
		"desc": "Mucho dinero, pero si falta se paran obras y alguien pregunta por qué.", "cut": {"economia": -3, "clase_media": -2}, "minister": "economia"},
	"defensa": {"name": "Partida de Defensa", "icon": "militares", "mode": "serio", "amounts": [500, 1200, 2500], "risk": 1.3,
		"desc": "La caja más grande. Si se nota el agujero, los militares no lo perdonan.", "cut": {"militares": -7, "seguridad": -2}, "minister": "defensa"},
	"pensiones": {"name": "La hucha de las pensiones", "icon": "jubilados", "mode": "meme", "amounts": [1000, 2500, 5000], "risk": 1.8,
		"desc": "La caja más grande de Valdoria. Total, los jubilados no miran el saldo... ¿o sí?", "cut": {"jubilados": -9}, "minister": "economia"},
}

## Fichas (en millones de euros): valor, color del canto, color de las marcas
const CHIPS := [
	{"v": 5, "col": "b81c2a", "spot": "f2efe6"},
	{"v": 25, "col": "1f7a3a", "spot": "f2efe6"},
	{"v": 100, "col": "18181c", "spot": "e9c46a"},
	{"v": 500, "col": "5b2a86", "spot": "f2efe6"},
]

## La noche: empieza a las 22:30 y a las 3:00 llama la Jefa de Gabinete. Minutos que se van en cada jugada
const NIGHT_START := 22 * 60 + 30
const NIGHT_END := 27 * 60
const MINUTES := {"ruleta": 9, "blackjack": 6, "tragaperras": 3}

## Límites de las mesas (M€)
const LIMITS := {"ruleta": [5, 1000], "blackjack": [10, 1000], "tragaperras": [5, 100]}

# ------------------------------------------------------------------ ruleta

## Orden de las casillas en la rueda (sentido horario empezando por el 0)
const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22,
	18, 29, 7, 28, 12, 35, 3, 26]
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Cuánto paga cada apuesta (x a 1) y su nombre en la mesa
const BETS := {
	"pleno": {"pay": 35, "name": "Pleno"},
	"caballo": {"pay": 17, "name": "Caballo"},
	"transversal": {"pay": 11, "name": "Transversal"},
	"cuadro": {"pay": 8, "name": "Cuadro"},
	"seisena": {"pay": 5, "name": "Seisena"},
	"docena": {"pay": 2, "name": "Docena"},
	"columna": {"pay": 2, "name": "Columna"},
	"rojo": {"pay": 1, "name": "Rojo"},
	"negro": {"pay": 1, "name": "Negro"},
	"par": {"pay": 1, "name": "Par"},
	"impar": {"pay": 1, "name": "Impar"},
	"falta": {"pay": 1, "name": "Falta (1-18)"},
	"pasa": {"pay": 1, "name": "Pasa (19-36)"},
}

# ------------------------------------------------------------------ tragaperras

## Símbolos (en el modo meme, otros dibujos con las mismas probabilidades y premios)
const SYMBOLS := ["cereza", "limon", "campana", "bar", "siete", "sello"]
const SYMBOL_NAMES := {"cereza": "Cereza", "limon": "Limón", "campana": "Campana", "bar": "BAR", "siete": "Siete", "sello": "Sello presidencial"}
const MEME_NAMES := {"cereza": "Cereza", "limon": "Tortilla", "campana": "Paloma", "bar": "Plasma", "siete": "Siete", "sello": "Galbana"}
## Tiras de los rodillos: 12 símbolos cada una (3 cerezas, 3 limones, 2 campanas, 2 BAR, 1 siete, 1 sello)
const STRIPS := [
	["cereza", "bar", "limon", "campana", "cereza", "siete", "limon", "bar", "cereza", "campana", "limon", "sello"],
	["limon", "cereza", "campana", "bar", "limon", "sello", "cereza", "campana", "limon", "bar", "cereza", "siete"],
	["campana", "limon", "cereza", "siete", "bar", "cereza", "limon", "sello", "campana", "cereza", "bar", "limon"],
]
## Premios (veces la apuesta): tres iguales en la línea, o cerezas en los dos primeros rodillos. Devuelve ~92,7 %
const PAYTABLE := [
	{"combo": ["sello", "sello", "sello"], "x": 300},
	{"combo": ["siete", "siete", "siete"], "x": 120},
	{"combo": ["bar", "bar", "bar"], "x": 35},
	{"combo": ["campana", "campana", "campana"], "x": 25},
	{"combo": ["limon", "limon", "limon"], "x": 10},
	{"combo": ["cereza", "cereza", "cereza"], "x": 10},
	{"combo": ["cereza", "cereza", "*"], "x": 2},
]
const SLOT_BETS := [5, 25, 100]

# ------------------------------------------------------------------ frases

const CROUPIER := {
	"bets": ["Hagan juego, señores.", "Hagan juego.", "Pueden apostar."],
	"close": ["No va más.", "No va más, señores."],
	"bj_hello": ["Buenas noches, presidente. Apueste cuando quiera.", "Bienvenido a la mesa. ¿Cuánto juega?"],
	"bj_bust": ["Se ha pasado, lo siento.", "Veintidós. La banca gana."],
	"bj_dealer_bust": ["La banca se pasa.", "Me he pasado. Enhorabuena."],
	"bj_push": ["Empate. Recupera su apuesta.", "Empate."],
	"bj_win": ["Gana usted.", "Enhorabuena, presidente."],
	"bj_lose": ["La banca gana.", "Lo siento, gana la banca."],
	"bj_bj": ["¡Blackjack! Paga tres a dos.", "¡Blackjack!"],
	"cashier": ["Buenas noches. ¿Cambia sus fichas?", "Aquí tiene su cuenta, señor."],
}

## La Jefa de Gabinete al teléfono: a las 3:00 se acaba la noche
const JEFA_CALL := ["Presidente, son las tres de la mañana. Hay un consejo de ministros a las nueve y fotógrafos en la puerta. Salga ya, por favor.",
	"Presidente, ¿dónde está? Son las tres. Si no sale ahora, mañana abre usted todos los telediarios."]

## Un fotógrafo en la sala (una vez por noche, a veces)
const PHOTOGRAPHER := {"title": "Un fotógrafo", "text": "Un fotógrafo de El Heraldo ha colado una cámara en la sala y le ha hecho una foto con las fichas en la mano.",
	"choices": [
		{"t": "Comprarle la tarjeta de memoria (50 M€ en fichas)", "chips": -50.0, "corr": 1.5, "exposure": 2.0},
		{"t": "Sonreír a la cámara: «Es una cena de trabajo»", "exposure": 14.0},
		{"t": "Que seguridad le saque de la sala", "exposure": 8.0, "press": true},
	]}

## Cómo tapar el agujero (si se ha perdido dinero público)
const COVERS := {
	"contabilidad": {"name": "Contabilidad creativa", "desc": "Se apunta como «gastos de representación» repartidos en varios años. No cuesta nada... hasta que alguien tira del hilo.", "icon": "documento"},
	"recorte": {"name": "Recortar sin avisar", "desc": "Se tapa con un recorte en esa misma partida. Lo pagan los ciudadanos, pero el rastro casi desaparece.", "icon": "grafico"},
	"culpar": {"name": "Culpar a un ministro", "desc": "Se cesa al ministro responsable de esa partida y se le echa la culpa del desfase. Él sabe la verdad.", "icon": "salir"},
	"prestamo": {"name": "Préstamo discreto", "desc": "El anfitrión lo cubre con un préstamo «entre amigos». Sin rastro en las cuentas... y con una deuda que no es de dinero.", "icon": "dinero"},
}

## Qué hacer con lo ganado (el principal vuelve a su partida)
const PROFITS := {
	"tesoro": {"name": "Al Tesoro, sin decir nada", "desc": "Las cuentas cuadran mejor de lo esperado y nadie pregunta por qué.", "icon": "dinero"},
	"ong": {"name": "Donarlo a una ONG, con foto", "desc": "Buena prensa... y alguien preguntará de dónde salía el dinero.", "icon": "bienestar"},
	"cuenta": {"name": "A una cuenta en Qadar", "desc": "Nadie lo sabrá nunca. Probablemente.", "icon": "candado"},
}

## Cuando sale todo a la luz: titulares según cuánto dinero público se jugó y se perdió (M€)
const SCANDAL_LEVELS := [
	{"max": 300.0, "head": "El presidente se jugó %s de dinero público en el casino", "fx": {"approval": -3, "clase_media": -3, "jovenes": -2, "estabilidad": -3}},
	{"max": 1500.0, "head": "ESCÁNDALO: %s de dinero público, perdidos en la ruleta", "fx": {"approval": -6, "clase_media": -5, "jovenes": -4, "jubilados": -4, "estabilidad": -8, "prestigio": -4}},
	{"max": 1e12, "head": "%s DE DINERO PÚBLICO EN EL CASINO: VALDORIA, EN SHOCK", "fx": {"approval": -10, "clase_media": -8, "jovenes": -6, "jubilados": -7, "trabajadores": -6, "estabilidad": -14, "prestigio": -8}},
]
