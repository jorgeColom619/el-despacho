extends RefCounted
## Modo meme: política de chiste. Eventos absurdos y guiños a la política de siempre,
## con personajes y partidos inventados. Ningún parecido con la realidad es casual... ni intencionado.

const EVENTS := [
	{"id": "bienvenida_meme", "type": "advisor", "who": "jefa", "chain_only": true, "meme": true, "title": "Bienvenido al circo",
		"text": "Bienvenido a su despacho, presidente {pres}. Soy {jefa}, su Jefa de Gabinete. Le advierto: este país está un poco loco. Ayer el Congreso votó si la tortilla lleva cebolla, el exministro de Industria trabaja de 'consejero de la energía de la energía' y hay palomas con más poder que la oposición. Usted pulse ▶ cuando esté listo... y que sea lo que Dios quiera.",
		"choices": [
			{"t": "He venido a hablar de mi libro.", "fx": {"pc": 5, "jovenes": 2}},
			{"t": "Bueno... eso.", "fx": {"stress": -5}},
		]},
	# =====================================================================  ASESORES
	{"id": "meme_vecino_alcalde", "type": "advisor", "who": "jefa", "meme": true, "title": "El discurso del redactor nuevo",
		"text": "Presidente, el redactor de discursos en prácticas le ha preparado esto para el acto municipal de mañana: «Es el vecino el que elige al alcalde, y es el alcalde el que quiere que sean los vecinos el alcalde». Dice que es 'muy profundo'. Yo no sé ni qué significa.",
		"choices": [
			{"t": "Leerlo tal cual. Con convicción.", "fx": {"jovenes": 7, "prestigio": -3, "jubilados": -2, "approval": 1}, "news": "La frase del presidente sobre el alcalde y los vecinos, trending topic mundial"},
			{"t": "Corregirlo: «Los vecinos eligen al alcalde. Punto».", "fx": {"clase_media": 1}},
			{"t": "Improvisar: «Un vaso es un vaso y un plato es un plato».", "fx": {"jovenes": 5, "jubilados": 2, "prestigio": -2}, "news": "«Un vaso es un vaso»: el presidente filosofa en directo"},
		], "default": 1},
	{"id": "meme_plasma", "type": "advisor", "who": "jefa", "meme": true, "title": "Comparecer por pantalla",
		"text": "La prensa le espera en la sala para preguntarle por el último escándalo. Tengo una idea: usted comparece desde su despacho a través de una pantalla de plasma gigante. Sin preguntas. Muy moderno. Muy tecnológico.",
		"choices": [
			{"t": "Plasma. Que vean lo moderno que soy.", "fx": {"clase_media": -4, "jovenes": 3, "estabilidad": 1, "prestigio": -2, "unlock": "plasma"}, "news": "El presidente comparece a través de una pantalla de plasma: la prensa entrevista a un televisor"},
			{"t": "Comparecer en persona y aguantar el chaparrón.", "fx": {"press": "rueda"}},
			{"t": "Hacer un directo en Twitch respondiendo al chat.", "fx": {"jovenes": 6, "jubilados": -5, "prestigio": -1}, "news": "El presidente bate el récord de espectadores en Twitch: 'GG, presi'"},
		], "default": 0},
	{"id": "meme_se_fuerte", "type": "advisor", "who": "jefa", "meme": true, "title": "Un SMS desde la cárcel",
		"text": "Presidente, Bernabé, el extesorero del partido, le ha escrito un SMS desde prisión: «Presi, esto es muy duro, ¿me echas un cable?». Le recuerdo que su abogado está muy interesado en saber si usted le contesta.",
		"choices": [
			{"t": "Responder: «Sé fuerte. Hacemos lo que podemos».", "fx": {"corr": 3, "risk": {"p": 0.6, "fx": {"clase_media": -8, "estabilidad": -5, "jovenes": 3}, "news": "Se filtra el SMS del presidente al extesorero: «Sé fuerte»", "text": "El SMS ha llegado a la prensa. Ya hay camisetas con la frase."}, "else": {"fx": {}, "text": "Nadie se ha enterado. Por ahora."}}},
			{"t": "Bloquear el número y cambiar de móvil.", "fx": {"stress": 4}},
			{"t": "Entregar el SMS al juez.", "fx": {"clase_media": 4, "estabilidad": -2, "corr_mult": 0.6}, "news": "El presidente entrega al juez los mensajes del extesorero"},
		], "default": 1},
	{"id": "meme_master", "type": "advisor", "who": "sanidad", "meme": true, "title": "El máster fantasma",
		"text": "Presidente... tengo que confesarle algo. Ese máster que pone en mi currículum... Bueno, me matriculé. Y me lo dieron. Pero no fui a ninguna clase, y el trabajo final 'se perdió en una mudanza'. Un periódico lo publica mañana.",
		"choices": [
			{"t": "Cesarla con todo el dolor de mi corazón.", "fx": {"fire": "sanidad", "clase_media": 3, "estabilidad": -2}, "news": "Dimite la ministra del máster fantasma"},
			{"t": "Defenderla: «Hizo los trabajos... mentalmente».", "fx": {"clase_media": -5, "jovenes": -3, "corr": 2}, "news": "El Gobierno defiende a la ministra: 'Los trabajos se hicieron de forma mental'"},
			{"t": "Que se saque el máster este fin de semana, de verdad.", "fx": {"jovenes": 4, "stress": -2, "approval": 1}},
		], "default": 1},
	{"id": "meme_tortilla", "type": "advisor", "who": "jefa", "meme": true, "title": "La gran cuestión nacional",
		"text": "El Congreso lleva tres días bloqueado. No es por los presupuestos ni por una ley. Es por la tortilla del bar: con cebolla o sin cebolla. Los grupos se han partido y su propio partido también. Esperan que el presidente se pronuncie.",
		"choices": [
			{"t": "Con cebolla. Siempre.", "fx": {"clase_media": 4, "jubilados": 3, "jovenes": -3, "party": {"PO": -3}}, "news": "El presidente se declara 'concebollista': media Valdoria, indignada"},
			{"t": "Sin cebolla. Faltaría más.", "fx": {"jovenes": 4, "trabajadores": 2, "jubilados": -3, "party": {"VV": -3}}, "news": "El presidente se declara 'sincebollista': la otra media Valdoria, indignada"},
			{"t": "Comisión parlamentaria de investigación sobre la tortilla.", "fx": {"pc": -4, "estabilidad": 2, "jovenes": 2}, "news": "Creada la Comisión de la Tortilla: emitirá su dictamen en 2031"},
		], "default": 2},
	{"id": "meme_colchon", "type": "advisor", "who": "jefa", "meme": true, "title": "El colchón presidencial",
		"text": "Un digital ha encontrado la factura: lo primero que hizo usted al llegar fue cambiar el colchón del Palacio. Uno de 4.000 euros, viscoelástico, con memoria. La oposición pregunta si 'también tiene memoria para sus promesas'.",
		"choices": [
			{"t": "Un buen descanso es una cuestión de Estado.", "fx": {"stress": -15, "clase_media": -3}, "news": "El presidente defiende su colchón: 'Un país bien gobernado empieza por una buena siesta'"},
			{"t": "Subastar el colchón viejo con fines benéficos.", "fx": {"money": 1, "jovenes": 4, "clase_media": 2}, "news": "Se subasta el colchón presidencial: 30.000 euros para un comedor social"},
			{"t": "Pagarlo de mi bolsillo.", "fx": {"clase_media": 2, "stress": 3}},
		], "default": 0},
	{"id": "meme_halcon", "type": "advisor", "who": "defensa", "meme": true, "title": "El avión oficial y el concierto",
		"text": "Presidente, los periodistas han descubierto que usó el avión oficial, el 'Halcón', para ir al concierto de Los Cuñados del Rock en Marvella. Dicen que coincidió 'casualmente' con una reunión de trabajo de diez minutos.",
		"choices": [
			{"t": "Era una reunión de trabajo. Con mucho rock.", "fx": {"clase_media": -4, "jovenes": 2}, "news": "El presidente justifica el uso del Halcón: 'Fue una reunión muy intensa'"},
			{"t": "Pagar el viaje y pedir perdón.", "fx": {"money": -1, "clase_media": 2, "stress": 3}},
			{"t": "Anunciar que el Halcón se usará para llevar abuelos a la playa.", "fx": {"jubilados": 6, "money": -50, "jovenes": 2}, "news": "Nace el 'Halcón Social': abuelos de Altamira vuelan a la playa por primera vez"},
		], "default": 0},
	{"id": "meme_puerta_giratoria", "type": "advisor", "who": "economia", "meme": true, "title": "La puerta giratoria",
		"text": "Su exministro de Industria acaba de fichar por la principal eléctrica del país. Cargo: 'consejero de Desarrollo de la Energía para la Energía del Desarrollo'. Sueldo: 300.000 euros al año. Funciones: 'por definir'.",
		"choices": [
			{"t": "Prohibir por ley las puertas giratorias.", "fx": {"clase_media": 4, "jovenes": 3, "empresarios": -4}, "news": "El Gobierno cierra las puertas giratorias... y abre las correderas"},
			{"t": "Felicitarle por su nuevo trabajo.", "fx": {"clase_media": -5, "corr": 2}},
			{"t": "Pedirle que nos baje la factura de la luz del Palacio.", "fx": {"monthly": 5, "jovenes": 2}},
		], "default": 1},
	{"id": "meme_siesta", "type": "advisor", "who": "economia", "meme": true, "title": "Siesta obligatoria",
		"text": "Los sindicatos, la patronal hostelera y la Asociación de Abuelos de Banco proponen algo insólito: siesta obligatoria por ley, de 14:30 a 16:30. Dicen que subirá la productividad. Los turistas de Norland no entienden nada.",
		"choices": [
			{"t": "Siesta para todos. Es patrimonio nacional.", "fx": {"trabajadores": 6, "jubilados": 4, "empresarios": -5, "economia": -2, "rel": {"norland": -4}}, "news": "Valdoria aprueba la siesta obligatoria: el país, en pijama a las 15:00"},
			{"t": "Siesta voluntaria pero con el móvil en silencio.", "fx": {"trabajadores": 2, "jubilados": 1}},
			{"t": "No. Aquí se viene a trabajar.", "fx": {"trabajadores": -3, "empresarios": 3}},
		], "default": 1},
	{"id": "meme_hilillos", "type": "advisor", "who": "interior", "meme": true, "title": "Unos hilillos",
		"text": "Un petrolero se ha partido frente a la Costa Sur. Hay chapapote hasta en las gaviotas. El ministro de turno acaba de decir en televisión que 'solo salen unos hilillos con aspecto de plastilina'. Las imágenes dicen otra cosa.",
		"choices": [
			{"t": "Corregir al ministro y movilizar todos los medios.", "fx": {"money": -1200, "ambiente": 4, "clase_media": 3, "militares": 2}, "news": "El Gobierno moviliza al Ejército para limpiar la costa"},
			{"t": "Insistir: son hilillos. Muy finos.", "fx": {"ambiente": -8, "clase_media": -6, "jovenes": -5, "prestigio": -3}, "news": "El Gobierno insiste en los 'hilillos' mientras la marea negra llega a las playas"},
			{"t": "Echarle la culpa a Sarvenia.", "fx": {"rel": {"sarvenia": -12}, "militares": 2, "ambiente": -3}},
		], "default": 1},
	{"id": "meme_brotes_verdes", "type": "advisor", "who": "economia", "meme": true, "title": "Brotes verdes",
		"text": "Presidente, los datos son horribles, pero he visto algo prometedor: en la maceta de mi despacho ha salido un brote verde. Propongo anunciar que la crisis ha terminado. Y que estamos en la Champions League de la economía mundial.",
		"choices": [
			{"t": "Anunciarlo a bombo y platillo.", "fx": {"approval": 3, "risk": {"p": 0.6, "fx": {"clase_media": -6, "trabajadores": -4}, "news": "La 'Champions League de la economía': los memes inundan las redes", "text": "Los datos del mes siguiente son aún peores. Internet no perdona."}, "else": {"fx": {"economia": 2}, "text": "¡Por una vez, la economía acompaña!"}}},
			{"t": "Regar la maceta y esperar.", "fx": {"stress": -4}},
		], "default": 1},
	{"id": "meme_caballo", "type": "advisor", "who": "interior", "meme": true, "title": "Un caballo en el Congreso",
		"text": "El líder de Patria y Orden ha llegado al Congreso a caballo 'para reivindicar las tradiciones'. El caballo ha dejado un 'regalo' en mitad del hemiciclo y se ha comido las flores de la tribuna. Nadie sabe dónde aparcarlo.",
		"choices": [
			{"t": "Multarle por aparcar en doble fila.", "fx": {"jovenes": 4, "party": {"PO": -6}, "money": 1}, "news": "Multado por aparcar un caballo en doble fila frente al Congreso"},
			{"t": "Prohibir los caballos en el Congreso.", "fx": {"estabilidad": 1, "party": {"PO": -3}, "militares": -1}},
			{"t": "Llegar mañana yo en tractor. A ver quién puede más.", "fx": {"trabajadores": 4, "jubilados": 3, "prestigio": -3}, "news": "Duelo en el Congreso: el presidente llega en tractor"},
		], "default": 1},
	{"id": "meme_gato_ministro", "type": "advisor", "who": "jefa", "meme": true, "title": "Un gato en su silla",
		"text": "Presidente, un gato callejero se ha colado en el Consejo de Ministros y se ha dormido en su silla. Ha salido en todas las cámaras. Internet exige que le nombre ministro. Hay 900.000 firmas en una hora.",
		"choices": [
			{"t": "Nombrarle Ministro sin Cartera.", "fx": {"jovenes": 7, "prestigio": -3, "flag": "gato", "stress": -10, "unlock": "michi"}, "news": "Michi, el gato, nuevo ministro sin cartera: 'Es el más trabajador del Gobierno'"},
			{"t": "Adoptarlo, pero sin cargo.", "fx": {"jovenes": 3, "stress": -6}},
			{"t": "Echarlo del Palacio.", "fx": {"jovenes": -5, "jubilados": -2}, "news": "Indignación: el presidente expulsa a un gato del Consejo de Ministros"},
		], "default": 1},
	{"id": "meme_influencer", "type": "advisor", "who": "jefa", "meme": true, "title": "Un influencer quiere ser ministro",
		"text": "El influencer más famoso del país, 'El Brayan', ha subido un vídeo exigiendo ser ministro de Juventud: 'Yo sé lo que quieren los chavales: vibes'. Tiene 12 millones de seguidores y su vídeo, 40 millones de visitas.",
		"choices": [
			{"t": "Nombrarle ministro. Las vibes son importantes.", "fx": {"jovenes": 8, "jubilados": -6, "estabilidad": -4, "prestigio": -3}, "news": "'El Brayan', ministro de Juventud: su primera medida, el lunes festivo"},
			{"t": "Invitarle a un directo conmigo.", "fx": {"jovenes": 4, "jubilados": -2}},
			{"t": "Que se presente a las elecciones.", "fx": {"jovenes": -3, "clase_media": 1}},
		], "default": 2},
	{"id": "meme_wifi_congreso", "type": "advisor", "who": "jefa", "meme": true, "title": "Se cae el wifi del Congreso",
		"text": "Se ha caído el wifi del Congreso en plena votación. 120 diputados han descubierto que no saben votar sin la aplicación. Uno ha intentado votar con el mando de la tele. La votación tendrá que repetirse.",
		"choices": [
			{"t": "Volver a votar a mano alzada, como toda la vida.", "fx": {"jubilados": 3, "estabilidad": 1}},
			{"t": "Contratar el mejor wifi del mundo.", "fx": {"money": -80, "jovenes": 2}},
			{"t": "Dejar el Congreso sin wifi para que presten atención.", "fx": {"clase_media": 3, "jovenes": -2, "party": {"VV": -2, "CC": -2}}, "news": "El Congreso, sin wifi: los diputados descubren los debates"},
		], "default": 0},
	{"id": "meme_bocadillo", "type": "advisor", "who": "economia", "meme": true, "title": "El bocadillo de calamares",
		"text": "Escándalo nacional: el bocadillo de calamares del bar del Congreso cuesta 1,80 euros. En la calle, 6,50. La oposición lo llama 'el bocata de la vergüenza'. Los diputados, mientras, piden otro.",
		"choices": [
			{"t": "Precio de mercado para todos los diputados.", "fx": {"clase_media": 4, "money": 1, "party": {"CC": -2, "AR": -2}}, "news": "Se acabó el chollo: el bocata del Congreso, a precio de mercado"},
			{"t": "Bocadillo de calamares a 1,80 para todo el país.", "fx": {"trabajadores": 5, "jubilados": 4, "monthly": -60, "economia": -1}, "news": "El Gobierno subvenciona el bocadillo de calamares para todos"},
			{"t": "Es una tradición parlamentaria.", "fx": {"clase_media": -4}},
		], "default": 2},
	{"id": "meme_gordo", "type": "advisor", "who": "economia", "meme": true, "title": "El Gordo cae en el Congreso",
		"text": "¡El Gordo de Navidad ha caído en el número que juegan todos los diputados desde hace treinta años! 200 diputados millonarios de golpe. Algunos ya han anunciado que se jubilan mañana. Necesitamos quórum.",
		"cond": {"months": [12, 1]}, "once": true,
		"choices": [
			{"t": "Pedirles que donen la mitad a la sanidad pública.", "fx": {"money": 300, "bienestar": 2, "clase_media": 3}},
			{"t": "Felicitarles. ¡Hay que saber celebrar!", "fx": {"clase_media": -3, "jubilados": 2}},
			{"t": "Convocar elecciones: ya no van a trabajar igual.", "fx": {"estabilidad": -4, "jovenes": 3}},
		], "default": 1},
	{"id": "meme_operacion_salida", "type": "advisor", "who": "interior", "meme": true, "title": "El puente de diciembre",
		"text": "Operación salida del puente de diciembre: 12 millones de coches a la vez. Hay atascos de 200 kilómetros, gente haciendo barbacoas en el arcén y un señor que lleva cuatro horas parado ha montado un bar con su nevera.",
		"cond": {"months": [12, 11]},
		"choices": [
			{"t": "Pedir por televisión que nadie salga de casa.", "fx": {"clase_media": -4, "jovenes": -2}},
			{"t": "Peaje gratis y helicópteros con bocadillos.", "fx": {"money": -200, "clase_media": 4, "jubilados": 2}},
			{"t": "Declarar el arcén zona de ocio oficial.", "fx": {"jovenes": 4, "seguridad": -2, "empresarios": 2}, "news": "El Gobierno declara el arcén de la autopista 'zona de ocio'"},
		], "default": 0},
	{"id": "meme_expresidente_galbana", "type": "advisor", "who": "jefa", "meme": true, "title": "Las frases de Galbana",
		"text": "El expresidente Eusebio Galbana ha dado una entrevista histórica. Ha dicho, cito: «Los valdorianos son muy valdorianos y mucho valdorianos», y también «Cuanto peor, mejor para todos, y cuanto peor para todos, mejor». Ahora quiere que usted le cite en su próximo discurso.",
		"choices": [
			{"t": "Citarle: es un clásico.", "fx": {"jubilados": 4, "jovenes": 4, "prestigio": -2}, "news": "El presidente cita a Galbana y el hemiciclo se pone en pie... de risa"},
			{"t": "Ignorarle con respeto.", "fx": {"party": {"AR": -2}}},
			{"t": "Nombrarle embajador en Tsaing. Lejos.", "fx": {"rel": {"tsaing": -3}, "jovenes": 3, "stress": -4}, "news": "Galbana, nuevo embajador en Tsaing: 'Es muy difícil todo esto'"},
		], "default": 1},
	{"id": "meme_fruta", "type": "advisor", "who": "jefa", "meme": true, "title": "Un micrófono abierto",
		"text": "Durante la sesión de control, a {opo} se le quedó el micrófono abierto y murmuró algo ininteligible mientras usted hablaba. Internet ha decidido por unanimidad que dijo 'me gusta la fruta'. Ya hay canciones, camisetas y una fruta con su nombre.",
		"choices": [
			{"t": "Regalarle un frutero en la próxima sesión.", "fx": {"jovenes": 5, "party": {"AR": -3, "MP": -3}, "approval": 1}, "news": "El presidente regala un frutero a la oposición en pleno debate"},
			{"t": "Defenderla: 'Todos decimos tonterías con el micro abierto'.", "fx": {"estabilidad": 2, "clase_media": 2}},
			{"t": "Lanzar la campaña 'Come fruta' del Ministerio de Sanidad.", "fx": {"bienestar": 2, "jovenes": 3, "money": -30}},
		], "default": 1},
	{"id": "meme_chuleton", "type": "advisor", "who": "economia", "meme": true, "title": "Team chuletón",
		"text": "Un ministro ha recomendado comer menos carne por el medio ambiente. El país se ha dividido en dos bandos irreconciliables: el 'team chuletón' y el 'team tofu'. Ya hay barbacoas reivindicativas frente al Ministerio.",
		"choices": [
			{"t": "Hacerme una foto con un chuletón 'al punto'.", "fx": {"jubilados": 4, "trabajadores": 3, "jovenes": -3, "ambiente": -2}, "news": "El presidente zanja la polémica con un chuletón de un kilo"},
			{"t": "Apoyar al ministro: la ciencia es la ciencia.", "fx": {"jovenes": 4, "ambiente": 2, "jubilados": -3, "trabajadores": -2}},
			{"t": "Cada uno que coma lo que quiera.", "fx": {"clase_media": 2}},
		], "default": 2},
	{"id": "meme_cunado_embajada", "type": "advisor", "who": "exteriores", "meme": true, "title": "Su cuñado quiere ser embajador",
		"text": "Presidente, su cuñado ha llamado a mi gabinete. Quiere ser embajador en Qadar 'porque sabe inglés y ha estado en Dubái de vacaciones'. Ha enviado un currículum de una página. Con foto en bañador.",
		"choices": [
			{"t": "Nombrarle. La familia es la familia.", "fx": {"corr": 4, "clase_media": -6, "rel": {"qadar": -4}}, "news": "El cuñado del presidente, nuevo embajador en Qadar"},
			{"t": "Ofrecerle un curso de inglés. Gratis.", "fx": {"stress": 4, "clase_media": 1}},
			{"t": "No volver a ir a las cenas de Navidad.", "fx": {"stress": -6, "clase_media": 2}},
		], "default": 1},
	{"id": "meme_contabilidad", "type": "advisor", "who": "jefa", "meme": true, "title": "¿Quién es 'P. Presi'?",
		"text": "En la contabilidad B del partido aparecen pagos a un tal 'P. Presi'. La prensa se pregunta quién será. Usted es el presidente. Del país y del partido. La oposición ha hecho una lista de sospechosos con una sola persona.",
		"choices": [
			{"t": "«Es una persona con ese nombre. Muy común.»", "fx": {"clase_media": -6, "jovenes": 3, "corr": 2}, "news": "El Gobierno asegura que 'P. Presi' es 'un señor de Ferrosa'"},
			{"t": "Pedir una auditoría externa.", "fx": {"pc": -6, "clase_media": 3, "corr_mult": 0.5}},
			{"t": "Responder con un meme.", "fx": {"jovenes": 6, "jubilados": -4, "estabilidad": -2}},
		], "default": 0},
	{"id": "meme_ministra_tiktok", "type": "advisor", "who": "interior", "meme": true, "title": "La ministra viral",
		"text": "Presidente, mi baile en TikTok con el uniforme de gala de la Guardia Civil tiene 30 millones de visitas. La oposición pide mi dimisión. Mi hija dice que soy 'la más top'. No sé qué hacer.",
		"choices": [
			{"t": "Felicitarla. Es la ministra más popular.", "fx": {"jovenes": 6, "militares": -3, "jubilados": -3}},
			{"t": "Prohibir los bailes en horario laboral.", "fx": {"jubilados": 3, "jovenes": -4}},
		], "default": 1},
	{"id": "meme_teleprompter", "type": "advisor", "who": "jefa", "meme": true, "title": "Se rompe el teleprompter",
		"text": "En pleno discurso institucional se ha roto el teleprompter. Usted ha estado catorce segundos en silencio mirando a cámara. Luego ha dicho 'Bueno... eso'. El vídeo tiene más visitas que la final del Mundial.",
		"choices": [
			{"t": "Convertirlo en el lema de campaña: 'Bueno... eso'.", "fx": {"jovenes": 6, "prestigio": -2, "approval": 1}, "news": "'Bueno... eso': el nuevo lema del partido del Gobierno"},
			{"t": "Despedir al técnico del teleprompter.", "fx": {"trabajadores": -3, "stress": 3}},
			{"t": "Aprenderme los discursos de memoria a partir de ahora.", "fx": {"stress": 6, "clase_media": 2}},
		], "default": 0},
	{"id": "meme_palomas_aviso", "type": "advisor", "who": "interior", "meme": true, "title": "Las palomas se organizan",
		"text": "Presidente, no es broma: las palomas de Santa Aurora se han multiplicado por diez. Han ocupado la Plaza Mayor, el tejado del Congreso y el coche oficial. Los abuelos siguen dándoles pan. Esto va a acabar mal.",
		"choices": [
			{"t": "Prohibir dar de comer a las palomas.", "fx": {"jubilados": -5, "bienestar": 1}},
			{"t": "Contratar halconeros.", "fx": {"money": -60, "ambiente": 1}},
			{"t": "Ignorarlo. Son palomas.", "fx": {"chain": {"id": "meme_crisis_palomas", "delay": 15}}},
		], "default": 2},

	# =====================================================================  CRISIS ABSURDAS
	{"id": "meme_crisis_palomas", "type": "crisis", "crisis": "palomas", "meme": true, "chain_only": true, "title": "La rebelión de las palomas",
		"text": "Millones de palomas toman las ciudades. Han atacado una boda y un desfile militar."},
	{"id": "meme_crisis_patinetes", "type": "crisis", "crisis": "patinetes", "meme": true, "title": "Invasión de patinetes", "text": "Un millón de patinetes eléctricos abandonados bloquean las calles.",
		"cond": {"min_day": 40}, "cd": 300, "w": 1.2},
	{"id": "meme_crisis_wifi", "type": "crisis", "crisis": "wifi", "meme": true, "title": "Caída nacional del wifi", "text": "Valdoria se queda sin internet. La gente sale a la calle y descubre a sus vecinos.",
		"cond": {"min_day": 60}, "cd": 360, "w": 1.0},

	# =====================================================================  DOCUMENTOS
	{"id": "meme_doc_siesta", "type": "doc", "kind": "ley", "meme": true, "title": "Ley de la Siesta Nacional",
		"text": "Proposición de ley que establece la siesta como derecho fundamental de 14:30 a 16:30, con prohibición expresa de taladros, cortacéspedes y llamadas comerciales en esa franja.",
		"cond": {"min_day": 20}, "once": true,
		"small": ["Art. 7: los turistas de Norland quedan exentos 'porque no lo entenderían'."],
		"choices": [
			{"t": "Aprobar", "fx": {"trabajadores": 5, "jubilados": 4, "empresarios": -4, "unlock": "siesta"}, "hidden": {"rel": {"norland": -5}}, "news": "Aprobada la Ley de la Siesta Nacional"},
			{"t": "Vetar", "fx": {"trabajadores": -3, "empresarios": 2}},
		], "default": 0},
	{"id": "meme_doc_cunados", "type": "doc", "kind": "ley", "meme": true, "title": "Ley de Convivencia Navideña",
		"text": "Prohíbe hablar de política, fútbol y herencias en las comidas familiares del 24 al 31 de diciembre. Los cuñados reincidentes deberán hacer un curso de escucha activa.",
		"cond": {"min_day": 30}, "once": true,
		"small": ["Disposición adicional: se permite hablar del tiempo y de 'lo caro que está todo'."],
		"choices": [
			{"t": "Aprobar", "fx": {"clase_media": 4, "jubilados": 2, "stress": -5}, "news": "Prohibido discutir de política en Nochebuena: los cuñados recurren al Constitucional"},
			{"t": "Vetar", "fx": {"jovenes": -1}},
		], "default": 0},
	{"id": "meme_doc_indulto_chiringuito", "type": "doc", "kind": "indulto", "meme": true, "title": "Solicitud de indulto: Javi 'el del Chiringuito'",
		"text": "Javier Montes, 44 años, condenado a 1 año por montar un chiringuito ilegal en una playa protegida. Alega que 'las mejores sardinas del país no pueden ser delito'. 300.000 firmas le apoyan.",
		"cond": {"min_day": 30}, "once": true, "prisoner": {"g": "m", "skin": 3, "hair": "curly", "hc": 0, "age": 1},
		"small": ["Informe: el chiringuito tenía cola de dos horas y una valoración de 4,9 estrellas."],
		"choices": [
			{"t": "Conceder", "fx": {"jovenes": 4, "trabajadores": 3, "ambiente": -2}, "news": "Indultado Javi el del Chiringuito: 'Vuelven las sardinas'"},
			{"t": "Denegar", "fx": {"ambiente": 2, "jovenes": -2}},
		], "default": 1},
	{"id": "meme_doc_carta_lentejas", "type": "doc", "kind": "carta", "meme": true, "title": "Carta de doña Remedios, 88 años",
		"text": "Hijo: te he visto en la tele y estás muy delgado y muy ojeroso. Te mando un táper de lentejas con chorizo. Devuélveme el táper, que es de los buenos. Y abrígate, que en ese palacio seguro que hay corriente.",
		"cond": {"min_day": 10}, "once": true, "stamps": ["DEVOLVER TÁPER", "ARCHIVAR"],
		"choices": [
			{"t": "Devolver táper", "fx": {"jubilados": 4, "stress": -8}, "news": "El presidente devuelve el táper a doña Remedios con una carta de agradecimiento"},
			{"t": "Archivar", "fx": {"jubilados": -3}, "news": "Doña Remedios denuncia que el presidente no le ha devuelto el táper"},
		], "default": 1},
	{"id": "meme_doc_ministro_cultura", "type": "doc", "kind": "nombramiento", "meme": true, "title": "Ministerio de Cultura",
		"text": "Debe nombrar al nuevo titular del Ministerio de Cultura. Los tres candidatos finalistas han sido elegidos por votación popular en internet. Selle el expediente del candidato elegido.",
		"cond": {"min_day": 30}, "once": true,
		"options": [
			{"name": "La Niña de Puerto Alba", "look": {"g": "f", "skin": 3, "hair": "bun", "hc": 0, "glasses": 0, "age": 2}, "lines": ["Cantaora de flamenco", "Tres veces récord de ventas", "No sabe usar el correo"], "small": "Propone que cada ley empiece con un quejío.", "fx": {"jubilados": 4, "prestigio": 2, "jovenes": -1}},
			{"name": "XxDarkLordxX", "look": {"g": "m", "skin": 1, "hair": "curly", "hc": 3, "glasses": 2, "age": 0}, "lines": ["Youtuber de videojuegos", "8 millones de suscriptores", "Nunca ha salido de casa"], "small": "Quiere declarar los videojuegos 'Bien de Interés Cultural'.", "fx": {"jovenes": 6, "jubilados": -4}},
			{"name": "Tribuno, el perro del presidente", "lines": ["Perro", "Muy bueno", "Muy, muy bueno"], "small": "No hay constancia de que sepa leer. Sí de que es muy bueno.", "fx": {"jovenes": 4, "jubilados": 3, "prestigio": -3, "stress": -6}},
		]},
	{"id": "meme_doc_contrato_banderitas", "type": "doc", "kind": "contrato", "meme": true, "title": "Banderitas para el Mundial",
		"text": "Concurso urgente para fabricar 20 millones de banderitas para la selección antes del Mundial. Selle la oferta que desea adjudicar.",
		"cond": {"min_day": 40}, "once": true,
		"options": [
			{"name": "Banderas Patrióticas S.L.", "lines": ["Precio: 40 M€", "Calidad: ★★★★☆", "Entrega: 2 meses"], "small": "Empresa creada hace tres días. Su administrador es el primo del ministro de Deportes.", "fx": {"money": -40, "corr": 4, "jovenes": 1}},
			{"name": "Tsaing Flags Ltd.", "lines": ["Precio: 6 M€", "Calidad: ★☆☆☆☆", "Entrega: 1 semana"], "small": "La muestra enviada tiene la bandera de Valdoria al revés.", "fx": {"money": -6, "prestigio": -3, "jovenes": 3, "rel": {"tsaing": 3}}},
			{"name": "Cooperativa de Costureras de Ferrosa", "lines": ["Precio: 25 M€", "Calidad: ★★★★★", "Entrega: 4 meses"], "small": "Llegarán justo para la final. Si llegamos a la final.", "fx": {"money": -25, "trabajadores": 3, "jubilados": 2}},
		]},

	# =====================================================================  LLAMADAS
	{"id": "meme_call_kade_golf", "type": "call", "who": "norland", "meme": true, "title": "Kade quiere jugar al golf",
		"text": "¡Presidente! Me han dicho que su Palacio tiene unos jardines magníficos. Muy grandes. Los mejores. Quiero construir allí un campo de golf de nueve hoyos para cuando venga de visita. Lo pago yo. Bueno, lo paga usted, pero yo lo inauguro.",
		"choices": [
			{"t": "Por supuesto. Hoyo uno: la fuente.", "fx": {"rel": {"norland": 10}, "ambiente": -2, "jovenes": -3, "money": -40}},
			{"t": "Le propongo un partido de petanca.", "fx": {"rel": {"norland": 2}, "jubilados": 4}},
			{"t": "Los jardines son del pueblo.", "fx": {"rel": {"norland": -6}, "jovenes": 3}},
		], "default": 1},
	{"id": "meme_call_hao_pandas", "type": "call", "who": "tsaing", "meme": true, "title": "La diplomacia del panda",
		"text": "Presidente, Tsaing quiere regalar a Valdoria dos osos panda como símbolo de amistad. Comen 40 kilos de bambú al día, necesitan un palacio climatizado y, a cambio, nos gustaría la concesión de su puerto principal. Pero sobre todo, los pandas.",
		"choices": [
			{"t": "¡Pandas! Acepto todo.", "fx": {"jovenes": 6, "rel": {"tsaing": 10, "norland": -8}, "money": -200, "economia": 1}, "news": "Llegan los pandas: colas de seis horas en el zoo de Santa Aurora"},
			{"t": "Los pandas sí, el puerto no.", "fx": {"rel": {"tsaing": -2}, "jovenes": 2}},
		], "default": 1},
	{"id": "meme_call_vaelsen_cenas", "type": "call", "who": "union", "meme": true, "title": "La Unión y los horarios",
		"text": "Presidente, la Comisión ha recibido 3.000 quejas de funcionarios continentales destinados en Valdoria. Dicen que ustedes cenan a las once de la noche y que les llaman para reuniones 'después de comer' a las cinco. Hay que armonizar horarios.",
		"choices": [
			{"t": "Valdoria cena cuando le da la gana.", "fx": {"clase_media": 4, "rel": {"union": -5}}, "news": "El presidente a la Unión: 'Aquí se cena cuando se cena'"},
			{"t": "Ofrecer a los funcionarios clases de siesta.", "fx": {"rel": {"union": 2}, "jovenes": 3}},
		], "default": 0},
	{"id": "meme_call_olmedo_tortilla", "type": "call", "who": "sarvenia", "meme": true, "title": "Olmedo reclama la tortilla",
		"text": "Presidente. Mis historiadores han demostrado que la tortilla de patatas se inventó en Sarvenia en 1817. Exijo que su país deje de llamarla 'tortilla valdoriana'. Es una cuestión de honor nacional.",
		"choices": [
			{"t": "Declarar la tortilla Patrimonio Nacional Valdoriano.", "fx": {"rel": {"sarvenia": -10}, "jubilados": 4, "militares": 2, "clase_media": 3}, "news": "Valdoria blinda la tortilla frente a Sarvenia"},
			{"t": "Proponer un concurso de tortillas para decidirlo.", "fx": {"rel": {"sarvenia": 5}, "jovenes": 3, "prestigio": 1}, "news": "Cumbre de la tortilla en la frontera: empate técnico"},
		], "default": 1},

	# =====================================================================  NOTICIAS
	{"id": "mn1", "type": "news", "meme": true, "title": "Un señor de Cuenca lee entera la letra pequeña de un contrato y se convierte en leyenda", "cd": 400},
	{"id": "mn2", "type": "news", "meme": true, "title": "El Congreso aprueba por unanimidad que el lunes es un día horrible", "fx": {"trabajadores": 1}, "cd": 400},
	{"id": "mn3", "type": "news", "meme": true, "title": "Detenido un turista por llevar calcetines con chanclas en zona monumental", "cd": 400},
	{"id": "mn4", "type": "news", "meme": true, "title": "El tren de alta velocidad llega puntual y los pasajeros piden una explicación", "cd": 400},
	{"id": "mn5", "type": "news", "meme": true, "title": "Un estudio confirma que el 90% de las reuniones podrían haber sido un correo", "fx": {"trabajadores": 1}, "cd": 400},
	{"id": "mn6", "type": "news", "meme": true, "title": "Récord: un funcionario resuelve un expediente el mismo día que se presenta", "cd": 500},
	{"id": "mn7", "type": "news", "meme": true, "title": "Un cuñado gana un debate en la cena familiar sin aportar un solo dato", "cd": 400},
	{"id": "mn8", "type": "news", "meme": true, "title": "Se agotan los turrones en septiembre: los supermercados culpan al calor", "cd": 400},
	{"id": "mn9", "type": "news", "meme": true, "title": "Un pueblo de 12 habitantes declara la independencia de la otra mitad del pueblo", "cd": 500},
	{"id": "mn10", "type": "news", "meme": true, "title": "Kharovia confunde Valdoria con una marca de queso en su informe anual", "fx": {"prestigio": -1}, "cd": 500},
	{"id": "mn11", "type": "news", "meme": true, "title": "La tortilla con cebolla gana por la mínima en la encuesta del Instituto Nacional de Estadística", "cd": 500},
	{"id": "mn12", "type": "news", "meme": true, "title": "Jubilados vigilan las obras de la calle Mayor: 'Llevan tres años y nosotros, aquí'", "fx": {"jubilados": 1}, "cd": 400},
	{"id": "mn13", "type": "news", "meme": true, "title": "Un concursante de la tele sabe nombrar a todos los ministros y el país se preocupa", "cd": 500},
	{"id": "mn14", "type": "news", "meme": true, "title": "El horóscopo del Diario acierta por fin y el astrólogo dimite por la presión", "cd": 500},
	{"id": "mn15", "type": "news", "meme": true, "title": "Las palomas de la Plaza Mayor forman un sindicato y piden pan integral", "cd": 400},
]

