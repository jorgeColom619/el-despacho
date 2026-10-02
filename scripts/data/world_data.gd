extends RefCounted
## Datos estáticos del mundo: partidos, países, regiones, personajes, leyes y crisis.

const COUNTRY_NAME := "Valdoria"
const CAPITAL := "Santa Aurora"

const METER_INFO := {
	"economia": {"name": "Economía", "icon": "economia", "desc": "Crecimiento, empleo e ingresos fiscales."},
	"bienestar": {"name": "Bienestar", "icon": "bienestar", "desc": "Sanidad, educación y servicios sociales."},
	"seguridad": {"name": "Seguridad", "icon": "seguridad", "desc": "Orden público, delincuencia y defensa."},
	"estabilidad": {"name": "Estabilidad", "icon": "estabilidad", "desc": "Gobernabilidad y apoyo parlamentario. Si cae, peligra tu mandato."},
	"prestigio": {"name": "Prestigio", "icon": "prestigio", "desc": "Imagen internacional y peso diplomático."},
	"ambiente": {"name": "Medio ambiente", "icon": "ambiente", "desc": "Calidad ambiental y transición ecológica."},
}

const FACTION_INFO := {
	"trabajadores": {"name": "Trabajadores", "icon": "trabajadores", "w": 0.26, "desc": "Asalariados y sindicatos. Quieren empleo, salarios y servicios públicos."},
	"empresarios": {"name": "Empresarios", "icon": "empresarios", "w": 0.08, "desc": "Patronal e inversores. Quieren impuestos bajos y estabilidad."},
	"clase_media": {"name": "Clase media", "icon": "clase_media", "w": 0.30, "desc": "El votante decisivo. Economía, seguridad e impuestos moderados."},
	"jovenes": {"name": "Jóvenes", "icon": "jovenes", "w": 0.16, "desc": "Educación, vivienda, empleo y medio ambiente."},
	"jubilados": {"name": "Jubilados", "icon": "jubilados", "w": 0.20, "desc": "Pensiones, sanidad y seguridad. Votan en masa."},
	"militares": {"name": "Fuerzas Armadas", "icon": "militares", "w": 0.0, "desc": "No deciden elecciones, pero sí golpes de Estado."},
}

const BUDGET := {
	"sanidad": {"name": "Sanidad", "icon": "hospital", "base": 7200.0},
	"educacion": {"name": "Educación", "icon": "jovenes", "base": 4600.0},
	"pensiones": {"name": "Pensiones", "icon": "jubilados", "base": 12500.0},
	"seguridad": {"name": "Seguridad y Justicia", "icon": "policia", "base": 3000.0},
	"defensa": {"name": "Defensa", "icon": "militares", "base": 2600.0},
	"infraestructura": {"name": "Infraestructuras", "icon": "tren", "base": 3800.0},
	"social": {"name": "Vivienda y Serv. Sociales", "icon": "clase_media", "base": 4800.0},
	"ambiente": {"name": "Medio Ambiente y Energía", "icon": "ambiente", "base": 1400.0},
}

const TAXES := {
	"renta": {"name": "IRPF (renta)", "base": 22.0, "min": 12.0, "max": 36.0},
	"sociedades": {"name": "Impuesto de Sociedades", "base": 25.0, "min": 12.0, "max": 38.0},
	"iva": {"name": "IVA", "base": 21.0, "min": 10.0, "max": 27.0},
}

const PARTIES := {
	"FS": {"name": "Frente Social", "short": "FS", "ideo": -75.0, "color": "9b1c1c", "leader": "Nuria Campos"},
	"VV": {"name": "Verdes de Valdoria", "short": "VV", "ideo": -45.0, "color": "3a9d5d", "leader": "Iker Solano"},
	"MP": {"name": "Movimiento Progresista", "short": "MP", "ideo": -28.0, "color": "e2574c", "leader": "Irene Sotomayor"},
	"CC": {"name": "Centro Cívico", "short": "CC", "ideo": 5.0, "color": "f0a030", "leader": "Pablo Iturbe"},
	"CR": {"name": "Coalición Regional", "short": "CR", "ideo": 0.0, "color": "1aa39a", "leader": "Marcos Quintana"},
	"AR": {"name": "Alianza Republicana", "short": "AR", "ideo": 35.0, "color": "2f6fd6", "leader": "Gonzalo Arriaga"},
	"PO": {"name": "Patria y Orden", "short": "PyO", "ideo": 80.0, "color": "6a4a9c", "leader": "Bruno Valverde"},
}

const PARTY_ORDER := ["FS", "VV", "MP", "CR", "CC", "AR", "PO"]

const SEATS := {
	"MP": {"FS": 30, "VV": 18, "MP": 138, "CR": 16, "CC": 42, "AR": 92, "PO": 14},
	"AR": {"FS": 22, "VV": 14, "MP": 92, "CR": 16, "CC": 42, "AR": 138, "PO": 26},
	"CC": {"FS": 22, "VV": 16, "MP": 88, "CR": 16, "CC": 118, "AR": 74, "PO": 16},
}

const PLAYER_PARTIES := {
	"MP": {"desc": "Centro-izquierda. Fuerte entre trabajadores y jóvenes. Recelo empresarial.", "bonus": {"trabajadores": 8.0, "jovenes": 5.0, "empresarios": -8.0, "militares": -3.0}, "opp": "AR"},
	"CC": {"desc": "Centro liberal. Gusta a la clase media; debe pactar a izquierda o derecha.", "bonus": {"clase_media": 6.0, "empresarios": 3.0}, "opp": "AR"},
	"AR": {"desc": "Centro-derecha. Apoyo de empresarios, jubilados y militares.", "bonus": {"empresarios": 8.0, "militares": 6.0, "jubilados": 4.0, "jovenes": -5.0, "trabajadores": -6.0}, "opp": "MP"},
}

const SKIN := ["f1d3bd", "e6bc98", "d4a276", "b67f56", "8d5a3b", "5e3b26"]
const HAIR_COL := ["1c1816", "3b2a20", "6b4a2f", "8a4b2a", "c9a46a", "9a9a98", "dcd8d0"]

