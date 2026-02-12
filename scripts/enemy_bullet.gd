extends Area3D

@export var speed: float = 24.0
@export var lifetime: float = 2.0

var direction: Vector3 = Vector3.FORWARD
var damage: int = 10
var shooter: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func fire(origin: Vector3, dir: Vector3, dmg: int, owner: Node) -> void:
	global_position = origin
	direction = dir.normalized()
	damage = dmg
	shooter = owner

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
