extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sense: float = 0.12

@onready var cam: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		cam.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()
	var direction := (global_transform.basis * input_dir).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if ray.is_colliding():
			var hit = ray.get_collider()
			if hit and hit.has_method("on_hit"):
				hit.on_hit()
