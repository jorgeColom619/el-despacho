extends RefCounted
## Reglas para entender lo que el presidente escribe con sus propias palabras (sin IA, sin internet).
## Todo se compara en minúsculas y sin tildes. Cada intención tiene palabras y frases que la delatan.
## Para añadir vocabulario basta con ampliar estas listas. (Si algún día se conecta una IA, estas reglas
## seguirán sirviendo cuando no haya conexión: ver scripts/systems/interprete.gd)

const INTENTS := {
	"aceptar": ["si", "vale", "de acuerdo", "adelante", "hagalo", "hazlo", "haganlo", "aprobado", "apruebo", "acepto", "aceptamos",
		"perfecto", "claro", "por supuesto", "ok", "okay", "venga", "dale", "procede", "proceda", "autorizo", "firmo", "me parece bien",
		"me parece buena idea", "buena idea", "luz verde", "sin problema", "que se haga", "hagamoslo", "tiramos", "a por ello", "manos a la obra"],
	"rechazar": ["no", "ni hablar", "jamas", "nunca", "rechazo", "me niego", "de ninguna manera", "olvidalo", "olvidelo", "ni de broma",
		"imposible", "denegado", "deniego", "ni en suenos", "ni loco", "ni muerto", "fuera de la mesa", "no me da la gana", "ni de cona",
		"para nada", "en absoluto", "descartado", "no pienso"],
	"negociar": ["negociar", "negociemos", "a cambio", "y si", "propongo", "ofrezco", "contraoferta", "termino medio", "punto medio",
		"la mitad", "mitad", "rebaja", "condicion", "siempre que", "solo si", "con la condicion", "pacto", "pactar", "algo intermedio", "intermedia"],
	"aplazar": ["luego", "mas tarde", "manana", "esperar", "esperemos", "espera", "pensarlo", "lo pienso", "dejame pensar", "deme tiempo",
		"dame tiempo", "estudiar", "estudiemos", "aplazar", "aplazo", "no hay prisa", "dejalo para", "ya veremos", "otro dia", "la semana que viene",
		"ahora no", "mas adelante", "lo hablamos", "vuelva", "vuelve"],
	"delegar": ["que lo decida", "encargate", "encarguese", "decide tu", "decida usted", "usted decide", "lo que tu veas", "lo que usted vea",
		"confio en ti", "confio en usted", "delego", "tu criterio", "su criterio", "lo que considere", "lo que consideres", "elige tu", "elija usted",
		"lo dejo en sus manos", "lo dejo en tus manos", "haga lo que crea", "haz lo que creas"],
	"investigar": ["investigar", "investiguen", "investigad", "averiguar", "averigue", "quiero datos", "mas datos", "un informe", "informe",
		"pruebas", "auditoria", "auditar", "comprobar", "comprueben", "verificar", "quiero saber", "quien es el responsable", "que me expliquen"],
	"dinero": ["dinero", "pagar", "pagamos", "financiar", "fondos", "subvencion", "subvencionar", "ayudas", "ayuda economica", "invertir",
		"inversion", "presupuesto", "rescatar", "rescate", "millones", "euros", "partida", "dotar"],
	"ahorrar": ["recortar", "recorte", "ahorrar", "ahorro", "austeridad", "sin gastar", "gratis", "cero euros", "barato", "que no cueste",
		"no hay dinero", "no tenemos dinero", "las cuentas"],
	"fuerza": ["mano dura", "policia", "ejercito", "militares", "detener", "detengan", "sancionar", "sancion", "multar", "multa", "castigar",
		"castigo", "expulsar", "prohibir", "prohibicion", "cerrar", "cierre", "intervenir", "contundencia", "firmeza", "orden publico"],
	"dialogo": ["dialogo", "dialogar", "hablar", "hablemos", "reunion", "reunirme", "reunamonos", "escuchar", "escucharles", "sentarnos",
		"mesa", "convocar", "convoca", "llamar", "llamale", "llamelo", "mediador", "mediacion", "consenso", "entre todos"],
	"comunicar": ["rueda de prensa", "comunicado", "explicar", "explicarlo", "transparencia", "transparente", "decirlo", "contarlo", "publicar",
		"anunciar", "anuncio", "la verdad", "que se sepa", "dar la cara", "comparecer", "comparecencia", "salir en la tele", "a la prensa"],
	"ocultar": ["ocultar", "tapar", "taparlo", "que no se sepa", "discrecion", "discreto", "secreto", "en silencio", "callar", "callarlo",
		"off the record", "debajo de la alfombra", "que nadie se entere", "borrar", "destruir"],
	"pasivo": ["no hacer nada", "no hacemos nada", "no haremos nada", "dejarlo estar", "dejadlo estar", "que siga igual", "no mover un dedo",
		"ni caso", "ignorarlo", "ignorar", "no tocar nada", "dejarlo como esta", "que pase", "dejar pasar"],
	"humor": ["jaja", "jajaja", "jeje", "broma", "chiste", "lol", "xd", "jiji", "es coña", "de cachondeo"],
	"insulto": ["idiota", "imbecil", "inutil", "estupido", "estupida", "tonto", "tonta", "payaso", "payasa", "callate", "cállese", "pesado",
		"pesada", "incompetente", "vete a la", "largo de aqui", "fuera de mi despacho", "que te den"],
	"corrupcion": ["sobres", "un sobre", "comision para mi", "para mi bolsillo", "mi cunado", "mi amigo", "a dedo", "enchufe", "enchufar",
		"mordida", "soborno", "untar", "bajo cuerda", "en negro", "una comision", "algo para mi", "que me paguen"],
	"elogio": ["gracias", "buen trabajo", "bien hecho", "enhorabuena", "excelente", "magnifico", "estupendo", "genial", "bravo", "felicidades"],
	"cortesia": ["por favor", "porfavor", "si es tan amable", "le agradeceria", "te agradeceria", "disculpe", "perdone", "le ruego"],
}

