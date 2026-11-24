extends RefCounted
## Recursos del mercado mundial y lo que produce y consume cada país.
##
## PERFILES: saldo de cada recurso en «unidades» (+ exporta, − importa). Una unidad, con el precio un 100 % por
## encima de lo normal, mueve un 0,4 % del PIB mensual: así un país que importa mucho gas sufre de verdad cuando
## el gas se dispara, y uno que lo vende se forra.
##
## ARMAS: el recurso que cada país puede cortar a quien se lo compra (si la relación se hunde).

const RECURSOS := {
	"gas": {"name": "Gas", "icon": "rayo", "desc": "Calefacción, electricidad e industria. Sube en invierno."},
	"petroleo": {"name": "Petróleo", "icon": "rayo", "desc": "Transporte, plásticos y fertilizantes."},
	"alimentos": {"name": "Alimentos", "icon": "sol", "desc": "Cereal, carne, fruta. Lo primero que nota la cesta de la compra."},
	"industria": {"name": "Industria", "icon": "fabrica", "desc": "Maquinaria, coches, bienes de consumo."},
	"tecnologia": {"name": "Tecnología", "icon": "movil", "desc": "Chips, software y patentes."},
	"minerales": {"name": "Minerales", "icon": "fabrica", "desc": "Litio, cobalto y tierras raras para baterías."},
}

## Recursos que llegan a los precios del súper y de la luz (empujan la inflación de quien los compra)
const BASICOS := ["gas", "petroleo", "alimentos"]

const PERFILES := {
	"valdoria": {"gas": -3, "petroleo": -3, "alimentos": 3, "industria": 0, "tecnologia": -1, "minerales": -1},
	"norland": {"gas": 2, "petroleo": 1, "alimentos": 2, "industria": -1, "tecnologia": 4, "minerales": -1},
	"union": {"gas": -4, "petroleo": -3, "alimentos": 1, "industria": 2, "tecnologia": 2, "minerales": -2},
	"kharovia": {"gas": 6, "petroleo": 3, "alimentos": 1, "industria": -2, "tecnologia": -3, "minerales": 1},
	"tsaing": {"gas": -2, "petroleo": -4, "alimentos": -2, "industria": 6, "tecnologia": 2, "minerales": -2},
	"qadar": {"gas": 2, "petroleo": 6, "alimentos": -4, "industria": -2, "tecnologia": -2, "minerales": 0},
	"sarvenia": {"gas": -1, "petroleo": -1, "alimentos": -1, "industria": -1, "tecnologia": -1, "minerales": 0},
	"aldora": {"gas": 0, "petroleo": 0, "alimentos": -1, "industria": -2, "tecnologia": -2, "minerales": 5},
}

## Ventaja y punto débil de cada país (se ven en el mapa del mundo)
const VENTAJAS := {
	"valdoria": ["Turismo, campo y fondos de la Unión", "Importa casi toda su energía"],
	"norland": ["Finanzas, tecnología y el ejército más fuerte", "Depende de fábricas ajenas"],
	"union": ["Mercado enorme e industria", "Sin gas ni petróleo propios"],
	"kharovia": ["Gas y petróleo para medio mundo", "Sin tecnología propia"],
	"tsaing": ["La fábrica del mundo", "Necesita petróleo y comida de fuera"],
	"qadar": ["Petróleo y un fondo soberano gigante", "Importa casi toda su comida"],
	"sarvenia": ["Ejército y el nacimiento del río Seco", "Economía pequeña y aislada"],
	"aldora": ["Minerales para baterías y el estrecho", "Pobreza e instituciones frágiles"],
}

## El recurso que cada país puede cortar. Sarvenia no corta un recurso del mercado: corta el agua del río Seco,
## y solo a Valdoria, que está río abajo.
const ARMAS := {
	"kharovia": "gas",
	"qadar": "petroleo",
	"tsaing": "industria",
	"aldora": "minerales",
	"norland": "tecnologia",
	"sarvenia": "agua",
}