## Leyes generadas para la bandeja en el modo meme
const BILLS := [
	{"t": "Ley de Protección del Botijo", "fx": {"jubilados": 2, "ambiente": 1}},
	{"t": "Ley del Puente Perpetuo", "fx": {"trabajadores": 2, "empresarios": -2}},
	{"t": "Ley del Derecho Universal al Chiringuito", "fx": {"jovenes": 2, "ambiente": -1}},
	{"t": "Ley Antispoiler de Series", "fx": {"jovenes": 2}},
	{"t": "Ley del Reggaetón en el Transporte Público (prohibido sin cascos)", "fx": {"jubilados": 2, "jovenes": -1}},
	{"t": "Ley de la Caña a un Euro", "fx": {"trabajadores": 2, "empresarios": -1}},
	{"t": "Ley de la Sobremesa Garantizada", "fx": {"clase_media": 2, "empresarios": -1}},
	{"t": "Ley de los Grupos de WhatsApp de Padres", "fx": {"clase_media": 2}},
	{"t": "Ley del Pan del Día Anterior", "fx": {"jubilados": 1, "ambiente": 1}},
	{"t": "Ley de Libertad de Chancla", "fx": {"jovenes": 1, "jubilados": -1}},
	{"t": "Ley de Regulación del 'Ya Tal'", "fx": {"estabilidad": 1}},
	{"t": "Ley del Mando de la Tele Compartido", "fx": {"clase_media": 1, "jovenes": 1}},
	{"t": "Ley de Dignidad de la Croqueta Casera", "fx": {"jubilados": 2, "empresarios": -1}},
	{"t": "Ley de Prohibición del Sí-Pero-No", "fx": {"estabilidad": 1, "jovenes": 1}},
	{"t": "Ley del Toldo Verde Obligatorio", "fx": {"empresarios": 1, "ambiente": 1}},
]

