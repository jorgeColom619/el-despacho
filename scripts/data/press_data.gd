extends RefCounted
## Preguntas de prensa, frases de discurso y contenido del debate electoral.
## Tonos: honesto, evasivo, firme, humor, ataque

const QUESTIONS := [
	# --- economía
	{"q": "El paro está en el {paro}%. ¿Cuándo va a notar la gente de la calle su política económica?", "cond": {"lt": {"economia": 45}},
		"a": [
			{"t": "Reconozco que vamos lento. Pero las reformas estructurales tardan en dar fruto.", "tone": "honesto", "s": 4, "fx": {"clase_media": 1}},
			{"t": "Los datos de afiliación de este mes son los mejores de la década.", "tone": "evasivo", "s": -2, "fx": {}},
			{"t": "Heredamos un país en ruinas. La oposición debería pedir perdón.", "tone": "ataque", "s": 1, "fx": {"estabilidad": -1, "trabajadores": 1}},
			{"t": "Cuando me dejen de hacer esta pregunta. Es broma. En seis meses.", "tone": "humor", "s": -3, "fx": {"trabajadores": -1}},
		]},
	{"q": "La economía crece al {crec}%. ¿Se atribuye usted el mérito?", "cond": {"gt": {"economia": 58}},
		"a": [
			{"t": "El mérito es de los trabajadores y empresas de Valdoria. Nosotros solo quitamos obstáculos.", "tone": "honesto", "s": 6, "fx": {"trabajadores": 1, "empresarios": 1}},
			{"t": "Sí. Hace un año nos decían que era imposible.", "tone": "firme", "s": 3, "fx": {}},
			{"t": "Me atribuyo el mérito, el tiempo soleado y el Mundial.", "tone": "humor", "s": 4, "fx": {"jovenes": 1}},
		]},
	{"q": "La deuda pública ya supera el {deuda}% del PIB. ¿No está hipotecando a nuestros hijos?", "cond": {"gt": {"debt": 100.0}},
		"a": [
			{"t": "Tiene razón en preocuparse. Presentaremos un plan de consolidación creíble.", "tone": "honesto", "s": 4, "fx": {"empresarios": 1}},
			{"t": "Endeudarse para invertir en el futuro no es hipotecar, es sembrar.", "tone": "firme", "s": 2, "fx": {"jovenes": 1}},
			{"t": "Todos los países tienen deuda. Siguiente pregunta.", "tone": "evasivo", "s": -4, "fx": {}},
		]},
	{"q": "La inflación se come los sueldos. ¿Va a subir los salarios públicos?", "cond": {"min_day": 60},
		"a": [
			{"t": "Subiremos los salarios públicos en línea con la inflación.", "tone": "firme", "s": 4, "fx": {"trabajadores": 2, "money": -400}},
			{"t": "Hay que ser prudentes. No podemos alimentar la espiral de precios.", "tone": "honesto", "s": 0, "fx": {"empresarios": 1, "trabajadores": -1}},
			{"t": "Estamos estudiando todas las opciones.", "tone": "evasivo", "s": -3, "fx": {}},
		]},
	# --- sociedad
	{"q": "Las listas de espera en sanidad superan los seis meses. ¿Qué les dice a los enfermos?", "cond": {"lt": {"bienestar": 48}},
		"a": [
			{"t": "Que les pido perdón. Y que vamos a poner más dinero en la sanidad pública.", "tone": "honesto", "s": 5, "fx": {"jubilados": 2}},
			{"t": "Que la culpa es de las comunidades que gestionan los hospitales.", "tone": "ataque", "s": -2, "fx": {"estabilidad": -1}},
			{"t": "Que la sanidad valdoriana es de las mejores del mundo.", "tone": "evasivo", "s": -5, "fx": {"jubilados": -1}},
		]},
	{"q": "Los jóvenes no pueden emanciparse hasta los 30 años. ¿Tiene usted algún plan?", "cond": {"min_day": 30},
		"a": [
			{"t": "Vivienda pública, alquiler asequible y empleo estable. En ese orden.", "tone": "firme", "s": 4, "fx": {"jovenes": 2}},
			{"t": "Yo me emancipé a los 31 y aquí estoy.", "tone": "humor", "s": -2, "fx": {"jovenes": -2}},
			{"t": "Es un problema de todo el continente, no solo de Valdoria.", "tone": "evasivo", "s": -3, "fx": {"jovenes": -1}},
		]},
	{"q": "Los datos de delincuencia son los peores en diez años. ¿Está perdiendo el control?", "cond": {"lt": {"seguridad": 45}},
		"a": [
			{"t": "No. Más policías en la calle desde el mes que viene.", "tone": "firme", "s": 4, "fx": {"clase_media": 1, "jubilados": 1}},
			{"t": "Los datos hay que leerlos con contexto. Hay más denuncias porque la gente confía más.", "tone": "evasivo", "s": -2, "fx": {}},
			{"t": "Es la herencia de años de recortes de la oposición.", "tone": "ataque", "s": 0, "fx": {"estabilidad": -1}},
		]},
	{"q": "¿Qué opina de las protestas ecologistas que cortan carreteras cada viernes?", "cond": {"lt": {"ambiente": 45}},
		"a": [
			{"t": "Entiendo su angustia. Tienen razón en el fondo, aunque no comparta las formas.", "tone": "honesto", "s": 3, "fx": {"jovenes": 2, "jubilados": -1}},
			{"t": "La ley es para todos. Quien corte una carretera será sancionado.", "tone": "firme", "s": 1, "fx": {"clase_media": 1, "jovenes": -2}},
			{"t": "Yo también corto carreteras... cuando voy en caravana oficial.", "tone": "humor", "s": -4, "fx": {"jovenes": -1}},
		]},
	# --- política
	{"q": "¿Tiene usted mayoría suficiente para gobernar o esto es un gobierno en funciones permanente?", "cond": {"lt": {"estabilidad": 45}},
		"a": [
			{"t": "Gobernaremos con diálogo. Mi puerta está abierta a todos los grupos.", "tone": "honesto", "s": 4, "fx": {"estabilidad": 1}},
			{"t": "Tengo la legitimidad de las urnas. Quien bloquee, que lo explique.", "tone": "firme", "s": 1, "fx": {}},
			{"t": "Pregúntele a la oposición, que es experta en bloquear.", "tone": "ataque", "s": -1, "fx": {"estabilidad": -1}},
		]},
	{"q": "Su índice de aprobación está en el {aprob}%. ¿Se plantea dimitir?", "cond": {"lt": {"approval": 35}},
		"a": [
			{"t": "No. Los valdorianos me eligieron para cuatro años difíciles, no para cuatro meses fáciles.", "tone": "firme", "s": 5, "fx": {"estabilidad": 1}},
			{"t": "Las encuestas suben y bajan. Mi compromiso, no.", "tone": "evasivo", "s": 1, "fx": {}},
			{"t": "Solo si la oposición promete no presentarse.", "tone": "humor", "s": 2, "fx": {"jovenes": 1}},
		]},
	{"q": "{opo} dice que usted es 'el peor presidente de la historia'. ¿Qué le responde?", "cond": {"min_day": 45},
		"a": [
			{"t": "Respeto a {opo}. Prefiero hablar de propuestas que de insultos.", "tone": "honesto", "s": 5, "fx": {"clase_media": 1}},
			{"t": "Viniendo de quien viene, lo tomo como un halago.", "tone": "ataque", "s": 2, "fx": {}},
			{"t": "Todavía me queda tiempo para mejorar esa marca.", "tone": "humor", "s": 4, "fx": {"jovenes": 1}},
		]},
	{"q": "¿Es cierto que su partido se financió ilegalmente en el pasado?", "cond": {"gt": {"corr": 8}},
		"a": [
			{"t": "Colaboraremos con la justicia. Si alguien delinquió, pagará.", "tone": "honesto", "s": 3, "fx": {"clase_media": 1}},
			{"t": "Es una campaña orquestada por los de siempre.", "tone": "ataque", "s": -4, "fx": {"estabilidad": -1}},
			{"t": "No voy a comentar asuntos judicializados.", "tone": "evasivo", "s": -2, "fx": {}},
		]},
	{"q": "Su Gobierno ha aprobado la {ultima_ley}. ¿No teme el rechazo de una parte de la sociedad?", "cond": {"has_law": true},
		"a": [
			{"t": "Gobernar es decidir. Estoy convencido de que es lo mejor para Valdoria.", "tone": "firme", "s": 4, "fx": {}},
			{"t": "Escucharemos a todos y corregiremos lo que haya que corregir.", "tone": "honesto", "s": 2, "fx": {"estabilidad": 1}},
			{"t": "Ya veremos. Todavía hay que desarrollarla.", "tone": "evasivo", "s": -3, "fx": {}},
		]},
	# --- internacional
	{"q": "¿Es Valdoria un país soberano o una colonia de Norland?", "cond": {"gt": {"rel_norland": 40}},
		"a": [
			{"t": "Norland es un aliado, no un amo. Decidimos en Santa Aurora.", "tone": "firme", "s": 4, "fx": {"jovenes": 1}},
			{"t": "Tener amigos poderosos no es una debilidad.", "tone": "honesto", "s": 1, "fx": {"militares": 1}},
			{"t": "Pregunta para la próxima cumbre. Siguiente.", "tone": "evasivo", "s": -3, "fx": {}},
		]},
	{"q": "¿Por qué hace negocios con el régimen de Drogan?", "cond": {"gt": {"rel_kharovia": 15}},
		"a": [
			{"t": "El gas no entiende de ideologías. La calefacción de las familias, tampoco.", "tone": "firme", "s": 1, "fx": {"trabajadores": 1, "jovenes": -1}},
			{"t": "Es una relación pragmática y temporal.", "tone": "evasivo", "s": -1, "fx": {}},
			{"t": "Tiene razón. Revisaremos esa relación.", "tone": "honesto", "s": 3, "fx": {"rel": {"kharovia": -4}}},
		]},
	{"q": "Tensión con Sarvenia en la frontera. ¿Estamos al borde de una guerra?", "cond": {"lt": {"rel_sarvenia": -25}},
		"a": [
			{"t": "No. Pero que nadie confunda nuestra prudencia con debilidad.", "tone": "firme", "s": 5, "fx": {"militares": 1, "clase_media": 1}},
			{"t": "Estamos agotando todas las vías diplomáticas.", "tone": "honesto", "s": 2, "fx": {"prestigio": 1}},
			{"t": "Si Olmedo quiere guerra, la tendrá.", "tone": "ataque", "s": -3, "fx": {"rel": {"sarvenia": -6}, "militares": 2, "prestigio": -2}},
		]},
	{"q": "¿Qué papel quiere que juegue Valdoria en el mundo?", "cond": {},
		"a": [
			{"t": "Un país puente: fiable para nuestros socios y firme con quien amenace la paz.", "tone": "firme", "s": 4, "fx": {"prestigio": 1}},
			{"t": "Primero, arreglar nuestra casa. Luego, el mundo.", "tone": "honesto", "s": 2, "fx": {"clase_media": 1}},
			{"t": "El de campeones del mundo. De fútbol, por ejemplo.", "tone": "humor", "s": 1, "fx": {"jovenes": 1}},
		]},
	# --- anecdóticas / flags
	{"q": "¿Es cierto que su perro Tribuno mordió al embajador de Norland en la recepción?", "cond": {"flag": "perro"},
		"a": [
			{"t": "Tribuno tiene muy buen olfato diplomático. Sin comentarios.", "tone": "humor", "s": 6, "fx": {"jovenes": 2, "rel": {"norland": -1}}},
			{"t": "Fue un malentendido. Ya hemos enviado disculpas.", "tone": "honesto", "s": 2, "fx": {}},
		]},
	{"q": "Hablemos del OVNI. ¿Tiene usted información que no comparte con los ciudadanos?", "cond": {"flag_event": "ovni"},
		"a": [
			{"t": "Si supiera algo de extraterrestres, sería el presidente más feliz del mundo.", "tone": "humor", "s": 5, "fx": {"jovenes": 2}},
			{"t": "La investigación sigue abierta.", "tone": "evasivo", "s": 0, "fx": {}},
		]},
	{"q": "Usted prometió regenerar la política. ¿Qué ha cambiado realmente?", "cond": {"min_day": 150},
		"a": [
			{"t": "Menos de lo que querría. Pero más de lo que nadie hizo antes.", "tone": "honesto", "s": 4, "fx": {"clase_media": 1}},
			{"t": "Hemos aprobado la ley de transparencia más ambiciosa del continente.", "tone": "firme", "s": 3, "fx": {}, "req_policy": "transparencia"},
			{"t": "Mucho. Pregunte a sus lectores.", "tone": "evasivo", "s": -3, "fx": {}},
		]},
	{"q": "¿Cómo se encuentra de salud? Se le ve agotado.", "cond": {"gt": {"stress": 65}},
		"a": [
			{"t": "Perfectamente. Duermo cuatro horas, como los grandes estadistas.", "tone": "humor", "s": 1, "fx": {}},
			{"t": "Es un trabajo exigente. Me cuido, gracias por preguntar.", "tone": "honesto", "s": 3, "fx": {"jubilados": 1}},
		]},
	{"q": "¿Qué nota se pone como presidente, del uno al diez?", "cond": {},
		"a": [
			{"t": "Un siete. Aprobado alto, con mucho por mejorar.", "tone": "honesto", "s": 4, "fx": {}},
			{"t": "Un diez. Y porque no hay once.", "tone": "humor", "s": 0, "fx": {"jovenes": 1, "clase_media": -1}},
			{"t": "Las notas las ponen los ciudadanos en las urnas.", "tone": "evasivo", "s": 1, "fx": {}},
		]},
	{"q": "Las Islas Cordales hablan de independencia. ¿Permitirá un referéndum?", "cond": {"flag": "islas_tension"},
		"a": [
			{"t": "La Constitución es clara. Pero el diálogo, siempre.", "tone": "honesto", "s": 3, "fx": {"estabilidad": 1}},
			{"t": "Jamás. Valdoria es indivisible.", "tone": "firme", "s": 1, "fx": {"militares": 1, "party": {"CR": -5}}},
		]},
	{"q": "¿No cree que los ciudadanos merecen saber qué hace su Gobierno con los servicios secretos?", "cond": {"gt": {"corr": 12}},
		"a": [
			{"t": "La seguridad nacional exige discreción. Pero no hay nada ilegal.", "tone": "firme", "s": 0, "fx": {}},
			{"t": "Comparecerá el director del CNI en el Congreso.", "tone": "honesto", "s": 3, "fx": {"estabilidad": -1}},
			{"t": "No sé de qué me habla.", "tone": "evasivo", "s": -5, "fx": {"clase_media": -1}},
		]},
]

