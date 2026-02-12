extends CharacterBody3D

@export var speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var mouse_sense: float = 0.12
@export var max_hp: int = 100

@onready var cam: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var guns: Array[Node3D] = [
	$Camera3D/Guns/Pistol,
	$Camera3D/Guns/Rifle,
	$Camera3D/Guns/Sniper,
	$Camera3D/Guns/Launcher,
	$Camera3D/Guns/Shotgun
]
var gun: Node3D = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp: int = 100

var rocket_scene: PackedScene = preload("res://rocket.tscn")

var weapons := [
	{
		"name": "Pistol",
		"mag_size": 15,
		"reserve": 60,
		"reload": 1.2,
		"fire_rate": 0.12,
		"damage": 22,
		"recoil": 1.2,
		"spread": 0.02,
		"zoom": 1.0,
		"type": "hitscan"
	},
	{
		"name": "Rifle",
		"mag_size": 30,
		"reserve": 120,
		"reload": 1.6,
		"fire_rate": 0.08,
		"damage": 30,
		"recoil": 1.8,
		"spread": 0.03,
		"zoom": 1.0,
		"type": "hitscan"
	},
	{
		"name": "Sniper",
		"mag_size": 5,
		"reserve": 25,
		"reload": 2.2,
		"fire_rate": 0.35,
		"damage": 85,
		"recoil": 3.2,
		"spread": 0.005,
		"zoom": 0.35,
		"type": "hitscan"
	},
	{
		"name": "Launcher",
		"mag_size": 4,
		"reserve": 16,
		"reload": 2.4,
		"fire_rate": 0.6,
		"damage": 70,
		"recoil": 4.2,
		"spread": 0.01,
		"zoom": 1.0,
		"type": "rocket",
		"radius": 4.0
	},
	{
		"name": "Shotgun",
		"mag_size": 6,
		"reserve": 36,
		"reload": 1.9,
		"fire_rate": 0.7,
		"damage": 12,
		"recoil": 3.5,
		"spread": 0.08,
		"zoom": 1.0,
		"type": "hitscan"
	}
]

var weapon_index: int = -1
var mag: int = 30
var reserve: int = 120
var cooldown: float = 0.0
var reloading: bool = false
var reload_left: float = 0.0

var recoil_pitch: float = 0.0
var gun_kick: float = 0.0
var sway_phase: float = 0.0

func _ready() -> void:
	hp = max_hp
	_apply_weapon(1)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
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

func _process(delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	cooldown = max(0.0, cooldown - delta)

	if Input.is_key_pressed(KEY_1):
		_apply_weapon(0)
	elif Input.is_key_pressed(KEY_2):
		_apply_weapon(1)
	elif Input.is_key_pressed(KEY_3):
		_apply_weapon(2)
	elif Input.is_key_pressed(KEY_4):
		_apply_weapon(3)
	elif Input.is_key_pressed(KEY_5):
		_apply_weapon(4)

	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			var need = _weapon().mag_size - mag
			var take = min(need, reserve)
			mag += take
			reserve -= take
			reloading = false
		_update_gun_anim(delta)
		return

	if mag == 0 and reserve > 0 and not reloading:
		reloading = true
		reload_left = _weapon().reload
		_update_gun_anim(delta)
		return

	if Input.is_key_pressed(KEY_R):
		if mag < _weapon().mag_size and reserve > 0:
			reloading = true
			reload_left = _weapon().reload
		_update_gun_anim(delta)
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if cooldown <= 0.0 and mag > 0:
			_fire()

	_update_zoom()
	_update_gun_anim(delta)

func _fire() -> void:
	mag -= 1
	cooldown = _weapon().fire_rate

	recoil_pitch = min(recoil_pitch + _weapon().recoil, 10.0)
	gun_kick = min(gun_kick + 0.08, 0.14)
	cam.rotate_x(deg_to_rad(-_weapon().recoil * 0.35))
	cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	var spread = _weapon().spread
	var rand = Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0)
	var origin = cam.global_transform.origin
	var dir = (-cam.global_transform.basis.z + rand).normalized()
	if _weapon().type == "rocket":
		var r = rocket_scene.instantiate()
		var rad = _weapon().radius
		r.fire(origin + dir * 0.6, dir, _weapon().damage, rad)
		get_tree().current_scene.add_child(r)
	else:
		var to = origin + dir * 80.0
		var params = PhysicsRayQueryParameters3D.create(origin, to)
		var hit = get_world_3d().direct_space_state.intersect_ray(params)
		if hit and hit.collider and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(_weapon().damage)

func _update_zoom() -> void:
	if weapon_index == 2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam.fov = lerp(cam.fov, 35.0, 0.15)
	else:
		cam.fov = lerp(cam.fov, 75.0, 0.15)

func _update_gun_anim(delta: float) -> void:
	recoil_pitch = max(0.0, recoil_pitch - delta * 10.0)
	gun_kick = max(0.0, gun_kick - delta * 0.6)

	var move_speed = Vector3(velocity.x, 0, velocity.z).length()
	sway_phase += delta * (3.0 + move_speed * 0.15)
	var sway = Vector3(sin(sway_phase) * 0.03, cos(sway_phase * 1.2) * 0.02, 0)

	gun.position = Vector3(0.25, -0.2, -0.5 - gun_kick) + sway

func _apply_weapon(idx: int) -> void:
	if idx == weapon_index:
		return
	weapon_index = idx
	for i in guns.size():
		guns[i].visible = (i == idx)
	gun = guns[idx]
	var w = _weapon()
	mag = w.mag_size
	reserve = w.reserve
	cooldown = 0.0
	reloading = false

func _weapon() -> Dictionary:
	return weapons[weapon_index]

func get_weapon_name() -> String:
	return _weapon().name

func get_mag() -> int:
	return mag

func get_reserve() -> int:
	return reserve

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		hp = 0

func is_dead() -> bool:
	return hp <= 0