const RIDERS := [
	{"t": "Disp. adicional 3ª: el presidente tendrá plaza de aparcamiento reservada en todas las playas del país.", "fx": {"clase_media": -2, "corr": 1}},
	{"t": "Disp. final 1ª: se declara festivo nacional el cumpleaños del ministro de Hacienda.", "fx": {"trabajadores": 1, "economia": -1}},
	{"t": "Anexo IV: el bar del Congreso será de barra libre los jueves.", "fx": {"clase_media": -2, "money": -10}},
	{"t": "Disp. adicional 9ª: los diputados podrán votar desde la playa en agosto.", "fx": {"clase_media": -2, "jovenes": 1}},
	{"t": "Art. 44 bis: el himno nacional se versionará en reggaetón para los actos oficiales.", "fx": {"jovenes": 2, "jubilados": -2, "militares": -2}},
]

const LETTERS := [
	{"from": "Un señor de Cuenca", "t": "Le escribo para quejarme de que en mi pueblo no hay cobertura de móvil, pero sí hay wifi en el bar. Exijo que pongan el wifi del bar en toda la comarca.", "fx_yes": {"jubilados": 1, "money": -10}, "yes": "AYUDAR"},
	{"from": "El grupo de WhatsApp '4ºB Padres y Madres'", "t": "Estimado señor presidente: llevamos 400 mensajes discutiendo quién compra el regalo de la profesora. Solicitamos que el Gobierno decida por decreto.", "fx_yes": {"clase_media": 1, "stress": 2}, "yes": "DECRETAR"},
	{"from": "Asociación de Cuñados de Valdoria", "t": "Queremos denunciar el acoso que sufrimos en las cenas familiares. Nosotros solo opinamos de todo con mucha seguridad. Pedimos respeto.", "fx_yes": {"clase_media": -1, "jovenes": 1}, "yes": "RESPONDER"},
	{"from": "Pablo, 7 años", "t": "Señor presidente: quiero ser presidente cuando sea mayor para no tener que ir al cole y comer helado en el desayuno. ¿Es verdad que usted come helado en el desayuno?", "fx_yes": {"jovenes": 1, "stress": -4}, "yes": "RESPONDER"},
	{"from": "Los jubilados de la calle Mayor", "t": "Llevamos tres años supervisando las obras de la calle Mayor. Ninguna empresa nos paga. Exigimos ser contratados como inspectores oficiales.", "fx_yes": {"jubilados": 2, "money": -5}, "yes": "CONTRATAR"},
	{"from": "Un fan de las rotondas", "t": "En mi pueblo hay 14 rotondas para 800 habitantes. Son preciosas. Le pido una más, con una escultura de un botijo gigante.", "fx_yes": {"jubilados": 1, "money": -20, "corr": 1}, "yes": "FINANCIAR"},
	{"from": "Doña Pura, presidenta de la comunidad de vecinos", "t": "El del tercero tiende las toallas y gotean a mi ropa. Como nadie me hace caso, me dirijo a la más alta autoridad del Estado.", "fx_yes": {"jubilados": 1, "stress": 2}, "yes": "MEDIAR"},
]