const SPEECH := {
	"apertura": [
		{"t": "Queridos compatriotas: hoy me dirijo a ustedes con humildad y con determinación.", "fx": {"clase_media": 1.0, "jubilados": 1.0}},
		{"t": "Valdorianas y valdorianos: vivimos un momento decisivo para nuestra historia.", "fx": {"militares": 1.0, "clase_media": 0.5}},
		{"t": "Buenas noches. Seré breve, porque ustedes merecen hechos y no palabras.", "fx": {"trabajadores": 1.0, "jovenes": 1.0}},
		{"t": "Amigos: lo que nos une es mucho más fuerte que lo que nos separa.", "fx": {"estabilidad": 1.0, "jubilados": 0.5}},
	],
	"economia": [
		{"t": "Nuestra economía crece. Cada nuevo empleo es una familia que vuelve a sonreír.", "fx": {"trabajadores": 1.5, "clase_media": 1.0}, "need": {"gt": {"economia": 50}}},
		{"t": "Sé que llegar a fin de mes es difícil. Por eso bajaremos los precios de lo esencial.", "fx": {"trabajadores": 1.5, "jubilados": 1.0}},
		{"t": "Las empresas son el motor del progreso. Vamos a liberar su energía.", "fx": {"empresarios": 2.0, "trabajadores": -0.5}},
		{"t": "Quien más tiene, más debe aportar. Esa es la esencia de la justicia fiscal.", "fx": {"trabajadores": 2.0, "empresarios": -1.5}},
	],
	"social": [
		{"t": "Nuestra sanidad pública es un tesoro que defenderé con uñas y dientes.", "fx": {"jubilados": 2.0, "trabajadores": 1.0}},
		{"t": "Ningún joven debería tener que emigrar para cumplir sus sueños.", "fx": {"jovenes": 2.0, "clase_media": 0.5}},
		{"t": "La seguridad es la primera de las libertades. Y no habrá impunidad.", "fx": {"clase_media": 1.5, "jubilados": 1.0, "jovenes": -0.5}},
		{"t": "El planeta no espera. Nuestra generación será la del gran cambio verde.", "fx": {"jovenes": 2.0, "empresarios": -0.5}},
	],
	"tragedia": [
		{"t": "Hoy Valdoria llora. Ninguna palabra puede reparar el dolor de las familias.", "fx": {"clase_media": 1.5, "jubilados": 1.5}},
		{"t": "Llegaremos hasta el fondo. Si hubo responsables, responderán ante la justicia.", "fx": {"clase_media": 1.5, "estabilidad": 1.0}},
		{"t": "En los peores momentos, este país siempre ha sabido levantarse unido.", "fx": {"jubilados": 1.0, "militares": 1.0, "trabajadores": 1.0}},
		{"t": "Decreto tres días de luto oficial. Las banderas ondearán a media asta.", "fx": {"militares": 1.0, "jubilados": 1.0}},
	],
	"campana": [
		{"t": "¡Cuatro años más para terminar lo que empezamos!", "fx": {"trabajadores": 1.0, "clase_media": 1.0}},
		{"t": "¡La alternativa es volver al pasado! ¡Y el pasado no vuelve!", "fx": {"jovenes": 1.5, "jubilados": -0.5}},
		{"t": "¡Esta tierra merece un Gobierno que no se rinde!", "fx": {"militares": 1.0, "trabajadores": 1.0}},
		{"t": "¡Votad con el corazón, pero también con la cabeza!", "fx": {"clase_media": 1.5, "empresarios": 0.5}},
	],
	"promesa": [
		{"t": "Les prometo que no subiré los impuestos a la clase trabajadora.", "fx": {"trabajadores": 1.5, "clase_media": 1.5}},
		{"t": "Les prometo que las pensiones nunca perderán poder adquisitivo.", "fx": {"jubilados": 2.5}},
		{"t": "Les prometo un país más seguro, más limpio y más justo.", "fx": {"jovenes": 1.0, "clase_media": 1.0}},
		{"t": "Les prometo trabajar cada día como si fuera el último de mi mandato.", "fx": {"estabilidad": 1.0, "clase_media": 1.0}},
	],
	"cierre": [
		{"t": "Viva Valdoria y viva su gente. Buenas noches.", "fx": {"militares": 1.0, "jubilados": 1.0}},
		{"t": "El futuro no se espera: se construye. Construyámoslo juntos.", "fx": {"jovenes": 1.5, "clase_media": 1.0}},
		{"t": "Gracias por su confianza. No les fallaré.", "fx": {"clase_media": 1.0, "trabajadores": 1.0}},
	],
}