const CHARACTERS := {
	"jefa": {"name": "Elena Márquez", "role": "Jefa de Gabinete", "look": {"g": "f", "skin": 1, "hair": "bob", "hc": 1, "glasses": 2, "suit": "243653", "shirt": "e8e4dc", "tie": "", "age": 1, "eyes": "5a4632"}},
	"economia": {"name": "Tomás Ferrer", "role": "Ministro de Economía", "look": {"g": "m", "skin": 0, "hair": "balding", "hc": 5, "glasses": 1, "suit": "3a3d44", "shirt": "f2f2f2", "tie": "7a1f2b", "age": 2, "beard": "none", "eyes": "4d6a80"}},
	"interior": {"name": "Carmen Robles", "role": "Ministra del Interior", "look": {"g": "f", "skin": 2, "hair": "bun", "hc": 0, "glasses": 0, "suit": "1f2124", "shirt": "d9d9d9", "tie": "", "age": 1, "eyes": "3b2a20"}},
	"exteriores": {"name": "Andrés Villalba", "role": "Ministro de Exteriores", "look": {"g": "m", "skin": 1, "hair": "slick", "hc": 5, "glasses": 0, "suit": "1d2b4a", "shirt": "eef2f7", "tie": "2d5a9e", "age": 1, "beard": "stubble", "eyes": "3b2a20"}},
	"defensa": {"name": "Gral. Julio Prieto", "role": "Ministro de Defensa", "look": {"g": "m", "skin": 2, "hair": "buzz", "hc": 5, "glasses": 0, "suit": "3f4a32", "shirt": "d8d2b8", "tie": "2b2f22", "age": 2, "beard": "mustache", "uniform": true, "eyes": "3b2a20"}},
	"sanidad": {"name": "Lucía Varela", "role": "Ministra de Sanidad", "look": {"g": "f", "skin": 3, "hair": "curly", "hc": 0, "glasses": 0, "suit": "2e5f6b", "shirt": "f5f5f5", "tie": "", "age": 0, "eyes": "2a1c14"}},
	"sindicato": {"name": "Rosa Beltrán", "role": "Secretaria General de la Confederación de Trabajadores", "look": {"g": "f", "skin": 2, "hair": "curly", "hc": 5, "glasses": 1, "suit": "6b2b2b", "shirt": "e9e2d6", "tie": "", "age": 2, "eyes": "3b2a20"}},
	"patronal": {"name": "Federico Lanz", "role": "Presidente de la Confederación Empresarial", "look": {"g": "m", "skin": 0, "hair": "slick", "hc": 6, "glasses": 0, "suit": "22252c", "shirt": "ffffff", "tie": "b08a3e", "age": 2, "beard": "none", "eyes": "4d6a80"}},
	"islas": {"name": "Marcos Quintana", "role": "Presidente de las Islas Cordales", "look": {"g": "m", "skin": 3, "hair": "wavy", "hc": 1, "glasses": 0, "suit": "2a4a5a", "shirt": "f0f0f0", "tie": "1aa39a", "age": 1, "beard": "stubble", "eyes": "2a1c14"}},
	"opo_AR": {"name": "Gonzalo Arriaga", "role": "Líder de la Oposición (AR)", "look": {"g": "m", "skin": 1, "hair": "side", "hc": 5, "glasses": 0, "suit": "1b2c52", "shirt": "f4f6fa", "tie": "2f6fd6", "age": 1, "beard": "none", "eyes": "4d6a80"}},
	"opo_MP": {"name": "Irene Sotomayor", "role": "Líder de la Oposición (MP)", "look": {"g": "f", "skin": 2, "hair": "wavy", "hc": 3, "glasses": 0, "suit": "5a1f2a", "shirt": "f3ece6", "tie": "", "age": 1, "eyes": "3b2a20"}},
	"periodista": {"name": "Laura Vidal", "role": "Presentadora de Canal 7", "look": {"g": "f", "skin": 1, "hair": "long", "hc": 4, "glasses": 0, "suit": "2b3e66", "shirt": "fafafa", "tie": "", "age": 0, "eyes": "4d6a80"}},
}

const COUNTRIES := {
	"norland": {"name": "Norland", "full": "Estados Federados de Norland", "leader": "Harrison Kade", "title": "Presidente", "pers": "orgulloso", "power": 95.0, "rel": 25.0, "map": 7, "color": "3b6fb6",
		"desc": "La superpotencia occidental. Aliado histórico que exige lealtad a cambio de protección.",
		"look": {"g": "m", "skin": 0, "hair": "side", "hc": 4, "glasses": 0, "suit": "1a2440", "shirt": "ffffff", "tie": "b8262e", "age": 2, "beard": "none", "eyes": "4d6a80"}},
	"union": {"name": "Unión Continental", "full": "Unión Continental", "leader": "Ingrid Vaelsen", "title": "Presidenta de la Comisión", "pers": "pragmatico", "power": 88.0, "rel": 35.0, "map": 4, "color": "3d58a8",
		"desc": "El gran bloque económico vecino. Tu principal socio comercial; vigila de cerca tu déficit.",
		"look": {"g": "f", "skin": 0, "hair": "bob", "hc": 4, "glasses": 0, "suit": "2e4a8c", "shirt": "f7f7f7", "tie": "", "age": 1, "eyes": "5b86a8"}},
	"kharovia": {"name": "Kharovia", "full": "Federación de Kharovia", "leader": "Viktor Drogan", "title": "Presidente", "pers": "agresivo", "power": 80.0, "rel": -10.0, "map": 5, "color": "8e2a2a",
		"desc": "Potencia autoritaria y rica en gas. Sus ofertas son tentadoras y su amistad, peligrosa.",
		"look": {"g": "m", "skin": 0, "hair": "balding", "hc": 4, "glasses": 0, "suit": "2a2c30", "shirt": "e0e0e0", "tie": "22262b", "age": 2, "beard": "none", "eyes": "6d8aa0"}},
	"tsaing": {"name": "Tsaing", "full": "República de Tsaing", "leader": "Hao Lin", "title": "Presidente", "pers": "paciente", "power": 90.0, "rel": 5.0, "map": 6, "color": "c9a227",
		"desc": "Gigante industrial. Invierte a largo plazo... y cobra a largo plazo.",
		"look": {"g": "m", "skin": 1, "hair": "slick", "hc": 0, "glasses": 2, "suit": "15171b", "shirt": "f4f4f4", "tie": "8c1c1c", "age": 2, "beard": "none", "eyes": "2a1c14"}},
	"sarvenia": {"name": "Sarvenia", "full": "República de Sarvenia", "leader": "Ramiro Olmedo", "title": "General-Presidente", "pers": "volatil", "power": 42.0, "rel": -15.0, "map": 2, "color": "4f7a3a",
		"desc": "Vecino occidental gobernado por una junta militar. Disputa contigo las aguas del río Seco.",
		"look": {"g": "m", "skin": 3, "hair": "buzz", "hc": 0, "glasses": 0, "suit": "4a5236", "shirt": "d8d2b8", "tie": "2b2f22", "age": 1, "beard": "mustache", "uniform": true, "eyes": "2a1c14"}},
	"qadar": {"name": "Qadar", "full": "Emirato de Qadar", "leader": "Faisal al-Rashid", "title": "Emir", "pers": "pragmatico", "power": 55.0, "rel": 10.0, "map": 8, "color": "7a2b3e",
		"desc": "Petromonarquía con un fondo soberano gigantesco y ganas de influencia.",
		"look": {"g": "m", "skin": 3, "hair": "short", "hc": 0, "glasses": 0, "suit": "e9e4d8", "shirt": "ffffff", "tie": "", "age": 1, "beard": "full", "eyes": "2a1c14"}},
	"aldora": {"name": "Aldora", "full": "República de Aldora", "leader": "Amina Seko", "title": "Presidenta", "pers": "paciente", "power": 22.0, "rel": 20.0, "map": 3, "color": "c77d2e",
		"desc": "Vecino del sur, al otro lado del estrecho. Inestable y origen de flujos migratorios.",
		"look": {"g": "f", "skin": 5, "hair": "bun", "hc": 0, "glasses": 0, "suit": "2f6b4a", "shirt": "f2e6c8", "tie": "", "age": 1, "eyes": "2a1c14"}},
}

