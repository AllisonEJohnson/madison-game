extends Node
## Thin wrapper around Godot's ENet high-level multiplayer.
## The menu picks host or join, then the world scene calls start() once it is
## loaded, so the scene tree exists before any replication arrives.

signal connection_ready
signal status_changed(text: String)

enum Mode { NONE, HOST, JOIN }

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 8
const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"

var mode := Mode.NONE
var address := "127.0.0.1"
var port := DEFAULT_PORT
## Shown on the menu after being sent back there (e.g. "The host left").
var menu_message := ""


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): back_to_menu("Could not connect to that world."))
	multiplayer.server_disconnected.connect(func(): back_to_menu("The host closed the world."))


func request_host(p: int) -> void:
	mode = Mode.HOST
	port = p
	get_tree().change_scene_to_file(WORLD_SCENE)


func request_join(addr: String, p: int) -> void:
	mode = Mode.JOIN
	address = addr
	port = p
	get_tree().change_scene_to_file(WORLD_SCENE)


## Called by the world scene. Returns OK, or an error the world shows to the player.
func start() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error
	if mode == Mode.HOST:
		err = peer.create_server(port, MAX_PLAYERS)
	else:
		err = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	if mode == Mode.HOST:
		status_changed.emit("Hosting on port %d" % port)
		connection_ready.emit.call_deferred()
	else:
		status_changed.emit("Connecting to %s:%d..." % [address, port])
	return OK


func stop() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.NONE


func back_to_menu(message := "") -> void:
	menu_message = message
	stop()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_connected() -> void:
	status_changed.emit("Connected to %s:%d" % [address, port])
	connection_ready.emit()
