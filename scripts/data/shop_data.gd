extends RefCounted
## Catálogo de la tienda: cosméticos, paquetes premium y logros.

const CURRENCY := "Laureles"
const PREMIUM := "Lingotes"

const SLOTS := {
	"bandera": "Bandera nacional",
	"despacho": "Estilo del despacho",
	"madera": "Madera del escritorio",
	"telefono": "Teléfono rojo",
	"globo": "Globo terráqueo",
	"lampara": "Lámpara",
	"traje": "Traje",
	"corbata": "Corbata",
	"accesorio": "Accesorio",
	"tinta": "Tinta de los sellos",
	"mascota": "Mascota",
}

const CATEGORIES := {
	"bandera": ["bandera"],
	"despacho": ["despacho", "madera", "telefono", "globo", "lampara"],
	"vestuario": ["traje", "corbata", "accesorio"],
	"sellos": ["tinta"],
	"mascotas": ["mascota"],
}

const CATEGORY_NAMES := {"bandera": "Banderas", "despacho": "Despacho", "vestuario": "Vestuario", "sellos": "Sellos", "mascotas": "Mascotas"}

const RARITY := {
	"comun": {"name": "Común", "color": "9aa4b5"},
	"raro": {"name": "Raro", "color": "4f8fe0"},
	"epico": {"name": "Épico", "color": "b06ef2"},
	"legendario": {"name": "Legendario", "color": "e5a93a"},
}

