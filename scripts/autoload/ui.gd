extends Node
## Estilo global: paleta, tipografías, tema, iconos y utilidades de formato.

const NAVY := Color("0a111d")
const NAVY2 := Color("111c2e")
const NAVY3 := Color("1a2a43")
const PANEL := Color(0.05, 0.075, 0.12, 0.96)
const GOLD := Color("c9a55c")
const GOLD_L := Color("ecd49a")
const GOLD_D := Color("8a6d33")
const CREAM := Color("f3ead6")
const PAPER := Color("efe4cc")
const INK := Color("2b2319")
const TEXT := Color("ebe6da")
const DIM := Color("9aa4b5")
const RED := Color("d9483b")
const RED_D := Color("8e2a22")
const GREEN := Color("47b574")
const GREEN_D := Color("25704a")
const BLUE := Color("4f8fe0")
const AMBER := Color("e5a93a")

const MONTHS := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
const MONTHS_SHORT := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
const WEEKDAYS := ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]

var f_serif: Font
var f_serif_b: Font
var f_serif_k: Font
var f_sans: Font
var f_sans_m: Font
var f_sans_b: Font
var f_cond: Font
var f_cond_b: Font
var f_mono: Font
var f_type: Font
var f_hand: Font
var f_goth: Font
var f_sign: Font
## Playfair con cifras alineadas (las cifras "antiguas" bailan de altura en los marcadores)
var f_num: Font
var f_num_r: Font
var theme: Theme

var _icon_cache := {}
var _start_unix := 0

