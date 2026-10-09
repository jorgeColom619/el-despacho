extends Node3D
## Público lejano (filas de atrás del hemiciclo): diputados sentados de art/characters/crowd.glb, estáticos y
## simplificados, un MultiMesh por modelo. Cada uno lleva su traje, tono de piel y color de pelo; cheer()
## hace botar a la bancada que aplaude.

## Se carga al montar la sala (no con preload): si el modelo no se ha importado, la sala sale sin público lejano en
## vez de no poder abrirse
const SCENE_PATH := "res://art/characters/crowd.glb"
const SHADER := preload("res://shaders/crowd3d.gdshader")
const W := preload("res://scripts/data/world_data.gd")
## Superficies de crowd.glb (un material por tipo de pieza, en el orden de crowd3d.gdshader)
const CATS := ["C_Suit", "C_Trousers", "C_Skin", "C_Hair", "C_Shirt", "C_Dark", "C_Tie", "C_Light"]

var _mats: Array = []


## seats: [{"xf": Transform3D, "suit": Color, "f": bool}]
func build(seats: Array, rng: RandomNumberGenerator) -> void:
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("No se ha podido cargar %s: hay que volver a importar el proyecto (Jugar.bat lo hace solo)." % SCENE_PATH)
		return
	var inst: Node = scene.instantiate()
	var meshes := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name)] = (mi as MeshInstance3D).mesh
	inst.free()
	var skin := PackedColorArray()
	for c in W.SKIN:
		skin.append(Color(c).srgb_to_linear())
	var hair := PackedColorArray()
	for c in W.HAIR_COL:
		hair.append(Color(c).srgb_to_linear())
	var by_name := {}
	for i in CATS.size():
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("cat", i)
		m.set_shader_parameter("skin_tones", skin)
		m.set_shader_parameter("hair_tones", hair)
		by_name[CATS[i]] = m
		_mats.append(m)
	var groups := {"Seated_M": [], "Seated_MB": [], "Seated_F": [], "Seated_FL": []}
	for s in seats:
		var opts: Array = ["Seated_F", "Seated_FL"] if s["f"] else ["Seated_M", "Seated_M", "Seated_MB"]
		groups[opts[rng.randi() % opts.size()]].append(s)
	for key in groups:
		var list: Array = groups[key]
		if list.is_empty() or not meshes.has(key):
			continue
		var mesh: Mesh = (meshes[key] as Mesh).duplicate()
		for si in mesh.get_surface_count():
			var sm := mesh.surface_get_material(si)
			mesh.surface_set_material(si, by_name.get(sm.resource_name if sm != null else "", by_name["C_Dark"]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var s: Dictionary = list[i]
			var suit: Color = s["suit"]
			mm.set_instance_transform(i, s["xf"])
			mm.set_instance_custom_data(i, Color(suit.r, suit.g, suit.b, float(rng.randi() % 6 + (rng.randi() % 7) * 8)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## Intensidad del aplauso de cada bancada (0 = quietos, 1 = botando)
func cheer(left: float, right: float) -> void:
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("cheer_left", left)
		(m as ShaderMaterial).set_shader_parameter("cheer_right", right)
