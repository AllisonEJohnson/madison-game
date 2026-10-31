extends Node3D
## The shared neighborhood: a plaza surrounded by house plots.
##
## Networking model (listen server): the host is authoritative. Clients send
## their profile and house edits to the host, which checks them and then
## spawns players / broadcasts layouts to everyone. Free text never travels:
## names are word-list indices and chat is a preset phrase index.

const PLOT_COUNT := 8
const PHRASE_COOLDOWN := 1.0
const AVATAR_COOLDOWN := 0.3
## Acorns: spots to grow them on in each land, and how many are out at once.
const ACORN_SPOTS := 48
## Starfall Glade sits this far off to the side of the town, out of sight.
## Being in the same scene keeps networking the same everywhere.
const GLADE_ORIGIN := Vector3(600, 0, 0)
## The Sky Garden floats above the glade's east side (glade coordinates); its
## portal stands at the castle door, where the north path ends.
const SKY_GARDEN := Vector3(40, 36, -2)
const SKY_PORTAL := Vector3(0, 0, -36)
const LAND_NAMES := {"town": "Hometown", "glade": "Starfall Glade"}

var houses: Array[House] = []
var house_layouts := {} # peer id -> layout, kept on every peer
var player_plots := {} # peer id -> plot index, kept on every peer
var player_names := {} # peer id -> display name, kept on every peer
## Avatars changed since their players joined (by buying clothes), kept on
## every peer so late joiners see the new look.
var player_avatars := {} # peer id -> avatar config
var local_player: Player

var _players: Node3D
var _spawner: MultiplayerSpawner
var _hud: Hud
var _build: BuildController
var _server_players := {} # host only: peer id -> sanitized public profile
var _last_phrase := {} # host only: peer id -> time of last phrase
var _last_avatar := {} # host only: peer id -> time of last avatar change
var _save_timer := 0.0
var _land := "town" # Where the local player is: "town" or "glade".
var _lands := {} # land -> its root node
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _glade: FantasyLand
var _pickups: Array[AcornPickups] = []
var _zone: InteractZone # the one the local player stands in
## Portals to places that open at a level: area (see Levels.AREAS) -> Portal.
var _area_portals := {}
var _lock_level := 0 # The level the portal locks were last set for.
var _sky: SkyGarden
var _in_sky := false
var _pets: PetKeeper


func _ready() -> void:
	_build_environment()
	for i in PLOT_COUNT:
		var house := House.new()
		house.name = "Plot%d" % i
		house.position = plot_center(i)
		house.rotation_degrees.y = 0.0 if i < 4 else 180.0
		house.set_owner_name("")
		_lands["town"].add_child(house)
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
	_hud.home_pressed.connect(_go_home)
	_hud.pet_action.connect(_pet_action)
	_hud.leave_confirmed.connect(func(): Net.back_to_menu())
	_hud.zone_used.connect(_use_zone)
	_hud.shop_decorate.connect(_decorate_with)
	_hud.shop_wear.connect(_wear)
	_hud.chase_again.connect(func(): _glade.chase.start())
	GameState.wallet_changed.connect(_hud.set_wallet)
	_glade.chase.ticked.connect(_hud.show_game)
	_glade.chase.finished.connect(_on_chase_finished)
	for pickups in _pickups:
		pickups.collected.connect(_on_acorn)
	if AdminConsole.enabled():
		add_child(AdminConsole.new())
	# Wild pets to find in every land, and bringing a different pet along.
	_pets = PetKeeper.new().setup(self, _hud)
	add_child(_pets)
	_pets.add_wild("town", _lands["town"], Scenery.acorn_spots(ACORN_SPOTS), 2, 41)
	_pets.add_wild("glade", _glade, _glade.acorn_spots(ACORN_SPOTS), 3, 42)
	_pets.add_wild("sky", _sky, _sky.acorn_spots(16), 2, 43)
	_build = BuildController.new()
	add_child(_build)
	_build.layout_edited.connect(_submit_house)
	_build.item_placed.connect(func(key):
		GameState.add_recent(key)
		_hud.refresh_recent()
		Progress.award("decorate"))
	_build.purchase_needed.connect(_hud.need_purchase)
	_hud.entry_chosen.connect(func(id, style):
		_build.select_item(id, style)
		_show_build_selection())
	_hud.color_changed.connect(_build.set_color)
	_hud.style_stepped.connect(func(step):
		_build.step_style(step)
		_show_build_selection())
	_hud.rotate_pressed.connect(_build.rotate_item)
	_hud.erase_toggled.connect(_build.set_erasing)

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
	# Late joiners get the newest layouts and looks (spawn data only holds the original).
	if id != 1:
		for other in house_layouts:
			apply_house.rpc_id(id, other, house_layouts[other])
		for other in player_avatars:
			apply_avatar.rpc_id(id, other, player_avatars[other])
	house_layouts[id] = data["house"]
	_spawner.spawn(data)


