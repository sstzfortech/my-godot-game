extends Node

var mode: int = 0 # 0=DM, 1=Bomb
var max_players: int = 8
var server_port: int = 7777

func start_host(p_max_players: int, p_mode: int) -> void:
    max_players = p_max_players
    mode = p_mode
    var peer := ENetMultiplayerPeer.new()
    peer.create_server(server_port, max_players)
    multiplayer.multiplayer_peer = peer

func start_client(ip: String) -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_client(ip, server_port)
    multiplayer.multiplayer_peer = peer
