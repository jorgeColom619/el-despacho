extends RefCounted
## Fichas de los países jugables: nombre, gentilicios, capital, regiones, partidos, personajes fijos, nombres para
## los cargos que se generan, mapa y bandera. Los textos del juego están escritos para Valdoria; al empezar una
## partida con otro país, scripts/systems/pais.gd cambia cada dato de Valdoria por el del país elegido.
##
## Cada ficha usa las mismas claves que la de Valdoria (regiones 1-8, partidos FS...PO, personajes vice, jefa...):
## así el país elegido ocupa el sitio de Valdoria en todos los sistemas del juego.

const ORDEN := ["valdoria", "norland"]

const PAISES := {
	"valdoria": {
		"name": "Valdoria", "full": "República de Valdoria",
		"gent": ["valdoriano", "valdoriana", "valdorianos", "valdorianas"],
		"cap": "Santa Aurora",
		"currency": "€",
		"pres_m": "Alejandro Ríos", "pres_f": "Alejandra Ríos",
		"desc": "Democracia parlamentaria del sur, socia de la Unión Continental. Turismo, campo y un Congreso de siete partidos donde siempre falta un voto.",
		"regime": "Democracia parlamentaria",
		"world_id": 1, "map": "valdoria", "flag": "valdoria",
		"regions": {1: "Santa Aurora", 2: "Ferrosa", 3: "Marvella", 4: "Puerto Alba", 5: "Vallegrande", 6: "Altamira", 7: "Rioseco", 8: "Islas Cordales"},
		"parties": {
			"FS": {"name": "Frente Social", "short": "FS", "leader": "Nuria Campos"},
			"VV": {"name": "Verdes de Valdoria", "short": "VV", "leader": "Iker Solano"},
			"MP": {"name": "Movimiento Progresista", "short": "MP", "leader": "Irene Sotomayor"},
			"CC": {"name": "Centro Cívico", "short": "CC", "leader": "Pablo Iturbe"},
			"CR": {"name": "Coalición Regional", "short": "CR", "leader": "Marcos Quintana"},
			"AR": {"name": "Alianza Republicana", "short": "AR", "leader": "Gonzalo Arriaga"},
			"PO": {"name": "Patria y Orden", "short": "PyO", "leader": "Bruno Valverde"},
		},
		"cast": {"vice": "Inés Aranda", "jefa": "Elena Márquez", "economia": "Tomás Ferrer", "interior": "Carmen Robles",
			"exteriores": "Andrés Villalba", "defensa": "Julio Prieto", "sanidad": "Lucía Varela", "sindicato": "Rosa Beltrán",
			"patronal": "Federico Lanz", "periodista": "Laura Vidal"},
		# cuando Valdoria es un país extranjero (gobiernas otro): su presidenta y su carácter
		"ai": {"name": "Valdoria", "full": "República de Valdoria", "leader": "Ramón Benavente", "title": "Presidente", "pers": "pragmatico",
			"power": 48.0, "rel": 30.0, "map": 1, "color": "2a8c8c",
			"desc": "Democracia del sur, socia de la Unión Continental. Turismo, campo y gobiernos que siempre dependen de un voto.",
			"look": {"g": "m", "skin": 1, "hair": "side", "hc": 2, "glasses": 1, "suit": "2b3a5c", "shirt": "f4efe6", "tie": "8c2a2a", "age": 2, "beard": "none", "eyes": "4a3426"}},
	},
	"norland": {
		"name": "Norland", "full": "Estados Federados de Norland",
		"gent": ["norlandés", "norlandesa", "norlandeses", "norlandesas"],
		"cap": "Fairhaven",
		"currency": "$",
		"pres_m": "Alexander Reed", "pres_f": "Alexandra Reed",
		"desc": "La superpotencia occidental: república federal, la mayor economía y el ejército más fuerte del mundo. Sus aliados esperan protección y su opinión pública, resultados.",
		"regime": "República federal presidencial",
		"world_id": 7, "map": "norland", "flag": "norland",
		"regions": {1: "Fairhaven", 2: "Ironwood", 3: "New Bristol", 4: "Port Calloway", 5: "Greenfield", 6: "Redrock", 7: "Lakeshore", 8: "Islas Pacíficas"},
		"parties": {
			"FS": {"name": "Partido Laborista", "short": "PL", "leader": "Megan O'Neill"},
			"VV": {"name": "Verdes de Norland", "short": "VN", "leader": "Ethan Brooks"},
			"MP": {"name": "Partido de la Unión", "short": "PU", "leader": "Claire Whitman"},
			"CC": {"name": "Liberales Independientes", "short": "LI", "leader": "Daniel Hayes"},
			"CR": {"name": "Alianza de los Estados", "short": "AE", "leader": "Robert Kealoha"},
			"AR": {"name": "Partido Federal", "short": "PF", "leader": "Jack Morrison"},
			"PO": {"name": "Norland Primero", "short": "NP", "leader": "Wade Colton"},
		},
		"cast": {"vice": "Rebecca Hale", "jefa": "Margaret Dunn", "economia": "Thomas Fielding", "interior": "Karen Whitaker",
			"exteriores": "Andrew Sinclair", "defensa": "James Porter", "sanidad": "Lucy Warren", "sindicato": "Rose Bennett",
			"patronal": "Frederick Lang", "periodista": "Laura Bishop"},
		"names_m": ["James", "Michael", "Robert", "David", "William", "Daniel", "Matthew", "Andrew", "Joseph", "Ryan", "Nathan", "Samuel", "Henry", "Owen", "Lucas", "Caleb", "Jack", "Thomas"],
		"names_f": ["Emily", "Sarah", "Jessica", "Hannah", "Olivia", "Rachel", "Megan", "Laura", "Grace", "Claire", "Abigail", "Natalie", "Emma", "Lauren", "Anna", "Julia", "Kate", "Rebecca"],
		"surnames": ["Smith", "Walker", "Carter", "Mitchell", "Harper", "Bennett", "Coleman", "Reed", "Foster", "Parker", "Hughes", "Russell", "Sullivan", "Palmer", "Grant", "Lawson", "Fletcher", "Barnes", "Holloway", "Price", "Ward", "Ellis", "Murphy", "Ramírez", "Nakamura", "Kowalski"],
		# lo que en los textos de Valdoria es geografía o historia de Valdoria y no tiene sentido aquí: los eventos y
		# las tramas que los nombran no salen (el vecino Sarvenia y el río Seco, el estrecho de Aldora, la Unión
		# Continental de la que Valdoria es socia y Norland como aliado protector)
		"excl_ids": ["norland", "union", "sarvenia", "aldora"],
		"excl_names": ["Norland", "Kade", "Unión Continental", "la Unión", "Sarvenia", "Olmedo", "Aldora", "Seko", "río Seco", "estrecho"],
		# cómo se ven desde Norland los países cuya descripción habla de Valdoria
		"vistos": {
			"union": "El gran bloque económico del otro lado del océano. Socio comercial exigente y rival regulador.",
			"sarvenia": "Pequeña república gobernada por una junta militar. Pide armas y ayuda; Norland pide elecciones.",
			"aldora": "País pobre e inestable al sur del estrecho. Ayuda humanitaria, minerales y migración.",
		},
	},
}
