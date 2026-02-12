extends CharacterBody3D

@export var speed: float = 3.2
@export var max_hp: int = 100
@export var damage: int = 10
@export var attack_cooldown: float = 1.0
@export var shoot_range: float = 18.0

var hp: int = 100
var target: Node3D = null
var cooldown: float = 0.0
@onready var gun: Node3D = $Gun
@onready var muzzle: Node3D = $Gun/Muzzle

var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")
var anim_player: AnimationPlayer = null
var anim_last: StringName = &""

func _ready() -> void:
    hp = max_hp
    _attach_gun_to_hand()
    anim_player = _find_anim_player(self)
    _play_anim(_pick_anim(["Idle", "idle", "Idle_01"]))

func _physics_process(delta: float) -> void:
    if not target:
        return

    cooldown = max(0.0, cooldown - delta)

    var dir = (target.global_position - global_position)
    dir.y = 0
    var dist = dir.length()
    if dist > 0.1:
        dir = dir.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
    else:
        velocity.x = 0
        velocity.z = 0

    if dist > 0.1:
        var look_pos = target.global_position
        look_pos.y = global_position.y
        look_at(look_pos, Vector3.UP)

    move_and_slide()

    if dist <= shoot_range and cooldown <= 0.0:
        _try_shoot()


func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0:
        queue_free()

func _try_shoot() -> void:
    if not target:
        return
    var origin = muzzle.global_transform.origin
    var to = target.global_transform.origin
    var params = PhysicsRayQueryParameters3D.create(origin, to)
    params.exclude = [self]
    var hit = get_world_3d().direct_space_state.intersect_ray(params)
    if hit and hit.collider == target:
        var dir = (to - origin).normalized()
        var b = bullet_scene.instantiate()
        get_tree().current_scene.add_child(b)
        b.fire(origin + dir * 0.2, dir, damage, self)
        _play_anim(_pick_anim(["Firing Rifle", "Fire", "Shoot", "Attack", "attack"]))
        cooldown = attack_cooldown

func _attach_gun_to_hand() -> void:
    var skel = _find_skeleton(self)
    if skel == null:
        return
    var bone_idx = _find_right_hand_bone(skel)
    if bone_idx == -1:
        _print_bones(skel)
        return
    var bone_name = skel.get_bone_name(bone_idx)
    var attach = skel.get_node_or_null("GunAttach") as BoneAttachment3D
    if attach == null:
        attach = BoneAttachment3D.new()
        attach.name = "GunAttach"
        skel.add_child(attach)
    attach.bone_name = bone_name
    if gun.get_parent() != attach:
        gun.get_parent().remove_child(gun)
        attach.add_child(gun)
    gun.position = Vector3(0.08, -0.02, -0.12)
    gun.rotation_degrees = Vector3(0, 180, 0)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found = _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_anim_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found = _find_anim_player(child)
        if found != null:
            return found
    return null

func _find_right_hand_bone(skel: Skeleton3D) -> int:
    var best := -1
    var count = skel.get_bone_count()
    for i in range(count):
        var name = skel.get_bone_name(i).to_lower()
        if name.find("hand") == -1:
            continue
        if name.find("right") != -1 or name.find("_r") != -1 or name.find("r_") != -1 or name.ends_with("r"):
            return i
        if best == -1:
            best = i
    return best

func _print_bones(skel: Skeleton3D) -> void:
    var count = skel.get_bone_count()
    for i in range(count):
        print("BONE ", i, ": ", skel.get_bone_name(i))

func _pick_anim(names: Array[String]) -> StringName:
    if anim_player == null:
        return &""
    for n in names:
        if anim_player.has_animation(n):
            return StringName(n)
    return &""

func _play_anim(name: StringName) -> void:
    if anim_player == null:
        return
    if name == &"":
        return
    if name == anim_last:
        return
    anim_player.play(name)
    anim_last = name