const CRIMES := [
	{"c": "Robo de 400 rollos de papel higiénico de un ministerio", "y": 1, "note": "Alega que 'en el ministerio no se notaría'.", "fx_yes": {"clase_media": -1}, "fx_no": {}},
	{"c": "Hacer la ola en un funeral de Estado", "y": 1, "note": "Dice que pensaba que era un partido de fútbol.", "fx_yes": {"jovenes": 1, "jubilados": -1}, "fx_no": {}},
	{"c": "Aparcar un tractor en la escalinata del Congreso", "y": 2, "note": "Asegura que estaba 'en doble fila, pero con los intermitentes'.", "fx_yes": {"trabajadores": 1, "jubilados": 1}, "fx_no": {}},
	{"c": "Vender humo (literalmente) por internet", "y": 2, "note": "Tenía 3.000 clientes satisfechos.", "fx_yes": {"jovenes": 1, "clase_media": -1}, "fx_no": {}},
	{"c": "Colarse en la boda de un ministro y dar un discurso", "y": 1, "note": "Los invitados dicen que fue el mejor discurso de la boda.", "fx_yes": {"jovenes": 1}, "fx_no": {}},
]

## Frases extra de discurso (se mezclan con las normales)
const SPEECH := {
	"apertura": [
		{"t": "Valdorianos: los valdorianos son muy valdorianos y mucho valdorianos.", "fx": {"jubilados": 1.5, "jovenes": 1.0}},
		{"t": "Buenas noches. O buenos días, según donde estén. Es difícil todo esto.", "fx": {"jovenes": 1.5}},
	],
	"economia": [
		{"t": "Un vaso es un vaso, un plato es un plato, y un presupuesto es un presupuesto.", "fx": {"jovenes": 1.5, "clase_media": 0.5}},
		{"t": "Estamos en la Champions League de la economía. Bueno, en la previa.", "fx": {"empresarios": 1.0, "jovenes": 1.0}},
	],
	"social": [
		{"t": "Somos sentimientos y tenemos seres humanos.", "fx": {"jubilados": 1.0, "jovenes": 1.5}},
		{"t": "La tortilla, con cebolla o sin cebolla, nos une a todos.", "fx": {"clase_media": 1.5, "jubilados": 1.0}},
	],
	"cierre": [
		{"t": "Haremos lo que tengamos que hacer, que es lo que hay que hacer. Fin de la cita.", "fx": {"jovenes": 1.5, "clase_media": 0.5}},
		{"t": "Y recuerden: cuanto peor, mejor para todos. ¿O era al revés? Buenas noches.", "fx": {"jovenes": 2.0, "prestigio": -0.5}},
	],
}