const DEBATE := [
	{"topic": "Economía", "attack": "Bajo su Gobierno la cesta de la compra está más cara que nunca. Las familias no llegan a fin de mes, presidente. ¿Vive usted en otro país?", "kind": "emocional", "meter": "economia"},
	{"topic": "Sanidad", "attack": "Las listas de espera se han disparado. Mi vecina lleva ocho meses esperando una operación de cadera. ¿Qué le digo?", "kind": "emocional", "meter": "bienestar"},
	{"topic": "Seguridad", "attack": "Los datos no mienten: la delincuencia ha subido y su Gobierno mira hacia otro lado.", "kind": "cifras", "meter": "seguridad"},
	{"topic": "Corrupción", "attack": "Su Gobierno está rodeado de escándalos. ¿Cómo puede mirar a la cámara y pedir el voto?", "kind": "personal", "meter": "estabilidad"},
	{"topic": "Empleo joven", "attack": "Yo le prometo a cada joven de Valdoria un empleo digno en seis meses. ¿Puede usted decir lo mismo?", "kind": "promesa", "meter": "economia"},
	{"topic": "Relaciones exteriores", "attack": "Nuestro prestigio internacional está por los suelos. Nadie nos toma en serio fuera.", "kind": "cifras", "meter": "prestigio"},
	{"topic": "Deuda", "attack": "Usted va a dejar a nuestros hijos una deuda impagable. Es una irresponsabilidad histórica.", "kind": "cifras", "meter": "deuda"},
	{"topic": "Medio ambiente", "attack": "Mientras el planeta arde, su Gobierno no ha hecho nada. Nada.", "kind": "emocional", "meter": "ambiente"},
]

