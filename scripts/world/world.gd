extends Node3D
## The shared neighborhood: a plaza surrounded by house plots.
##
## Networking model (listen server): the host is authoritative. Clients send
## their profile and house edits to the host, which checks them and then
## spawns players / broadcasts layouts to everyone. Free text never travels:
## names are word-list indices and chat is a preset phrase index.

const PLOT_COUNT := 8
const PHRASE_COOLDOWN := 1.0

var houses: Array[House] = []
var house_layouts := {} # peer id -> layout, kept on every peer
var player_plots := {} # peer id -> plot index, kept on every peer
var player_names := {} # peer id -> display name, kept on every peer
var local_player: Player

var _players: Node3D
var _spawner: MultiplayerSpawner
var _hud: Hud
var _build: BuildController
var _server_players := {} # host only: peer id -> sanitized public profile
var _last_phrase := {} # host only: peer id -> time of last phrase
var _save_timer := 0.0


func _ready() -> void:
	_build_environment()
	for i in PLOT_COUNT:
		var house := House.new()
		house.name = "Plot%d" % i
		house.position = plot_center(i)
		house.rotation_degrees.y = 0.0 if i < 4 else 180.0
		house.set_owner_name("")
		add_child(house)
		houses.append(house)

	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawn_function = _spawn_player
	_spawner.spawn_limit = Net.MAX_PLAYERS + 1

	_hud = Hud.new()
	add_child(_hud)
	_hud.phrase_chosen.connect(_send_phrase)
	_hud.build_toggled.connect(_toggle_build)
	_hud.leave_pressed.connect(func(): Net.back_to_menu())
	_build = BuildController.new()
	add_child(_build)
	_build.layout_edited.connect(_submit_house)
	_hud.item_selected.connect(func(id):
		_build.select_item(id)
		_hud.set_build_selection(id, _build.item_color, _build.item_style))
	_hud.color_changed.connect(_build.set_color)
	_hud.style_stepped.connect(func(step):
		_build.step_style(step)
		_hud.set_build_selection(_build.item_id, _build.item_color, _build.item_style))

	Net.status_changed.connect(_hud.set_status)
	Net.connection_ready.connect(_on_connection_ready)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	var err := Net.start()
	if err != OK:
		Net.back_to_menu.call_deferred("Could not start the world (error %d). Is the port in use?" % err)


func _exit_tree() -> void:
	_save_local_pet()


static func plot_center(i: int) -> Vector3:
	var x := -27.0 + 18.0 * float(i % 4)
	var z := -24.0 if i < 4 else 24.0
	return Vector3(x, 0, z)


# --- Joining and leaving -----------------------------------------------------

func _on_connection_ready() -> void:
	if multiplayer.is_server():
		_register(1, GameState.public_profile())
	else:
		register_player.rpc_id(1, GameState.public_profile())


@rpc("any_peer", "reliable")
func register_player(profile: Dictionary) -> void:
	if multiplayer.is_server():
		_register(multiplayer.get_remote_sender_id(), profile)


func _register(id: int, profile: Variant) -> void:
	if _server_players.has(id) or not profile is Dictionary:
		return
	var used := player_plots.values()
	var plot := -1
	for i in PLOT_COUNT:
		if not (i in used):
			plot = i
			break
	var data := {
		"id": id,
		"name_parts": SafeNames.clean_name_parts(profile.get("name_parts")),
		"avatar": AvatarBuilder.sanitize(profile.get("avatar")),
		"pet": PetBuilder.sanitize(profile.get("pet")),
		"house": House.sanitize_layout(profile.get("house")),
		"plot": plot,
		"spawn": Vector3(randf_range(-4, 4), 0.5, randf_range(4, 7)),
	}
	_server_players[id] = data
	# Late joiners get the newest layouts (spawn data only holds the original).
	if id != 1:
		for other in house_layouts:
			apply_house.rpc_id(id, other, house_layouts[other])
	house_layouts[id] = data["house"]
	_spawner.spawn(data)


## Runs on every peer, both for live spawns and for players who were already
## in the world when this peer joined.
func _spawn_player(data: Dictionary) -> Node:
	var d := data.duplicate()
	d["viewer_id"] = multiplayer.get_unique_id()
	var player := Player.new()
	player.setup(d)
	var id: int = player.peer_id
	var plot := int(d.get("plot", -1))
	player_plots[id] = plot
	player_names[id] = player.display_name
	if not house_layouts.has(id):
		house_layouts[id] = House.sanitize_layout(d.get("house"))
	if plot >= 0:
		houses[plot].owner_id = id
		houses[plot].set_owner_name(player.display_name)
		houses[plot].set_layout(house_layouts[id])
	player.tree_exiting.connect(_on_player_removed.bind(id))
	if id == multiplayer.get_unique_id():
		local_player = player
		_setup_local_player.call_deferred(player)
	else:
		_hud.add_chat("*", "%s joined" % player.display_name)
	return player


