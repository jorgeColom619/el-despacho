extends RefCounted
## Promesas electorales. Se eligen hasta tres al empezar la partida (de seis que se ofrecen, distintas cada vez).
## Tipos:
##   nunca · «Nunca haré X»: se rompe en cuanto pasa X (subir un impuesto, recortar una partida, aprobar una ley...)
##   meta  · «Conseguiré X»: se juzga al empezar la campaña electoral
## Comprobaciones (check):
##   tax_up: [impuestos]          · se rompe si alguno sube por encima del valor del primer día
##   tax_down: {impuesto: puntos} · meta: bajarlo al menos esos puntos
##   budget_cut: [partidas]       · se rompe si alguna baja de su nivel del primer día
##   budget_up: {partida: nivel}  · meta: llegar a ese nivel de gasto
##   law: id                      · nunca: se rompe si se aprueba · meta: aprobarla
##   counter: clave               · se rompe si sube el contador (ceses, indultos, escándalos)
##   gt / lt: {valor: umbral}     · meta: superar / no superar el umbral
##   debt_drop: puntos            · meta: deuda (% PIB) al menos esos puntos por debajo de la inicial
##   laws_n: n                    · meta: n leyes aprobadas (se ajusta a la duración de la legislatura)
##   treaties_n: n                · meta: n tratados
## any: lista de comprobaciones alternativas (basta con una)
## ideo: ideología de la promesa (-100 izquierda .. 100 derecha): las afines a su partido salen más
## fx: lo que gana nada más prometerlo · groups: a quién le importa (lo que se pierde si la rompe)

