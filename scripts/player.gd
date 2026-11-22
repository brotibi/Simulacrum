extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 3.6
@export var ground_acceleration: float = 14.0
@export var ground_friction: float = 10.0
@export var air_acceleration: float = 6.5
@export var air_drag: float = 1.5

@export_group("Jumping & Wall Jumping")
@export var jump_velocity: float = 5.2
@export var wall_jump_up_velocity: float = 5.0
@export var wall_jump_push_velocity: float = 5.2
@export var coyote_time: float = 0.12
@export var wall_coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.12
@export var max_wall_jumps: int = 3

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.0025
@export var max_pitch_degrees: float = 80.0

@export_group("Headbob")
@export var bob_frequency: float = 2.4
@export var bob_amplitude_y: float = 0.045
@export var bob_amplitude_x: float = 0.025

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var _bob_time: float = 0.0
var _default_camera_pos: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _coyote_timer: float = 0.0
var _wall_coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _last_wall_normal: Vector3 = Vector3.ZERO
var _wall_jumps_remaining: int = 0


func _ready() -> void:
	_default_camera_pos = camera.position
	_wall_jumps_remaining = max_wall_jumps
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-max_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Update timers and floor/wall states
	if is_on_floor():
		_coyote_timer = coyote_time
		_wall_coyote_timer = 0.0
		_wall_jumps_remaining = max_wall_jumps
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
		velocity.y -= _gravity * delta

	if is_on_wall() and not is_on_floor():
		_last_wall_normal = get_wall_normal()
		_wall_coyote_timer = wall_coyote_time
	else:
		_wall_coyote_timer = max(_wall_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# Process buffered jump or wall jump
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
		elif _wall_coyote_timer > 0.0 and _wall_jumps_remaining > 0:
			var push_dir := _last_wall_normal
			push_dir.y = 0.0
			push_dir = push_dir.normalized()

			# Blend wall normal kick with player's directional input
			var jump_horizontal := (push_dir * wall_jump_push_velocity) + (wish_dir * (walk_speed * 0.45))
			velocity.x = jump_horizontal.x
			velocity.z = jump_horizontal.z
			velocity.y = wall_jump_up_velocity

			_wall_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			_wall_jumps_remaining -= 1

	# Horizontal acceleration & friction/drag
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var decel := ground_friction if is_on_floor() else air_drag

	if wish_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, wish_dir.x * walk_speed, accel * delta)
		velocity.z = move_toward(velocity.z, wish_dir.z * walk_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	move_and_slide()
	_update_headbob(delta)


func _update_headbob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.15:
		_bob_time += delta * horizontal_speed * bob_frequency
		var offset := Vector3(
			cos(_bob_time * 0.5) * bob_amplitude_x,
			sin(_bob_time) * bob_amplitude_y,
			0.0
		)
		camera.position = _default_camera_pos + offset
	else:
		camera.position = camera.position.lerp(_default_camera_pos, delta * 8.0)
