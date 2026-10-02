extends Control
## Retrato procedural: base vectorial (SVG generado) + rasgos dinámicos (ojos, cejas, boca, gafas).
## Espacio de dibujo de referencia: 400 x 480.

const W := preload("res://scripts/data/world_data.gd")
const REF := Vector2(400, 480)
static var _cache := {}

var look: Dictionary = {}
var mood := 0.0
var _mood := 0.0
var talking := false
var anger := 0.0
var _anger := 0.0
var surprise := 0.0
var track_mouse := true
var breathe := true
var _tex: Texture2D
var _t := 0.0
var _blink := 0.0
var _blink_timer := 2.5
var _mouth := 0.0
var _look_off := Vector2.ZERO
var _skin := Color.WHITE
var _hair := Color.BLACK
var _eye := Color.BLACK
var _lip := Color.BLACK
var _hi_res := true


func setup(l: Dictionary, hi_res: bool = true) -> void:
	look = _defaults(l)
	_hi_res = hi_res
	_skin = Color(W.SKIN[clampi(int(look["skin"]), 0, 5)])
	_hair = Color(W.HAIR_COL[clampi(int(look["hc"]), 0, 6)])
	_eye = Color(look["eyes"])
	_lip = _skin.darkened(0.28).lerp(Color("b0504f"), 0.45 if look["g"] == "f" else 0.2)
	_tex = texture_for(look, 1.4 if hi_res else 0.6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


static func _defaults(l: Dictionary) -> Dictionary:
	var d := {"g": "m", "skin": 1, "hair": "short", "hc": 1, "glasses": 0, "suit": "243653", "shirt": "f2f2f2", "tie": "7a1f2b", "age": 1, "beard": "none", "eyes": "3b2a20", "uniform": false}
	for k in l.keys():
		d[k] = l[k]
	if d["g"] == "f" and not l.has("tie"):
		d["tie"] = ""
	return d


static func texture_for(l: Dictionary, scale: float) -> Texture2D:
	var key := JSON.stringify(l) + str(scale)
	if _cache.has(key):
		return _cache[key]
	var svg := build_svg(l)
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


static func build_svg(l: Dictionary) -> String:
	var skin := Color(W.SKIN[clampi(int(l["skin"]), 0, 5)])
	var skin_d := skin.darkened(0.16)
	var skin_dd := skin.darkened(0.3)
	var skin_l := skin.lightened(0.1)
	var hair := Color(W.HAIR_COL[clampi(int(l["hc"]), 0, 6)])
	var hair_d := hair.darkened(0.3)
	var hair_l := hair.lightened(0.18)
	var suit := Color(l["suit"])
	var suit_d := suit.darkened(0.3)
	var suit_l := suit.lightened(0.12)
	var shirt := Color(l["shirt"])
	var g: String = l["g"]
	var style: String = l["hair"]
	var age := int(l["age"])
	var uniform: bool = l.get("uniform", false)
	var s := PackedStringArray()
	s.append("<svg xmlns='http://www.w3.org/2000/svg' width='400' height='480' viewBox='0 0 400 480'>")
	s.append("<defs>")
	s.append("<radialGradient id='face' cx='42%%' cy='36%%' r='70%%'><stop offset='0' stop-color='%s'/><stop offset='0.65' stop-color='%s'/><stop offset='1' stop-color='%s'/></radialGradient>" % [_hex(skin_l), _hex(skin), _hex(skin_d)])
	s.append("<linearGradient id='suit' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='%s'/><stop offset='1' stop-color='%s'/></linearGradient>" % [_hex(suit_l), _hex(suit_d)])
	s.append("<linearGradient id='hair' x1='0' y1='0' x2='0.3' y2='1'><stop offset='0' stop-color='%s'/><stop offset='1' stop-color='%s'/></linearGradient>" % [_hex(hair_l), _hex(hair_d)])
	s.append("<linearGradient id='neck' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='%s'/><stop offset='1' stop-color='%s'/></linearGradient>" % [_hex(skin_dd), _hex(skin_d)])
	s.append("</defs>")
	# pelo trasero
	var hb := _hair_back(style, g)
	if hb != "":
		s.append("<path d='%s' fill='url(#hair)'/>" % hb)
	# cuello
	s.append("<path d='M168 280 L166 360 Q200 384 234 360 L232 280 Z' fill='url(#neck)'/>")
	# torso
	s.append("<path d='M28 480 L30 440 Q36 388 104 368 L166 346 Q200 372 234 346 L296 368 Q364 388 370 440 L372 480 Z' fill='url(#suit)'/>")
	if uniform:
		s.append("<path d='M166 346 L200 400 L234 346 Q200 372 166 346 Z' fill='%s'/>" % _hex(shirt))
		s.append("<path d='M190 358 L210 358 L206 410 L200 418 L194 410 Z' fill='#2b2f22'/>")
		s.append("<path d='M166 346 L140 364 L186 420 L200 402 Z' fill='%s'/><path d='M234 346 L260 364 L214 420 L200 402 Z' fill='%s'/>" % [_hex(suit_d), _hex(suit_d)])
		s.append("<rect x='78' y='372' width='66' height='14' rx='4' fill='#c9a55c'/><rect x='256' y='372' width='66' height='14' rx='4' fill='#c9a55c'/>")
		s.append("<rect x='96' y='410' width='16' height='10' fill='#b8262e'/><rect x='114' y='410' width='16' height='10' fill='#2d5a9e'/><rect x='132' y='410' width='16' height='10' fill='#e9c46a'/>")
		s.append("<rect x='96' y='424' width='16' height='10' fill='#3a9d5d'/><rect x='114' y='424' width='16' height='10' fill='#e9c46a'/>")
		s.append("<rect x='150' y='352' width='14' height='8' fill='#e9c46a'/><rect x='236' y='352' width='14' height='8' fill='#e9c46a'/>")
	else:
		var tie: String = l.get("tie", "")
		if g == "m" or tie != "":
			s.append("<path d='M166 346 L200 430 L234 346 Q200 372 166 346 Z' fill='%s'/>" % _hex(shirt))
			if tie != "":
				var tc := Color(tie)
				s.append("<path d='M190 364 L210 364 L214 380 L205 446 L200 454 L195 446 L186 380 Z' fill='%s'/>" % _hex(tc))
				s.append("<path d='M189 358 L211 358 L207 376 L193 376 Z' fill='%s'/>" % _hex(tc.darkened(0.25)))
			s.append("<path d='M166 346 L146 366 L184 436 L198 450 L180 380 Z' fill='%s'/>" % _hex(suit_d))
			s.append("<path d='M234 346 L254 366 L216 436 L202 450 L220 380 Z' fill='%s'/>" % _hex(suit_d))
		else:
			s.append("<path d='M168 346 Q200 410 232 346 Q200 372 168 346 Z' fill='%s'/>" % _hex(shirt))
			s.append("<path d='M160 350 L150 366 L188 426 L200 416 Z' fill='%s'/><path d='M240 350 L250 366 L212 426 L200 416 Z' fill='%s'/>" % [_hex(suit_d), _hex(suit_d)])
			if age >= 1:
				for i in 9:
					var a := PI * (0.18 + i * 0.08)
					s.append("<circle cx='%f' cy='%f' r='4' fill='#f3ead6' stroke='#c9b89a' stroke-width='0.8'/>" % [200.0 - cos(a) * 30.0, 352.0 + sin(a) * 34.0])
		s.append("<rect x='70' y='420' width='40' height='6' rx='3' fill='%s' opacity='0.35'/>" % _hex(suit_l))
	# orejas
	s.append("<ellipse cx='117' cy='212' rx='13' ry='22' fill='%s'/><ellipse cx='283' cy='212' rx='13' ry='22' fill='%s'/>" % [_hex(skin_d), _hex(skin_d)])
	s.append("<ellipse cx='119' cy='213' rx='6' ry='12' fill='%s'/><ellipse cx='281' cy='213' rx='6' ry='12' fill='%s'/>" % [_hex(skin_dd), _hex(skin_dd)])
	# cabeza
	var face := "M200 96 C262 96 286 146 285 206 C284 262 254 314 200 320 C146 314 116 262 115 206 C114 146 138 96 200 96 Z"
	if g == "f":
		face = "M200 98 C258 98 282 146 281 204 C280 258 250 306 200 314 C150 306 120 258 119 204 C118 146 142 98 200 98 Z"
	s.append("<path d='%s' fill='url(#face)'/>" % face)
	# mejillas
	s.append("<ellipse cx='152' cy='246' rx='22' ry='14' fill='#d9776a' opacity='%f'/><ellipse cx='248' cy='246' rx='22' ry='14' fill='#d9776a' opacity='%f'/>" % [0.16 if g == "f" else 0.08, 0.16 if g == "f" else 0.08])
	# nariz
	s.append("<path d='M203 206 Q206 232 214 246 Q206 256 196 253' fill='none' stroke='%s' stroke-width='3.2' stroke-linecap='round' stroke-linejoin='round'/>" % _hex(skin_dd))
	s.append("<ellipse cx='205' cy='240' rx='8' ry='12' fill='%s' opacity='0.12'/>" % _hex(Color.WHITE))
	# edad
	if age >= 2:
		s.append("<path d='M160 146 Q200 138 240 146 M168 158 Q200 151 232 158' fill='none' stroke='%s' stroke-width='2' opacity='0.35' stroke-linecap='round'/>" % _hex(skin_dd))
		s.append("<path d='M174 252 Q168 272 176 290 M226 252 Q232 272 224 290' fill='none' stroke='%s' stroke-width='2.2' opacity='0.35' stroke-linecap='round'/>" % _hex(skin_dd))
	elif age == 1:
		s.append("<path d='M176 256 Q171 272 178 286 M224 256 Q229 272 222 286' fill='none' stroke='%s' stroke-width='1.8' opacity='0.22' stroke-linecap='round'/>" % _hex(skin_dd))
	# barba
	var beard: String = l.get("beard", "none")
	match beard:
		"stubble":
			s.append("<path d='M130 250 C140 300 170 318 200 320 C230 318 260 300 270 250 C262 282 238 300 200 302 C162 300 138 282 130 250 Z' fill='%s' opacity='0.25'/>" % _hex(hair_d))
		"full":
			s.append("<path d='M122 226 C124 300 164 336 200 338 C236 336 276 300 278 226 C270 262 252 282 234 286 C220 262 180 262 166 286 C148 282 130 262 122 226 Z' fill='url(#hair)'/>")
			s.append("<path d='M172 266 C184 258 216 258 228 266 C218 262 182 262 172 266 Z' fill='%s'/>" % _hex(hair_d))
		"goatee":
			s.append("<path d='M180 292 C184 312 216 312 220 292 C212 300 188 300 180 292 Z' fill='url(#hair)'/>")
			s.append("<path d='M176 266 C186 258 214 258 224 266 C214 263 186 263 176 266 Z' fill='%s'/>" % _hex(hair_d))
		"mustache":
			s.append("<path d='M170 270 C180 256 196 258 200 263 C204 258 220 256 230 270 C218 266 206 268 200 268 C194 268 182 266 170 270 Z' fill='url(#hair)'/>")
	# pelo delantero
	var hf := _hair_front(style, g)
	if hf != "":
		s.append("<path d='%s' fill='url(#hair)'/>" % hf)
		s.append("<path d='%s' fill='none' stroke='%s' stroke-width='1.5' opacity='0.4'/>" % [hf, _hex(hair_d)])
	if style == "curly":
		for i in 15:
			var a := PI + PI * (i / 14.0)
			var r := 90.0 if g == "m" else 96.0
			s.append("<circle cx='%f' cy='%f' r='%f' fill='url(#hair)'/>" % [200.0 + cos(a) * r, 176.0 + sin(a) * r * 0.9, 24.0 + (i % 3) * 3.0])
	if style == "bun":
		s.append("<circle cx='200' cy='78' r='32' fill='url(#hair)'/><path d='M172 92 Q200 104 228 92' stroke='%s' stroke-width='3' fill='none'/>" % _hex(hair_d))
	if style == "slick":
		s.append("<path d='M150 116 Q200 96 250 112' stroke='%s' stroke-width='3' fill='none' opacity='0.5' stroke-linecap='round'/>" % _hex(hair_l.lightened(0.3)))
	if uniform:
		s.append("<path d='M104 150 C104 88 150 58 200 58 C250 58 296 88 296 150 Z' fill='%s'/>" % _hex(suit))
		s.append("<path d='M92 150 L308 150 Q316 160 300 168 L100 168 Q84 160 92 150 Z' fill='#1f2419'/>")
		s.append("<rect x='112' y='140' width='176' height='12' fill='%s'/>" % _hex(suit_d))
		s.append("<circle cx='200' cy='112' r='14' fill='#c9a55c'/><path d='M200 102 L203 110 L211 110 L205 115 L207 123 L200 118 L193 123 L195 115 L189 110 L197 110 Z' fill='#8a6d33'/>")
	s.append("</svg>")
	return "".join(s)


static func _hair_back(style: String, g: String) -> String:
	match style:
		"bob":
			return "M100 304 C86 200 106 86 200 82 C294 86 314 200 300 304 C284 316 266 306 262 292 L262 210 C262 160 240 140 200 136 C160 140 138 160 138 210 L138 292 C134 306 116 316 100 304 Z"
		"long":
			return "M96 430 C78 300 86 104 200 80 C314 104 322 300 304 430 C284 438 270 426 266 408 L262 220 C262 160 240 134 200 130 C160 134 138 160 138 220 L134 408 C130 426 116 438 96 430 Z"
		"wavy":
			if g == "f":
				return "M92 400 C70 330 96 300 90 250 C80 150 120 78 200 76 C280 78 320 150 310 250 C304 300 330 330 308 400 C290 410 276 400 270 380 L262 220 C262 160 240 134 200 130 C160 134 138 160 138 220 L130 380 C124 400 110 410 92 400 Z"
			return ""
		"curly":
			if g == "f":
				return "M86 380 C60 300 70 120 200 72 C330 120 340 300 314 380 C296 396 272 386 266 360 L262 220 C262 160 240 134 200 130 C160 134 138 160 138 220 L134 360 C128 386 104 396 86 380 Z"
			return ""
		"ponytail":
			return "M262 150 C330 170 326 300 294 372 C282 330 286 240 262 196 Z"
	return ""


static func _hair_front(style: String, g: String) -> String:
	match style:
		"short":
			return "M114 192 C106 118 146 76 200 76 C258 76 296 116 286 192 C282 162 272 142 252 132 C222 122 172 124 150 134 C130 144 120 164 114 192 Z"
		"side":
			return "M112 198 C102 116 150 70 208 72 C268 74 300 122 288 198 C284 170 276 150 262 140 C236 124 204 136 170 126 C150 122 128 150 112 198 Z"
		"slick":
			return "M116 182 C110 114 150 78 200 78 C252 78 292 114 284 182 C278 150 262 128 236 122 C212 116 186 116 164 122 C140 130 122 152 116 182 Z"
		"bald":
			return "M116 214 C112 184 116 164 124 152 L134 200 Z M284 214 C288 184 284 164 276 152 L266 200 Z"
		"balding":
			return "M116 214 C112 180 118 158 128 146 L136 200 Z M284 214 C288 180 282 158 272 146 L264 200 Z M156 112 C176 100 224 100 244 112 C224 106 176 106 156 112 Z"
		"buzz":
			return "M116 178 C112 114 152 84 200 84 C248 84 288 114 284 178 C276 148 256 126 200 124 C144 126 124 148 116 178 Z"
		"wavy":
			return "M108 212 C96 130 140 70 202 70 C270 70 306 130 292 214 C290 184 282 160 266 146 C254 160 236 150 222 140 C206 150 186 146 172 136 C156 150 138 150 128 160 C118 176 112 192 108 212 Z"
		"curly":
			return "M110 200 C100 130 140 84 200 84 C260 84 300 130 290 200 C280 160 250 134 200 134 C150 134 120 160 110 200 Z"
		"bob":
			return "M124 184 C128 118 170 94 208 96 C254 98 282 130 278 180 C258 152 230 142 204 142 C176 142 146 154 124 184 Z"
		"long":
			return "M122 196 C120 124 160 90 204 92 C250 94 284 126 280 190 C262 150 236 130 214 128 C196 150 160 170 122 196 Z"
		"bun", "ponytail":
			return "M116 186 C112 118 150 86 200 86 C250 86 288 118 284 186 C276 150 256 128 200 126 C144 128 124 150 116 186 Z"
	return ""


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_mood = lerpf(_mood, mood, minf(1.0, delta * 5.0))
	_anger = lerpf(_anger, anger, minf(1.0, delta * 4.0))
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.5)
	_blink = maxf(0.0, _blink - delta * 7.0)
	if talking:
		_mouth = clampf(absf(sin(_t * 17.0)) * 0.7 + absf(sin(_t * 7.3)) * 0.3, 0.0, 1.0)
	else:
		_mouth = lerpf(_mouth, 0.0, minf(1.0, delta * 12.0))
	if track_mouse:
		var s := _scale()
		var center := global_position + (_offset() + Vector2(200, 210) * s) * get_global_transform().get_scale()
		var d := get_global_mouse_position() - center
		_look_off = _look_off.lerp(d.normalized() * minf(3.5, d.length() / 80.0), minf(1.0, delta * 6.0))
	queue_redraw()