# Respuestas del debate: eficacia según el tipo de ataque
const DEBATE_REPLIES := [
	{"id": "datos", "name": "Datos y gestión", "icon": "grafico", "desc": "Defiende tu gestión con cifras. Muy eficaz si tus números son buenos.", "vs": {"cifras": 1.0, "emocional": 0.4, "personal": 0.6, "promesa": 0.7}, "uses_meter": true},
	{"id": "empatia", "name": "Empatía", "icon": "bienestar", "desc": "Conecta con el dolor de la gente. Imbatible contra la emoción.", "vs": {"cifras": 0.4, "emocional": 1.0, "personal": 0.6, "promesa": 0.5}},
	{"id": "elegancia", "name": "Elegancia", "icon": "capital", "desc": "No entrar al trapo. Desactiva los ataques personales.", "vs": {"cifras": 0.3, "emocional": 0.5, "personal": 1.0, "promesa": 0.4}},
	{"id": "realismo", "name": "¿Y quién lo paga?", "icon": "dinero", "desc": "Desmonta promesas imposibles.", "vs": {"cifras": 0.5, "emocional": 0.3, "personal": 0.4, "promesa": 1.0}},
	{"id": "contraataque", "name": "Contraataque", "icon": "rayo", "desc": "Golpe al historial del rival. Arriesgado pero puede ser devastador.", "vs": {"cifras": 0.7, "emocional": 0.6, "personal": 0.7, "promesa": 0.7}, "risky": true},
]