const PERSONALITIES := {
	"orgulloso": {"name": "Orgulloso", "desc": "Le encantan los halagos; la presión le ofende.", "arg": 0.9, "pres": 0.8, "flat": 1.8, "threat_mood": 1.5, "patience": 6, "thr": -5.0},
	"agresivo": {"name": "Agresivo", "desc": "Responde a la fuerza con fuerza. Respeta la firmeza.", "arg": 0.7, "pres": 1.1, "flat": 0.6, "threat_mood": 1.2, "patience": 5, "thr": -12.0},
	"pragmatico": {"name": "Pragmático", "desc": "Se deja convencer con buenos argumentos y datos.", "arg": 1.5, "pres": 0.9, "flat": 0.5, "threat_mood": 1.0, "patience": 6, "thr": 8.0},
	"paciente": {"name": "Paciente", "desc": "Negocia sin prisa. Difícil de alterar en ambos sentidos.", "arg": 1.1, "pres": 0.8, "flat": 0.9, "threat_mood": 0.7, "patience": 8, "thr": 0.0},
	"volatil": {"name": "Imprevisible", "desc": "Cambia de humor de un momento a otro.", "arg": 1.0, "pres": 1.2, "flat": 1.2, "threat_mood": 1.6, "patience": 5, "thr": -2.0},
}

const REGIONS := {
	1: {"key": "capital", "name": "Santa Aurora", "sub": "Capital", "pop": 0.19, "demo": {"trabajadores": 0.22, "empresarios": 0.12, "clase_media": 0.36, "jovenes": 0.2, "jubilados": 0.1}},
	2: {"key": "norte", "name": "Ferrosa", "sub": "Norte Industrial", "pop": 0.16, "demo": {"trabajadores": 0.42, "empresarios": 0.06, "clase_media": 0.24, "jovenes": 0.13, "jubilados": 0.15}},
	3: {"key": "este", "name": "Marvella", "sub": "Costa Este", "pop": 0.15, "demo": {"trabajadores": 0.24, "empresarios": 0.1, "clase_media": 0.3, "jovenes": 0.22, "jubilados": 0.14}},
	4: {"key": "sur", "name": "Puerto Alba", "sub": "Costa Sur", "pop": 0.14, "demo": {"trabajadores": 0.3, "empresarios": 0.06, "clase_media": 0.26, "jovenes": 0.14, "jubilados": 0.24}},
	5: {"key": "valle", "name": "Vallegrande", "sub": "Valle Central", "pop": 0.12, "demo": {"trabajadores": 0.3, "empresarios": 0.05, "clase_media": 0.25, "jovenes": 0.1, "jubilados": 0.3}},
	6: {"key": "sierra", "name": "Altamira", "sub": "Sierra Oeste", "pop": 0.07, "demo": {"trabajadores": 0.34, "empresarios": 0.05, "clase_media": 0.22, "jovenes": 0.1, "jubilados": 0.29}},
	7: {"key": "frontera", "name": "Rioseco", "sub": "Frontera", "pop": 0.1, "demo": {"trabajadores": 0.3, "empresarios": 0.05, "clase_media": 0.28, "jovenes": 0.12, "jubilados": 0.25}},
	8: {"key": "islas", "name": "Islas Cordales", "sub": "Islas", "pop": 0.07, "demo": {"trabajadores": 0.26, "empresarios": 0.08, "clase_media": 0.3, "jovenes": 0.18, "jubilados": 0.18}},
}

