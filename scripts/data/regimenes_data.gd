extends RefCounted
## Regímenes políticos. Todos comparten el mismo juego (cámara con siete grupos, aprobación, gabinete, leyes),
## pero cambian las reglas:
##   elecciones   "libres" (hay que ganarlas), "controladas" (hay elecciones, pero se pueden amañar)
##                o "ninguna" (al final del mandato decide el Partido, la familia real o la Junta)
##   prensa       libertad de prensa (1 = total): con menos libertad salen menos escándalos
##   pilar        quién sostiene al presidente de verdad (su lealtad, 0-100, está en GS.regimen["lealtad"]).
##                Si se hunde, le echan: golpe de Estado, purga, golpe de palacio.
##   mocion       si la cámara puede tumbar al Gobierno con una moción de censura
##   limite       legislaturas como máximo (0 = sin límite)
##   mitad        elecciones de mitad de mandato (renuevan la cámara a los dos años)
##   acciones     poderes propios del régimen (panel «Régimen»), cada uno con su efecto y su espera en días

const REGIMENES := {
	"parlamentaria": {
		"name": "Democracia parlamentaria", "elecciones": "libres", "prensa": 1.0, "mocion": true, "limite": 0, "mitad": false,
		"aprobacion": "Aprobación",
		"desc": "El Gobierno depende del Congreso: siete partidos, coaliciones y mociones de censura. Elecciones libres cada cuatro años.",
		"pilar": "", "pilar_name": "",
		"acciones": [],
	},
	"presidencial": {
		"name": "República federal presidencial", "elecciones": "libres", "prensa": 1.0, "mocion": false, "limite": 2, "mitad": true,
		"aprobacion": "Aprobación",
		"desc": "El presidente no depende de la cámara: no hay moción de censura. A los dos años, elecciones de mitad de mandato renuevan el Congreso. Como mucho, dos mandatos.",
		"pilar": "", "pilar_name": "",
		"acciones": [
			{"id": "orden", "name": "Orden ejecutiva", "desc": "Gobernar sin el Congreso: rápido, pero los tribunales y la oposición lo recuerdan.", "cd": 120,
				"fx": {"estabilidad": -2, "pc": 8, "clase_media": -1}, "news": "El presidente firma una orden ejecutiva y esquiva al Congreso"},
			{"id": "gira", "name": "Gira por los estados", "desc": "Mítines y gobernadores amigos: sube el apoyo, cuesta tiempo y dinero.", "cd": 150,
				"fx": {"money": -300, "pc": -5, "trabajadores": 2, "clase_media": 2, "jubilados": 1}, "news": "El presidente inicia una gira por los estados del país"},
		],
	},
	"fragil": {
		"name": "Democracia frágil", "elecciones": "libres", "prensa": 0.8, "mocion": true, "limite": 0, "mitad": false,
		"aprobacion": "Aprobación",
		"desc": "Elecciones libres, pero instituciones débiles: si el ejército pierde la paciencia y el país se desordena, puede haber golpe.",
		"pilar": "militares", "pilar_name": "Paciencia del ejército",
		"acciones": [
			{"id": "pacto_militar", "name": "Pacto con los cuarteles", "desc": "Presupuesto y respeto para el ejército. Calma a los generales; a los demócratas, no tanto.", "cd": 180,
				"fx": {"money": -500, "militares": 6, "prestigio": -2, "regimen": {"lealtad": 14}}, "news": "El Gobierno sella un pacto con la cúpula militar"},
			{"id": "emergencia", "name": "Estado de emergencia", "desc": "Orden en la calle a cambio de libertades. Sube la estabilidad, bajan los jóvenes y el prestigio.", "cd": 240,
				"fx": {"estabilidad": 5, "jovenes": -4, "prestigio": -3, "regimen": {"lealtad": 6, "calma": true}}, "news": "El Gobierno declara el estado de emergencia"},
			{"id": "donantes", "name": "Pedir ayuda a los donantes", "desc": "Fondos de la Unión y de Norland, con condiciones: reformas y transparencia.", "cd": 300,
				"fx": {"money": 1200, "prestigio": -1, "corr": -2, "estabilidad": 1}, "news": "Los donantes internacionales aprueban un paquete de ayuda con condiciones"},
		],
	},
	"autoritaria": {
		"name": "Autoritarismo electoral", "elecciones": "controladas", "prensa": 0.35, "mocion": false, "limite": 0, "mitad": false,
		"aprobacion": "Apoyo popular",
		"desc": "Hay elecciones, pero el poder las controla: se pueden amañar, a riesgo de protestas. La prensa libre es poca. Le sostienen los oligarcas y los servicios de seguridad.",
		"pilar": "oligarcas", "pilar_name": "Lealtad de los oligarcas",
		"acciones": [
			{"id": "amano", "name": "Preparar las elecciones", "desc": "Urnas llenas antes de votar, candidatos rivales inhabilitados. +4 puntos el día de las elecciones; si se nota, protestas.", "cd": 120,
				"fx": {"pc": -10, "money": -300, "regimen": {"amano": 4.0}}, "news": ""},
			{"id": "contratos", "name": "Contratos para los oligarcas", "desc": "Obras y privatizaciones para los amigos. Compra lealtad con corrupción.", "cd": 150,
				"fx": {"money": -800, "corr": 6, "empresarios": 3, "regimen": {"lealtad": 14}}, "news": "Grandes contratos públicos para empresas cercanas al Gobierno"},
			{"id": "censura", "name": "Cerrar un medio crítico", "desc": "Menos escándalos durante medio año. Los jóvenes y el extranjero lo ven.", "cd": 180,
				"fx": {"prestigio": -3, "jovenes": -3, "regimen": {"censura": 180}}, "news": "La fiscalía cierra el último diario independiente del país"},
			{"id": "represion", "name": "Disolver las protestas", "desc": "Policía antidisturbios y detenciones. La calle se calla un tiempo; el mundo protesta.", "cd": 120,
				"fx": {"estabilidad": 4, "jovenes": -5, "prestigio": -5, "rel_democracias": -8, "regimen": {"calma": true, "lealtad": 4}}, "news": "La policía disuelve con dureza las protestas en la capital"},
		],
	},
	"partido_unico": {
		"name": "Partido único", "elecciones": "ninguna", "prensa": 0.1, "mocion": false, "limite": 0, "mitad": false,
		"aprobacion": "Legitimidad",
		"desc": "No hay elecciones: al acabar el mandato, el Congreso del Partido decide si sigue. El crecimiento es la legitimidad. El Politburó le vigila; si pierde su confianza, le purgan.",
		"pilar": "politburo", "pilar_name": "Confianza del Politburó",
		"revision": "el Congreso del Partido",
		"acciones": [
			{"id": "purga", "name": "Purga en el Politburó", "desc": "Fuera los rivales. El miedo da lealtad... por un tiempo.", "cd": 240,
				"fx": {"estabilidad": -3, "corr": -4, "regimen": {"lealtad": 16}}, "news": "Destituidos tres miembros del Politburó por «graves violaciones de la disciplina»"},
			{"id": "anticorrupcion", "name": "Campaña anticorrupción", "desc": "Cae algún pez gordo: la gente aplaude, los cuadros tiemblan.", "cd": 180,
				"fx": {"corr": -8, "clase_media": 3, "trabajadores": 2, "regimen": {"lealtad": -6}}, "news": "El Partido lanza una gran campaña contra la corrupción"},
			{"id": "cortafuegos", "name": "Reforzar la censura en internet", "desc": "Menos escándalos durante medio año. Los jóvenes protestan en voz baja.", "cd": 180,
				"fx": {"jovenes": -4, "prestigio": -2, "regimen": {"censura": 180}}, "news": ""},
			{"id": "estimulo", "name": "Plan de estímulo", "desc": "Crédito barato y obras: crece la economía, crece la deuda.", "cd": 240,
				"fx": {"money": -2500, "economia": 4, "trabajadores": 3, "regimen": {"lealtad": 5}}, "news": "El Gobierno aprueba un gigantesco plan de estímulo económico"},
		],
	},
	"monarquia": {
		"name": "Emirato (monarquía absoluta)", "elecciones": "ninguna", "prensa": 0.2, "mocion": false, "limite": 0, "mitad": false,
		"aprobacion": "Legitimidad",
		"desc": "No hay elecciones ni partidos de verdad: el Consejo Consultivo solo aconseja. Lo que cuenta es la familia real y los clérigos. Si la familia se cansa, golpe de palacio.",
		"pilar": "familia", "pilar_name": "Lealtad de la familia real",
		"revision": "el consejo de la familia real",
		"acciones": [
			{"id": "subsidios", "name": "Subsidios para todos", "desc": "El petróleo paga la paz social: gasolina, vivienda y empleos públicos.", "cd": 180,
				"fx": {"money": -1500, "trabajadores": 4, "clase_media": 4, "jovenes": 3, "regimen": {"lealtad": 4}}, "news": "El Emir anuncia nuevas ayudas para todas las familias"},
			{"id": "clerigos", "name": "Contentar a los clérigos", "desc": "Más poder para los religiosos: estabilidad en las mezquitas, malestar entre los jóvenes.", "cd": 180,
				"fx": {"estabilidad": 3, "jovenes": -3, "prestigio": -1, "regimen": {"lealtad": 8}}, "news": "El Emir concede nuevas competencias al consejo de clérigos"},
			{"id": "heredero", "name": "Nombrar heredero", "desc": "Asegura la sucesión. Un primo resentido es un enemigo.", "cd": 9999,
				"fx": {"estabilidad": 6, "regimen": {"lealtad": -8, "heredero": true}}, "news": "El Emir nombra a su heredero en una ceremonia en palacio"},
			{"id": "censura", "name": "Silenciar a los críticos", "desc": "Menos escándalos durante medio año. El mundo mira hacia otro lado... casi siempre.", "cd": 180,
				"fx": {"prestigio": -3, "jovenes": -2, "regimen": {"censura": 180}}, "news": ""},
		],
	},
	"junta": {
		"name": "Junta militar", "elecciones": "ninguna", "prensa": 0.2, "mocion": false, "limite": 0, "mitad": false,
		"aprobacion": "Apoyo popular",
		"desc": "Gobiernan los generales. No hay elecciones mientras no las convoque la Junta. Si los generales dejan de apoyarle, contragolpe. Una transición democrática puede ser su mejor final.",
		"pilar": "generales", "pilar_name": "Lealtad de los generales",
		"revision": "la Junta",
		"acciones": [
			{"id": "ascensos", "name": "Ascensos y primas", "desc": "Galones y sobres para los mandos.", "cd": 150,
				"fx": {"money": -700, "militares": 6, "corr": 2, "regimen": {"lealtad": 14}}, "news": "La Junta aprueba una ronda de ascensos en las Fuerzas Armadas"},
			{"id": "toque", "name": "Toque de queda", "desc": "Orden a la fuerza: la calle se vacía y el mundo condena.", "cd": 120,
				"fx": {"estabilidad": 4, "jovenes": -5, "prestigio": -5, "rel_democracias": -8, "regimen": {"calma": true, "lealtad": 3}}, "news": "La Junta decreta el toque de queda en todo el país"},
			{"id": "censura", "name": "Censura militar", "desc": "Menos escándalos durante medio año.", "cd": 180,
				"fx": {"prestigio": -3, "jovenes": -3, "regimen": {"censura": 180}}, "news": ""},
			{"id": "transicion", "name": "Anunciar la transición democrática", "desc": "Elecciones libres al final del mandato. El mundo aplaude, los generales se inquietan. Si las gana, entra en la historia.", "cd": 9999,
				"fx": {"prestigio": 10, "jovenes": 8, "clase_media": 5, "rel_democracias": 12, "regimen": {"lealtad": -18, "transicion": true}}, "news": "La Junta anuncia elecciones libres: comienza la transición democrática"},
		],
	},
}

## Países democráticos (a los que les molestan la represión y la censura)
const DEMOCRACIAS := ["valdoria", "norland", "union", "aldora"]