# price = laureles (0 = no se vende con laureles), premium = lingotes
const ITEMS := {
	# --- banderas
	"flag_clasica": {"slot": "bandera", "name": "Bandera de la República", "desc": "Azul marino y oro con la estrella de ocho puntas.", "rarity": "comun", "price": 0, "default": true, "data": {"style": "clasica"}},
	"flag_aurora": {"slot": "bandera", "name": "Bandera Aurora", "desc": "Verde bosque y blanco con el sol naciente dorado.", "rarity": "comun", "price": 120, "data": {"style": "aurora"}},
	"flag_carmesi": {"slot": "bandera", "name": "Bandera Carmesí", "desc": "Carmesí con franja dorada en diagonal y estrella.", "rarity": "raro", "price": 180, "data": {"style": "carmesi"}},
	"flag_marina": {"slot": "bandera", "name": "Bandera Marina", "desc": "Azul océano con ola blanca y tres estrellas.", "rarity": "raro", "price": 180, "data": {"style": "marina"}},
	"flag_imperial": {"slot": "bandera", "name": "Estandarte Imperial", "desc": "Negro y oro con corona de laurel.", "rarity": "epico", "price": 320, "data": {"style": "imperial"}},
	"flag_nocturna": {"slot": "bandera", "name": "Bandera Nocturna", "desc": "Medianoche con rosa de los vientos plateada.", "rarity": "legendario", "price": 0, "premium": 120, "data": {"style": "nocturna"}},
	# --- despacho
	"office_clasico": {"slot": "despacho", "name": "Despacho clásico", "desc": "Papel pintado verde, cortinas granate.", "rarity": "comun", "price": 0, "default": true, "data": {"theme": "clasico"}},
	"office_republicano": {"slot": "despacho", "name": "Despacho republicano", "desc": "Paredes azul marino y cortinas doradas.", "rarity": "raro", "price": 250, "data": {"theme": "republicano"}},
	"office_oval": {"slot": "despacho", "name": "Salón crema", "desc": "Paredes crema, alfombra azul y cortinas de oro viejo.", "rarity": "epico", "price": 400, "data": {"theme": "crema"}},
	"office_imperial": {"slot": "despacho", "name": "Salón imperial", "desc": "Rojo pompeyano, maderas oscuras y terciopelo negro.", "rarity": "epico", "price": 400, "data": {"theme": "imperial"}},
	"office_noche": {"slot": "despacho", "name": "Gabinete de medianoche", "desc": "Azul tinta, plata y cortinas de seda gris.", "rarity": "legendario", "price": 0, "premium": 150, "data": {"theme": "medianoche"}},
	"desk_caoba": {"slot": "madera", "name": "Caoba", "desc": "El escritorio de siempre.", "rarity": "comun", "price": 0, "default": true, "data": {"wood": "caoba"}},
	"desk_roble": {"slot": "madera", "name": "Roble claro", "desc": "Madera clara y luminosa.", "rarity": "comun", "price": 120, "data": {"wood": "roble"}},
	"desk_ebano": {"slot": "madera", "name": "Ébano", "desc": "Negro profundo y elegante.", "rarity": "raro", "price": 150, "data": {"wood": "ebano"}},
	"desk_marmol": {"slot": "madera", "name": "Mármol de Altamira", "desc": "Un escritorio de mármol blanco veteado.", "rarity": "legendario", "price": 0, "premium": 100, "data": {"wood": "marmol"}},
	"phone_rojo": {"slot": "telefono", "name": "Teléfono rojo", "desc": "La línea directa de siempre.", "rarity": "comun", "price": 0, "default": true, "data": {"phone": "rojo"}},
	"phone_oro": {"slot": "telefono", "name": "Teléfono de oro", "desc": "Para las crisis con estilo.", "rarity": "epico", "price": 220, "data": {"phone": "oro"}},
	"globe_antiguo": {"slot": "globo", "name": "Globo antiguo", "desc": "Pergamino y mares de cobre.", "rarity": "comun", "price": 0, "default": true, "data": {"globe": "antiguo"}},
	"globe_nocturno": {"slot": "globo", "name": "Globo nocturno", "desc": "Océanos oscuros y ciudades iluminadas.", "rarity": "raro", "price": 200, "data": {"globe": "nocturno"}},
	"lamp_verde": {"slot": "lampara", "name": "Lámpara de banquero", "desc": "Cristal verde clásico.", "rarity": "comun", "price": 0, "default": true, "data": {"lamp": "verde"}},
	"lamp_rubi": {"slot": "lampara", "name": "Lámpara rubí", "desc": "Cristal rojo intenso.", "rarity": "comun", "price": 90, "data": {"lamp": "rubi"}},
	"lamp_zafiro": {"slot": "lampara", "name": "Lámpara zafiro", "desc": "Cristal azul profundo.", "rarity": "raro", "price": 140, "data": {"lamp": "zafiro"}},
	# --- vestuario
	"suit_marino": {"slot": "traje", "name": "Traje azul marino", "desc": "El uniforme del poder.", "rarity": "comun", "price": 0, "default": true, "data": {"suit": "1b2436"}},
	"suit_negro": {"slot": "traje", "name": "Traje negro", "desc": "Serio y solemne.", "rarity": "comun", "price": 80, "data": {"suit": "15171b"}},
	"suit_gris": {"slot": "traje", "name": "Gris marengo", "desc": "Discreto y moderno.", "rarity": "comun", "price": 80, "data": {"suit": "3a3d44"}},
	"suit_burdeos": {"slot": "traje", "name": "Traje burdeos", "desc": "Para presidentes con carácter.", "rarity": "raro", "price": 150, "data": {"suit": "5a1f2a"}},
	"suit_crema": {"slot": "traje", "name": "Traje crema", "desc": "Elegancia de verano.", "rarity": "epico", "price": 260, "data": {"suit": "d8ccb2"}},
	"tie_granate": {"slot": "corbata", "name": "Corbata granate", "desc": "La de los grandes días.", "rarity": "comun", "price": 0, "default": true, "data": {"tie": "8e2a22"}},
	"tie_azul": {"slot": "corbata", "name": "Corbata azul real", "desc": "Institucional.", "rarity": "comun", "price": 60, "data": {"tie": "2d5a9e"}},
	"tie_dorada": {"slot": "corbata", "name": "Corbata dorada", "desc": "Brilla en los debates.", "rarity": "raro", "price": 90, "data": {"tie": "c9a227"}},
	"tie_verde": {"slot": "corbata", "name": "Corbata esmeralda", "desc": "Para el presidente verde.", "rarity": "comun", "price": 60, "data": {"tie": "1f7a4a"}},
	"acc_ninguno": {"slot": "accesorio", "name": "Sin accesorio", "desc": "Sencillez republicana.", "rarity": "comun", "price": 0, "default": true, "data": {"acc": ""}},
	"acc_pin": {"slot": "accesorio", "name": "Pin de la bandera", "desc": "Un pequeño pin en la solapa.", "rarity": "comun", "price": 50, "data": {"acc": "pin"}},
	"acc_banda": {"slot": "accesorio", "name": "Banda presidencial", "desc": "La banda con los colores nacionales.", "rarity": "legendario", "price": 0, "premium": 90, "data": {"acc": "banda"}},
	"acc_medalla": {"slot": "accesorio", "name": "Gran Cruz al Mérito", "desc": "Una condecoración dorada.", "rarity": "epico", "price": 280, "data": {"acc": "medalla"}},
	# --- sellos
	"ink_clasica": {"slot": "tinta", "name": "Tinta oficial", "desc": "Verde para aprobar, rojo para vetar.", "rarity": "comun", "price": 0, "default": true, "data": {"ok": "2e8b57", "no": "b3261e"}},
	"ink_real": {"slot": "tinta", "name": "Tinta real", "desc": "Azul real y púrpura.", "rarity": "comun", "price": 100, "data": {"ok": "2d5a9e", "no": "6a2c8a"}},
	"ink_dorada": {"slot": "tinta", "name": "Tinta de oro", "desc": "Oro y negro azabache.", "rarity": "raro", "price": 140, "data": {"ok": "b8913f", "no": "1c1c1c"}},
	"ink_lacre": {"slot": "tinta", "name": "Lacre carmesí", "desc": "Sellos de lacre como en los viejos tiempos.", "rarity": "epico", "price": 260, "data": {"ok": "9e1b1b", "no": "4a0f0f", "wax": true}},
	# --- mascotas
	"pet_ninguna": {"slot": "mascota", "name": "Sin mascota", "desc": "El despacho, en silencio.", "rarity": "comun", "price": 0, "default": true, "data": {"pet": ""}},
	"pet_pez": {"slot": "mascota", "name": "Pez dorado", "desc": "Una pecera junto a la lámpara.", "rarity": "comun", "price": 90, "data": {"pet": "pez"}},
	"pet_gato": {"slot": "mascota", "name": "Decreto, el gato", "desc": "Duerme sobre el escritorio. Reduce el estrés.", "rarity": "raro", "price": 200, "data": {"pet": "gato"}},
	"pet_perro": {"slot": "mascota", "name": "Tribuno, el perro", "desc": "Asoma junto a la mesa. Reduce el estrés.", "rarity": "raro", "price": 200, "data": {"pet": "perro"}},
	"pet_loro": {"slot": "mascota", "name": "Senador, el loro", "desc": "Vive sobre el reloj y opina de todo.", "rarity": "epico", "price": 320, "data": {"pet": "loro"}},
}