const PROMISES := {
	# ------------------------------------------------------------------ «nunca»
	"no_iva": {"name": "No subiré el IVA", "kind": "nunca", "icon": "dinero", "ideo": -10.0,
		"desc": "El impuesto que pagan todos en la caja del súper no subirá ni un punto.",
		"check": {"tax_up": ["iva"]}, "fx": {"trabajadores": 2, "clase_media": 1}, "groups": ["trabajadores", "clase_media"]},
	"no_irpf": {"name": "No subiré el IRPF", "kind": "nunca", "icon": "dinero", "ideo": 20.0,
		"desc": "Ni un punto más de impuesto sobre la renta en toda la legislatura.",
		"check": {"tax_up": ["renta"]}, "fx": {"clase_media": 2, "empresarios": 1}, "groups": ["clase_media"]},
	"no_impuestos": {"name": "No subiré ningún impuesto", "kind": "nunca", "icon": "dinero", "ideo": 35.0,
		"desc": "Ni IVA, ni IRPF, ni Sociedades. La promesa más ambiciosa y la más fácil de romper.",
		"check": {"tax_up": ["iva", "renta", "sociedades"]}, "fx": {"clase_media": 3, "empresarios": 3}, "groups": ["clase_media", "empresarios"]},
	"no_sociedades": {"name": "Las empresas no pagarán más", "kind": "nunca", "icon": "empresarios", "ideo": 45.0,
		"desc": "El Impuesto de Sociedades no subirá: estabilidad para quien invierte.",
		"check": {"tax_up": ["sociedades"]}, "fx": {"empresarios": 3}, "groups": ["empresarios"]},
	"no_recorte_sanidad": {"name": "Ni un euro menos para la sanidad", "kind": "nunca", "icon": "hospital", "ideo": -20.0,
		"desc": "El presupuesto de Sanidad nunca bajará del que encontré.",
		"check": {"budget_cut": ["sanidad"]}, "fx": {"jubilados": 2, "trabajadores": 1}, "groups": ["jubilados", "trabajadores"]},
	"no_recorte_educacion": {"name": "La educación no se toca", "kind": "nunca", "icon": "jovenes", "ideo": -20.0,
		"desc": "Ni recortes en colegios ni en universidades.",
		"check": {"budget_cut": ["educacion"]}, "fx": {"jovenes": 2, "clase_media": 1}, "groups": ["jovenes", "clase_media"]},
	"no_recorte_pensiones": {"name": "Las pensiones no se tocan", "kind": "nunca", "icon": "jubilados", "ideo": -5.0,
		"desc": "Ni recortes en las pensiones ni retrasar la edad de jubilación.",
		"check": {"any": [{"budget_cut": ["pensiones"]}, {"law": "pensiones_edad"}]}, "fx": {"jubilados": 3}, "groups": ["jubilados"]},
	"no_recorte_social": {"name": "Nadie se quedará atrás", "kind": "nunca", "icon": "clase_media", "ideo": -35.0,
		"desc": "El gasto en vivienda y servicios sociales no bajará.",
		"check": {"budget_cut": ["social"]}, "fx": {"trabajadores": 2, "jovenes": 1}, "groups": ["trabajadores", "jovenes"]},
	"no_recorte_defensa": {"name": "Nuestras Fuerzas Armadas no sufrirán recortes", "kind": "nunca", "icon": "militares", "ideo": 45.0,
		"desc": "El presupuesto de Defensa se mantendrá o crecerá.",
		"check": {"budget_cut": ["defensa"]}, "fx": {"militares": 4}, "groups": ["militares"]},
	"no_amnistia": {"name": "Jamás habrá una amnistía fiscal", "kind": "nunca", "icon": "candado", "ideo": -10.0,
		"desc": "Quien defraude pagará. Sin perdones a los evasores.",
		"check": {"law": "amnistia_fiscal"}, "fx": {"trabajadores": 1, "clase_media": 2}, "groups": ["clase_media", "trabajadores"]},
	"no_mili": {"name": "No volverá la mili", "kind": "nunca", "icon": "militares", "ideo": -25.0,
		"desc": "Ningún joven será obligado a hacer el servicio militar.",
		"check": {"law": "mili"}, "fx": {"jovenes": 3}, "groups": ["jovenes"]},
	"no_privatizar": {"name": "Lo público no se vende", "kind": "nunca", "icon": "trabajadores", "ideo": -45.0,
		"desc": "Correos, la aerolínea y las loterías seguirán siendo de todos.",
		"check": {"law": "privatizar"}, "fx": {"trabajadores": 3}, "groups": ["trabajadores"]},
	"no_medios": {"name": "Nunca tocaré la libertad de prensa", "kind": "nunca", "icon": "prensa", "ideo": 0.0,
		"desc": "Ningún consejo del Gobierno decidirá qué es verdad.",
		"check": {"law": "ley_medios"}, "fx": {"jovenes": 1, "clase_media": 2}, "groups": ["jovenes", "clase_media"]},
	"no_ceses": {"name": "Un Gobierno estable: no cesaré a nadie", "kind": "nunca", "icon": "estabilidad", "ideo": 10.0,
		"desc": "Mis ministros acabarán la legislatura conmigo. Sin crisis de Gobierno.",
		"check": {"counter": "ceses"}, "fx": {"estabilidad": 3}, "groups": ["clase_media"]},
	"no_indultos": {"name": "No firmaré ni un solo indulto", "kind": "nunca", "icon": "mazo", "ideo": 30.0,
		"desc": "La justicia es para todos: ningún condenado saldrá por mi firma.",
		"check": {"counter": "indultos"}, "fx": {"clase_media": 2, "jubilados": 1}, "groups": ["clase_media", "jubilados"]},
	"no_escandalos": {"name": "Tolerancia cero con la corrupción", "kind": "nunca", "icon": "ojo", "ideo": 0.0,
		"desc": "Si estalla un solo escándalo en mi Gobierno, habré fallado.",
		"check": {"counter": "escandalos"}, "fx": {"clase_media": 2, "jovenes": 2}, "groups": ["clase_media", "jovenes"]},
	"no_mandato": {"name": "No me aferraré al sillón", "kind": "nunca", "icon": "candado", "ideo": 0.0,
		"desc": "Ni reformas para alargar mi mandato ni elecciones aplazadas.",
		"check": {"law": "ampliar_mandato"}, "fx": {"estabilidad": 2}, "groups": ["clase_media"]},
	# ------------------------------------------------------------------ «meta»
	"paro": {"name": "Bajaré el paro por debajo del 9 %", "kind": "meta", "icon": "trabajadores", "ideo": 0.0,
		"desc": "Al llegar la campaña, el paro tendrá que estar por debajo del 9 %. Hará falta una economía fuerte.",
		"check": {"lt": {"paro": 9.0}}, "fx": {"trabajadores": 2, "jovenes": 1}, "groups": ["trabajadores", "jovenes"]},
	"deuda": {"name": "Reduciré la deuda", "kind": "meta", "icon": "grafico", "ideo": 30.0,
		"desc": "Al llegar la campaña, la deuda tendrá que estar al menos 4 puntos por debajo de la que encontré.",
		"check": {"debt_drop": 4.0}, "fx": {"empresarios": 2, "jubilados": 1}, "groups": ["empresarios", "clase_media"]},
	"vivienda": {"name": "Aprobaré la Ley de Vivienda", "kind": "meta", "icon": "clase_media", "ideo": -30.0,
		"desc": "Topes al alquiler y vivienda pública antes de que acabe la legislatura.",
		"check": {"law": "vivienda"}, "fx": {"jovenes": 3}, "groups": ["jovenes"]},
	"rebaja": {"name": "Bajaré los impuestos", "kind": "meta", "icon": "dinero", "ideo": 40.0,
		"desc": "Una rebaja general o, al menos, dos puntos menos de IRPF.",
		"check": {"any": [{"law": "rebaja_fiscal"}, {"tax_down": {"renta": 2.0}}]}, "fx": {"clase_media": 2, "empresarios": 2}, "groups": ["clase_media", "empresarios"]},
	"subir_pensiones": {"name": "Subiré las pensiones", "kind": "meta", "icon": "jubilados", "ideo": -15.0,
		"desc": "Revalorización por ley o un 10 % más de gasto en pensiones.",
		"check": {"any": [{"law": "pensiones_subida"}, {"budget_up": {"pensiones": 1.1}}]}, "fx": {"jubilados": 3}, "groups": ["jubilados"]},
	"verde": {"name": "Valdoria será un país verde", "kind": "meta", "icon": "ambiente", "ideo": -30.0,
		"desc": "Pacto por la Transición Verde o un medio ambiente por encima de 60.",
		"check": {"any": [{"law": "transicion_verde"}, {"gt": {"ambiente": 60.0}}]}, "fx": {"jovenes": 3}, "groups": ["jovenes"]},
	"calles": {"name": "Unas calles más seguras", "kind": "meta", "icon": "policia", "ideo": 35.0,
		"desc": "La seguridad tendrá que estar por encima de 65 al llegar la campaña.",
		"check": {"gt": {"seguridad": 65.0}}, "fx": {"jubilados": 2, "clase_media": 1}, "groups": ["jubilados", "clase_media"]},
	"sanidad": {"name": "La mejor sanidad de nuestra historia", "kind": "meta", "icon": "hospital", "ideo": -20.0,
		"desc": "El bienestar tendrá que estar por encima de 65 al llegar la campaña.",
		"check": {"gt": {"bienestar": 65.0}}, "fx": {"jubilados": 2, "trabajadores": 1}, "groups": ["jubilados", "trabajadores"]},
	"reformas": {"name": "Haré las grandes reformas", "kind": "meta", "icon": "ley", "ideo": 0.0,
		"desc": "Varias leyes aprobadas antes de la campaña: dos en una legislatura de un año, tres en una de dos y cinco en una de cuatro.",
		"check": {"laws_n": 2}, "fx": {"pc": 4, "estabilidad": 1}, "groups": ["clase_media"]},
	"mundo": {"name": "Pondré a Valdoria en el mapa", "kind": "meta", "icon": "bandera", "ideo": 10.0,
		"desc": "Tres tratados internacionales o un prestigio por encima de 65.",
		"check": {"any": [{"treaties_n": 3}, {"gt": {"prestigio": 65.0}}]}, "fx": {"prestigio": 2, "empresarios": 1}, "groups": ["empresarios", "militares"]},
	"economia": {"name": "Una economía de récord", "kind": "meta", "icon": "economia", "ideo": 25.0,
		"desc": "La economía tendrá que estar por encima de 65 al llegar la campaña.",
		"check": {"gt": {"economia": 65.0}}, "fx": {"empresarios": 2, "clase_media": 1}, "groups": ["empresarios", "clase_media"]},
	"jovenes": {"name": "Un país para los jóvenes", "kind": "meta", "icon": "jovenes", "ideo": -15.0,
		"desc": "Los jóvenes tendrán que valorarle por encima de 60 al llegar la campaña.",
		"check": {"gt": {"jovenes": 60.0}}, "fx": {"jovenes": 2}, "groups": ["jovenes"]},
	"transparencia": {"name": "Aprobaré una Ley de Transparencia", "kind": "meta", "icon": "ojo", "ideo": 0.0,
		"desc": "Agenda pública de los altos cargos y registro de lobbies.",
		"check": {"law": "transparencia"}, "fx": {"clase_media": 2, "jovenes": 1}, "groups": ["clase_media"]},
	"salario": {"name": "Subiré el salario mínimo", "kind": "meta", "icon": "trabajadores", "ideo": -40.0,
		"desc": "Una subida del salario mínimo aprobada por el Congreso.",
		"check": {"law": "salario_minimo"}, "fx": {"trabajadores": 3}, "groups": ["trabajadores"]},
	"reforma_laboral": {"name": "Haré la reforma laboral", "kind": "meta", "icon": "fabrica", "ideo": 45.0,
		"desc": "Contratos flexibles y menos trabas para contratar.",
		"check": {"law": "reforma_laboral"}, "fx": {"empresarios": 3}, "groups": ["empresarios"]},
	"mano_dura": {"name": "Mano dura contra el delito", "kind": "meta", "icon": "policia", "ideo": 50.0,
		"desc": "Una reforma penal o una ley de seguridad ciudadana aprobada.",
		"check": {"any": [{"law": "penal"}, {"law": "seguridad_ciudadana"}]}, "fx": {"jubilados": 2, "clase_media": 1}, "groups": ["jubilados"]},
	"cuatro_dias": {"name": "Trabajaremos cuatro días", "kind": "meta", "icon": "reloj", "ideo": -50.0,
		"desc": "La semana laboral de cuatro días, aprobada antes de las elecciones.",
		"check": {"law": "cuatro_dias"}, "fx": {"jovenes": 2, "trabajadores": 2}, "groups": ["jovenes", "trabajadores"]},
	"popular": {"name": "Gobernaré para todos", "kind": "meta", "icon": "aprobacion", "ideo": 0.0,
		"desc": "Llegar a la campaña con una aprobación por encima del 50 %.",
		"check": {"gt": {"approval": 50.0}}, "fx": {"estabilidad": 1, "clase_media": 1}, "groups": ["clase_media"]},
}

