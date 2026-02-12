extends StaticBody3D

@export var area_size: float = 14.0
@export var height: float = 1.0

func on_hit() -> void:
    var x = randf_range(-area_size, area_size)
    var z = randf_range(-area_size, area_size)
    global_position = Vector3(x, height, z)