const ICONS := {
	"economia": "<path d='M3 3v18h18'/><path d='M7 15l4-4 3 3 6-6'/><path d='M16 8h4v4'/>",
	"bienestar": "<path d='M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z'/>",
	"seguridad": "<path d='M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'/>",
	"estabilidad": "<path d='M2 21h20M4 18h16M6 18v-7M10 18v-7M14 18v-7M18 18v-7M3 11h18L12 4z'/>",
	"prestigio": "<circle cx='12' cy='12' r='10'/><path d='M2 12h20'/><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'/>",
	"ambiente": "<path d='M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.5 19 2c1 2 2 4.2 2 8 0 5.5-4.8 10-10 10z'/><path d='M2 21c0-3 1.9-5.4 5.1-6C9.5 14.5 12 13 13 12'/>",
	"dinero": "<circle cx='12' cy='12' r='9'/><path d='M15.5 8.5A4 4 0 1 0 15.5 15.5'/><path d='M6.5 10.5h7M6.5 13.5h7'/>",
	"capital": "<path d='M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z'/>",
	"aprobacion": "<circle cx='9' cy='7' r='4'/><path d='M2 21v-2a4 4 0 0 1 4-4h6a4 4 0 0 1 4 4v2'/><path d='M16 3.1a4 4 0 0 1 0 7.8'/><path d='M22 21v-2a4 4 0 0 0-3-3.9'/>",
	"trabajadores": "<path d='M2 18h20'/><path d='M4 18v-3a8 8 0 0 1 16 0v3'/><path d='M10 7V5h4v2'/><path d='M12 7v4'/>",
	"empresarios": "<rect x='2' y='7' width='20' height='14' rx='2'/><path d='M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2'/><path d='M2 13h20'/>",
	"clase_media": "<path d='M3 10l9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z'/><path d='M9 21v-7h6v7'/>",
	"jovenes": "<path d='M22 10L12 5 2 10l10 5 10-5z'/><path d='M6 12v5c3 2.5 9 2.5 12 0v-5'/>",
	"jubilados": "<circle cx='11' cy='4' r='2'/><path d='M9 22l1.5-8-3-3 2-4h3l3 4'/><path d='M17 12v10'/><path d='M17 12a2 2 0 0 1 2-2'/>",
	"militares": "<circle cx='12' cy='15' r='6'/><path d='M8.5 10L6 2h4l2 5 2-5h4l-2.5 8'/>",
	"prensa": "<path d='M4 22h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-4 0v-9h4'/><path d='M10 6h6M10 10h6M10 14h6M10 18h4'/>",
	"telefono": "<path d='M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z'/>",
	"documento": "<path d='M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'/><path d='M14 2v6h6'/><path d='M16 13H8M16 17H8M10 9H8'/>",
	"alerta": "<path d='M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z'/><path d='M12 9v4M12 17h.01'/>",
	"pausa": "<rect x='6' y='4' width='4' height='16' rx='1' fill='#fff' stroke='none'/><rect x='14' y='4' width='4' height='16' rx='1' fill='#fff' stroke='none'/>",
	"play": "<path d='M7 4l13 8-13 8z' fill='#fff' stroke='none'/>",
	"ff": "<path d='M3 5l9 7-9 7zM12 5l9 7-9 7z' fill='#fff' stroke='none'/>",
	"fff": "<path d='M1 6l7 6-7 6zM8.5 6l7 6-7 6zM16 6l7 6-7 6z' fill='#fff' stroke='none'/>",
	"check": "<path d='M20 6L9 17l-5-5'/>",
	"cruz": "<path d='M18 6L6 18M6 6l12 12'/>",
	"fuego": "<path d='M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.4-.5-2-1-3-1.1-2.1-.2-4.1 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.2.4-2.3 1-3.3.3 1.5 1.2 2.8 2.5 2.8z'/>",
	"virus": "<circle cx='12' cy='12' r='5'/><path d='M12 2v5M12 17v5M2 12h5M17 12h5M4.9 4.9l3.5 3.5M15.6 15.6l3.5 3.5M4.9 19.1l3.5-3.5M15.6 8.4l3.5-3.5'/>",
	"barco": "<path d='M2 20c2 1 4 1 6 0s4-1 6 0 4 1 6 0'/><path d='M4 16l-1-5h18l-1 5'/><path d='M12 11V3l5 4-5 1'/>",
	"megafono": "<path d='M3 11l15-6v14L3 13z'/><path d='M11.6 16.8a3 3 0 1 1-5.8-1.6'/>",
	"agua": "<path d='M12 2.7l5.7 5.7a8 8 0 1 1-11.3 0z'/>",
	"rayo": "<path d='M13 2L3 14h9l-1 8 10-12h-9z'/>",
	"hospital": "<rect x='3' y='3' width='18' height='18' rx='3'/><path d='M12 8v8M8 12h8'/>",
	"policia": "<path d='M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'/><path d='M12 7.5l1.3 2.6 2.8.4-2 2 .5 2.8-2.6-1.4-2.6 1.4.5-2.8-2-2 2.8-.4z'/>",
	"ejercito": "<circle cx='12' cy='12' r='9'/><path d='M12 6.5l1.6 3.3 3.6.5-2.6 2.5.6 3.6-3.2-1.7-3.2 1.7.6-3.6-2.6-2.5 3.6-.5z'/>",
	"medicos": "<path d='M8 2v4M16 2v4'/><rect x='4' y='4' width='16' height='18' rx='2'/><path d='M12 10v6M9 13h6'/>",
	"mediador": "<path d='M21 11.5a8.4 8.4 0 0 1-9 8.4 8.5 8.5 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6A8.4 8.4 0 0 1 12.5 3h.5a8.5 8.5 0 0 1 8 8z'/>",
	"ancla": "<circle cx='12' cy='5' r='3'/><path d='M12 22V8'/><path d='M5 12H2a10 10 0 0 0 20 0h-3'/>",
	"ojo": "<path d='M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z'/><circle cx='12' cy='12' r='3'/>",
	"avion": "<path d='M17.8 19.2L16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z'/>",
	"tecnico": "<rect x='5' y='5' width='14' height='14' rx='2'/><rect x='9' y='9' width='6' height='6'/><path d='M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3'/>",
	"tienda": "<path d='M3.5 21L12 3l8.5 18z'/><path d='M12 13l-4 8M12 13l4 8'/>",
	"camion": "<rect x='1' y='3' width='15' height='13'/><path d='M16 8h4l3 3v5h-7z'/><circle cx='5.5' cy='18.5' r='2.5'/><circle cx='18.5' cy='18.5' r='2.5'/>",
	"mazo": "<path d='M14 13l-7.5 7.5a2.1 2.1 0 0 1-3-3L11 10'/><path d='M16 16l6-6M8 8l6-6M9 7l8 8M21 11l-8-8'/>",
	"calendario": "<rect x='3' y='4' width='18' height='18' rx='2'/><path d='M16 2v4M8 2v4M3 10h18'/>",
	"microfono": "<path d='M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3z'/><path d='M19 10v2a7 7 0 0 1-14 0v-2'/><path d='M12 19v3M8 22h8'/>",
	"tv": "<rect x='2' y='7' width='20' height='15' rx='2'/><path d='M17 2l-5 5-5-5'/>",
	"grafico": "<path d='M12 20V10M18 20V4M6 20v-4'/>",
	"ley": "<path d='M4 19.5A2.5 2.5 0 0 1 6.5 17H20'/><path d='M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z'/>",
	"reloj": "<circle cx='12' cy='12' r='10'/><path d='M12 6v6l4 2'/>",
	"lupa": "<circle cx='11' cy='11' r='8'/><path d='M21 21l-4.4-4.4'/>",
	"arriba": "<path d='M12 19V5M5 12l7-7 7 7'/>",
	"abajo": "<path d='M12 5v14M19 12l-7 7-7-7'/>",
	"estres": "<path d='M22 12h-4l-3 9L9 3l-3 9H2'/>",
	"salir": "<path d='M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'/><path d='M16 17l5-5-5-5M21 12H9'/>",
	"ajustes": "<circle cx='12' cy='12' r='3'/><path d='M12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1'/>",
	"bandera": "<path d='M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z'/><path d='M4 22v-7'/>",
	"sonrisa": "<circle cx='12' cy='12' r='10'/><path d='M8 14s1.5 2 4 2 4-2 4-2'/><path d='M9 9h.01M15 9h.01'/>",
	"presion": "<path d='M6 9l6-6 6 6M6 15l6-6 6 6M6 21l6-6 6 6'/>",
	"ceder": "<path d='M9 14l-5-5 5-5'/><path d='M20 20v-7a4 4 0 0 0-4-4H4'/>",
	"acuerdo": "<path d='M22 11.1V12a10 10 0 1 1-5.9-9.1'/><path d='M22 4L12 14l-3-3'/>",
	"votar": "<path d='M9 12l2 2 4-4'/><path d='M5 7c0-1.1.9-2 2-2h10a2 2 0 0 1 2 2v12H5z'/><path d='M22 19H2'/>",
	"info": "<circle cx='12' cy='12' r='10'/><path d='M12 16v-4M12 8h.01'/>",
	"sello": "<path d='M5 22h14'/><path d='M19 17H5v-3a2 2 0 0 1 2-2h3l1-4a3 3 0 1 1 2 0l1 4h3a2 2 0 0 1 2 2z'/>",
	"pluma": "<path d='M12 20h9'/><path d='M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z'/>",
	"mapa": "<path d='M1 6v16l7-4 8 4 7-4V2l-7 4-8-4z'/><path d='M8 2v16M16 6v16'/>",
	"fabrica": "<path d='M2 20h20V9l-6 4V9l-6 4V4H2z'/>",
	"guardar": "<path d='M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z'/><path d='M17 21v-8H7v8M7 3v5h8'/>",
	"libro": "<path d='M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z'/><path d='M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z'/>",
	"candado": "<rect x='3' y='11' width='18' height='11' rx='2'/><path d='M7 11V7a5 5 0 0 1 10 0v4'/>",
	"escudo_x": "<path d='M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'/><path d='M9.5 9.5l5 5M14.5 9.5l-5 5'/>",
	"corazon_roto": "<path d='M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z'/><path d='M12 5.7l-2 4 3 2-2 4'/>",
	"tren": "<rect x='4' y='3' width='16' height='13' rx='2'/><path d='M4 11h16M12 3v8M8 19l-2 3M16 19l2 3'/><path d='M8 16h.01M16 16h.01'/>",
	"sol": "<circle cx='12' cy='12' r='5'/><path d='M12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4'/>",
	"movil": "<rect x='6' y='2' width='12' height='20' rx='2.5'/><line x1='10.5' y1='18.5' x2='13.5' y2='18.5'/>",
	"cafe": "<path d='M18 8h1a4 4 0 0 1 0 8h-1'/><path d='M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z'/><path d='M6 1v3M10 1v3M14 1v3'/>",
	"laurel": "<path d='M12 21c-4-2-7-6-7-11'/><path d='M12 21c4-2 7-6 7-11'/><path d='M5 10c-1.5-1-2-3-1.5-4.5 1.5.5 2.5 2 1.5 4.5zM6 14c-2-.5-3-2-3-3.5 1.5 0 3 1.2 3 3.5zM19 10c1.5-1 2-3 1.5-4.5-1.5.5-2.5 2-1.5 4.5zM18 14c2-.5 3-2 3-3.5-1.5 0-3 1.2-3 3.5z' fill='#fff'/>",
	"lingote": "<path d='M2 19l3-7h14l3 7z' fill='#fff' fill-opacity='0.25'/><path d='M2 19l3-7h14l3 7z'/><path d='M7 12l2-5h6l2 5'/>",
	"shop": "<path d='M3 9l1.5-5h15L21 9'/><path d='M3 9h18v2a3 3 0 0 1-6 0 3 3 0 0 1-6 0 3 3 0 0 1-6 0z'/><path d='M5 13v8h14v-8'/><path d='M10 21v-5h4v5'/>",
	"trofeo":"<path d='M6 9H4.5a2.5 2.5 0 0 1 0-5H6M18 9h1.5a2.5 2.5 0 0 0 0-5H18'/><path d='M4 22h16M10 14.7V17c0 .6-.5 1-1 1.2-1.2.5-2 2-2 3.8M14 14.7V17c0 .6.5 1 1 1.2 1.2.5 2 2 2 3.8'/><path d='M18 2H6v7a6 6 0 0 0 12 0z'/>",
}


