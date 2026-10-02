extends Control
## Mapa regional de Valdoria (sala de crisis y noche electoral).

const W := preload("res://scripts/data/world_data.gd")
const REF := Vector2(1000, 760)

var tex: Texture2D
var img: Image
var pal_img: Image
var pal_tex: ImageTexture
var mat: ShaderMaterial
var rect: TextureRect
var mode := 0
var hover_id := 0
var centroids := {}
var adjacency := {}
var _dirty := true
var labels := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tex = load("res://art/maps/valdoria_ids.png")
	img = tex.get_image()
	if img.is_compressed():
		img.decompress()
	pal_img = Image.create(16, 1, false, Image.FORMAT_RGBA8)
	pal_img.fill(Color(0, 0, 0, 0))
	pal_tex = ImageTexture.create_from_image(pal_img)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/regions.gdshader")
	mat.set_shader_parameter("ids", tex)
	mat.set_shader_parameter("pal", pal_tex)
	mat.set_shader_parameter("tex_size", REF)
	mat.set_shader_parameter("mode", mode)
	rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = size
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var sc := size / REF
	var regs: Dictionary = DB.region_info.get("regions", {})
	for k in regs.keys():
		centroids[int(k)] = Vector2(regs[k]["x"], regs[k]["y"]) * sc
	# ajuste manual de etiquetas para que queden centradas visualmente
	if centroids.has(3):
		centroids[3] += Vector2(-20, -40) * sc
	for i in range(1, 9):
		adjacency[i] = []
	for pair in DB.region_info.get("adjacency", []):
		var ab: PackedStringArray = String(pair).split("-")
		var a := int(ab[0])
		var b := int(ab[1])
		adjacency[a].append(b)
		adjacency[b].append(a)
	mouse_exited.connect(func():
		hover_id = 0
		_refresh_hover())


func set_mode(m: int) -> void:
	mode = m
	if mat != null:
		mat.set_shader_parameter("mode", m)


func set_region(id: int, c: Color) -> void:
	var old := pal_img.get_pixel(id, 0)
	c.a = old.a
	pal_img.set_pixel(id, 0, c)
	_dirty = true


func _refresh_hover() -> void:
	for i in range(1, 9):
		var c := pal_img.get_pixel(i, 0)
		c.a = 1.0 if i == hover_id else 0.0
		pal_img.set_pixel(i, 0, c)
	_dirty = true


func id_at(local: Vector2) -> int:
	var p := local / size * REF
	if p.x < 0 or p.y < 0 or p.x >= REF.x or p.y >= REF.y:
		return 0
	var c := img.get_pixel(int(p.x), int(p.y))
	return int(round(c.r * 255.0 / 16.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := id_at(event.position)
		if id < 1 or id > 8:
			id = 0
		if id != hover_id:
			hover_id = id
			_refresh_hover()


func _process(_d: float) -> void:
	if _dirty:
		pal_tex.update(pal_img)
		_dirty = false