const PACKS := [
	{"id": "lingotes_100", "name": "Saquito de lingotes", "amount": 100, "bonus": "", "price": "0,99 €"},
	{"id": "lingotes_550", "name": "Cofre de lingotes", "amount": 550, "bonus": "+10% extra", "price": "4,99 €"},
	{"id": "lingotes_1200", "name": "Tesoro nacional", "amount": 1200, "bonus": "+20% extra", "price": "9,99 €"},
]

const EXCHANGE := {"lingotes": 50, "laureles": 500}

const ACHIEVEMENTS := {
	"primera_ley": {"name": "Legislador", "desc": "Aprueba tu primera ley.", "reward": 30},
	"cinco_leyes": {"name": "Reformista", "desc": "Aprueba 5 leyes en una partida.", "reward": 80},
	"crisis_perfecta": {"name": "Sangre fría", "desc": "Resuelve una crisis con un 90% de eficacia.", "reward": 50},
	"tiburon": {"name": "Tiburón", "desc": "Cierra un acuerdo con un 85% a tu favor.", "reward": 50},
	"estadista": {"name": "Estadista", "desc": "Firma un acuerdo en una cumbre internacional.", "reward": 60},
	"orador": {"name": "Orador", "desc": "Gana un debate televisado.", "reward": 40},
	"martillo": {"name": "Martillo del Congreso", "desc": "Consigue un combo x3 en la sesión de control.", "reward": 40},
	"reelegido": {"name": "Cuatro años más", "desc": "Gana la reelección.", "reward": 150},
	"rodillo": {"name": "Rodillo", "desc": "Consigue mayoría absoluta propia (176 escaños).", "reward": 200},
	"superviviente": {"name": "Superviviente", "desc": "Sobrevive a una moción de censura.", "reward": 60},
	"democracia": {"name": "La democracia resiste", "desc": "Frustra un golpe de Estado.", "reward": 80},
	"idolo": {"name": "Ídolo de masas", "desc": "Alcanza un 70% de aprobación.", "reward": 60},
	"cuentas": {"name": "Cuentas claras", "desc": "Baja la deuda por debajo del 80% del PIB.", "reward": 80},
	"lupa": {"name": "Letra pequeña", "desc": "Descubre 5 cláusulas ocultas.", "reward": 30},
	"primera_partida": {"name": "Primera legislatura", "desc": "Termina una partida.", "reward": 30},
	"fichaje": {"name": "Cazatalentos", "desc": "Ficha a un nuevo ministro.", "reward": 25},
	"campana": {"name": "En la carretera", "desc": "Realiza 6 actos de campaña en una partida.", "reward": 40},
	"coleccionista": {"name": "Coleccionista", "desc": "Consigue 10 objetos de la tienda.", "reward": 100},
}

# Recompensas durante la partida
const EARN := {"ley": 12, "crisis": 15, "acuerdo": 8, "debate": 20, "control": 10, "cumbre": 25, "campana": 4}