const LAWS := {
	"salario_minimo": {"name": "Subida del Salario Mínimo", "icon": "trabajadores", "ideo": -40.0, "pc": 12, "desc": "Eleva el salario mínimo un 12%. Los sindicatos lo celebran; la patronal advierte de despidos.", "fx": {"trabajadores": 8, "empresarios": -8}, "mods": {"trabajadores": 10, "jovenes": 4, "empresarios": -10, "economia": -2}},
	"fortunas": {"name": "Impuesto a las Grandes Fortunas", "icon": "dinero", "ideo": -55.0, "pc": 15, "desc": "Nuevo tributo sobre patrimonios superiores a 3 millones. Recauda, pero ahuyenta capitales.", "fx": {"empresarios": -10, "trabajadores": 5}, "mods": {"empresarios": -14, "trabajadores": 6, "economia": -2, "clase_media": 2}, "monthly": 700.0},
	"rebaja_fiscal": {"name": "Rebaja General de Impuestos", "icon": "dinero", "ideo": 40.0, "pc": 14, "desc": "Baja el IRPF y Sociedades. Alegría inmediata en los bolsillos... y agujero en las cuentas.", "fx": {"clase_media": 6, "empresarios": 6}, "mods": {"clase_media": 8, "empresarios": 8, "economia": 4, "trabajadores": 2}, "monthly": -1500.0},
	"vivienda": {"name": "Ley de Vivienda Asequible", "icon": "clase_media", "ideo": -30.0, "pc": 12, "desc": "Topes al alquiler en zonas tensionadas y un parque público de vivienda.", "fx": {"jovenes": 8, "empresarios": -5}, "mods": {"jovenes": 12, "clase_media": 3, "empresarios": -6, "bienestar": 4}, "monthly": -400.0},
	"nuclear": {"name": "Plan Nuclear Nacional", "icon": "rayo", "ideo": 25.0, "pc": 16, "desc": "Construcción de dos nuevos reactores. Energía barata y sin CO₂, pero con miedos y residuos.", "fx": {"jovenes": -6, "empresarios": 5, "money": -6000}, "mods": {"economia": 5, "ambiente": 3, "jovenes": -6, "empresarios": 6}, "flag": "nuclear"},
	"transicion_verde": {"name": "Pacto por la Transición Verde", "icon": "ambiente", "ideo": -25.0, "pc": 14, "desc": "Cierre progresivo del carbón, renovables y coche eléctrico.", "fx": {"jovenes": 8, "trabajadores": -4}, "mods": {"ambiente": 14, "jovenes": 10, "trabajadores": -4, "empresarios": -4, "prestigio": 4}, "monthly": -500.0},
	"penal": {"name": "Reforma Penal de Mano Dura", "icon": "policia", "ideo": 50.0, "pc": 12, "desc": "Penas más duras y más poder policial.", "fx": {"clase_media": 4, "jubilados": 5, "jovenes": -6}, "mods": {"seguridad": 8, "clase_media": 5, "jubilados": 6, "jovenes": -8, "prestigio": -2}},
	"pensiones_edad": {"name": "Jubilación a los 69 años", "icon": "jubilados", "ideo": 35.0, "pc": 20, "desc": "Retrasa la edad de jubilación para salvar el sistema. Impopular, pero ahorra muchísimo.", "fx": {"jubilados": -12, "trabajadores": -8}, "mods": {"jubilados": -16, "trabajadores": -8, "empresarios": 8, "economia": 3}, "monthly": 1200.0},
	"pensiones_subida": {"name": "Revalorización de las Pensiones", "icon": "jubilados", "ideo": -15.0, "pc": 10, "desc": "Pensiones ligadas a la inflación y subida extraordinaria del 5%.", "fx": {"jubilados": 10}, "mods": {"jubilados": 14}, "monthly": -900.0},
	"universidad": {"name": "Universidad Gratuita", "icon": "jovenes", "ideo": -45.0, "pc": 14, "desc": "Matrícula universitaria gratuita para todos los estudiantes.", "fx": {"jovenes": 10}, "mods": {"jovenes": 15, "bienestar": 4, "clase_media": 4, "empresarios": -2}, "monthly": -600.0},
	"inmigracion_dura": {"name": "Ley de Control Migratorio", "icon": "escudo_x", "ideo": 60.0, "pc": 14, "desc": "Deportaciones exprés, vallas y fin de la reagrupación familiar.", "fx": {"clase_media": 4, "jovenes": -8}, "mods": {"clase_media": 5, "jubilados": 6, "militares": 4, "jovenes": -10, "prestigio": -6, "economia": -2}, "flag": "control_migratorio"},
	"regularizacion": {"name": "Regularización de Inmigrantes", "icon": "aprobacion", "ideo": -40.0, "pc": 14, "desc": "Papeles para 400.000 personas que ya trabajan en el país.", "fx": {"jovenes": 5, "clase_media": -4}, "mods": {"economia": 2, "jovenes": 6, "clase_media": -5, "jubilados": -4, "prestigio": 4}, "monthly": 300.0},
	"reforma_laboral": {"name": "Reforma Laboral Flexible", "icon": "fabrica", "ideo": 45.0, "pc": 16, "desc": "Despido más barato y contratos flexibles. La patronal aplaude.", "fx": {"empresarios": 10, "trabajadores": -12}, "mods": {"empresarios": 15, "economia": 6, "trabajadores": -14, "jovenes": -2}},
	"cuatro_dias": {"name": "Semana Laboral de 4 Días", "icon": "reloj", "ideo": -50.0, "pc": 18, "desc": "32 horas semanales sin reducción de salario.", "fx": {"trabajadores": 8, "jovenes": 10, "empresarios": -12}, "mods": {"trabajadores": 10, "jovenes": 12, "empresarios": -15, "economia": -4, "clase_media": 3}},
	"cannabis": {"name": "Legalización del Cannabis", "icon": "ambiente", "ideo": -35.0, "pc": 10, "desc": "Venta regulada en establecimientos autorizados.", "fx": {"jovenes": 8, "jubilados": -6}, "mods": {"jovenes": 10, "jubilados": -8, "clase_media": -2}, "monthly": 250.0},
	"mili": {"name": "Servicio Militar Obligatorio", "icon": "militares", "ideo": 70.0, "pc": 18, "desc": "Nueve meses de servicio para todos los jóvenes de 18 años.", "fx": {"militares": 12, "jovenes": -15}, "mods": {"militares": 16, "jovenes": -20, "seguridad": 3, "prestigio": 2}, "monthly": -300.0},
	"transparencia": {"name": "Ley de Transparencia", "icon": "ojo", "ideo": 0.0, "pc": 12, "desc": "Agenda pública de altos cargos, registro de lobbies y fiscalía anticorrupción reforzada.", "fx": {"clase_media": 4}, "mods": {"estabilidad": 6, "clase_media": 4, "empresarios": -2}, "flag": "transparencia"},
	"nacionalizar_energia": {"name": "Nacionalización de la Energía", "icon": "rayo", "ideo": -75.0, "pc": 22, "desc": "El Estado toma el control de las eléctricas.", "fx": {"trabajadores": 8, "empresarios": -16, "money": -9000}, "mods": {"trabajadores": 10, "empresarios": -20, "economia": -3, "prestigio": -4}, "flag": "energia_publica"},
	"privatizar": {"name": "Privatización de Empresas Públicas", "icon": "empresarios", "ideo": 60.0, "pc": 18, "desc": "Venta de Correos, la aerolínea estatal y las loterías.", "fx": {"empresarios": 10, "trabajadores": -8, "money": 14000}, "mods": {"empresarios": 12, "trabajadores": -10, "economia": 2, "bienestar": -3}},
	"ley_medios": {"name": "Ley de Medios", "icon": "prensa", "ideo": 55.0, "pc": 20, "desc": "Un consejo estatal supervisará la 'veracidad' de la información. La oposición grita censura.", "fx": {"jovenes": -8, "clase_media": -4}, "mods": {"estabilidad": 6, "prestigio": -10, "jovenes": -8, "clase_media": -4}, "flag": "ley_medios"},
	"renta_basica": {"name": "Renta Básica Universal", "icon": "dinero", "ideo": -65.0, "pc": 24, "desc": "600 € al mes para todo adulto con ingresos bajos.", "fx": {"trabajadores": 10, "jovenes": 10, "empresarios": -10}, "mods": {"trabajadores": 14, "jovenes": 12, "bienestar": 10, "empresarios": -12, "economia": -2}, "monthly": -2500.0},
	"digitalizacion": {"name": "Plan Nacional de Digitalización", "icon": "tecnico", "ideo": 0.0, "pc": 10, "desc": "Fibra rural, administración digital y formación tecnológica.", "fx": {"jovenes": 4, "money": -3000}, "mods": {"economia": 4, "jovenes": 5, "empresarios": 4}},
	"amnistia_fiscal": {"name": "Amnistía Fiscal", "icon": "dinero", "ideo": 30.0, "pc": 12, "desc": "Los defraudadores regularizan su dinero pagando solo un 10%.", "fx": {"empresarios": 5, "trabajadores": -6, "clase_media": -6, "money": 5000, "corr": 5}, "mods": {"empresarios": 6, "trabajadores": -6, "clase_media": -6, "estabilidad": -3}},
	"seguridad_ciudadana": {"name": "Ley de Seguridad Ciudadana", "icon": "escudo_x", "ideo": 50.0, "pc": 14, "desc": "Multas por protestar sin permiso y más poder a la policía.", "fx": {"jovenes": -10, "jubilados": 4}, "mods": {"seguridad": 6, "estabilidad": 4, "jovenes": -12, "prestigio": -3}, "flag": "mordaza"},
	"bienestar_animal": {"name": "Ley de Bienestar Animal", "icon": "bienestar", "ideo": -20.0, "pc": 6, "desc": "Prohíbe el maltrato y regula la cría de mascotas.", "fx": {"jovenes": 3}, "mods": {"jovenes": 4, "ambiente": 2}},
	"ampliar_mandato": {"name": "Reforma Constitucional: mandato de 6 años", "icon": "candado", "ideo": 40.0, "pc": 40, "desc": "Amplía el mandato presidencial dos años más. Requiere mayoría de dos tercios (234 escaños).", "fx": {"jovenes": -10, "clase_media": -8, "prestigio": -12}, "mods": {"estabilidad": -8, "prestigio": -15, "jovenes": -10, "clase_media": -8}, "term": 730, "super": true},
}