## Preguntas extra de prensa
const QUESTIONS := [
	{"q": "Presidente, ¿es verdad que ha pedido que el Consejo de Ministros se haga con sobremesa?",
		"a": [
			{"t": "Las mejores decisiones se toman con el café y la copa.", "tone": "humor", "s": 4, "fx": {"jovenes": 1}},
			{"t": "Es una cuestión de productividad.", "tone": "evasivo", "s": -2, "fx": {}},
			{"t": "Sí, y la oposición está invitada. Ellos ponen el postre.", "tone": "ataque", "s": 2, "fx": {"estabilidad": -1}},
		]},
	{"q": "Presidente, ¿con cebolla o sin cebolla?",
		"a": [
			{"t": "Con cebolla. Y lo digo con la cabeza bien alta.", "tone": "firme", "s": 3, "fx": {"jubilados": 1, "jovenes": -1}},
			{"t": "Sin cebolla. El que avisa no es traidor.", "tone": "firme", "s": 3, "fx": {"jovenes": 1, "jubilados": -1}},
			{"t": "Depende de quién la haga. Siguiente pregunta.", "tone": "evasivo", "s": -1, "fx": {}},
		]},
	{"q": "¿Qué opina de que le llamen 'el presidente del plasma'?",
		"a": [
			{"t": "Que la próxima rueda de prensa la hago en 4K.", "tone": "humor", "s": 5, "fx": {"jovenes": 2}},
			{"t": "Aquí estoy, de carne y hueso, respondiendo.", "tone": "honesto", "s": 3, "fx": {"clase_media": 1}},
		]},
]