## En el modo meme hay alguna más... de las que nadie cumple
const PROMISES_MEME := {
	"meme_tortilla": {"name": "Zanjaré el debate de la tortilla", "kind": "meta", "icon": "sonrisa", "ideo": 0.0, "meme": true,
		"desc": "Con o sin cebolla, pero que el país deje de discutir. Tres leyes antes de la campaña cuentan como zanjarlo.",
		"check": {"laws_n": 2}, "fx": {"jubilados": 1, "jovenes": 1}, "groups": ["jubilados", "jovenes"]},
	"meme_wifi": {"name": "Wifi gratis hasta en el pueblo más pequeño", "kind": "meta", "icon": "tecnico", "ideo": 0.0, "meme": true,
		"desc": "Con el Plan de Digitalización aprobado, nadie volverá a buscar cobertura subido a una silla.",
		"check": {"law": "digitalizacion"}, "fx": {"jovenes": 3}, "groups": ["jovenes"]},
	"meme_siesta": {"name": "No tocaré la siesta", "kind": "nunca", "icon": "reloj", "ideo": 0.0, "meme": true,
		"desc": "Ni reformas laborales ni semanas raras: la siesta es sagrada.",
		"check": {"any": [{"law": "reforma_laboral"}, {"law": "cuatro_dias"}]}, "fx": {"jubilados": 2, "trabajadores": 1}, "groups": ["jubilados"]},
}

## Votos (puntos de intención de voto) por cada promesa al llegar la campaña
const VOTES_KEPT := 2.0
const VOTES_FAILED := -2.0
## Castigo inmediato al romper una promesa de «nunca»
const BROKEN_APPROVAL := -3.0
const BROKEN_GROUP := -4.0