const OUTLETS := [
	{"name": "El Heraldo", "bias": 40.0, "tag": "Conservador"},
	{"name": "Diario Libre", "bias": -40.0, "tag": "Progresista"},
	{"name": "La Crónica", "bias": 0.0, "tag": "Centro"},
	{"name": "Canal 7 Noticias", "bias": 0.0, "tag": "Sensacionalista"},
	{"name": "The Norland Times", "bias": 10.0, "tag": "Internacional"},
	{"name": "Radio Popular", "bias": -60.0, "tag": "Izquierda"},
	{"name": "El Observador Económico", "bias": 25.0, "tag": "Económico"},
	{"name": "Voz Digital", "bias": -10.0, "tag": "Digital"},
]

const NAMES_M := ["Alejandro", "Javier", "Luis", "Diego", "Martín", "Sergio", "Andrés", "Pablo", "Raúl", "Hugo", "Óscar", "Rubén", "Ignacio", "Fernando", "Álvaro", "Mateo", "Gabriel", "Víctor", "Emilio", "Joaquín"]
const NAMES_F := ["Lucía", "Marta", "Sara", "Paula", "Elena", "Carmen", "Laura", "Ana", "Nerea", "Irene", "Beatriz", "Clara", "Julia", "Noelia", "Alba", "Inés", "Rocío", "Silvia", "Teresa", "Adriana"]
const SURNAMES := ["García", "Moreno", "Navarro", "Castillo", "Herrera", "Molina", "Ortega", "Delgado", "Vidal", "Serrano", "Ramos", "Iglesias", "Cortés", "Medina", "Fuentes", "Cano", "Prieto", "Marín", "Lozano", "Gallardo", "Esteban", "Pascual", "Aguirre", "Beltrán", "Soler", "Crespo", "Rosales", "Vega", "Robledo", "Salcedo"]
const COMPANIES := ["Constructora Albatros", "Obras Meridión", "Grupo Castellar", "Consorcio Vértice", "Hidrovalle", "Infraestructuras Lumen", "Grupo Estrella del Norte", "Ingeniería Solvente", "Sistemas Ágora", "Tecnologías Halcón", "Norland Dynamics", "Tsaing Heavy Industries", "Qadar Holdings", "Brisa Capital", "Aceros Ferrosa", "Grupo Atalaya"]
const PROJECTS := [
	{"t": "Hospital comarcal de %s", "kind": "sanidad", "cost": 380.0},
	{"t": "Línea de alta velocidad %s–Santa Aurora", "kind": "infraestructura", "cost": 1800.0},
	{"t": "Planta desaladora de %s", "kind": "ambiente", "cost": 520.0},
	{"t": "Parque eólico marino frente a %s", "kind": "ambiente", "cost": 900.0},
	{"t": "Nueva prisión de alta seguridad en %s", "kind": "seguridad", "cost": 260.0},
	{"t": "Sistema informático de la Agencia Tributaria", "kind": "tecnico", "cost": 210.0},
	{"t": "Renovación del puerto de %s", "kind": "infraestructura", "cost": 640.0},
	{"t": "Campus universitario de %s", "kind": "educacion", "cost": 330.0},
]