## Runs on every peer, both for live spawns and for players who were already
## in the world when this peer joined.
func _spawn_player(data: Dictionary) -> Node:
	var d := data.duplicate()
	d["viewer_id"] = multiplayer.get_unique_id()
	if player_avatars.has(int(d["id"])):
		d["avatar"] = player_avatars[int(d["id"])]
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
	_hud.set_player(player.display_name, GameState.profile["avatar"])
	for pickups in _pickups:
		pickups.player = player
	_glade.chase.player = player
	_pets.set_player(player)
	_hud.set_pet(player.pet.config["name"], PetBuilder.species_name(player.pet.config), player.pet.config)
	player.pet_needs_changed.connect(_hud.set_pet_needs)
	var plot: int = player_plots.get(player.peer_id, -1)
	if plot >= 0:
		_build.house = houses[plot]
		_build.player = player
		_hud.toast("Welcome, %s! Your home is plot %d. Press Home to go there." % [player.display_name, plot + 1])
	else:
		_hud.toast("Welcome! The neighborhood is full, so you are visiting today.")
	Progress.award("daily")


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
	player_avatars.erase(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_players.erase(id)
	_last_phrase.erase(id)
	_last_avatar.erase(id)
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


# --- Avatars ---------------------------------------------------------------------
# Clothes bought in the shop can be worn right away. Like houses, the host checks
# the new look and tells everyone.

func _submit_avatar(avatar: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_avatar(1, avatar)
	else:
		submit_avatar.rpc_id(1, avatar)


@rpc("any_peer", "reliable")
func submit_avatar(avatar: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_avatar(multiplayer.get_remote_sender_id(), avatar)


func _receive_avatar(id: int, avatar: Variant) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _server_players.has(id) or now - float(_last_avatar.get(id, -10.0)) < AVATAR_COOLDOWN:
		return
	_last_avatar[id] = now
	var clean := AvatarBuilder.sanitize(avatar)
	_server_players[id]["avatar"] = clean
	apply_avatar.rpc(id, clean)


@rpc("authority", "call_local", "reliable")
func apply_avatar(id: int, avatar: Dictionary) -> void:
	var clean := AvatarBuilder.sanitize(avatar)
	player_avatars[id] = clean
	var player := _players.get_node_or_null(str(id)) as Player
	if player:
		player.set_avatar(clean)
	if id == multiplayer.get_unique_id() and player:
		_hud.set_player(player.display_name, clean)


## Puts on clothes from the shop (only ones you own).
func _wear(option: String, index: int) -> void:
	if not GameState.owns(ShopCatalog.clothes_key(option, index)):
		return
	var avatar := AvatarBuilder.sanitize(ShopCatalog.try_on(GameState.profile["avatar"], option, index))
	GameState.profile["avatar"] = avatar
	GameState.save_profile()
	_submit_avatar(avatar)
	_hud.toast("Looking good!")


# --- Earning and the shop -----------------------------------------------------------

func _on_acorn(amount: int, golden: bool, _where: Vector3) -> void:
	GameState.earn("acorns", amount)
	Progress.award("golden_acorn" if golden else "acorn")
	if golden:
		_hud.toast("A golden acorn! +%d Acorns" % amount)


func _on_chase_finished(caught: int, reward: int) -> void:
	var new_best := GameState.record_best("chase_best", caught)
	GameState.earn("acorns", reward)
	_hud.show_game_result(caught, reward, new_best, Progress.award("star", caught))


## The zone the local player is standing in, or null.
func _zone_here() -> InteractZone:
	if not local_player or not is_instance_valid(local_player):
		return null
	for zone: InteractZone in get_tree().get_nodes_in_group("interact_zones"):
		if zone.reaches(local_player.global_position):
			return zone
	return null


func _use_zone() -> void:
	if not _zone or _build.active:
		return
	if _zone == _glade.chase.zone:
		_hud.close_popups()
		_glade.chase.start()
	elif _pets.use_zone(_zone):
		pass
	else:
		_hud.open_shop()


## From the shop's "Decorate" button: go home and pick that piece.
func _decorate_with(id: String, style: int) -> void:
	if not _build.active:
		_toggle_build()
	if _build.active:
		_build.select_item(id, style)
		_show_build_selection()


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
		_show_build_selection()
	elif event.is_action_pressed("interact") and not _build.active and _zone:
		_use_zone()
	elif event.is_action_pressed("quick_chat"):
		_hud.open_quick_chat()
	elif event.is_action_pressed("go_home"):
		_go_home()
	elif event.is_action_pressed("menu"):
		# Esc closes the top-most thing first, and asks before leaving.
		if _hud.close_popups():
			pass
		elif _build.active:
			_toggle_build()
		else:
			_hud.ask_leave()
	elif event.is_action_pressed("pet_feed"):
		_pet_action(true)
	elif event.is_action_pressed("pet_play"):
		_pet_action(false)


# --- Lands and portals ---------------------------------------------------------

func _travel(player: Player, to: Portal) -> void:
	if player != local_player or _build.active:
		return
	player.teleport(to.arrival_point())
	player.set_camera_yaw(to.arrival_yaw())


## Which land a spot is in. The glade is far enough away that a simple
## split halfway between works.
static func land_at(pos: Vector3) -> String:
	return "glade" if pos.x > GLADE_ORIGIN.x / 2.0 else "town"


## Swaps the sky and light for the land the local player is in, and hides the
## other land so it costs nothing to draw.
func _enter_land(land: String) -> void:
	_land = land
	_env.environment = Lighting.environment(true, land)
	_sun.light_color = Lighting.LANDS[land]["sun"]
	for key in _lands:
		_lands[key].visible = key == land
	if land != "glade":
		_glade.chase.stop()
	_hud.toast("Welcome to %s!" % LAND_NAMES[land])
	Progress.visit(land)


func _go_home() -> void:
	var plot: int = player_plots.get(local_player.peer_id, -1) if local_player else -1
	if plot >= 0:
		local_player.teleport(houses[plot].to_global(Vector3(0, 0.5, House.PLOT_SIZE / 2.0 + 1.5)))
		local_player.set_camera_yaw(houses[plot].rotation.y)


func _pet_action(feed: bool) -> void:
	if not local_player:
		return
	var pet := local_player.pet
	if pet.global_position.distance_to(local_player.global_position) > 4.0:
		_hud.toast("Get closer to %s first!" % pet.config["name"])
	elif feed:
		pet.feed()
		local_player.pet_reaction.rpc(0, 0)
		Progress.award("feed_pet")
	else:
		local_player.pet_reaction.rpc(1, pet.play())
		Progress.award("play_pet")


func _toggle_build() -> void:
	if not _build.house:
		_hud.toast("You need a home to decorate. The neighborhood is full right now.")
		return
	# Homes are in town, so decorating from another land takes you home first.
	if not _build.active and land_at(local_player.global_position) != "town":
		_go_home()
	_glade.chase.stop()
	_build.set_active(not _build.active)
	_hud.show_build(_build.active)
	_show_build_selection()


func _show_build_selection() -> void:
	_hud.set_build_selection(_build.item_id, _build.item_color, _build.item_style, _build.erasing)


func _process(delta: float) -> void:
	if local_player and is_instance_valid(local_player) and local_player.is_inside_tree():
		var land := land_at(local_player.global_position)
		if land != _land:
			_enter_land(land)
		var in_sky := land == "glade" and local_player.global_position.y > SKY_GARDEN.y - 6.0
		if in_sky != _in_sky:
			_in_sky = in_sky
			if in_sky:
				_hud.toast("Welcome to the Sky Garden!")
				Progress.visit("sky")
		var zone := _zone_here()
		if zone != _zone:
			_zone = zone
			_hud.show_prompt(zone)
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
	_env = WorldEnvironment.new()
	_env.environment = Lighting.environment()
	add_child(_env)
	_sun = Lighting.sun()
	add_child(_sun)
	var town := Node3D.new()
	town.name = "Town"
	add_child(town)
	_lands["town"] = town
	var ground := Node3D.new()
	ground.name = "Ground"
	town.add_child(ground)
	Scenery.build(ground)
	var glade := FantasyLand.new()
	glade.position = GLADE_ORIGIN
	glade.visible = false
	add_child(glade)
	_lands["glade"] = glade
	_glade = glade
	var shop := ShopStall.new()
	shop.position = Scenery.SHOP_SPOT
	shop.rotation.y = -PI / 2 # Faces the fountain.
	town.add_child(shop)
	# Acorns to find in both lands; they grow under each land so they hide with it.
	var town_acorns := AcornPickups.new().setup(Scenery.acorn_spots(ACORN_SPOTS), 11)
	town_acorns.name = "Acorns"
	town.add_child(town_acorns)
	var glade_acorns := AcornPickups.new().setup(glade.acorn_spots(ACORN_SPOTS), 22)
	glade_acorns.name = "Acorns"
	glade.add_child(glade_acorns)
	# The Sky Garden, high above the glade, opens at a level; golden acorns grow there often.
	_sky = SkyGarden.new()
	_sky.position = SKY_GARDEN
	glade.add_child(_sky)
	var sky_acorns := AcornPickups.new().setup(_sky.acorn_spots(16), 33)
	sky_acorns.name = "Acorns"
	sky_acorns.golden_chance = 0.4
	_sky.add_child(sky_acorns)
	_pickups.assign([town_acorns, glade_acorns, sky_acorns])
	var to_sky := Portal.new().setup("Sky Garden", Color("ff9ad5"))
	to_sky.position = SKY_PORTAL
	glade.add_child(to_sky)
	to_sky.entered.connect(_travel.bind(_sky.portal))
	_sky.portal.entered.connect(_travel.bind(to_sky))
	var to_glade := Portal.new().setup("Starfall Glade", Color("b77cff"))
	to_glade.position = Scenery.GLADE_PORTAL
	to_glade.rotation.y = PI / 2 # Faces the plaza.
	town.add_child(to_glade)
	to_glade.entered.connect(_travel.bind(glade.portal))
	glade.portal.entered.connect(_travel.bind(to_glade))
	_area_portals["glade"] = to_glade
	_area_portals["sky"] = to_sky
	for area in _area_portals:
		_area_portals[area].knocked.connect(_on_locked_portal.bind(area))
	_refresh_locks()
	Progress.xp_changed.connect(func(_gained): _refresh_locks())


## Locks each portal whose place needs a higher level than yours (locks are
## for the local player only; everyone has their own level).
func _refresh_locks() -> void:
	if Progress.level() == _lock_level:
		return
	_lock_level = Progress.level()
	for area in _area_portals:
		_area_portals[area].set_locked(not Progress.can_enter(area), Levels.area_level(area))


func _on_locked_portal(player: Player, area: String) -> void:
	if player != local_player:
		return
	_hud.toast("%s opens at level %d! Pick up acorns and play to earn XP." % [Levels.AREAS[area]["name"],
			Levels.area_level(area)])