## Sacudidas del mercado mundial (sin que nadie las provoque): recurso, cambio del precio y titular
const SACUDIDAS := [
	["petroleo", 0.28, "Un huracán cierra las refinerías del golfo: el petróleo se dispara"],
	["petroleo", -0.22, "Guerra de precios entre productores: el petróleo se desploma"],
	["gas", 0.3, "Ola de frío en medio mundo: el gas, por las nubes"],
	["gas", -0.18, "Inviernos suaves y almacenes llenos: el gas se abarata"],
	["alimentos", 0.25, "Sequía en los graneros del mundo: suben el trigo y el maíz"],
	["alimentos", -0.15, "Cosechas récord: bajan los precios de los alimentos"],
	["tecnologia", 0.2, "Escasez mundial de chips: los fabricantes paran líneas"],
	["minerales", 0.3, "Fiebre de las baterías: el litio vale oro"],
	["industria", -0.12, "Exceso de fábricas en Tsaing: los productos industriales, de saldo"],
]


# ================================================================== producción (versión 5.1)
## Cada país produce y consume cada recurso. Producción de partida = consumo + saldo del perfil (lo que le sobra
## para vender o le falta y compra fuera). El jugador decide cuánto produce, cómo (el método) y si amplía la
## capacidad; y a quién vende, a qué precio y cuánto, con contratos negociados (ver systems/negociacion.gd).

## Consumo propio de cada país (unidades al mes)
const CONSUMO := {
	"valdoria": {"gas": 3.5, "petroleo": 3.5, "alimentos": 3.0, "industria": 3.0, "tecnologia": 2.0, "minerales": 1.5},
	"norland": {"gas": 5.0, "petroleo": 6.0, "alimentos": 4.0, "industria": 6.0, "tecnologia": 4.0, "minerales": 2.5},
	"union": {"gas": 6.0, "petroleo": 6.0, "alimentos": 5.0, "industria": 6.0, "tecnologia": 4.0, "minerales": 3.0},
	"kharovia": {"gas": 3.0, "petroleo": 2.0, "alimentos": 2.5, "industria": 3.0, "tecnologia": 3.0, "minerales": 1.0},
	"tsaing": {"gas": 4.0, "petroleo": 6.0, "alimentos": 6.0, "industria": 4.0, "tecnologia": 3.0, "minerales": 4.0},
	"qadar": {"gas": 1.5, "petroleo": 1.5, "alimentos": 4.5, "industria": 2.5, "tecnologia": 2.0, "minerales": 0.5},
	"sarvenia": {"gas": 1.5, "petroleo": 1.5, "alimentos": 2.0, "industria": 1.5, "tecnologia": 1.0, "minerales": 0.5},
	"aldora": {"gas": 0.5, "petroleo": 0.5, "alimentos": 2.5, "industria": 2.5, "tecnologia": 2.0, "minerales": 0.5},
}

## Hasta dónde puede llegar la capacidad de cada país invirtiendo: yacimientos de gas, petróleo y minerales, y
## tierra cultivable. Industria y tecnología se pueden levantar en cualquier sitio (hasta producción + TECHO_LIBRE),
## pero las obras cuestan más.
const TECHO := {
	"valdoria": {"gas": 1.5, "petroleo": 1.0, "alimentos": 8.5, "minerales": 1.5},
	"norland": {"gas": 9.5, "petroleo": 9.5, "alimentos": 8.0, "minerales": 3.0},
	"union": {"gas": 3.0, "petroleo": 4.0, "alimentos": 8.0, "minerales": 2.0},
	"kharovia": {"gas": 13.0, "petroleo": 8.0, "alimentos": 5.0, "minerales": 3.0},
	"tsaing": {"gas": 3.0, "petroleo": 3.0, "alimentos": 5.5, "minerales": 4.0},
	"qadar": {"gas": 6.0, "petroleo": 11.0, "alimentos": 1.0, "minerales": 1.0},
	"sarvenia": {"gas": 1.0, "petroleo": 1.0, "alimentos": 3.0, "minerales": 1.5},
	"aldora": {"gas": 1.5, "petroleo": 1.5, "alimentos": 4.0, "minerales": 9.0},
}
const TECHO_LIBRE := 5.0

