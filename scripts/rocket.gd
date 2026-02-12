extends Area3D

@export var speed: float = 28.0
@export var lifetime: float = 2.5
@export var damage: int = 60
@export var radius: float = 3.5

var dir: Vector3 = Vector3.ZERO

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    lifetime -= delta
    if lifetime <= 0.0:
        _explode()
        return
    global_position += dir * speed * delta

func fire(from: Vector3, direction: Vector3, dmg: int, rad: float) -> void:
    global_position = from
    dir = direction.normalized()
    damage = dmg
    radius = rad

func _on_body_entered(_body: Node) -> void:
    _explode()

func _explode() -> void:
    var space = get_world_3d().direct_space_state
    var shape := SphereShape3D.new()
    shape.radius = radius
    var params := PhysicsShapeQueryParameters3D.new()
    params.shape = shape
    params.transform = Transform3D(Basis(), global_position)
    var hits = space.intersect_shape(params, 32)
    for h in hits:
        var col = h.get("collider")
        if col and col.has_method("take_damage"):
            col.take_damage(damage)
    queue_free()