# Temas de negociación por país. "term": [etiqueta, valor si ganan ellos, valor si ganas tú, unidad]
const TOPICS := {
	"norland": [
		{"id": "comercio", "name": "Tratado de libre comercio", "desc": "Norland quiere acceso a nuestro mercado agrícola; nosotros, a su industria tecnológica.", "term": ["Aranceles a nuestras exportaciones", 16.0, 0.0, "%"], "fx_min": {"economia": 1, "rel": {"norland": 6}}, "fx_max": {"economia": 5, "rel": {"norland": 1}, "empresarios": 4}, "treaty": "comercio"},
		{"id": "bases", "name": "Ampliación de la base naval", "desc": "Norland quiere ampliar su base en Puerto Alba. ¿Cuánto vale nuestra soberanía?", "term": ["Compensación anual", 200.0, 2500.0, " M€"], "fx_min": {"money": 200, "rel": {"norland": 12, "kharovia": -8}, "militares": 3, "jovenes": -4}, "fx_max": {"money": 2500, "rel": {"norland": 4, "kharovia": -8}, "militares": 5, "jovenes": -3}, "treaty": "defensa"},
		{"id": "acero", "name": "Aranceles al acero", "desc": "Norland amenaza con un arancel del 25% al acero valdoriano. Ferrosa tiembla.", "term": ["Arancel al acero", 25.0, 0.0, "%"], "fx_min": {"trabajadores": -5, "economia": -3}, "fx_max": {"trabajadores": 3, "economia": 1, "rel": {"norland": -3}}},
	],
	"union": [
		{"id": "fondos", "name": "Fondos de recuperación", "desc": "La Unión reparte fondos de inversión... con condiciones.", "term": ["Fondos para Valdoria", 3000.0, 12000.0, " M€"], "fx_min": {"money": 3000, "rel": {"union": 6}}, "fx_max": {"money": 12000, "rel": {"union": 0}}},
		{"id": "cuotas", "name": "Reparto de migrantes", "desc": "La Unión propone un reparto de solicitantes de asilo entre socios.", "term": ["Personas acogidas por Valdoria", 40000.0, 8000.0, ""], "fx_min": {"prestigio": 4, "clase_media": -5, "rel": {"union": 8}}, "fx_max": {"prestigio": 1, "clase_media": 1, "rel": {"union": 1}}, "flag": "cuotas_pactadas"},
		{"id": "deficit", "name": "Reglas de déficit", "desc": "Bruselas... perdón, la Comisión exige un plan de ajuste. Negocia el calendario.", "term": ["Recorte exigido", 6000.0, 500.0, " M€/año"], "fx_min": {"monthly": 500, "bienestar": -4, "trabajadores": -5, "rel": {"union": 10}}, "fx_max": {"monthly": 40, "rel": {"union": -2}}},
	],
	"kharovia": [
		{"id": "gas", "name": "Contrato de gas", "desc": "Kharovia ofrece gas barato a largo plazo. El precio... y la dependencia.", "term": ["Descuento en el gas", 5.0, 35.0, "%"], "fx_min": {"economia": 1, "rel": {"kharovia": 8, "union": -5}}, "fx_max": {"economia": 4, "trabajadores": 3, "rel": {"kharovia": 2, "union": -5}}, "treaty": "energia", "flag": "dependencia_gas"},
		{"id": "presos", "name": "Intercambio de prisioneros", "desc": "Dos periodistas valdorianos siguen presos en Kharovia.", "term": ["Presos liberados", 0.0, 2.0, ""], "fx_min": {"prestigio": -3, "rel": {"kharovia": 5}}, "fx_max": {"prestigio": 5, "jovenes": 3, "clase_media": 3, "rel": {"kharovia": -2}}},
	],
	"tsaing": [
		{"id": "puerto", "name": "Inversión en el puerto de Marvella", "desc": "Tsaing financiaría una gran terminal de contenedores a cambio de su gestión.", "term": ["Años de concesión a Tsaing", 99.0, 20.0, ""], "fx_min": {"economia": 4, "rel": {"tsaing": 10, "norland": -12}, "prestigio": -3}, "fx_max": {"economia": 3, "rel": {"tsaing": 3, "norland": -5}}, "treaty": "inversion"},
		{"id": "tecnologia", "name": "Acuerdo tecnológico", "desc": "Tsaing ofrece fábricas de baterías y transferencia de tecnología.", "term": ["Empleos locales garantizados", 800.0, 9000.0, ""], "fx_min": {"economia": 1, "rel": {"tsaing": 8}}, "fx_max": {"economia": 4, "trabajadores": 4, "jovenes": 3, "rel": {"tsaing": 2}}, "treaty": "comercio"},
	],
	"sarvenia": [
		{"id": "rio", "name": "Reparto del río Seco", "desc": "Sarvenia construye una presa río arriba. Nuestros agricultores se quedan sin agua.", "term": ["Caudal garantizado para Valdoria", 25.0, 60.0, "%"], "fx_min": {"trabajadores": -3, "jubilados": -2, "rel": {"sarvenia": 8}}, "fx_max": {"trabajadores": 3, "ambiente": 3, "rel": {"sarvenia": -2}}, "flag": "rio_pactado"},
		{"id": "frontera", "name": "Cooperación fronteriza", "desc": "Patrullas conjuntas contra el contrabando... y los refugiados.", "term": ["Control compartido", 80.0, 30.0, "%"], "fx_min": {"seguridad": 2, "prestigio": -3, "rel": {"sarvenia": 10}}, "fx_max": {"seguridad": 4, "rel": {"sarvenia": 3}}, "flag": "frontera_pactada"},
	],
	"qadar": [
		{"id": "inversion", "name": "Fondo soberano de Qadar", "desc": "El Emir quiere invertir en nuestras empresas estratégicas.", "term": ["Inversión comprometida", 2000.0, 15000.0, " M€"], "fx_min": {"economia": 2, "rel": {"qadar": 8}}, "fx_max": {"economia": 5, "empresarios": 5, "rel": {"qadar": 2}}, "treaty": "inversion"},
		{"id": "petroleo", "name": "Suministro de petróleo", "desc": "Precio preferente de crudo a diez años.", "term": ["Descuento en el crudo", 3.0, 25.0, "%"], "fx_min": {"economia": 1, "rel": {"qadar": 6}}, "fx_max": {"economia": 4, "trabajadores": 2, "rel": {"qadar": 1}}, "treaty": "energia"},
	],
	"aldora": [
		{"id": "migracion", "name": "Control migratorio en el estrecho", "desc": "Aldora vigilará sus costas... si pagamos.", "term": ["Ayuda anual a Aldora", 1500.0, 250.0, " M€"], "fx_min": {"money": -1500, "rel": {"aldora": 10}, "clase_media": 3}, "fx_max": {"money": -250, "rel": {"aldora": 2}, "clase_media": 3}, "flag": "pacto_aldora"},
		{"id": "cooperacion", "name": "Cooperación al desarrollo", "desc": "Escuelas, pozos y hospitales en Aldora.", "term": ["Aportación valdoriana", 900.0, 150.0, " M€"], "fx_min": {"money": -900, "prestigio": 5, "jovenes": 3, "rel": {"aldora": 14}}, "fx_max": {"money": -150, "prestigio": 2, "rel": {"aldora": 4}}},
	],
}