func _ready() -> void:
	_start_unix = Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	_load_fonts()
	_build_theme()


func _font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


func _var(base: Font, wght: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": wght}
	return fv


func _load_fonts() -> void:
	var playfair := _font("res://fonts/PlayfairDisplay.ttf")
	var inter := _font("res://fonts/Inter.ttf")
	var oswald := _font("res://fonts/Oswald.ttf")
	f_serif = _var(playfair, 400)
	f_serif_b = _var(playfair, 700)
	f_serif_k = _var(playfair, 900)
	f_sans = _var(inter, 400)
	f_sans_m = _var(inter, 550)
	f_sans_b = _var(inter, 700)
	f_cond = _var(oswald, 500)
	f_cond_b = _var(oswald, 700)
	f_mono = _font("res://fonts/ShareTechMono.ttf")
	f_type = _font("res://fonts/SpecialElite.ttf")
	f_hand = _var(_font("res://fonts/Caveat.ttf"), 600)
	f_goth = _font("res://fonts/UnifrakturMaguntia.ttf")
	f_sign = _font("res://fonts/MrsSaintDelafield.ttf")
	f_num = _lining(playfair, 700)
	f_num_r = _lining(playfair, 400)


func _lining(base: Font, wght: int) -> FontVariation:
	var fv := _var(base, wght)
	var ts := TextServerManager.get_primary_interface()
	fv.opentype_features = {ts.name_to_tag("lnum"): 1, ts.name_to_tag("pnum"): 1}
	return fv


# ------------------------------------------------------------------ estilos

func sb(bg: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0, shadow: int = 0, margin: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.35)
	if margin >= 0:
		s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = f_sans
	theme.default_font_size = 20
	# Botones
	var bn := sb(Color(0.09, 0.13, 0.2, 0.92), 6, Color(GOLD_D, 0.7), 1)
	bn.content_margin_left = 20
	bn.content_margin_right = 20
	bn.content_margin_top = 10
	bn.content_margin_bottom = 10
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color(0.14, 0.19, 0.29, 0.96)
	bh.border_color = GOLD
	var bp: StyleBoxFlat = bn.duplicate()
	bp.bg_color = Color(0.2, 0.17, 0.1, 0.96)
	bp.border_color = GOLD_L
	var bd: StyleBoxFlat = bn.duplicate()
	bd.bg_color = Color(0.1, 0.11, 0.13, 0.6)
	bd.border_color = Color(0.3, 0.3, 0.3, 0.4)
	theme.set_stylebox("normal", "Button", bn)
	theme.set_stylebox("hover", "Button", bh)
	theme.set_stylebox("pressed", "Button", bp)
	theme.set_stylebox("disabled", "Button", bd)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD_L)
	theme.set_color("font_pressed_color", "Button", GOLD_L)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.6))
	theme.set_font("font", "Button", f_sans_m)
	theme.set_font_size("font_size", "Button", 20)
	# Etiquetas
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font("normal_font", "RichTextLabel", f_sans)
	theme.set_font("bold_font", "RichTextLabel", f_sans_b)
	theme.set_font("italics_font", "RichTextLabel", f_serif)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	# Paneles
	theme.set_stylebox("panel", "PanelContainer", sb(PANEL, 10, Color(GOLD_D, 0.5), 1, 12, 18))
	theme.set_stylebox("panel", "Panel", sb(PANEL, 10, Color(GOLD_D, 0.5), 1))
	# LineEdit
	var le := sb(Color(0.04, 0.06, 0.1, 0.95), 6, Color(GOLD_D, 0.8), 1)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	var lef: StyleBoxFlat = le.duplicate()
	lef.border_color = GOLD
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_stylebox("focus", "LineEdit", lef)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", GOLD_L)
	theme.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	theme.set_font_size("font_size", "LineEdit", 24)
	# Sliders
	var track := sb(Color(0.03, 0.05, 0.08, 1.0), 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := sb(GOLD_D, 4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", sb(GOLD, 4))
	theme.set_icon("grabber", "HSlider", _circle_tex(22, GOLD_L, NAVY))
	theme.set_icon("grabber_highlight", "HSlider", _circle_tex(22, Color.WHITE, NAVY))
	# Scroll
	var sc := sb(Color(1, 1, 1, 0.04), 4)
	var gr := sb(Color(GOLD, 0.45), 4)
	var grh := sb(Color(GOLD, 0.75), 4)
	for n in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", n, sc)
		theme.set_stylebox("grabber", n, gr)
		theme.set_stylebox("grabber_highlight", n, grh)
		theme.set_stylebox("grabber_pressed", n, grh)
	# Tooltips
	theme.set_stylebox("panel", "TooltipPanel", sb(Color(0.03, 0.05, 0.09, 0.97), 6, GOLD_D, 1, 6, 10))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	# CheckButton / CheckBox
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", GOLD_L)
	theme.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())


func _circle_tex(size: int, col: Color, ring: Color) -> Texture2D:
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'><circle cx='%f' cy='%f' r='%f' fill='#%s' stroke='#%s' stroke-width='3'/></svg>" % [size, size, size / 2.0, size / 2.0, size / 2.0 - 2.0, col.to_html(false), ring.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)


func svg_tex(svg: String, scale: float = 1.0) -> Texture2D:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_warning("SVG inválido")
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func icon(name: String, size: int = 48) -> Texture2D:
	var key := "%s_%d" % [name, size]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var inner: String = ICONS.get(name, ICONS["info"])
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 24 24' fill='none' stroke='#ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [size, size, inner]
	var tex := svg_tex(svg)
	_icon_cache[key] = tex
	return tex


# ------------------------------------------------------------------ nodos

func lbl(text: String, font: Font = null, size: int = 20, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func rich(text: String, size: int = 20, color: Color = TEXT, font: Font = null, bold: Font = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	if font != null:
		r.add_theme_font_override("normal_font", font)
	if bold != null:
		r.add_theme_font_override("bold_font", bold)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = text
	return r


func btn(text: String, kind: String = "normal", size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)
	match kind:
		"gold":
			var n := sb(GOLD, 6, GOLD_L, 1)
			_pad(n, 26, 12)
			var h := sb(GOLD_L, 6, Color.WHITE, 1)
			_pad(h, 26, 12)
			var p := sb(GOLD_D, 6, GOLD, 1)
			_pad(p, 26, 12)
			var d := sb(Color(0.35, 0.32, 0.25, 0.6), 6)
			_pad(d, 26, 12)
			b.add_theme_stylebox_override("normal", n)
			b.add_theme_stylebox_override("hover", h)
			b.add_theme_stylebox_override("pressed", p)
			b.add_theme_stylebox_override("disabled", d)
			b.add_theme_color_override("font_color", NAVY)
			b.add_theme_color_override("font_hover_color", NAVY)
			b.add_theme_color_override("font_pressed_color", NAVY)
			b.add_theme_color_override("font_disabled_color", Color(0.2, 0.2, 0.2))
			b.add_theme_font_override("font", f_sans_b)
		"danger":
			var n2 := sb(Color(0.45, 0.1, 0.08, 0.95), 6, RED, 1)
			_pad(n2, 22, 10)
			var h2 := sb(Color(0.6, 0.15, 0.12, 0.98), 6, Color("ff8a7a"), 1)
			_pad(h2, 22, 10)
			b.add_theme_stylebox_override("normal", n2)
			b.add_theme_stylebox_override("hover", h2)
			b.add_theme_stylebox_override("pressed", n2)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
		"ghost":
			var n3 := StyleBoxFlat.new()
			n3.bg_color = Color(0, 0, 0, 0)
			_pad(n3, 14, 8)
			var h3 := sb(Color(1, 1, 1, 0.06), 6)
			_pad(h3, 14, 8)
			b.add_theme_stylebox_override("normal", n3)
			b.add_theme_stylebox_override("hover", h3)
			b.add_theme_stylebox_override("pressed", h3)
			b.add_theme_stylebox_override("disabled", n3)
	b.mouse_entered.connect(func(): Sfx.play("hover", -8.0))
	b.pressed.connect(func(): Sfx.play("click", -3.0, 1.0, 0.05))
	return b


func _pad(s: StyleBoxFlat, h: int, v: int) -> void:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v


func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if child != null:
		m.add_child(child)
	return m


func panel(bg: Color = PANEL, radius: int = 10, border: Color = Color(GOLD_D, 0.55), pad: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, radius, border, 1, 14, pad))
	return p


func icon_rect(name: String, size: int, color: Color = TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name, size * 2)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func spacer(w: float = 0.0, h: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


# ------------------------------------------------------------------ formato

func num(v: float, dec: int = 0) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var ip := int(floor(a))
	var fp := a - ip
	var s := str(ip)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	if dec > 0:
		var frac := str(int(round(fp * pow(10, dec)))).pad_zeros(dec)
		if frac.length() > dec:
			# redondeo que desborda
			return num((ip + 1) * (-1 if neg else 1), dec)
		out += "," + frac
	return ("−" if neg else "") + out


func money(m: float, show_sign: bool = false) -> String:
	var sgn := ""
	if show_sign and m > 0:
		sgn = "+"
	if absf(m) >= 1000.0:
		return sgn + num(m / 1000.0, 1) + " mil M€"
	return sgn + num(m, 0) + " M€"


func pct(v: float, dec: int = 1) -> String:
	return num(v, dec) + "%"


func signed(v: float, dec: int = 0) -> String:
	if v > 0:
		return "+" + num(v, dec)
	return num(v, dec)


func date_dict(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(_start_unix + day * 86400)


func date_long(day: int) -> String:
	var d := date_dict(day)
	return "%s, %d de %s de %d" % [WEEKDAYS[d["weekday"]], d["day"], MONTHS[d["month"] - 1], d["year"]]


func date_mid(day: int) -> String:
	var d := date_dict(day)
	return "%d de %s de %d" % [d["day"], MONTHS[d["month"] - 1], d["year"]]


func date_short(day: int) -> String:
	var d := date_dict(day)
	return "%02d %s %d" % [d["day"], MONTHS_SHORT[d["month"] - 1], d["year"]]


func month_year(day: int) -> String:
	var d := date_dict(day)
	return "%s %d" % [MONTHS[d["month"] - 1].capitalize(), d["year"]]


# ------------------------------------------------------------------ animación

func pop_in(c: CanvasItem, dur: float = 0.35) -> void:
	c.modulate.a = 0.0
	if c is Control:
		var ctrl := c as Control
		ctrl.pivot_offset = ctrl.size * 0.5
		ctrl.scale = Vector2(0.94, 0.94)
		var t := ctrl.create_tween().set_parallel(true)
		t.tween_property(ctrl, "modulate:a", 1.0, dur)
		t.tween_property(ctrl, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		c.create_tween().tween_property(c, "modulate:a", 1.0, dur)


func fade(c: CanvasItem, to: float, dur: float = 0.3) -> Tween:
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", to, dur)
	return t


func color_for(v: float) -> Color:
	# rojo (0) -> ámbar (50) -> verde (100)
	if v < 50.0:
		return RED.lerp(AMBER, v / 50.0)
	return AMBER.lerp(GREEN, (v - 50.0) / 50.0)
