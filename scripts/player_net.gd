extends CharacterBody3D

@export var speed: float = 6.5
@export var jump_velocity: float = 4.5
@export var mouse_sense: float = 0.12

@onready var cam: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var body_mesh: MeshInstance3D = $Body

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 100
var team: int = 0
var player_id: int = 0
var game: Node = null

func _is_local() -> bool:
	return multiplayer.get_unique_id() == player_id

func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	if _is_local():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		cam.current = false

func _input(event: InputEvent) -> void:
	if not _is_local():
		return
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
	if not _is_local():
		return

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

	rpc("sync_state", global_position, global_rotation)

func _process(_delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not _is_local():
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if game and game.has_method("request_shoot"):
			var origin = cam.global_transform.origin
			var dir = -cam.global_transform.basis.z
			game.request_shoot(origin, dir)
	if Input.is_key_pressed(KEY_E):
		if game and game.has_method("request_use"):
			game.request_use(player_id, global_position)

func set_team(t: int) -> void:
	team = t
	if team == 0:
		body_mesh.material_override = StandardMaterial3D.new()
		body_mesh.material_override.albedo_color = Color(0.2, 0.8, 0.6)
	else:
		body_mesh.material_override = StandardMaterial3D.new()
		body_mesh.material_override.albedo_color = Color(0.85, 0.25, 0.2)

@rpc("unreliable")
func sync_state(pos: Vector3, rot: Vector3) -> void:
	if _is_local():
		return
	global_position = pos
	global_rotation = rot

@rpc("reliable")
func apply_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		health = 0
