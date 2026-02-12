extends Node3D

@export var start_bots: int = 4
@export var max_bots: int = 12
@export var spawn_interval: float = 2.0

@onready var player: Node = $Player
@onready var bots_root: Node3D = $Bots
@onready var spawns: Node3D = $Spawns
@onready var hp_label: Label = $CanvasLayer/HUD/HP
@onready var ammo_label: Label = $CanvasLayer/HUD/Ammo
@onready var score_label: Label = $CanvasLayer/HUD/Score
@onready var wave_label: Label = $CanvasLayer/HUD/Wave

var bot_scene: PackedScene = preload("res://bot.tscn")
var score: int = 0
var wave: int = 1
var spawn_timer: float = 0.0

func _ready() -> void:
	_spawn_wave(start_bots)

func _process(delta: float) -> void:
	if player.has_method("is_dead") and player.is_dead():
		_update_hud()
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		if bots_root.get_child_count() < max_bots:
			_spawn_bot()

	if bots_root.get_child_count() == 0:
		wave += 1
		max_bots += 2
		_spawn_wave(start_bots + wave)

	_update_hud()

func _update_hud() -> void:
	if player:
		hp_label.text = "HP " + str(player.hp)
		if player.has_method("get_weapon_name"):
			ammo_label.text = "AMMO " + str(player.get_mag()) + " / " + str(player.get_reserve()) + "  [" + player.get_weapon_name() + "]  (1-5)"
		else:
			ammo_label.text = "AMMO"
	score_label.text = "SCORE " + str(score)
	wave_label.text = "WAVE " + str(wave)

func _spawn_wave(count: int) -> void:
	for i in range(count):
		_spawn_bot()

func _spawn_bot() -> void:
	var points = spawns.get_children()
	if points.size() == 0:
		return
	var idx = randi() % points.size()
	var pos = points[idx].global_position
	var b = bot_scene.instantiate()
	b.global_position = pos
	b.target = player
	b.tree_exited.connect(_on_bot_died)
	bots_root.add_child(b)

func _on_bot_died() -> void:
	score += 10