## Cuánto se puede subir o bajar la producción en un mes (unidades): las minas y los pozos no se abren de golpe
const RITMO_SUBIR := 1.0
const RITMO_BAJAR := 2.0

## Ampliar la capacidad en una unidad: coste (M) y meses de obra
const OBRAS := {
	"gas": [2600.0, 8], "petroleo": [3000.0, 9], "alimentos": [1100.0, 5],
	"industria": [2200.0, 7], "tecnologia": [3200.0, 10], "minerales": [2300.0, 8],
}

## Actividad que da producir una unidad más de lo normal (empleo y economía)
const EMPLEO := {"gas": 0.3, "petroleo": 0.3, "alimentos": 0.5, "industria": 0.9, "tecnologia": 0.8, "minerales": 0.45}

## Cómo se produce cada recurso. coste: lo que cuesta producir una unidad (100 = el precio normal del mercado);
## cap: multiplica el techo (el fracking saca gas donde antes no se podía); prima: se vende más caro (+%);
## fx: efecto en los medidores y grupos por unidad producida (frente al método habitual); riesgo: probabilidad al
## mes por unidad de un accidente, con su titular y sus efectos; usa: lo que consume de otro recurso por unidad;
## vaiven: cuánto puede variar lo que sale cada mes.
const METODOS := {
	"gas": {
		"convencional": {"name": "Pozos convencionales", "desc": "Lo de siempre: pozos y gasoductos.", "coste": 45.0, "cap": 1.0, "fx": {}},
		"fracking": {"name": "Fracturación hidráulica", "desc": "Saca gas de rocas donde antes no se podía. Barato de ampliar, pero contamina acuíferos y hay pequeños terremotos.", "coste": 58.0, "cap": 1.5,
			"fx": {"ambiente": -0.45, "jovenes": -0.15}, "riesgo": [0.012, "Pequeños terremotos y agua contaminada junto a los pozos de fracking", {"ambiente": -2, "approval": -0.5}]},
		"biogas": {"name": "Biogás y gas renovable", "desc": "Gas de residuos agrícolas y basura. Caro y limitado, pero limpio.", "coste": 82.0, "cap": 0.6,
			"fx": {"ambiente": 0.25, "trabajadores": 0.05}},
	},
	"petroleo": {
		"convencional": {"name": "Pozos en tierra", "desc": "Extracción clásica, sin sorpresas.", "coste": 40.0, "cap": 1.0, "fx": {}},
		"offshore": {"name": "Plataformas en alta mar", "desc": "Llega a yacimientos profundos. Un vertido puede salir carísimo.", "coste": 55.0, "cap": 1.4,
			"fx": {"ambiente": -0.15}, "riesgo": [0.008, "Vertido de crudo de una plataforma petrolífera en alta mar", {"ambiente": -4, "money": -700, "approval": -1}]},
		"arenas": {"name": "Arenas bituminosas", "desc": "Mucho petróleo donde parecía no haber, a costa del paisaje y del clima.", "coste": 68.0, "cap": 1.8,
			"fx": {"ambiente": -0.7, "jovenes": -0.2}},
	},
	"alimentos": {
		"familiar": {"name": "Campo familiar", "desc": "Explotaciones pequeñas: mucho empleo en los pueblos y paisaje cuidado.", "coste": 60.0, "cap": 0.9, "fx": {"trabajadores": 0.12, "ambiente": 0.05}},
		"intensiva": {"name": "Agricultura intensiva", "desc": "Grandes explotaciones, fertilizantes y regadío. Más barato, peor para la tierra.", "coste": 45.0, "cap": 1.2, "fx": {"ambiente": -0.3, "trabajadores": -0.05}, "usa": {"petroleo": 0.1}},
		"ecologica": {"name": "Agricultura ecológica", "desc": "Produce menos, pero se vende un 15 % más caro y cuida el campo.", "coste": 72.0, "cap": 0.75, "prima": 15.0, "fx": {"ambiente": 0.3, "jovenes": 0.1}},
		"invernadero": {"name": "Invernaderos y desaladoras", "desc": "Cultivar donde no llueve. Muy caro, pero no depende de la tierra.", "coste": 95.0, "cap": 2.5, "fx": {"ambiente": -0.1}, "usa": {"gas": 0.15}},
	},
	"industria": {
		"tradicional": {"name": "Fábricas de toda la vida", "desc": "Mucho empleo y algo de humo.", "coste": 60.0, "cap": 1.0, "fx": {"trabajadores": 0.15, "ambiente": -0.15}},
		"automatizada": {"name": "Fábricas robotizadas", "desc": "Más baratas, pero con menos empleo y necesitan tecnología.", "coste": 46.0, "cap": 1.2, "fx": {"trabajadores": -0.15, "empresarios": 0.15}, "usa": {"tecnologia": 0.25}},
		"maquila": {"name": "Zonas francas", "desc": "Sueldos bajos y pocos impuestos. Barato... y mala fama fuera.", "coste": 36.0, "cap": 1.1, "fx": {"trabajadores": -0.3, "empresarios": 0.2, "prestigio": -0.15}},
	},
	"tecnologia": {
		"publica": {"name": "Universidades y centros públicos", "desc": "Lento y caro, pero forma a los jóvenes.", "coste": 70.0, "cap": 1.0, "fx": {"jovenes": 0.15, "bienestar": 0.05}},
		"startups": {"name": "Empresas emergentes", "desc": "Capital riesgo y mucho ruido: unos meses se produce más y otros menos.", "coste": 55.0, "cap": 1.2, "fx": {"empresarios": 0.15, "jovenes": 0.05}, "vaiven": 0.25},
		"licencias": {"name": "Licencias extranjeras", "desc": "Fabricar con patentes de otros: barato, sin prestigio propio.", "coste": 50.0, "cap": 1.0, "fx": {"prestigio": -0.1}, "usa": {"minerales": 0.1}},
	},
	"minerales": {
		"industrial": {"name": "Minería industrial", "desc": "Grandes minas a cielo abierto.", "coste": 50.0, "cap": 1.0, "fx": {"ambiente": -0.1}},
		"artesanal": {"name": "Minería artesanal", "desc": "Barata y con mucha mano de obra... en condiciones terribles.", "coste": 34.0, "cap": 0.8, "fx": {"prestigio": -0.25, "trabajadores": -0.1, "ambiente": -0.2},
			"riesgo": [0.015, "Derrumbe en una mina artesanal: varios mineros atrapados", {"approval": -1, "prestigio": -2}]},
		"verde": {"name": "Minería responsable y reciclaje", "desc": "Recupera litio de baterías viejas y cuida el entorno. Cara.", "coste": 76.0, "cap": 0.8, "fx": {"ambiente": 0.2, "prestigio": 0.1}},
	},
}

## Método con el que empieza cada país (si no se dice, el primero de la lista)
const METODO_INICIAL := {
	"norland": {"gas": "fracking", "tecnologia": "startups"},
	"tsaing": {"industria": "automatizada", "alimentos": "intensiva"},
	"aldora": {"minerales": "artesanal"},
	"qadar": {"alimentos": "invernadero"},
	"kharovia": {"tecnologia": "licencias"},
}

## Lo que mueve el precio mundial que un país produzca una unidad más o menos: oferta del mundo entero (incluidos
## los países que no salen en el juego) y sensibilidad del precio
const MUNDO := {"gas": 50.0, "petroleo": 52.0, "alimentos": 57.0, "industria": 57.0, "tecnologia": 40.0, "minerales": 27.0}
const ELASTICIDAD := 2.0
