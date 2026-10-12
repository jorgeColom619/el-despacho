extends RefCounted
## Reto del día: cada día, la misma partida para todos (partido, escenario, mundo y promesas) con dos reglas especiales.
## Legislatura de un año en dificultad normal. Se guarda la mejor puntuación del día y la racha de días seguidos.

const RULES := {
	"congreso_hostil": {"name": "Congreso hostil", "desc": "Todos los grupos parlamentarios desconfían de usted: −15 de relación con cada uno.", "icon": "mazo"},
	"herencia": {"name": "Herencia envenenada", "desc": "El Gobierno anterior dejó un agujero: la deuda empieza 20 puntos más alta.", "icon": "dinero"},
	"sin_luna": {"name": "Sin luna de miel", "desc": "Nadie le da cien días de cortesía: todos los grupos sociales empiezan enfadados.", "icon": "corazon_roto"},
	"crisis_cadena": {"name": "Crisis en cadena", "desc": "Las crisis llegan antes y más a menudo.", "icon": "alerta"},
	"ministros_discolos": {"name": "Ministros díscolos", "desc": "Cada ministro tiene un defecto. Le tocará decidir a quién aguanta.", "icon": "empresarios"},
	"bonanza": {"name": "Viento de cola", "desc": "La economía arranca fuerte. Hoy es un día para lucirse... o para confiarse.", "icon": "economia"},
	"mundo_hostil": {"name": "Mundo hostil", "desc": "Las relaciones con todos los países empiezan 20 puntos más frías.", "icon": "bandera"},
	"plazos": {"name": "Plazos imposibles", "desc": "Documentos, visitas y crisis caducan tan rápido como en difícil.", "icon": "reloj"},
	"pc_cero": {"name": "Sin capital político", "desc": "Empieza casi sin capital político: cada ley costará el doble de esfuerzo.", "icon": "capital"},
	"anticipadas": {"name": "Elecciones anticipadas", "desc": "La legislatura dura solo nueve meses.", "icon": "votar"},
	"jovenes": {"name": "Jóvenes indignados", "desc": "Los jóvenes empiezan muy enfadados con el Gobierno.", "icon": "jovenes"},
	"jubilados": {"name": "Jubilados en pie de guerra", "desc": "Los jubilados empiezan muy enfadados con el Gobierno.", "icon": "jubilados"},
	"militares": {"name": "Cuarteles inquietos", "desc": "Las Fuerzas Armadas empiezan desconfiando del Gobierno.", "icon": "militares"},
	"empresarios": {"name": "Patronal en guerra", "desc": "Los empresarios empiezan muy enfadados con el Gobierno.", "icon": "empresarios"},
	"trabajadores": {"name": "Sindicatos en pie de guerra", "desc": "Los trabajadores empiezan muy enfadados con el Gobierno.", "icon": "trabajadores"},
	"sobres": {"name": "Cadáveres en el armario", "desc": "Hereda corrupción acumulada: los escándalos saldrán antes o después.", "icon": "ojo"},
	"prima": {"name": "Mercados nerviosos", "desc": "La deuda se paga a un interés más alto todo el año.", "icon": "grafico"},
	"sequia": {"name": "Año de sequía", "desc": "Los embalses están vacíos: medio ambiente y campo empiezan muy tocados.", "icon": "agua"},
	"promesas_duras": {"name": "Programa ambicioso", "desc": "Sus tres promesas son de objetivo, y no son fáciles.", "icon": "pluma"},
	"meme": {"name": "Día del meme", "desc": "Hoy se juega en modo meme: política de chiste.", "icon": "sonrisa"},
}

## Reglas que no se mezclan entre sí
const CLASH := [["bonanza", "herencia"], ["bonanza", "sequia"], ["anticipadas", "crisis_cadena"], ["meme", "promesas_duras"],
	["jovenes", "jubilados"], ["empresarios", "trabajadores"], ["pc_cero", "congreso_hostil"]]

const NAMES := ["Alejandro Ríos", "Lucía Herrera", "Martín Salcedo", "Clara Vidal", "Andrés Molina", "Elena Robledo", "Sergio Cano", "Irene Pascual"]