func _setup_local_player(player: Player) -> void:
	_hud.set_pet(player.pet.config["name"], PetBuilder.species_name(player.pet.config))
	player.pet_needs_changed.connect(_hud.set_pet_needs)
	var plot: int = player_plots.get(player.peer_id, -1)
	if plot >= 0:
		_build.house = houses[plot]
		_build.player = player
		_hud.toast("Welcome, %s! Your home is plot %d. Press H to go there." % [player.display_name, plot + 1])
	else:
		_hud.toast("Welcome! The neighborhood is full, so you are visiting today.")


func _on_player_removed(id: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var plot: int = player_plots.get(id, -1)
	if plot >= 0 and houses[plot].owner_id == id:
		houses[plot].owner_id = 0
		houses[plot].set_owner_name("")
		houses[plot].set_layout([])
	if id != multiplayer.get_unique_id() and player_names.has(id):
		_hud.add_chat("*", "%s left" % player_names[id])
	player_plots.erase(id)
	player_names.erase(id)
	house_layouts.erase(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_players.erase(id)
	_last_phrase.erase(id)
	var node := _players.get_node_or_null(str(id))
	if node:
		node.queue_free()


# --- Houses ------------------------------------------------------------------

func _submit_house(layout: Array) -> void:
	if multiplayer.is_server():
		_receive_house(1, layout)
	else:
		submit_house.rpc_id(1, layout)


@rpc("any_peer", "reliable")
func submit_house(layout: Array) -> void:
	if multiplayer.is_server():
		_receive_house(multiplayer.get_remote_sender_id(), layout)


func _receive_house(id: int, layout: Variant) -> void:
	if not _server_players.has(id):
		return
	apply_house.rpc(id, House.sanitize_layout(layout))


@rpc("authority", "call_local", "reliable")
func apply_house(id: int, layout: Array) -> void:
	house_layouts[id] = layout
	# The local player already sees their own edits; skip the echo.
	if id == multiplayer.get_unique_id() and not multiplayer.is_server():
		return
	var plot: int = player_plots.get(id, -1)
	if plot >= 0 and houses[plot].owner_id == id:
		houses[plot].set_layout(layout)


# --- Chat and pets -----------------------------------------------------------

func _send_phrase(index: int) -> void:
	if multiplayer.is_server():
		_receive_phrase(1, index)
	else:
		submit_phrase.rpc_id(1, index)


@rpc("any_peer", "reliable")
func submit_phrase(index: int) -> void:
	if multiplayer.is_server():
		_receive_phrase(multiplayer.get_remote_sender_id(), index)


func _receive_phrase(id: int, index: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _server_players.has(id) or SafeNames.phrase(index) == "":
		return
	if now - float(_last_phrase.get(id, -10.0)) < PHRASE_COOLDOWN:
		return
	_last_phrase[id] = now
	show_phrase.rpc(id, index)


@rpc("authority", "call_local", "reliable")
func show_phrase(id: int, index: int) -> void:
	var player := _players.get_node_or_null(str(id)) as Player
	var text := SafeNames.phrase(index)
	if player and text != "":
		player.say(text)
		_hud.add_chat(player.display_name, text)


func _unhandled_input(event: InputEvent) -> void:
	if not local_player:
		return
	if event.is_action_pressed("build_mode"):
		_toggle_build()
	elif event.is_action_pressed("build_style") and _build.active:
		_build.step_style(1)
		_hud.set_build_selection(_build.item_id, _build.item_color, _build.item_style)
	elif event.is_action_pressed("quick_chat"):
		_hud.open_quick_chat()
	elif event.is_action_pressed("go_home"):
		var plot: int = player_plots.get(local_player.peer_id, -1)
		if plot >= 0:
			local_player.teleport(houses[plot].to_global(Vector3(0, 0.5, House.PLOT_SIZE / 2.0 + 1.5)))
			local_player.set_camera_yaw(houses[plot].rotation.y)
	elif event.is_action_pressed("menu"):
		if _build.active:
			_toggle_build()
		else:
			Net.back_to_menu()
	elif event.is_action_pressed("pet_feed") or event.is_action_pressed("pet_play"):
		var pet := local_player.pet
		if pet.global_position.distance_to(local_player.global_position) > 4.0:
			_hud.toast("Get closer to %s first!" % pet.config["name"])
		elif event.is_action_pressed("pet_feed"):
			pet.feed()
			local_player.pet_reaction.rpc(0, 0)
		else:
			local_player.pet_reaction.rpc(1, pet.play())


func _toggle_build() -> void:
	if not _build.house:
		_hud.toast("You need a plot to build. The neighborhood is full right now.")
		return
	_build.set_active(not _build.active)
	_hud.show_build(_build.active)
	_hud.set_build_selection(_build.item_id, _build.item_color, _build.item_style)


func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		_save_local_pet()


func _save_local_pet() -> void:
	if local_player and is_instance_valid(local_player) and local_player.pet:
		GameState.profile["pet"] = local_player.pet.save_state()
		GameState.save_profile()


# --- Scenery -------------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Lighting.environment()
	add_child(env)
	add_child(Lighting.sun())
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	Scenery.build(ground)