const DEBATE_LINES := {
	"datos": ["Los datos oficiales dicen exactamente lo contrario, y usted lo sabe.", "Le invito a mirar las cifras: hoy estamos mejor que cuando llegamos."],
	"empatia": ["Esa vecina merece respeto, no ser utilizada. Y le digo: no la vamos a abandonar.", "Sé lo que es sufrir. Por eso cada decisión que tomo piensa en esas familias."],
	"elegancia": ["No voy a entrar en descalificaciones. Los ciudadanos merecen un debate a la altura.", "Usted insulta; yo propongo. Esa es la diferencia entre nosotros."],
	"realismo": ["Prometer es gratis. ¿Me dice de dónde saca el dinero? Porque las cuentas no salen.", "Eso ya lo prometieron en su día y el resultado fue la ruina."],
	"contraataque": ["Tiene gracia que me lo diga usted, con el historial de su partido.", "Cuando ustedes gobernaron, todo lo que hoy critica era el doble de grave."],
}

const OPP_REACTIONS := {
	"good": ["Eh... bueno, eso habría que matizarlo...", "Usted siempre con sus datos manipulados.", "No me ha respondido a la pregunta."],
	"bad": ["¿Lo ven? No tiene respuesta.", "Otra vez escurriendo el bulto, presidente.", "Los ciudadanos no son tontos."],
}