# Tipos de crisis para la Sala de Crisis
const CRISES := {
	"migrantes": {"title": "Crisis migratoria en el Estrecho", "icon": "barco", "hot": [4, 8, 3, 7], "start": 2, "growth": 2.3, "spread": false, "spawn": 9.0,
		"desc": "Cientos de embarcaciones precarias cruzan el Estrecho desde Aldora. Hay que salvar vidas sin perder el control.",
		"dmg": "Personas en peligro", "dmg_k": 2.2,
		"units": [
			{"id": "guardia", "name": "Salvamento Marítimo", "icon": "ancla", "n": 3, "cost": 60, "power": 5.0, "fx": {}},
			{"id": "ong", "name": "Cruz Roja y ONG", "icon": "hospital", "n": 3, "cost": 30, "power": 3.5, "fx": {"jovenes": 0.8, "prestigio": 0.5, "clase_media": -0.4}},
			{"id": "acogida", "name": "Centros de acogida", "icon": "tienda", "n": 2, "cost": 150, "power": 6.0, "fx": {"prestigio": 0.4, "jubilados": -0.4}},
			{"id": "ejercito", "name": "Ejército: contención", "icon": "ejercito", "n": 2, "cost": 80, "power": 7.5, "fx": {"jovenes": -1.5, "prestigio": -1.5, "militares": 1.0, "clase_media": 0.8, "jubilados": 0.6}},
		],
		"good": {"prestigio": 4, "clase_media": 2, "bienestar": 1}, "bad": {"prestigio": -6, "clase_media": -6, "seguridad": -4, "estabilidad": -4, "jubilados": -4},
		"news_good": "El Gobierno gestiona con eficacia la llegada de migrantes al Estrecho", "news_bad": "Caos en el Estrecho: el Gobierno desbordado por la crisis migratoria"},
	"huelga_sanitaria": {"title": "Huelga en los hospitales", "icon": "hospital", "hot": [1, 2, 3, 4, 5, 6, 7, 8], "start": 3, "growth": 1.9, "spread": true, "spawn": 12.0,
		"desc": "Médicos y enfermeras paran los hospitales públicos. Las listas de espera se disparan y la huelga se extiende.",
		"dmg": "Operaciones canceladas", "dmg_k": 9.0,
		"units": [
			{"id": "mesa", "name": "Mesa de negociación", "icon": "mediador", "n": 3, "cost": 40, "power": 4.5, "fx": {"trabajadores": 0.6}},
			{"id": "minimos", "name": "Servicios mínimos", "icon": "documento", "n": 3, "cost": 0, "power": 5.5, "fx": {"trabajadores": -1.0, "estabilidad": -0.3}},
			{"id": "militar", "name": "Sanidad militar", "icon": "ejercito", "n": 2, "cost": 50, "power": 5.0, "fx": {"trabajadores": -0.8, "militares": 0.4}},
			{"id": "pluses", "name": "Pluses salariales", "icon": "dinero", "n": 2, "cost": 220, "power": 8.0, "fx": {"bienestar": 0.5, "trabajadores": 0.5}},
		],
		"good": {"bienestar": 3, "jubilados": 3, "trabajadores": 2}, "bad": {"bienestar": -8, "jubilados": -8, "clase_media": -5, "trabajadores": -4},
		"news_good": "Fin de la huelga sanitaria: acuerdo en los hospitales", "news_bad": "La huelga sanitaria deja miles de operaciones canceladas"},
	"incendios": {"title": "Incendios forestales", "icon": "fuego", "hot": [6, 5, 3, 2, 7], "start": 2, "growth": 3.0, "spread": true, "spawn": 10.0,
		"desc": "Una ola de calor y fuertes vientos han desatado incendios simultáneos. Cada segundo cuenta.",
		"dmg": "Hectáreas calcinadas", "dmg_k": 110.0,
		"units": [
			{"id": "bomberos", "name": "Bomberos forestales", "icon": "fuego", "n": 4, "cost": 40, "power": 5.0, "fx": {}},
			{"id": "aviones", "name": "Hidroaviones", "icon": "avion", "n": 2, "cost": 120, "power": 9.0, "fx": {}},
			{"id": "ume", "name": "Unidad Militar de Emergencias", "icon": "ejercito", "n": 2, "cost": 60, "power": 6.0, "fx": {"militares": 0.5}},
			{"id": "evac", "name": "Evacuación", "icon": "camion", "n": 3, "cost": 20, "power": 2.0, "protect": true, "fx": {"jubilados": 0.3}},
		],
		"good": {"ambiente": -1, "seguridad": 2, "clase_media": 2}, "bad": {"ambiente": -10, "seguridad": -3, "clase_media": -5, "trabajadores": -3, "jubilados": -3},
		"news_good": "Los incendios, controlados gracias a una respuesta rápida", "news_bad": "Valdoria arde: los incendios arrasan miles de hectáreas"},
	"disturbios": {"title": "Disturbios en las calles", "icon": "megafono", "hot": [1, 2, 3, 4, 5], "start": 2, "growth": 2.6, "spread": true, "spawn": 9.0,
		"desc": "Las protestas han degenerado en disturbios: barricadas, contenedores ardiendo y comercios saqueados.",
		"dmg": "Heridos y daños", "dmg_k": 2.5,
		"units": [
			{"id": "policia", "name": "Policía", "icon": "policia", "n": 4, "cost": 30, "power": 4.0, "fx": {}},
			{"id": "antidist", "name": "Antidisturbios", "icon": "escudo_x", "n": 2, "cost": 50, "power": 7.0, "fx": {"jovenes": -0.9, "prestigio": -0.3}},
			{"id": "mediador", "name": "Mediadores sociales", "icon": "mediador", "n": 3, "cost": 20, "power": 3.5, "fx": {"trabajadores": 0.4, "jovenes": 0.4}},
			{"id": "ejercito", "name": "Ejército en las calles", "icon": "ejercito", "n": 1, "cost": 80, "power": 11.0, "fx": {"jovenes": -3.0, "prestigio": -2.5, "estabilidad": -1.5, "militares": 1.0, "clase_media": -1.0}},
		],
		"good": {"seguridad": 3, "estabilidad": 3, "clase_media": 3}, "bad": {"seguridad": -8, "estabilidad": -8, "clase_media": -6, "empresarios": -4},
		"news_good": "Vuelve la calma a las calles tras días de tensión", "news_bad": "Noches de fuego: el Gobierno pierde el control de las calles"},
	"pandemia": {"title": "Brote epidémico", "icon": "virus", "hot": [1, 3, 4, 8, 2], "start": 1, "growth": 1.7, "spread": true, "spawn": 11.0,
		"desc": "Un nuevo virus respiratorio se propaga. Los hospitales empiezan a saturarse.",
		"dmg": "Contagios", "dmg_k": 55.0,
		"units": [
			{"id": "sanitarios", "name": "Equipos sanitarios", "icon": "medicos", "n": 4, "cost": 50, "power": 4.2, "fx": {}},
			{"id": "confina", "name": "Confinamiento local", "icon": "candado", "n": 2, "cost": 300, "power": 9.0, "fx": {"economia": -1.2, "jovenes": -0.8, "empresarios": -1.0}},
			{"id": "campana", "name": "Hospital de campaña", "icon": "tienda", "n": 2, "cost": 120, "power": 5.5, "fx": {"bienestar": 0.3}},
			{"id": "rastreo", "name": "Rastreadores", "icon": "lupa", "n": 3, "cost": 30, "power": 3.0, "fx": {}},
		],
		"good": {"bienestar": 3, "jubilados": 4, "prestigio": 2}, "bad": {"bienestar": -10, "jubilados": -8, "economia": -5, "clase_media": -4},
		"news_good": "El brote, contenido: Valdoria, ejemplo de gestión sanitaria", "news_bad": "El virus se descontrola y colapsa los hospitales"},
	"inundaciones": {"title": "Inundaciones catastróficas", "icon": "agua", "hot": [3, 4, 5, 1], "start": 3, "growth": 2.2, "spread": false, "spawn": 12.0,
		"desc": "Una gota fría histórica ha desbordado ríos. Pueblos enteros bajo el agua.",
		"dmg": "Damnificados", "dmg_k": 12.0,
		"units": [
			{"id": "rescate", "name": "Equipos de rescate", "icon": "ancla", "n": 3, "cost": 40, "power": 5.0, "fx": {}},
			{"id": "ume", "name": "Unidad Militar de Emergencias", "icon": "ejercito", "n": 2, "cost": 60, "power": 6.5, "fx": {"militares": 0.5}},
			{"id": "bombeo", "name": "Brigadas de bombeo", "icon": "agua", "n": 3, "cost": 30, "power": 4.0, "fx": {}},
			{"id": "evac", "name": "Evacuación", "icon": "camion", "n": 2, "cost": 20, "power": 2.0, "protect": true, "fx": {}},
		],
		"good": {"seguridad": 2, "clase_media": 3, "jubilados": 2}, "bad": {"economia": -4, "clase_media": -6, "jubilados": -5, "estabilidad": -3},
		"news_good": "Rescate ejemplar en las inundaciones", "news_bad": "Las inundaciones dejan un reguero de víctimas y críticas al Gobierno"},
	"terrorismo": {"title": "Amenaza terrorista", "icon": "alerta", "hot": [1, 2, 3, 4, 5, 6, 7, 8], "start": 3, "growth": 1.5, "spread": false, "spawn": 13.0, "hidden": true,
		"desc": "Los servicios de inteligencia detectan células activas preparando un atentado. Desconocemos dónde.",
		"dmg": "Riesgo de atentado", "dmg_k": 3.0,
		"units": [
			{"id": "intel", "name": "Inteligencia (CNI)", "icon": "ojo", "n": 3, "cost": 30, "power": 2.0, "reveal": true, "fx": {}},
			{"id": "policia", "name": "Policía", "icon": "policia", "n": 3, "cost": 30, "power": 4.5, "fx": {}},
			{"id": "geo", "name": "Fuerzas especiales", "icon": "escudo_x", "n": 2, "cost": 60, "power": 9.0, "fx": {}},
			{"id": "patrulla", "name": "Patrullas militares", "icon": "ejercito", "n": 2, "cost": 50, "power": 3.0, "fx": {"jovenes": -0.5, "estabilidad": 0.4}},
		],
		"good": {"seguridad": 6, "estabilidad": 4, "clase_media": 3}, "bad": {"seguridad": -12, "estabilidad": -8, "clase_media": -6, "jubilados": -6},
		"news_good": "Desarticulada una red terrorista que preparaba una masacre", "news_bad": "Atentado en Valdoria: el país, conmocionado"},
	"apagon": {"title": "Ciberataque y apagón", "icon": "rayo", "hot": [1, 2, 3, 4], "start": 3, "growth": 2.1, "spread": true, "spawn": 10.0,
		"desc": "Un ciberataque masivo ha tumbado la red eléctrica. Hospitales con generadores y ciudades a oscuras.",
		"dmg": "Hogares sin luz (miles)", "dmg_k": 4.0,
		"units": [
			{"id": "tecnicos", "name": "Técnicos de red", "icon": "tecnico", "n": 4, "cost": 40, "power": 5.0, "fx": {}},
			{"id": "ciber", "name": "Mando Ciberdefensa", "icon": "ojo", "n": 2, "cost": 60, "power": 7.0, "fx": {"militares": 0.3}},
			{"id": "generadores", "name": "Generadores móviles", "icon": "rayo", "n": 2, "cost": 80, "power": 4.0, "protect": true, "fx": {}},
			{"id": "ejercito", "name": "Ejército (logística)", "icon": "ejercito", "n": 2, "cost": 60, "power": 3.5, "fx": {"militares": 0.4}},
		],
		"good": {"seguridad": 3, "prestigio": 2}, "bad": {"economia": -5, "seguridad": -6, "clase_media": -5, "empresarios": -5},
		"news_good": "Restablecida la luz tras el ciberataque: el Gobierno apunta a Kharovia", "news_bad": "Días a oscuras: el apagón paraliza Valdoria"},
	"huelga_general": {"title": "Huelga general", "icon": "trabajadores", "hot": [2, 1, 4, 3, 5], "start": 3, "growth": 2.0, "spread": true, "spawn": 11.0,
		"desc": "Los sindicatos convocan huelga general. Fábricas, puertos y transportes, paralizados.",
		"dmg": "Pérdidas (M€)", "dmg_k": 7.0,
		"units": [
			{"id": "mediador", "name": "Mediadores", "icon": "mediador", "n": 3, "cost": 30, "power": 5.0, "fx": {"trabajadores": 0.6}},
			{"id": "concesion", "name": "Concesiones salariales", "icon": "dinero", "n": 2, "cost": 250, "power": 8.5, "fx": {"trabajadores": 1.0, "empresarios": -0.8}},
			{"id": "policia", "name": "Policía en piquetes", "icon": "policia", "n": 3, "cost": 30, "power": 3.2, "fx": {"trabajadores": -0.6}},
			{"id": "minimos", "name": "Servicios mínimos", "icon": "documento", "n": 2, "cost": 0, "power": 5.0, "fx": {"trabajadores": -1.0, "estabilidad": -0.4}},
		],
		"good": {"estabilidad": 3, "trabajadores": 3, "economia": 1}, "bad": {"economia": -6, "estabilidad": -6, "empresarios": -6, "trabajadores": -3},
		"news_good": "Desconvocada la huelga general tras un acuerdo", "news_bad": "La huelga general paraliza el país y hunde la economía"},
	"golpe": {"title": "¡Intento de golpe de Estado!", "icon": "ejercito", "hot": [1, 2, 7, 6], "start": 2, "growth": 3.0, "spread": true, "spawn": 8.0, "fatal": true,
		"desc": "Unidades militares rebeldes toman posiciones. Si caen la capital y otras regiones clave, caerá tu gobierno.",
		"dmg": "Control rebelde", "dmg_k": 2.0,
		"units": [
			{"id": "guardia", "name": "Guardia Republicana", "icon": "escudo_x", "n": 3, "cost": 50, "power": 6.5, "fx": {}},
			{"id": "policia", "name": "Policía leal", "icon": "policia", "n": 3, "cost": 30, "power": 4.0, "fx": {}},
			{"id": "pueblo", "name": "Llamamiento ciudadano", "icon": "megafono", "n": 2, "cost": 0, "power": 5.0, "fx": {"estabilidad": 0.8, "jovenes": 0.5}},
			{"id": "negociar", "name": "Negociar con mandos", "icon": "mediador", "n": 2, "cost": 100, "power": 4.0, "fx": {"militares": 1.0}},
		],
		"good": {"estabilidad": 10, "prestigio": 6, "militares": -10}, "bad": {"estabilidad": -40},
		"news_good": "Fracasa el golpe: la democracia resiste", "news_bad": "Golpe de Estado en Valdoria"},
	"guerra": {"title": "Incursión militar de Sarvenia", "icon": "ejercito", "hot": [7, 6, 5], "start": 2, "growth": 2.7, "spread": true, "spawn": 10.0,
		"desc": "Tropas sarvenias cruzan la frontera por el río Seco. Hay que repeler la incursión y proteger a los civiles.",
		"dmg": "Bajas y daños", "dmg_k": 2.0,
		"units": [
			{"id": "ejercito", "name": "Brigadas acorazadas", "icon": "ejercito", "n": 4, "cost": 100, "power": 7.0, "fx": {"militares": 0.5}},
			{"id": "aviacion", "name": "Aviación", "icon": "avion", "n": 2, "cost": 200, "power": 10.0, "fx": {}},
			{"id": "diplomacia", "name": "Mediación internacional", "icon": "prestigio", "n": 2, "cost": 0, "power": 3.0, "fx": {"prestigio": 0.6}},
			{"id": "evac", "name": "Evacuación de civiles", "icon": "camion", "n": 3, "cost": 20, "power": 1.5, "protect": true, "fx": {}},
		],
		"good": {"militares": 8, "prestigio": 6, "estabilidad": 6, "seguridad": 5, "rel": {"sarvenia": -20}}, "bad": {"militares": -6, "estabilidad": -10, "seguridad": -10, "economia": -5, "prestigio": -6},
		"news_good": "Valdoria repele la incursión sarvenia", "news_bad": "Sarvenia ocupa parte de la Frontera tras una ofensiva relámpago"},
}
