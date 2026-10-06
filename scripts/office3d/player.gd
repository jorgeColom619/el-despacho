extends CharacterBody3D
## El presidente en primera persona: sentado en el sillón o de pie andando por el despacho.
## Ratón para mirar, WASD para andar, coger y lanzar objetos físicos.

signal sat_changed(seated: bool)

const EYE_STAND := 1.62
const EYE_SIT := 1.22
const WALK := 2.6
const RUN := 4.4
const GRAVITY := 9.8
const GRAB_RANGE := 2.6

var head: Node3D
var cam: Camera3D
var seated := true
var seat_pos := Vector3.ZERO
var seat_yaw := 0.0
var stand_pos := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var sens := 1.0
## El despacho lo desactiva mientras hay una pantalla abierta
var input_enabled := true
var held: RigidBody3D
var hold_dist := 0.9
var _bob := 0.0
var _transition := 0.0
var _focus_active := false
var _focus_yaw := 0.0
var _focus_pitch := 0.0
var _eye := EYE_SIT


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	head = Node3D.new()
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.03
	cam.far = 60.0
	cam.current = true
	head.add_child(cam)
	_apply_seat_state(true)


# ------------------------------------------------------------------ sentarse / levantarse

func _apply_seat_state(instant: bool) -> void:
	if seated:
		collision_mask = 0
		global_position = seat_pos
		yaw = seat_yaw
		pitch = deg_to_rad(-18.0)
	else:
		collision_mask = 1 | 2
	if instant:
		_eye = EYE_SIT if seated else EYE_STAND
		head.position.y = _eye


func sit() -> void:
	if seated:
		return
	seated = true
	_drop()
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", seat_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "_eye", EYE_SIT, 0.45).set_trans(Tween.TRANS_CUBIC)
	_transition = 0.45
	collision_mask = 0
	velocity = Vector3.ZERO
	_focus_yaw = seat_yaw
	_focus_pitch = deg_to_rad(-18.0)
	_focus_active = true
	Sfx.play("paper2", -14.0, 0.5)
	sat_changed.emit(true)


func stand() -> void:
	if not seated:
		return
	seated = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", stand_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "_eye", EYE_STAND, 0.4).set_trans(Tween.TRANS_CUBIC)
	_transition = 0.4
	t.chain().tween_callback(func(): collision_mask = 1 | 2)
	sat_changed.emit(false)


# ------------------------------------------------------------------ mirar

func look(rel: Vector2) -> void:
	_focus_active = false
	var k := 0.0022 * sens
	yaw -= rel.x * k
	pitch = clampf(pitch - rel.y * k, deg_to_rad(-85), deg_to_rad(85))
	yaw = wrapf(yaw, -PI, PI)


## Gira la vista suavemente hacia un punto; offset_x desplaza el punto en pantalla (−0.5 izquierda … 0.5 derecha)
func focus_on(p: Vector3, offset_x := 0.0) -> void:
	var from := cam.global_position
	var d := p - from
	var base_yaw := atan2(-d.x, -d.z)
	var hd := Vector2(d.x, d.z).length()
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		aspect = r.x / maxf(1.0, r.y)
	var half_h := tan(deg_to_rad(cam.fov) * 0.5) * aspect
	_focus_yaw = base_yaw + atan(offset_x * 2.0 * half_h)
	_focus_pitch = atan2(d.y, hd)
	_focus_active = true


# ------------------------------------------------------------------ coger y lanzar

func can_grab(b: Object) -> bool:
	return b is RigidBody3D and not (b as RigidBody3D).freeze and (b as Node3D).global_position.distance_to(cam.global_position) <= GRAB_RANGE


func grab(b: RigidBody3D) -> void:
	_drop()
	held = b
	hold_dist = clampf(b.global_position.distance_to(cam.global_position), 0.55, 1.4)
	add_collision_exception_with(b)
	b.sleeping = false
	Sfx.play("paper2", -12.0, 1.3)


func _drop() -> void:
	if held != null and is_instance_valid(held):
		remove_collision_exception_with(held)
	held = null


func drop() -> void:
	_drop()


func throw_held() -> void:
	if held == null or not is_instance_valid(held):
		return
	var b := held
	_drop()
	var dir := -cam.global_transform.basis.z
	b.linear_velocity = dir * clampf(7.5 / sqrt(maxf(0.05, b.mass)), 3.0, 11.0)
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	Sfx.play("whoosh", -10.0, 1.4)


func scroll_hold(amount: float) -> void:
	hold_dist = clampf(hold_dist + amount, 0.5, 2.0)


# ------------------------------------------------------------------ bucle

func _physics_process(delta: float) -> void:
	if _focus_active:
		var dy := wrapf(_focus_yaw - yaw, -PI, PI)
		yaw += dy * minf(1.0, delta * 5.0)
		pitch = lerpf(pitch, _focus_pitch, minf(1.0, delta * 5.0))
		if absf(dy) < 0.002 and absf(_focus_pitch - pitch) < 0.002:
			_focus_active = false
		yaw = wrapf(yaw, -PI, PI)
	rotation = Vector3(0, yaw, 0)
	head.rotation = Vector3(pitch, 0, 0)
	_transition = maxf(0.0, _transition - delta)
	var moving := false
	if not seated and _transition <= 0.0:
		var input := Vector2.ZERO
		if _keys_enabled():
			if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
				input.y -= 1
			if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
				input.y += 1
			if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
				input.x -= 1
			if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
				input.x += 1
		input = input.normalized()
		var spd := RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
		var dir := (transform.basis * Vector3(input.x, 0, input.y))
		dir.y = 0
		var want := dir.normalized() * spd * input.length()
		velocity.x = move_toward(velocity.x, want.x, delta * 22.0)
		velocity.z = move_toward(velocity.z, want.z, delta * 22.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = -0.1
		move_and_slide()
		# empujar objetos físicos al andar
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var col := c.get_collider()
			if col is RigidBody3D and col != held:
				var rb := col as RigidBody3D
				var push := -c.get_normal()
				push.y = 0.0
				rb.apply_impulse(push.normalized() * minf(0.6, rb.mass * 0.9) * Vector2(velocity.x, velocity.z).length() * delta * 8.0, c.get_position() - rb.global_position)
		moving = Vector2(velocity.x, velocity.z).length() > 0.3
		if global_position.y < -3.0:
			global_position = stand_pos
	# balanceo al andar
	if moving:
		_bob += delta * Vector2(velocity.x, velocity.z).length() * 2.6
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, minf(1.0, delta * 6.0))
	head.position.y = _eye + absf(sin(_bob)) * 0.035 - 0.0175 * float(moving)
	head.position.x = cos(_bob) * 0.02 * float(moving)
	# objeto sujeto
	if held != null:
		if not is_instance_valid(held):
			held = null
		else:
			var target := cam.global_position - cam.global_transform.basis.z * hold_dist
			var diff := target - held.global_position
			if diff.length() > 1.6:
				_drop()
			else:
				held.linear_velocity = diff * 14.0
				held.angular_velocity *= 0.85


func _keys_enabled() -> bool:
	return input_enabled
