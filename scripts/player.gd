extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 3.6
@export var acceleration: float = 12.0
@export var friction: float = 10.0

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


func _ready() -> void:
	_default_camera_pos = camera.position
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
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if wish_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, wish_dir.x * walk_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, wish_dir.z * walk_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

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
