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