## Palabras que no ayudan a comparar textos
const STOP := ["el", "la", "los", "las", "un", "una", "unos", "unas", "de", "del", "al", "a", "en", "y", "e", "o", "u", "que", "se",
	"lo", "le", "les", "me", "te", "nos", "os", "su", "sus", "mi", "mis", "tu", "tus", "es", "son", "por", "para", "con", "sin",
	"como", "mas", "muy", "ya", "pero", "este", "esta", "esto", "eso", "esa", "ese", "presidente", "senor", "senora", "usted", "vamos",
	"hay", "hacer", "haga", "haz", "podemos", "puede", "pueden", "quiero", "queremos", "pienso", "creo", "debemos", "tenemos", "tiene",
	"seria", "sea", "algo", "todo", "todos", "otro", "otra", "bien", "mal", "asi", "ahora", "aqui", "eso", "vez", "cosa", "cosas", "ministro", "ministra"]

## Palabras que niegan lo que viene detrás («no rescatar», «sin gastar», «nada de recortes»)
const NEGATORS := ["no", "nunca", "jamas", "ni", "sin", "nada", "nadie", "tampoco", "evitar", "evitemos", "dejemos de"]
## Lo que corta el alcance de una negación
const SCOPE_END := ["pero", "sino", "aunque", "y", "mejor", "porque"]

## Sinónimos: cualquier palabra de un grupo cuenta como la misma idea al comparar con las opciones
const SYN := [
	["quiebra", "quiebre", "quebrar", "caer", "caiga", "cae", "hundir", "hunda", "dejarlo", "dejarla"],
	["rescate", "rescatar", "rescatarlo", "rescatarla", "rescatala", "rescatalo", "salvar", "salvarlo", "salvarla", "salve", "salva", "rescaten"],
	["vender", "venta", "venderla", "venderlo", "comprador", "compradores", "compre", "comprar", "subasta"],
	["despedir", "despido", "echar", "echarle", "cesar", "cese", "destituir", "fuera"],
	["pagar", "pague", "dinero", "gastar", "gasto", "financiar", "fondos", "millones", "euros", "publico", "subvencion"],
	["negociar", "negocie", "negociemos", "dialogo", "dialogar", "hablar", "hablemos", "acuerdo", "pactar", "pacto", "reunion"],
	["nacionalizar", "nacionalizarlo", "nacionalizarla", "estatal", "estado", "publica"],
	["prohibir", "prohibirlo", "prohibicion", "vetar", "veto", "impedir"],
	["aprobar", "apruebo", "aprobarlo", "firmar", "firmo", "firmarlo", "sancionar", "promulgar"],
	["ayudar", "ayuda", "ayudas", "apoyar", "apoyo", "socorrer"],
	["policia", "agentes", "antidisturbios", "guardia", "seguridad"],
	["ejercito", "militares", "tropas", "soldados", "defensa"],
	["investigar", "investigacion", "comision", "auditoria", "informe"],
	["esperar", "esperemos", "aguantar", "aplazar", "tiempo"],
	["fusion", "fusionar", "fusionarlo", "unir", "absorber"],
	["empleo", "empleos", "trabajo", "trabajadores", "puestos", "plantilla"],
]

## Opción concreta por posición: «la primera», «opción 2», «la última»
const ORDINALS := {"primera": 0, "primero": 0, "uno": 0, "1": 0, "segunda": 1, "segundo": 1, "dos": 1, "2": 1,
	"tercera": 2, "tercero": 2, "tres": 2, "3": 2, "cuarta": 3, "cuarto": 3, "cuatro": 3, "4": 3}

## Lo que responde el visitante según lo que ha entendido
const REPLIES := {
	"elige": ["Entendido, presidente. Lo hacemos así.", "Clarísimo. Me pongo con ello.", "Así se hará, presidente.", "Hecho. Lo comunico de inmediato."],
	"elige_amable": ["Gracias por la confianza, presidente. Así se hará.", "Con mucho gusto. Me pongo ahora mismo."],
	"elige_brusco": ["...Entendido. No hacía falta el tono, pero lo haremos.", "Como usted diga. Aunque así no se habla a un ministro."],
	"aplazar": ["De acuerdo, lo pensamos. Pero no tarde: volveré en unos días.", "Le dejo el expediente. Vuelvo en unos días a por la respuesta."],
	"investigar": ["Pido un informe completo y vuelvo en unos días con datos.", "Bien visto. Encargo la investigación y le traigo resultados."],
	"delegar": ["Gracias por la confianza. Haré lo que creo mejor.", "Muy bien. Decido yo y asumo la responsabilidad."],
	"humor": ["Ja... Muy bueno, presidente. ¿Y qué hacemos?", "Me alegra verle de buen humor. Pero necesito una respuesta."],
	"insulto": ["Con todo el respeto, presidente: no tengo por qué aguantar esto. Decidiré yo.", "...Haré como que no lo he oído. Me voy, y decido yo."],
	"corrupcion": ["Haré como que no he oído eso. Pero tomo nota.", "...Entendido. Nadie sabrá nada. De momento."],
	"no_entiendo": ["Perdone, presidente, no le he entendido. ¿Cuál de las opciones prefiere?", "No sé si le sigo. ¿Me lo puede decir de otra manera?"],
}
