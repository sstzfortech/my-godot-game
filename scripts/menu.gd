extends Control

@onready var ip_input: LineEdit = $Panel/IpInput
@onready var mode_option: OptionButton = $Panel/ModeOption
@onready var status: Label = $Panel/Status
@onready var host_btn: Button = $Panel/HostButton
@onready var join_btn: Button = $Panel/JoinButton

func _ready() -> void:
    mode_option.clear()
    mode_option.add_item("Deathmatch")
    mode_option.add_item("Bomb")
    status.text = ""
    host_btn.pressed.connect(_on_host)
    join_btn.pressed.connect(_on_join)

func _on_host() -> void:
    status.text = "Hosting..."
    Network.start_host(8, _selected_mode())
    get_tree().change_scene_to_file("res://game.tscn")

func _on_join() -> void:
    var ip = ip_input.text.strip_edges()
    if ip == "":
        status.text = "Enter server IP"
        return
    status.text = "Joining " + ip + "..."
    Network.start_client(ip)
    get_tree().change_scene_to_file("res://game.tscn")

func _selected_mode() -> int:
    return mode_option.selected
