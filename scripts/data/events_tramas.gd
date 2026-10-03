extends RefCounted
## Eventos de las tramas (historias largas que se sortean en cada partida) y de los escenarios iniciales.
## Todos son "chain_only": solo aparecen cuando su trama o su escenario los programa.

const EVENTS := [
	# =====================================================================  TRAMA · Huelga de controladores
	{"id": "controladores_aviso", "type": "advisor", "who": "economia", "chain_only": true, "title": "Los controladores amenazan",
		"text": "Presidente, el sindicato de controladores aéreos amenaza con una huelga en plena temporada alta. Piden un 20% más de sueldo y jubilarse a los 52 años con el salario íntegro. Si paran, se cierra el espacio aéreo y el turismo se hunde.",
		"choices": [
			{"t": "Negociar una subida razonable antes de que paren.", "fx": {"money": -300, "trabajadores": 2, "empresarios": 1, "chain": {"id": "controladores_acuerdo", "delay": 15}}, "rec": "economia", "news": "El Gobierno abre negociaciones con los controladores"},
			{"t": "Avisarles: si paran, militarizaremos las torres.", "fx": {"militares": 2, "trabajadores": -3, "flag": "controladores_aviso_militar", "chain": {"id": "controladores_huelga", "delay": 20}}, "rec": "defensa", "news": "El Gobierno amenaza con militarizar el control aéreo"},
			{"t": "Son unos privilegiados. Que hagan lo que quieran.", "fx": {"clase_media": 2, "chain": {"id": "controladores_huelga", "delay": 14}}},
		], "default": 2},
	{"id": "controladores_huelga", "type": "advisor", "who": "interior", "chain_only": true, "urgent": 25.0, "title": "Caos en los aeropuertos",
		"text": "Los controladores han abandonado sus puestos alegando bajas médicas en masa. 600.000 pasajeros atrapados en pleno puente, turistas durmiendo en el suelo y las aerolíneas exigiendo indemnizaciones. Las televisiones no hablan de otra cosa.",
		"choices": [
			{"t": "Estado de alarma: los militares toman las torres de control.", "fx": {"militares": 4, "seguridad": 2, "trabajadores": -6, "empresarios": 3, "estabilidad": 2, "prestigio": -2}, "rec": "defensa", "news": "Estado de alarma: los militares toman el control aéreo"},
			{"t": "Ceder a todo para reabrir mañana mismo.", "fx": {"money": -900, "monthly": -120, "clase_media": -4, "empresarios": -2, "trabajadores": 2}, "news": "El Gobierno cede ante los controladores"},
			{"t": "Esperar a que se cansen.", "fx": {"economia": -4, "empresarios": -6, "clase_media": -5, "prestigio": -3, "chain": {"id": "controladores_juicio", "delay": 60}}, "news": "Tercer día de caos aéreo sin respuesta del Gobierno"},
		], "default": 2},
	{"id": "controladores_acuerdo", "type": "doc", "kind": "decreto", "chain_only": true, "title": "Convenio colectivo del control aéreo",
		"text": "Se aprueba el convenio colectivo de los controladores aéreos: subida salarial del 7% en tres años, refuerzo de plantilla y compromiso de paz social hasta el final de la legislatura.",
		"small": ["Disposición adicional 4ª: los controladores con 25 años de servicio podrán jubilarse a los 55 con el 100% del salario."],
		"choices": [
			{"t": "Aprobar", "fx": {"trabajadores": 2, "economia": 1, "estabilidad": 1}, "hidden": {"monthly": -90, "clase_media": -2}, "news": "Firmada la paz en el control aéreo"},
			{"t": "Vetar", "fx": {"trabajadores": -3, "chain": {"id": "controladores_huelga", "delay": 10}}},
		], "default": 0},
	{"id": "controladores_juicio", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Las aerolíneas pasan la factura",
		"text": "Las aerolíneas reclaman al Estado 1.200 millones por los días de cierre del espacio aéreo. Los tribunales dicen que el Gobierno tardó demasiado en actuar.",
		"choices": [
			{"t": "Pagar y pasar página.", "fx": {"money": -1200, "empresarios": 3}},
			{"t": "Recurrir hasta el final.", "fx": {"pc": -4, "empresarios": -3, "risk": {"p": 0.5, "fx": {"money": -1600}, "text": "Perdemos el recurso: ahora con intereses."}, "else": {"fx": {"money": -300}, "text": "El Supremo rebaja la indemnización a 300 millones."}}},
		], "default": 1},

	# =====================================================================  TRAMA · Pegaso (espías en el móvil)
	{"id": "pegaso_descubierto", "type": "advisor", "who": "interior", "chain_only": true, "title": "Alguien le escucha",
		"text": "Presidente, el Centro Nacional de Inteligencia ha encontrado un programa espía en su teléfono y en el de tres ministros. Lleva meses instalado: mensajes, llamadas, fotos... Aún no sabemos quién está detrás.",
		"choices": [
			{"t": "Hacerlo público ahora mismo: transparencia total.", "fx": {"prestigio": 2, "jovenes": 2, "estabilidad": -3, "chain": {"id": "pegaso_autor", "delay": 25}}, "news": "El Gobierno revela que el móvil del presidente fue espiado"},
			{"t": "Investigar en secreto antes de mover ficha.", "fx": {"money": -80, "seguridad": 2, "chain": {"id": "pegaso_filtra", "delay": 35}}, "rec": "interior"},
			{"t": "Culpar a Kharovia de inmediato.", "fx": {"rel": {"kharovia": -15}, "militares": 3, "prestigio": 1, "chain": {"id": "pegaso_autor", "delay": 25}}, "news": "Valdoria acusa a Kharovia de espiar al presidente"},
		], "default": 1},
	{"id": "pegaso_autor", "type": "advisor", "who": "interior", "chain_only": true, "title": "El espía estaba en casa",
		"text": "Tenemos al responsable, y no le va a gustar: el programa lo instaló nuestro propio servicio de inteligencia, por orden de un director adjunto nombrado por el anterior Gobierno. Dice que lo hizo 'por seguridad nacional'.",
		"choices": [
			{"t": "Purga total en el CNI y comisión de investigación.", "fx": {"clase_media": 3, "jovenes": 3, "militares": -3, "seguridad": -2, "estabilidad": -2}, "news": "Purga en el CNI tras el escándalo del espionaje al presidente"},
			{"t": "Cesar al responsable sin hacer ruido.", "fx": {"seguridad": 1, "corr": 2}},
			{"t": "Proteger la institución: asunto clasificado.", "fx": {"corr": 4, "seguridad": 2, "risk": {"p": 0.4, "fx": {"jovenes": -6, "clase_media": -5, "estabilidad": -4}, "news": "El Gobierno encubrió el espionaje del CNI al presidente", "text": "Se ha filtrado que usted tapó el asunto."}, "else": {"fx": {}, "text": "El asunto queda enterrado bajo la ley de secretos oficiales."}}},
		], "default": 1},
	{"id": "pegaso_filtra", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Lo sabía y lo calló",
		"text": "Diario Libre publica que su móvil fue espiado... y que usted lo sabía desde hace semanas sin decir nada. Le acusan de ocultarlo para tapar algo. ¿Qué respondemos?",
		"choices": [
			{"t": "Rueda de prensa: contarlo todo.", "fx": {"press": "rueda", "estabilidad": -2}},
			{"t": "Comunicado: 'Se estaba investigando con discreción'.", "fx": {"clase_media": -3, "jovenes": -3, "chain": {"id": "pegaso_autor", "delay": 10}}},
		], "default": 1},

	# =====================================================================  TRAMA · Burbuja inmobiliaria
	{"id": "burbuja_aviso", "type": "advisor", "who": "economia", "chain_only": true, "title": "Ladrillo, ladrillo, ladrillo",
		"text": "El precio de la vivienda sube un 18% al año. Los bancos conceden hipotecas por encima del valor de la casa y en Marvella se venden pisos sobre plano antes de tener licencia. El Banco Central nos pide que pongamos freno. Los constructores, que no toquemos nada.",
		"choices": [
			{"t": "Pinchar la burbuja: límites a las hipotecas.", "fx": {"economia": -3, "empresarios": -4, "jovenes": 3, "chain": {"id": "burbuja_suave", "delay": 150}}, "rec": "economia", "news": "El Gobierno endurece las hipotecas para frenar la burbuja"},
			{"t": "¡Que siga la fiesta! Es crecimiento.", "fx": {"economia": 3, "empresarios": 4, "clase_media": 2, "money": 600, "chain": {"id": "burbuja_estalla", "delay": 170}}, "news": "El ladrillo tira de la economía"},
			{"t": "Impuesto a los pisos vacíos y a la especulación.", "fx": {"monthly": 180, "jovenes": 3, "empresarios": -3, "chain": {"id": "burbuja_estalla_leve", "delay": 170}}, "news": "Nuevo impuesto a la especulación inmobiliaria"},
		], "default": 1},
	{"id": "burbuja_estalla", "type": "advisor", "who": "economia", "chain_only": true, "urgent": 30.0, "title": "Estalla la burbuja",
		"text": "Ha pasado. Tres grandes promotoras han quebrado en una semana y arrastran a dos cajas de ahorro. 300.000 familias deben más de lo que vale su casa y las grúas se han parado en toda la costa.",
		"choices": [
			{"t": "Rescatar a los bancos para evitar el colapso.", "fx": {"money": -6000, "empresarios": 5, "economia": 2, "clase_media": -6, "trabajadores": -4}, "rec": "economia", "news": "Rescate millonario a la banca tras el estallido inmobiliario"},
			{"t": "Rescatar a las familias: moratoria y quitas.", "fx": {"money": -4000, "monthly": -150, "clase_media": 5, "jovenes": 3, "empresarios": -4}, "news": "Moratoria hipotecaria para 300.000 familias"},
			{"t": "No intervenir: el mercado se purgará solo.", "fx": {"economia": -8, "clase_media": -10, "trabajadores": -6, "estabilidad": -5}, "news": "El Gobierno deja caer a las promotoras"},
		], "default": 2},
	{"id": "burbuja_estalla_leve", "type": "advisor", "who": "economia", "chain_only": true, "title": "Se desinfla el ladrillo",
		"text": "Los precios de la vivienda caen un 12%. Algunas promotoras tienen problemas, pero el impuesto a la especulación evitó lo peor. Los jóvenes, por primera vez en años, pueden plantearse comprar.",
		"choices": [
			{"t": "Plan de vivienda joven aprovechando la bajada.", "fx": {"money": -900, "jovenes": 5, "clase_media": 2}, "news": "Plan de vivienda joven tras el ajuste inmobiliario"},
			{"t": "Ayudas a las promotoras en apuros.", "fx": {"money": -1200, "empresarios": 4, "trabajadores": 2}},
		], "default": 0},
	{"id": "burbuja_suave", "type": "advisor", "who": "economia", "chain_only": true, "title": "Aterrizaje suave",
		"text": "Buenas noticias, por una vez: los precios de la vivienda se estabilizan sin sustos. El Banco Central felicita al Gobierno y la prensa económica habla de 'aterrizaje suave'.",
		"choices": [
			{"t": "Presumir de gestión.", "fx": {"economia": 2, "prestigio": 2, "pc": 4}, "news": "El Banco Central avala la política de vivienda del Gobierno"},
			{"t": "Seguir vigilantes.", "fx": {"economia": 2, "estabilidad": 1}},
		], "default": 0},

	# =====================================================================  TRAMA · El yate del expresidente
	{"id": "expresidente_yate", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Fotos en un yate",
		"text": "El expresidente Ernesto Salvatierra, histórico de {party}, aparece en las portadas de hoy tomando el sol en el yate de un empresario de Qadar investigado por blanqueo. La oposición pregunta si usted va a defenderle.",
		"choices": [
			{"t": "Defenderle: un expresidente merece respeto.", "fx": {"clase_media": -3, "estabilidad": 1, "corr": 2, "chain": {"id": "expresidente_contratos", "delay": 35}}, "news": "El presidente defiende a Salvatierra"},
			{"t": "Distanciarse: 'Cada uno responde de sus amistades'.", "fx": {"clase_media": 2, "estabilidad": -3, "chain": {"id": "expresidente_venganza", "delay": 45}}, "news": "El presidente marca distancias con Salvatierra"},
			{"t": "No comment.", "fx": {"clase_media": -1, "chain": {"id": "expresidente_contratos", "delay": 40}}},
		], "default": 2},
	{"id": "expresidente_contratos", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Los contratos de Salvatierra",
		"text": "Aparecen contratos de 'asesoría' de Salvatierra con tres empresas que recibieron obra pública durante su mandato. 4,2 millones en total. Su partido está en estado de shock.",
		"choices": [
			{"t": "Expulsarle del partido de inmediato.", "fx": {"estabilidad": -4, "clase_media": 4, "jovenes": 2, "corr_mult": 0.6}, "news": "{party} expulsa al expresidente Salvatierra"},
			{"t": "Pedir una comisión de investigación en el Congreso.", "fx": {"pc": -6, "clase_media": 3, "estabilidad": -2}},
			{"t": "Seguir defendiéndole.", "fx": {"clase_media": -7, "jovenes": -5, "estabilidad": -3, "corr": 4}, "news": "El Gobierno insiste en defender a Salvatierra"},
		], "default": 2},
	{"id": "expresidente_venganza", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Las memorias del expresidente",
		"text": "Salvatierra publica sus memorias. Un capítulo entero se titula 'Mi sucesor no está a la altura'. Una docena de diputados de su partido le aplauden en la presentación.",
		"choices": [
			{"t": "Responder con una entrevista en prime time.", "fx": {"press": "entrevista"}},
			{"t": "Ignorarle con elegancia.", "fx": {"estabilidad": -2, "clase_media": 2}},
			{"t": "Reunir al grupo parlamentario y exigir lealtad.", "fx": {"pc": -6, "estabilidad": 3}},
		], "default": 1},

	# =====================================================================  TRAMA · Conspiración interna
	{"id": "conspiracion_rumor", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Ruido en el partido",
		"text": "Me llegan rumores preocupantes: un grupo de diputados de {party} se reúne a escondidas con {min_eco}. Hablan de 'relevo' y de 'salvar al partido antes de las elecciones'.",
		"choices": [
			{"t": "Cesar a {min_eco} esta misma tarde.", "fx": {"fire": "economia", "estabilidad": -3, "pc": -5, "chain": {"id": "conspiracion_carta", "delay": 40}}, "news": "Cese fulminante del ministro de Economía"},
			{"t": "Reunirme con los críticos y escucharles.", "fx": {"pc": -8, "estabilidad": 2, "chain": {"id": "conspiracion_pacto", "delay": 20}}, "rec": "jefa"},
			{"t": "Son cuatro descontentos. Ignorarlos.", "fx": {"chain": {"id": "conspiracion_carta", "delay": 30}}},
		], "default": 2},
	{"id": "conspiracion_carta", "type": "advisor", "who": "jefa", "chain_only": true, "title": "La carta de los cuarenta",
		"text": "Cuarenta diputados de su partido han firmado una carta exigiendo un congreso extraordinario y primarias. La han filtrado a todos los periódicos. Es un desafío en toda regla a su liderazgo.",
		"choices": [
			{"t": "Convocar primarias y ganarlas.", "fx": {"risk": {"p": 0.6, "fx": {"pc": 12, "estabilidad": 6, "approval": 2}, "news": "El presidente arrasa en las primarias y sale reforzado", "text": "¡Victoria aplastante en las primarias! El partido cierra filas."}, "else": {"fx": {"estabilidad": -10, "pc": -10, "clase_media": -4}, "news": "El presidente gana las primarias por la mínima: el partido, partido en dos", "text": "Gana por apenas 300 votos. El partido queda roto."}}},
			{"t": "Expulsar a los cabecillas.", "fx": {"estabilidad": -6, "pc": 4, "party": {"CC": -3}}, "news": "Purga en el partido del Gobierno"},
			{"t": "Pactar: dos ministerios para los críticos.", "fx": {"pc": -8, "estabilidad": 3}, "news": "El presidente integra a los críticos en el Gobierno"},
		], "default": 1},
	{"id": "conspiracion_pacto", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Una tregua con condiciones",
		"text": "Los críticos aceptan una tregua. A cambio quieren que el Gobierno apruebe su plan estrella: un gran programa de vivienda pública. Si no, volverán a la carga.",
		"choices": [
			{"t": "Aceptar: 2.000 millones para vivienda.", "fx": {"money": -2000, "jovenes": 5, "clase_media": 2, "estabilidad": 4}, "news": "Plan de vivienda pública de 2.000 millones"},
			{"t": "Rechazarlo: aquí mando yo.", "fx": {"estabilidad": -3, "chain": {"id": "conspiracion_carta", "delay": 25}}},
		], "default": 1},

	# =====================================================================  TRAMA · La tesis del presidente
	{"id": "tesis_acusacion", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Copiar y pegar",
		"text": "Un periódico digital asegura que su tesis doctoral está plagiada en un 40%: párrafos enteros copiados de un libro de los años ochenta. Las redes ya han encontrado veinte coincidencias. Piden que la haga pública.",
		"choices": [
			{"t": "Publicarla entera en internet. No tengo nada que ocultar.", "fx": {"risk": {"p": 0.55, "fx": {"clase_media": 4, "jovenes": 3, "estabilidad": 2}, "news": "La tesis del presidente supera el análisis antiplagio", "text": "Los análisis la dan por buena: las coincidencias son citas mal formateadas."}, "else": {"fx": {"jovenes": -6, "clase_media": -5, "prestigio": -2}, "news": "Los expertos confirman fragmentos copiados en la tesis del presidente", "text": "Hay fragmentos copiados. Lo ha confirmado hasta la universidad."}}},
			{"t": "Querellarme contra el digital.", "fx": {"jovenes": -3, "estabilidad": -2, "chain": {"id": "tesis_universidad", "delay": 30}}, "news": "El presidente se querella contra el digital que le acusa de plagio"},
			{"t": "Es una campaña de la oposición.", "fx": {"clase_media": -3, "chain": {"id": "tesis_universidad", "delay": 25}}},
		], "default": 2},
	{"id": "tesis_universidad", "type": "advisor", "who": "jefa", "chain_only": true, "title": "La universidad revisará la tesis",
		"text": "La universidad anuncia que una comisión revisará su tesis. Su director, un catedrático jubilado, dice a la prensa que 'no recuerda haberla leído entera'. Esto se nos va de las manos.",
		"choices": [
			{"t": "Renunciar al título de doctor y pedir perdón.", "fx": {"stress": 10, "clase_media": 2, "jovenes": 2, "prestigio": -1}, "news": "El presidente renuncia a su doctorado: «Me equivoqué»"},
			{"t": "Esperar el dictamen.", "fx": {"risk": {"p": 0.5, "fx": {"estabilidad": 2}, "text": "La comisión archiva el caso por falta de pruebas.", "news": "La universidad archiva el caso de la tesis del presidente"}, "else": {"fx": {"jovenes": -7, "clase_media": -6, "estabilidad": -3}, "text": "La comisión concluye que hubo plagio.", "news": "La universidad concluye que la tesis del presidente es un plagio"}}},
		], "default": 1},

	# =====================================================================  TRAMA · El tren de Altamira
	{"id": "ave_proyecto", "type": "advisor", "who": "economia", "chain_only": true, "title": "El tren que nunca llega",
		"text": "Altamira lleva treinta años esperando la alta velocidad. Cada Gobierno la promete y ninguno la hace. El proyecto completo cuesta 4.000 millones e incluye un túnel bajo la sierra que los ingenieros llaman 'el reto del siglo'.",
		"choices": [
			{"t": "¡Adelante con el proyecto completo!", "fx": {"money": -2500, "trabajadores": 3, "jubilados": 2, "economia": 1, "chain": {"id": "ave_sobrecoste", "delay": 150}}, "news": "Luz verde a la alta velocidad hasta Altamira"},
			{"t": "Una versión más barata: tren rápido sin túnel.", "fx": {"money": -1000, "trabajadores": 1, "chain": {"id": "ave_inauguracion", "delay": 300}}, "rec": "economia"},
			{"t": "No es prioritario.", "fx": {"jubilados": -3, "trabajadores": -2, "party": {"CR": -2}}, "news": "Altamira se queda otra vez sin tren"},
		], "default": 2},
	{"id": "ave_sobrecoste", "type": "advisor", "who": "economia", "chain_only": true, "title": "Agua en el túnel",
		"text": "La tuneladora ha topado con un acuífero que nadie había previsto. El túnel se inunda y la constructora pide 1.800 millones más y dos años de plazo. O eso, o la obra se queda a medias.",
		"choices": [
			{"t": "Pagar el sobrecoste.", "fx": {"money": -1800, "clase_media": -2, "chain": {"id": "ave_inauguracion", "delay": 200}}},
			{"t": "Rescindir el contrato y licitar de nuevo.", "fx": {"pc": -5, "trabajadores": -3, "economia": -1, "chain": {"id": "ave_inauguracion", "delay": 320}}},
			{"t": "Abandonar el túnel: el tren llegará... más despacio.", "fx": {"jubilados": -4, "trabajadores": -2, "money": 500}, "news": "El Gobierno abandona el túnel del tren de Altamira"},
		], "default": 0},
	{"id": "ave_inauguracion", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Primer viaje a Altamira",
		"text": "El tren de Altamira está terminado. Los técnicos piden un mes más de pruebas, pero el alcalde ya ha contratado la banda de música y la televisión quiere el primer viaje en directo... con usted a bordo.",
		"choices": [
			{"t": "Inaugurar ya, con todo el boato.", "fx": {"jubilados": 4, "trabajadores": 3, "clase_media": 2, "risk": {"p": 0.25, "fx": {"clase_media": -8, "estabilidad": -4, "prestigio": -3}, "news": "Avería en el viaje inaugural: el presidente, atrapado tres horas en un túnel", "text": "El tren se ha detenido en mitad del túnel. En directo."}, "else": {"fx": {"approval": 2}, "text": "Un viaje perfecto. Altamira entera llora de emoción."}}},
			{"t": "Esperar a que terminen las pruebas.", "fx": {"jubilados": 2, "trabajadores": 2, "economia": 1}, "news": "Inaugurado sin fanfarria el tren de Altamira"},
		], "default": 1},

	# =====================================================================  TRAMA · La guerra del agua
	{"id": "agua_trasvase", "type": "advisor", "who": "interior", "chain_only": true, "title": "La guerra del agua",
		"text": "Vallegrande se seca. Sus regantes exigen un trasvase desde el río Norte. En Ferrosa, los alcaldes ya han dicho que 'el agua del Norte no se toca' y amenazan con cortar carreteras. Ambas regiones son clave en las elecciones.",
		"choices": [
			{"t": "Aprobar el trasvase.", "fx": {"money": -1500, "jubilados": 3, "ambiente": -4, "flag": "trasvase", "chain": {"id": "agua_protesta_norte", "delay": 30}}, "news": "Aprobado el trasvase Norte–Valle"},
			{"t": "Desaladoras en la costa para el Valle.", "fx": {"money": -2500, "ambiente": 1, "trabajadores": 2}, "rec": "economia", "news": "Plan de desaladoras para Vallegrande"},
			{"t": "Que se pongan de acuerdo las regiones.", "fx": {"estabilidad": -2, "chain": {"id": "agua_valle_corta", "delay": 40}}},
		], "default": 2},
	{"id": "agua_protesta_norte", "type": "advisor", "who": "interior", "chain_only": true, "title": "Ferrosa se levanta",
		"text": "Cincuenta mil personas cortan la autopista en Ferrosa contra el trasvase. Los alcaldes de la región han devuelto sus bastones de mando al delegado del Gobierno.",
		"choices": [
			{"t": "Compensaciones millonarias para el Norte.", "fx": {"money": -1000, "trabajadores": 3, "estabilidad": 1}},
			{"t": "Mantenerse firme.", "fx": {"trabajadores": -5, "estabilidad": -3, "seguridad": -1}},
		], "default": 1},
	{"id": "agua_valle_corta", "type": "advisor", "who": "interior", "chain_only": true, "title": "El Valle corta el agua a la capital",
		"text": "Desesperados, los regantes de Vallegrande han cerrado las compuertas del canal que abastece a Santa Aurora. 'Si no hay agua para nosotros, no hay para nadie'.",
		"choices": [
			{"t": "Enviar a la Guardia Civil a abrir las compuertas.", "fx": {"seguridad": 2, "jubilados": -4, "trabajadores": -3, "estabilidad": -2}},
			{"t": "Aprobar el trasvase de urgencia.", "fx": {"money": -1500, "jubilados": 3, "ambiente": -4, "chain": {"id": "agua_protesta_norte", "delay": 25}}},
		], "default": 0},

	# =====================================================================  TRAMA · Fusión bancaria
	{"id": "fusion_anuncio", "type": "advisor", "who": "economia", "chain_only": true, "title": "Nace un gigante bancario",
		"text": "Banco Meridional y Caja Atlántica anuncian su fusión. El nuevo banco controlará el 45% del mercado y cerrará 1.200 oficinas, la mayoría en pueblos. Necesitan el visto bueno del Gobierno.",
		"choices": [
			{"t": "Vetar la fusión.", "fx": {"empresarios": -6, "trabajadores": 3, "jubilados": 3, "economia": -1}, "news": "El Gobierno veta la gran fusión bancaria"},
			{"t": "Aprobarla con condiciones: ninguna oficina en pueblos se cierra.", "fx": {"pc": -6, "empresarios": 1, "jubilados": 2}, "rec": "economia"},
			{"t": "Aprobarla sin condiciones.", "fx": {"economia": 2, "empresarios": 5, "trabajadores": -3, "chain": {"id": "fusion_cajeros", "delay": 60}}, "news": "Luz verde a la fusión: 1.200 oficinas cerrarán"},
		], "default": 2},
	{"id": "fusion_cajeros", "type": "advisor", "who": "economia", "chain_only": true, "title": "Soy mayor, no idiota",
		"text": "Un jubilado de Vallegrande ha recogido 600.000 firmas: 'Soy mayor, no idiota'. Las colas en las pocas oficinas que quedan dan la vuelta a la manzana y los bancos solo atienden por aplicación.",
		"choices": [
			{"t": "Obligar por ley a atención presencial.", "fx": {"jubilados": 6, "empresarios": -3}, "news": "Ley de atención bancaria presencial para los mayores"},
			{"t": "Pedir a los bancos que lo arreglen 'voluntariamente'.", "fx": {"jubilados": -3, "pc": 2}},
		], "default": 1},

	# =====================================================================  TRAMA · Bots extranjeros
	{"id": "injerencia_bots", "type": "advisor", "who": "interior", "chain_only": true, "title": "Una granja de bots",
		"text": "Una red de 40.000 cuentas falsas inunda las redes con bulos sobre su Gobierno: que va a subir el IVA al 30%, que cerrará hospitales... Los rastros apuntan a Kharovia. Los bulos ya se comparten en grupos familiares.",
		"choices": [
			{"t": "Denunciarlo ante el mundo.", "fx": {"rel": {"kharovia": -10}, "prestigio": 2, "chain": {"id": "injerencia_hackeo", "delay": 60}}, "news": "Valdoria denuncia una campaña de desinformación kharovia"},
			{"t": "Ley contra la desinformación.", "fx": {"jovenes": -4, "estabilidad": 2, "seguridad": 1}, "news": "El Gobierno prepara una ley contra los bulos"},
			{"t": "Contraatacar con nuestras propias cuentas.", "fx": {"corr": 3, "risk": {"p": 0.4, "fx": {"jovenes": -6, "clase_media": -4, "prestigio": -3}, "news": "Descubierta una red de cuentas falsas vinculada al Gobierno", "text": "Han descubierto nuestras cuentas. Ridículo internacional."}, "else": {"fx": {"approval": 1}, "text": "Nadie se ha dado cuenta."}}},
		], "default": 0},
	{"id": "injerencia_hackeo", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Correos al descubierto",
		"text": "Han hackeado mi correo, presidente. Publican mensajes privados: comentarios poco elegantes sobre socios del Gobierno... y algún chiste sobre usted. Lo siento muchísimo.",
		"choices": [
			{"t": "Defender a {jefa}: es la víctima.", "fx": {"estabilidad": -2, "party": {"CC": -3, "VV": -3}}},
			{"t": "Aceptar su dimisión.", "fx": {"fire": "jefa", "estabilidad": -3, "clase_media": 1}},
		], "default": 0},

	# =====================================================================  TRAMA · El barco del Estrecho
	{"id": "barco_ong", "type": "advisor", "who": "interior", "chain_only": true, "title": "El Esperanza",
		"text": "El Esperanza, un barco de una ONG con 300 personas rescatadas en el Estrecho, lleva doce días en el mar. Ningún país le deja atracar. A bordo hay niños y una mujer embarazada. Todos los ojos están puestos en Valdoria.",
		"choices": [
			{"t": "Que atraque en Puerto Alba.", "fx": {"prestigio": 4, "jovenes": 4, "clase_media": -3, "jubilados": -2, "chain": {"id": "barco_reparto", "delay": 20}}, "news": "El Esperanza atraca en Puerto Alba"},
			{"t": "No: otro país tendrá que hacerse cargo.", "fx": {"prestigio": -4, "jovenes": -4, "clase_media": 2, "chain": {"id": "barco_drama", "delay": 6}}, "news": "Valdoria cierra sus puertos al Esperanza"},
			{"t": "Negociar un reparto con la Unión.", "fx": {"nego": {"who": "union", "topic": "cuotas"}}, "rec": "exteriores"},
		], "default": 1},
	{"id": "barco_reparto", "type": "call", "who": "union", "chain_only": true, "title": "La Unión agradece el gesto",
		"text": "Presidente, la Comisión agradece su gesto con el Esperanza. Varios socios se ofrecen a acoger a parte de los rescatados... si Valdoria se compromete a liderar el nuevo pacto migratorio.",
		"choices": [
			{"t": "Valdoria liderará el pacto.", "fx": {"rel": {"union": 10}, "prestigio": 4, "clase_media": -2}},
			{"t": "Gracias, pero cada país con lo suyo.", "fx": {"rel": {"union": -3}, "clase_media": 1}},
		], "default": 1},
	{"id": "barco_drama", "type": "advisor", "who": "jefa", "chain_only": true, "title": "La foto que da la vuelta al mundo",
		"text": "Una niña de cuatro años ha muerto a bordo del Esperanza. La foto de su madre en cubierta abre todos los informativos del mundo. Hay vigilias en todas las ciudades del país.",
		"choices": [
			{"t": "Rectificar y abrir el puerto.", "fx": {"prestigio": 2, "jovenes": 2, "estabilidad": -2}, "news": "El Gobierno rectifica y abre el puerto al Esperanza"},
			{"t": "Mantener la decisión.", "fx": {"prestigio": -6, "jovenes": -6, "clase_media": -2, "rel": {"union": -6}}},
		], "default": 1},

	# =====================================================================  TRAMA · Robots en las oficinas
	{"id": "ia_despidos", "type": "advisor", "who": "economia", "chain_only": true, "title": "Despedidos por un algoritmo",
		"text": "La aseguradora más grande del país despide a 4.000 administrativos: una inteligencia artificial hará su trabajo. Otras diez empresas preparan anuncios similares. Los sindicatos hablan de 'tsunami'.",
		"choices": [
			{"t": "Impuesto a la automatización.", "fx": {"monthly": 150, "empresarios": -5, "trabajadores": 4, "economia": -1}, "news": "Nace el 'impuesto a los robots'"},
			{"t": "Plan nacional de reciclaje profesional.", "fx": {"money": -800, "trabajadores": 2, "jovenes": 3, "economia": 1}, "rec": "economia"},
			{"t": "Es el progreso. Que se adapten.", "fx": {"economia": 2, "empresarios": 3, "trabajadores": -5, "chain": {"id": "ia_huelga", "delay": 45}}},
		], "default": 2},
	{"id": "ia_huelga", "type": "advisor", "who": "interior", "chain_only": true, "title": "Huelga contra las máquinas",
		"text": "Banca, seguros y telefonía van a la huelga contra la automatización. Las pancartas dicen 'Los robots no pagan impuestos'. La patronal pide calma; los sindicatos, una ley ya.",
		"choices": [
			{"t": "Ley de transición digital justa.", "fx": {"trabajadores": 5, "empresarios": -4, "estabilidad": 2}},
			{"t": "Servicios mínimos y esperar.", "fx": {"trabajadores": -4, "economia": -2, "chain": {"id": "ia_renta", "delay": 60}}},
		], "default": 1},
	{"id": "ia_renta", "type": "advisor", "who": "jefa", "chain_only": true, "title": "700.000 firmas",
		"text": "Una iniciativa ciudadana entrega en el Congreso 700.000 firmas pidiendo una renta básica 'para la era de las máquinas'. Los jóvenes la apoyan en masa; los economistas, no tanto.",
		"choices": [
			{"t": "Apoyar que se debata.", "fx": {"jovenes": 5, "trabajadores": 2, "empresarios": -3}},
			{"t": "No es viable.", "fx": {"jovenes": -4, "empresarios": 2}},
		], "default": 1},

	# =====================================================================  TRAMA · Huelga de inquilinos
	{"id": "inquilinos_huelga", "type": "advisor", "who": "interior", "chain_only": true, "title": "Ni un euro más",
		"text": "Ocho mil inquilinos de Santa Aurora han dejado de pagar el alquiler en protesta: 'Ni un euro más a los fondos buitre'. Los fondos, dueños de miles de pisos, piden desalojos inmediatos.",
		"choices": [
			{"t": "Tope a los alquileres de los grandes propietarios.", "fx": {"jovenes": 6, "trabajadores": 3, "empresarios": -6, "chain": {"id": "inquilinos_fondos", "delay": 50}}, "news": "Tope al alquiler para los grandes tenedores"},
			{"t": "Mediación entre inquilinos y fondos.", "fx": {"pc": -5, "jovenes": 2, "empresarios": 1}, "rec": "jefa"},
			{"t": "La ley es la ley: desalojos.", "fx": {"jovenes": -7, "trabajadores": -3, "empresarios": 3, "seguridad": 1}},
		], "default": 1},
	{"id": "inquilinos_fondos", "type": "call", "who": "norland", "chain_only": true, "title": "Kade defiende a sus fondos",
		"text": "Presidente, varios fondos de inversión de Norland me dicen que su tope al alquiler es una expropiación encubierta. Si no rectifica, me será difícil explicar en casa por qué seguimos invirtiendo en Valdoria.",
		"choices": [
			{"t": "Valdoria decide sus leyes.", "fx": {"rel": {"norland": -8}, "jovenes": 2, "economia": -1}},
			{"t": "Buscaremos una fórmula para los fondos extranjeros.", "fx": {"rel": {"norland": 4}, "jovenes": -4}},
		], "default": 1},

	# =====================================================================  MODO INFINITO
	{"id": "nueva_legislatura", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Otros cuatro años",
		"text": "Enhorabuena, presidente: el país le ha vuelto a dar su confianza. Pero cuidado: cada legislatura pesa más que la anterior. La gente se cansa de las mismas caras y la oposición llega con hambre. ¿Mantiene su equipo o cambia el Gobierno?",
		"choices": [
			{"t": "El equipo que gana no se toca.", "fx": {"estabilidad": 3, "pc": 4}},
			{"t": "Remodelación parcial: dos caras nuevas.", "fx": {"reshuffle": 2, "approval": 2, "pc": -2}, "news": "El presidente remodela su Gobierno"},
			{"t": "Gobierno nuevo de arriba abajo.", "fx": {"reshuffle": 5, "approval": 4, "estabilidad": -3, "pc": -6}, "news": "Crisis de Gobierno: el presidente cambia a todo su gabinete"},
		], "default": 0},

	# =====================================================================  ESCENARIOS
	{"id": "recesion_paro", "type": "advisor", "who": "economia", "chain_only": true, "title": "El paro, por encima del 17%",
		"text": "Presidente, los datos de este mes son malos: el paro supera el 17% y entre los jóvenes roza el 35%. Necesitamos un mensaje y medidas ya. Tengo tres propuestas.",
		"choices": [
			{"t": "Plan de empleo público de choque.", "fx": {"money": -2500, "trabajadores": 5, "jovenes": 4, "economia": 1}, "news": "Plan de choque: 2.500 millones para el empleo"},
			{"t": "Rebajas fiscales para contratar.", "fx": {"monthly": -250, "empresarios": 5, "economia": 2, "trabajadores": 1}, "rec": "economia"},
			{"t": "Ajuste del gasto: primero, cuadrar las cuentas.", "fx": {"monthly": 400, "trabajadores": -5, "bienestar": -3, "empresarios": 3}},
		], "default": 2},
	{"id": "recesion_astilleros", "type": "doc", "kind": "decreto", "chain_only": true, "title": "Cierre de los Astilleros del Sur",
		"text": "Real Decreto por el que se autoriza el cierre ordenado de los Astilleros del Sur (Puerto Alba), con un plan social para sus 3.200 trabajadores y la venta de los terrenos portuarios.",
		"small": ["Anexo: los terrenos se venderán a Inmobiliaria Atalaya, cuyo consejero delegado fue jefe de gabinete del anterior ministro de Industria."],
		"choices": [
			{"t": "Aprobar", "fx": {"money": 600, "trabajadores": -6, "economia": 1}, "hidden": {"corr": 4, "clase_media": -2}, "news": "Cierran los Astilleros del Sur"},
			{"t": "Vetar", "fx": {"trabajadores": 4, "money": -500, "monthly": -60}, "news": "El Gobierno salva in extremis los Astilleros del Sur"},
		], "default": 0},
	{"id": "bonanza_superavit", "type": "advisor", "who": "economia", "chain_only": true, "title": "¡Sobra dinero!",
		"text": "Presidente, algo que no veía en veinte años: la recaudación supera lo previsto en 3.000 millones. Todos los ministerios ya han venido a pedirme su parte. ¿Qué hacemos con ello?",
		"choices": [
			{"t": "Amortizar deuda: pan para mañana.", "fx": {"money": 3000, "economia": 1, "prestigio": 1}, "rec": "economia", "news": "El Gobierno dedica el superávit a reducir deuda"},
			{"t": "Bajar impuestos a la clase media.", "fx": {"tax": {"renta": -1.0}, "clase_media": 5, "empresarios": 2}, "news": "Rebaja del IRPF gracias al superávit"},
			{"t": "Invertir en sanidad y educación.", "fx": {"budget": {"sanidad": 0.05, "educacion": 0.05}, "bienestar": 3, "jovenes": 3, "jubilados": 2}, "news": "El superávit irá a sanidad y educación"},
		], "default": 0},
	{"id": "minoria_socios", "type": "advisor", "who": "jefa", "chain_only": true, "title": "La factura de la investidura",
		"text": "Los socios que le votaron en la investidura pasan la factura: Coalición Regional quiere inversiones en las Islas y el Centro Cívico, una rebaja del impuesto de sucesiones. Si no cumplimos, no habrá ni una ley aprobada.",
		"choices": [
			{"t": "Cumplir con los dos.", "fx": {"money": -1500, "monthly": -150, "party": {"CR": 10, "CC": 10}, "estabilidad": 4}},
			{"t": "Cumplir solo con Coalición Regional.", "fx": {"money": -1500, "party": {"CR": 12, "CC": -6}}},
			{"t": "Cumplir solo con el Centro Cívico.", "fx": {"monthly": -150, "party": {"CC": 12, "CR": -6}, "empresarios": 2}},
			{"t": "Ganar tiempo con promesas.", "fx": {"party": {"CR": -6, "CC": -6}, "estabilidad": -3}},
		], "default": 3},
	{"id": "minoria_presupuestos", "type": "advisor", "who": "jefa", "chain_only": true, "title": "Los socios amenazan",
		"text": "Los socios del Gobierno avisan: no apoyarán ni una ley más si no se incluyen sus enmiendas en la agenda del Gobierno. Sin ellos, estamos en minoría para todo.",
		"choices": [
			{"t": "Pacto de legislatura por escrito.", "fx": {"pc": -10, "estabilidad": 6, "party": {"CR": 8, "CC": 8, "VV": 5}}},
			{"t": "Amenazar con adelantar las elecciones.", "fx": {"risk": {"p": 0.5, "fx": {"party": {"CR": 6, "CC": 6}, "estabilidad": 3}, "text": "Funciona: los socios se asustan y vuelven al redil."}, "else": {"fx": {"party": {"CR": -8, "CC": -8}, "estabilidad": -6}, "text": "Los socios le toman la palabra: 'Pues convoque'."}}},
		], "default": 1},
	{"id": "herencia_auditoria", "type": "advisor", "who": "economia", "chain_only": true, "title": "El agujero",
		"text": "Presidente, la auditoría de las cuentas ha terminado. El anterior Gobierno escondió 9.000 millones de gasto en empresas públicas para maquillar el déficit. Si lo contamos, los mercados se asustarán. Si no, será nuestro agujero.",
		"choices": [
			{"t": "Contarlo todo y llevarlo a la Fiscalía.", "fx": {"economia": -3, "clase_media": 5, "estabilidad": 2, "prestigio": 1, "rel": {"union": 4}}, "news": "El Gobierno destapa un agujero de 9.000 millones dejado por sus antecesores"},
			{"t": "Corregirlo poco a poco, sin ruido.", "fx": {"monthly": -200, "corr": 3}},
		], "default": 1},
	{"id": "herencia_juicio", "type": "advisor", "who": "jefa", "chain_only": true, "title": "El juicio del siglo",
		"text": "Arranca el juicio contra once exministros del anterior Gobierno. La oposición de entonces, que es su partido, celebra. Pero la defensa amenaza con 'tirar de la manta' y señalar a gente de todos los partidos.",
		"choices": [
			{"t": "Que la justicia llegue hasta el final, caiga quien caiga.", "fx": {"clase_media": 4, "jovenes": 3, "estabilidad": -3, "corr_mult": 0.7}},
			{"t": "Pedir prudencia: el país necesita pasar página.", "fx": {"clase_media": -4, "estabilidad": 2}},
		], "default": 1},
	{"id": "dana_reconstruccion", "type": "advisor", "who": "interior", "chain_only": true, "urgent": 30.0, "title": "Barro hasta las rodillas",
		"text": "Presidente, en la Costa Este aún hay pueblos sin luz ni agua potable. Miles de voluntarios limpian el barro con cubos. Los alcaldes piden el Ejército y dinero. Ya.",
		"choices": [
			{"t": "Desplegar el Ejército y aprobar 3.000 millones en ayudas directas.", "fx": {"money": -3000, "militares": 3, "clase_media": 5, "jubilados": 4, "bienestar": 2}, "news": "El Ejército y 3.000 millones para la Costa Este"},
			{"t": "Pedir fondos de emergencia a la Unión.", "fx": {"nego": {"who": "union", "topic": "fondos"}}, "rec": "exteriores"},
			{"t": "Visitar la zona y prometer ayudas 'en breve'.", "fx": {"clase_media": -4, "jubilados": -4, "risk": {"p": 0.4, "fx": {"clase_media": -4, "estabilidad": -3}, "news": "Vecinos de Marvella reciben al presidente entre insultos y barro", "text": "Le han lanzado barro a la llegada. Las imágenes están en todas partes."}, "else": {"fx": {}, "text": "La visita pasa sin incidentes."}}},
		], "default": 2},
	{"id": "dana_aseguradoras", "type": "doc", "kind": "decreto", "chain_only": true, "title": "Decreto de indemnizaciones por la gota fría",
		"text": "El Consorcio de Compensación de Seguros adelantará las indemnizaciones a los afectados por la gota fría de la Costa Este, que recibirán un 70% de la tasación en 30 días.",
		"small": ["Art. 9: quedan excluidas las viviendas sin licencia de primera ocupación, el 40% de las afectadas en los barrios más humildes."],
		"choices": [
			{"t": "Aprobar", "fx": {"money": -800, "clase_media": 3}, "hidden": {"trabajadores": -3, "jovenes": -2}, "news": "Las indemnizaciones de la gota fría llegarán en 30 días"},
			{"t": "Vetar", "fx": {"clase_media": -2, "chain": {"id": "dana_ayudas", "delay": 20}}},
		], "default": 0},
	{"id": "dana_ayudas", "type": "advisor", "who": "interior", "chain_only": true, "title": "Las ayudas no llegan",
		"text": "Dos meses después, solo el 20% de los afectados ha cobrado algo. La burocracia lo atasca todo. 'Nos han abandonado', dice la portada de El Heraldo con la foto de una anciana en su casa destrozada.",
		"choices": [
			{"t": "Ventanilla única y pago exprés sin papeleo.", "fx": {"money": -1200, "clase_media": 4, "jubilados": 4, "corr": 1}},
			{"t": "Culpar a las administraciones regionales.", "fx": {"estabilidad": -3, "party": {"CR": -5}, "clase_media": -2}},
		], "default": 1},
	{"id": "islas_hoja_ruta", "type": "advisor", "who": "interior", "chain_only": true, "title": "La hoja de ruta",
		"text": "Quintana presenta la 'hoja de ruta' de las Islas Cordales: consulta en seis meses y, si gana el sí, declaración de independencia. Medio Gobierno le pide mano dura; la otra mitad, diálogo.",
		"choices": [
			{"t": "Mesa de diálogo sin condiciones previas.", "fx": {"pc": -8, "party": {"CR": 10}, "estabilidad": 3, "militares": -3, "clase_media": -2}, "rec": "jefa", "news": "El Gobierno y las Islas abren una mesa de diálogo"},
			{"t": "Recurrir la hoja de ruta ante el Constitucional.", "fx": {"party": {"CR": -6}, "militares": 2, "estabilidad": -2, "chain": {"id": "islas_referendum", "delay": 90}}},
			{"t": "Ofrecer un nuevo Estatuto de Autonomía.", "fx": {"nego": {"who": "islas", "topic": "autonomia"}}},
		], "default": 1},
	{"id": "guerra_gasto_defensa", "type": "call", "who": "norland", "chain_only": true, "title": "Kade pide más gasto militar",
		"text": "Presidente, con Kharovia y Sarvenia enseñando los dientes, la Alianza necesita que todos arrimen el hombro. Valdoria gasta en defensa la mitad de lo pactado. Espero que eso cambie. Pronto.",
		"choices": [
			{"t": "Subiremos el gasto en defensa.", "fx": {"budget": {"defensa": 0.2}, "militares": 5, "rel": {"norland": 10}, "jovenes": -3, "trabajadores": -2}},
			{"t": "Lo subiremos... poco a poco.", "fx": {"budget": {"defensa": 0.08}, "rel": {"norland": 3}, "militares": 2}},
			{"t": "Valdoria no está en guerra con nadie.", "fx": {"rel": {"norland": -12}, "jovenes": 3, "militares": -4}},
		], "default": 1},
	{"id": "energia_apagones", "type": "advisor", "who": "economia", "chain_only": true, "title": "Apagones programados",
		"text": "Las eléctricas avisan: si este invierno es frío, habrá cortes de luz programados en la industria. La patronal habla de 'catástrofe' y pide que el Estado pague la factura.",
		"choices": [
			{"t": "Plan de ahorro obligatorio: escaparates apagados y calefacción a 19 grados.", "fx": {"ambiente": 3, "clase_media": -3, "empresarios": -2, "economia": 1}, "news": "Plan de ahorro energético: escaparates apagados a las 22.00"},
			{"t": "Subvencionar la factura industrial.", "fx": {"money": -2000, "empresarios": 5, "trabajadores": 2}},
			{"t": "Comprar gas a Kharovia a toda prisa.", "fx": {"rel": {"kharovia": 8, "union": -8}, "economia": 2, "flag": "dependencia_gas"}},
		], "default": 0},
]
