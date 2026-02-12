extends Node3D

@export var max_players: int = 8
@export var round_time: float = 120.0
@export var bomb_time: float = 30.0

@onready var players_root: Node3D = $Players
@onready var spawner: Node3D = $Spawner
@onready var mode_label: Label = $CanvasLayer/HUD/ModeLabel
@onready var round_label: Label = $CanvasLayer/HUD/RoundLabel
@onready var score_label: Label = $CanvasLayer/HUD/ScoreLabel
@onready var bomb_site: Node3D = $BombSite

var player_scene: PackedScene = preload("res://player.tscn")
var player_nodes := {}
var player_team := {}
var player_hp := {}
var team_score := [0, 0]

var mode: int = 0 # 0=Deathmatch, 1=Bomb
var time_left: float = 0.0
var bomb_planted: bool = false
var bomb_left: float = 0.0

func _ready() -> void:
	add_to_group("game")
	mode = Network.mode
	time_left = round_time
	bomb_left = bomb_time
	_update_hud()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())
		for id in multiplayer.get_peers():
			_spawn_player(id)
		rpc("rpc_set_mode", mode)

func _process(delta: float) -> void:
	if multiplayer.is_server():
		time_left -= delta
		if time_left <= 0.0:
			_new_round()

		if mode == 1 and bomb_planted:
			bomb_left -= delta
			if bomb_left <= 0.0:
				team_score[0] += 1
				_new_round()

		rpc("rpc_time_update", time_left, bomb_planted, bomb_left)

func _update_hud() -> void:
	var mode_name = "DEATHMATCH" if mode == 0 else "BOMB"
	mode_label.text = "MODE: " + mode_name
	score_label.text = "SCORE A " + str(team_score[0]) + " : " + str(team_score[1]) + " B"

@rpc("reliable")
func rpc_set_mode(m: int) -> void:
	mode = m
	bomb_left = bomb_time
	_update_hud()

@rpc("unreliable")
func rpc_time_update(t: float, planted: bool, bleft: float) -> void:
	time_left = t
	bomb_planted = planted
	bomb_left = bleft
	var mm = int(time_left) / 60
	var ss = int(time_left) % 60
	var round_text = "ROUND: %02d:%02d" % [mm, ss]
	if mode == 1 and bomb_planted:
		round_text += " | BOMB %02d" % int(bomb_left)
	round_label.text = round_text
	_update_hud()

func _new_round() -> void:
	time_left = round_time
	bomb_planted = false
	bomb_left = bomb_time
	for id in player_nodes.keys():
		var pos = _get_spawn_pos(id)
		rpc("rpc_respawn", id, pos)

@rpc("reliable")
func rpc_respawn(id: int, pos: Vector3) -> void:
	if player_nodes.has(id):
		player_nodes[id].global_position = pos
		player_hp[id] = 100

func _get_spawn_pos(id: int) -> Vector3:
	var points = spawner.get_children()
	if points.size() == 0:
		return Vector3.ZERO
	var idx = id % points.size()
	return points[idx].global_position

func _spawn_player(id: int) -> void:
	if player_nodes.has(id):
		return
	var p = player_scene.instantiate()
	p.name = str(id)
	p.player_id = id
	p.set_multiplayer_authority(id)
	p.global_position = _get_spawn_pos(id)
	players_root.add_child(p)
	player_nodes[id] = p
	player_team[id] = id % 2
	player_hp[id] = 100
	p.set_team(player_team[id])
	rpc("rpc_spawn_player", id, player_team[id], p.global_position)

@rpc("reliable")
func rpc_spawn_player(id: int, team: int, pos: Vector3) -> void:
	if player_nodes.has(id):
		return
	var p = player_scene.instantiate()
	p.name = str(id)
	p.player_id = id
	p.set_multiplayer_authority(id)
	p.global_position = pos
	players_root.add_child(p)
	player_nodes[id] = p
	player_team[id] = team
	player_hp[id] = 100
	p.set_team(team)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if player_nodes.has(id):
		player_nodes[id].queue_free()
		player_nodes.erase(id)
		player_team.erase(id)
		player_hp.erase(id)

func request_shoot(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_server_shoot(origin, dir, multiplayer.get_unique_id())
	else:
		rpc_id(1, "server_shoot", origin, dir)

@rpc("any_peer", "reliable")
func server_shoot(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var shooter_id = multiplayer.get_remote_sender_id()
	_server_shoot(origin, dir, shooter_id)

func _server_shoot(origin: Vector3, dir: Vector3, shooter_id: int) -> void:
	var space = get_world_3d().direct_space_state
	var to = origin + dir.normalized() * 60.0
	var params = PhysicsRayQueryParameters3D.create(origin, to)
	params.exclude = []
	var hit = space.intersect_ray(params)
	if hit and hit.collider and hit.collider is CharacterBody3D:
		var target = hit.collider
		if target.player_id == shooter_id:
			return
		var tid = target.player_id
		player_hp[tid] -= 35
		if player_hp[tid] <= 0:
			player_hp[tid] = 100
			team_score[player_team[shooter_id]] += 1
			var pos = _get_spawn_pos(tid)
			rpc("rpc_respawn", tid, pos)
			rpc("rpc_update_score", team_score[0], team_score[1])

@rpc("reliable")
func rpc_update_score(a: int, b: int) -> void:
	team_score[0] = a
	team_score[1] = b
	_update_hud()

func request_use(player_id: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_server_use(player_id, pos)
	else:
		rpc_id(1, "server_use", player_id, pos)

@rpc("any_peer", "reliable")
func server_use(player_id: int, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender != player_id:
		return
	_server_use(player_id, pos)

func _server_use(player_id: int, pos: Vector3) -> void:
	if mode != 1:
		return
	var site_pos = bomb_site.global_position
	if pos.distance_to(site_pos) > 2.8:
		return
	var team = player_team.get(player_id, 0)
	if not bomb_planted and team == 0:
		bomb_planted = true
		bomb_left = bomb_time
	elif bomb_planted and team == 1:
		bomb_planted = false
		team_score[1] += 1
		_new_round()
		rpc("rpc_update_score", team_score[0], team_score[1])