func _scale() -> float:
	return minf(size.x / REF.x, size.y / REF.y)


func _offset() -> Vector2:
	var s := _scale()
	return Vector2((size.x - REF.x * s) * 0.5, size.y - REF.y * s)


func _draw() -> void:
	if _tex == null:
		return
	var s := _scale()
	var off := _offset()
	if breathe:
		off.y += sin(_t * 1.7) * 1.4 * s
	draw_set_transform(off, 0.0, Vector2(s, s))
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, REF), false)
	# rubor de enfado
	if _anger > 0.02:
		var bc := Color(0.85, 0.15, 0.1, _anger * 0.35)
		_ellipse(Vector2(150, 244), Vector2(26, 15), bc)
		_ellipse(Vector2(250, 244), Vector2(26, 15), bc)
	var g: String = look.get("g", "m")
	var happy := clampf(_mood, 0.0, 1.0)
	var sad := clampf(-_mood, 0.0, 1.0)
	# ojos
	var open := 1.0 - _blink
	open *= 1.0 - happy * 0.22 - _anger * 0.2 + surprise * 0.25
	for side in [-1, 1]:
		var c := Vector2(200 + side * 34, 210)
		_draw_eye(c, open, g)
	# cejas
	var bw := 7.0 if g == "m" else 4.5
	var hair_c := _hair.darkened(0.15)
	if look.get("hair", "") in ["bald", "balding"] and int(look.get("hc", 0)) >= 5:
		hair_c = Color(W.HAIR_COL[5]).darkened(0.2)
	for side in [-1, 1]:
		var inner := Vector2(200 + side * 16, 184 + _anger * 7.0 - sad * 6.0 - surprise * 6.0)
		var outer := Vector2(200 + side * 52, 186 - _anger * 3.0 + sad * 3.0 - surprise * 6.0)
		var mid := (inner + outer) * 0.5 + Vector2(0, -5.0 - (3.0 if g == "f" else 0.0))
		draw_polyline(PackedVector2Array([inner, mid, outer]), hair_c, bw, true)
	# boca
	_draw_mouth(g, happy, sad)
	# gafas
	var gl := int(look.get("glasses", 0))
	if gl > 0:
		var fc := Color(0.12, 0.1, 0.1)
		for side in [-1, 1]:
			var c := Vector2(200 + side * 36, 212)
			if gl == 1:
				draw_arc(c, 22.0, 0, TAU, 40, fc, 3.2, true)
				draw_circle(c, 21.0, Color(1, 1, 1, 0.07))
			else:
				var r := Rect2(c - Vector2(25, 17), Vector2(50, 34))
				draw_rect(r, Color(1, 1, 1, 0.07), true)
				draw_rect(r, fc, false, 3.2, true)
			draw_line(c + Vector2(-10, -10), c + Vector2(-2, -14), Color(1, 1, 1, 0.35), 2.0, true)
		draw_line(Vector2(186 if gl == 2 else 182, 210), Vector2(214 if gl == 2 else 218, 210), fc, 3.0, true)
		draw_line(Vector2(136 if gl == 1 else 140, 208), Vector2(118, 204), fc, 3.0, true)
		draw_line(Vector2(264 if gl == 1 else 260, 208), Vector2(282, 204), fc, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw_eye(c: Vector2, open: float, g: String) -> void:
	var w := 16.0
	var h := 9.5 * clampf(open, 0.05, 1.3)
	var pts := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var x := lerpf(-w, w, t)
		var yy := -sin(t * PI) * h
		pts.append(c + Vector2(x, yy * 1.05))
	for i in range(19, 0, -1):
		var t := float(i) / 20.0
		var x := lerpf(-w, w, t)
		var yy := sin(t * PI) * h * 0.8
		pts.append(c + Vector2(x, yy))
	if open > 0.12:
		draw_colored_polygon(pts, Color(0.97, 0.96, 0.94))
		var ic := c + _look_off + Vector2(0, 0.5)
		var ir := minf(7.8, h * 0.95)
		draw_circle(ic, ir, _eye)
		draw_circle(ic, ir * 0.5, Color(0.05, 0.04, 0.04))
		draw_circle(ic + Vector2(-2.4, -2.4), 2.0, Color(1, 1, 1, 0.9))
	# párpado superior
	var lid := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		lid.append(c + Vector2(lerpf(-w - 1, w + 1, t), -sin(t * PI) * h * 1.05))
	draw_polyline(lid, Color(0.12, 0.08, 0.07), 3.0 if g == "f" else 2.4, true)
	if g == "f":
		draw_line(c + Vector2(w, -1), c + Vector2(w + 5, -5), Color(0.12, 0.08, 0.07), 2.4, true)


func _draw_mouth(g: String, happy: float, sad: float) -> void:
	var c := Vector2(200, 276)
	var hw := 22.0 + happy * 5.0
	var curve := happy * 9.0 - sad * 7.0
	var corner_y := -curve * 0.6
	var open := _mouth * 12.0 + surprise * 8.0
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(-hw, hw, t)
		var bend := sin(t * PI)
		upper.append(c + Vector2(x, corner_y * (1.0 - bend) + bend * curve * 0.35 - bend * open * 0.25))
		lower.append(c + Vector2(x, corner_y * (1.0 - bend) + bend * (curve * 0.5 + open)))
	if open > 1.5 or happy > 0.55:
		var poly := PackedVector2Array(upper)
		for i in range(lower.size() - 1, -1, -1):
			poly.append(lower[i])
		var o2 := open if open > 1.5 else happy * 6.0
		if o2 > 1.0 and Geometry2D.triangulate_polygon(poly).size() > 0:
			draw_colored_polygon(poly, Color(0.35, 0.1, 0.1))
			var teeth := PackedVector2Array()
			for i in range(3, 14):
				teeth.append(upper[i] + Vector2(0, 1.5))
			for i in range(13, 2, -1):
				teeth.append(upper[i] + Vector2(0, minf(5.5, o2 * 0.45)))
			if Geometry2D.triangulate_polygon(teeth).size() > 0:
				draw_colored_polygon(teeth, Color(0.96, 0.94, 0.9))
	draw_polyline(upper, _lip.darkened(0.25), 3.4, true)
	if open > 1.5:
		draw_polyline(lower, _lip, 3.0, true)
	else:
		var lip2 := PackedVector2Array()
		for i in range(4, 13):
			lip2.append(lower[i] + Vector2(0, 5.0))
		draw_polyline(lip2, Color(_lip, 0.45 if g == "f" else 0.25), 3.0, true)
