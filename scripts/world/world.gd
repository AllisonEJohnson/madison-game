extends Node3D
## The shared neighborhood: a plaza surrounded by house plots. Town only shows
## homes from outside; walking in through a front door takes you to that home's
## inside, a space of its own far from town that is only built while you're in
## it (see House and HomePlot).
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
## Insides of homes are built out here, one spot per plot, far from both lands
## (and from each other) so no one sees across.
const HOMES_ORIGIN := Vector3(-1500, 0, 0)
const HOME_SPACING := 300.0
## After walking through a door or portal, doors ignore you this long.
const DOOR_COOLDOWN := 1.0

var plots: Array[HomePlot] = []
## Each player's home as everyone sees it, kept on every peer:
## peer id -> {"type", "rooms", "items"} (see HomeCatalog).
var homes := {}
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
var _build_home_shown := "" # What the decorating banner last said about the home.
var _inside: House # The inside of the home the local player is in, or null.
var _inside_plot := -1
var _door_time := -10.0 # When the local player last went through a door.
var _pets: PetKeeper


func _ready() -> void:
	_build_environment()
	for i in PLOT_COUNT:
		var plot := HomePlot.new()
		plot.name = "Plot%d" % i
		plot.position = plot_center(i)
		plot.rotation_degrees.y = 0.0 if i < 4 else 180.0
		plot.door_entered.connect(_on_plot_door.bind(i))
		_lands["town"].add_child(plot)
		plots.append(plot)

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
	_build.home_full.connect(func(): _hud.toast("Your home is full! Add a room to fit more."))
	_hud.home_chosen.connect(_visit_home)
	GameState.owned_changed.connect(_refresh_own_home)
	_hud.entry_chosen.connect(func(id, style):
		_build.select_item(id, style)
		_show_build_selection())
	_hud.color_changed.connect(_build.set_color)
	_hud.style_stepped.connect(func(step):
		_build.step_style(step)
		_show_build_selection())
	_hud.rotate_pressed.connect(_build.rotate_item)
	_hud.erase_toggled.connect(_build.set_erasing)
	# Touch screens: look around and zoom with fingers; tap to place while decorating.
	_hud.touch.look.connect(func(yaw, pitch):
		if local_player:
			local_player.look(yaw, pitch))
	_hud.touch.zoomed.connect(func(factor):
		if local_player:
			local_player.zoom_by(factor))
	_hud.touch.pressed_at.connect(_build.preview_at)
	_hud.touch.press_ended.connect(_build.end_preview)
	_hud.touch.tapped.connect(_build.tap_at)

	Net.status_changed.connect(_hud.set_status)
	Net.connection_ready.connect(_on_connection_ready)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	var err := Net.start()
	if err != OK:
		Net.back_to_menu.call_deferred("Could not start the world (error %d). Is the port in use?" % err)


func _exit_tree() -> void:
	_save_local_pet()


## Four lots on each side of the plaza, fronts on the street.
static func plot_center(i: int) -> Vector3:
	var x := -39.0 + 26.0 * float(i % 4)
	var z := -29.0 if i < 4 else 29.0
	return Vector3(x, 0, z)


## Where the inside of plot `i`'s home is built.
static func inside_origin(i: int) -> Vector3:
	return HOMES_ORIGIN + Vector3(0, 0, i * HOME_SPACING)


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
		"home": HomeCatalog.sanitize(profile.get("home")),
		"plot": plot,
		"spawn": Vector3(randf_range(-4, 4), 0.5, randf_range(4, 7)),
	}
	_server_players[id] = data
	# Late joiners get the newest layouts and looks (spawn data only holds the original).
	if id != 1:
		for other in homes:
			apply_home.rpc_id(id, other, homes[other])
		for other in player_avatars:
			apply_avatar.rpc_id(id, other, player_avatars[other])
	homes[id] = data["home"]
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
	if not homes.has(id):
		homes[id] = HomeCatalog.sanitize(d.get("home"))
	if plot >= 0:
		plots[plot].owner_id = id
		plots[plot].set_owner_name(player.display_name)
		plots[plot].set_home(homes[id])
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
	_build.player = player
	if plot >= 0:
		plots[plot].sign_zone.enabled = true
		_hud.toast("Welcome, %s! Your home is plot %d. %s Go home to go inside." % [player.display_name, plot + 1,
				"Tap" if TouchInput.active else "Press"])
	else:
		_hud.toast("Welcome! The neighborhood is full, so you are visiting today.")
	Progress.award("daily")


func _on_player_removed(id: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var plot: int = player_plots.get(id, -1)
	if plot >= 0 and plots[plot].owner_id == id:
		# Visitors inside a home whose player left go back out to the street.
		if _inside_plot == plot and id != multiplayer.get_unique_id():
			_hud.toast("%s left, so you're back outside." % player_names.get(id, "Your host"))
			_leave_home(-1)
		plots[plot].owner_id = 0
		plots[plot].set_owner_name("")
		plots[plot].clear()
	if id != multiplayer.get_unique_id() and player_names.has(id):
		_hud.add_chat("*", "%s left" % player_names[id])
	player_plots.erase(id)
	player_names.erase(id)
	homes.erase(id)
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


# --- Homes ------------------------------------------------------------------------
# Each player's plot shows the outside of the home they live in. Furniture
# edits, moving to another home and new rooms all send the whole home to the
# host, which checks it and tells everyone; whoever is inside sees it change.

## Furniture edits from decorating.
func _submit_house(layout: Array) -> void:
	var home := Homes.active()
	home["items"] = layout
	_submit_home(home)


func _submit_home(home: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_home(1, home)
	else:
		submit_home.rpc_id(1, home)


@rpc("any_peer", "reliable")
func submit_home(home: Dictionary) -> void:
	if multiplayer.is_server():
		_receive_home(multiplayer.get_remote_sender_id(), home)


func _receive_home(id: int, home: Variant) -> void:
	if not _server_players.has(id):
		return
	apply_home.rpc(id, HomeCatalog.sanitize(home))


@rpc("authority", "call_local", "reliable")
func apply_home(id: int, home: Dictionary) -> void:
	homes[id] = home
	# The local player already sees their own home; skip the echo.
	if id == multiplayer.get_unique_id() and not multiplayer.is_server():
		return
	var plot: int = player_plots.get(id, -1)
	if plot < 0 or plots[plot].owner_id != id:
		return
	plots[plot].set_home(home)
	if _inside_plot == plot and id != multiplayer.get_unique_id():
		if home["type"] != _inside.home_type:
			# They moved to another of their homes: so does everyone visiting.
			_enter_home(plot, 0)
		else:
			_inside.set_home(home)


func _own_plot() -> int:
	return player_plots.get(local_player.peer_id, -1) if local_player else -1


## The inside of your own home while you're in it, else null.
func _own_inside() -> House:
	return _inside if _inside_plot >= 0 and _inside_plot == _own_plot() else null


## From the Homes window: moves into that home if it isn't the one lived in,
## then goes inside.
func _visit_home(type: String) -> void:
	var plot := _own_plot()
	if plot < 0:
		_hud.toast("The neighborhood is full right now, so there's no plot for a home.")
		return
	if type != Homes.current():
		if not Homes.move_in(type):
			return
		if _build.active:
			_toggle_build()
		plots[plot].set_home(Homes.active())
		_submit_home(Homes.active())
		_hud.toast("Welcome to your %s!" % HomeCatalog.home_name(type))
	_go_home()


## After buying something: a new room shows up on the plot (and inside, if
## you're there) right away.
func _refresh_own_home() -> void:
	var plot := _own_plot()
	if plot < 0:
		return
	var home := Homes.active()
	if home["type"] != plots[plot].home_type or home["rooms"] != plots[plot].rooms:
		plots[plot].set_home(home)
		_submit_home(home)
		var inside := _own_inside()
		if inside:
			inside.set_home(home)
			if _build.active:
				inside.set_decorating(true, Homes.plan_labels(inside.home_type))


## Goes inside the home on plot `plot`, through its entrance `door`: builds the
## inside out of sight of town and moves the local player there.
func _enter_home(plot: int, door: int) -> void:
	var owner_id := plots[plot].owner_id
	if not local_player or owner_id == 0 or not homes.has(owner_id):
		return
	var mine := owner_id == local_player.peer_id
	_close_inside()
	var inside := House.new()
	inside.name = "Inside"
	inside.position = inside_origin(plot)
	add_child(inside)
	inside.set_home(Homes.active() if mine else homes[owner_id])
	inside.door_entered.connect(_on_inside_door)
	_inside = inside
	_inside_plot = plot
	if mine:
		_build.house = inside
	var spot := inside.arrival(door)
	# A little apart, so friends coming in together don't land on each other.
	local_player.teleport(spot["position"] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))
	local_player.face(spot["yaw"])
	_door_time = _now()
	var name := HomeCatalog.home_name(inside.home_type)
	_hud.toast(("Welcome home!" if mine else "Welcome to %s's %s!" % [player_names.get(owner_id, "a friend"), name])
			+ " Walk out the door to go back outside.")


## Goes back out to town through door `door` of the home you're in (-1: to
## the street in front of the plot).
func _leave_home(door: int) -> void:
	var plot := _inside_plot
	if plot < 0:
		return
	if _build.active:
		_toggle_build()
	var spot := plots[plot].departure(door) if door >= 0 and plots[plot].home_type != "" \
			else {"position": plots[plot].front(), "yaw": plots[plot].global_rotation.y}
	_close_inside()
	local_player.teleport(spot["position"])
	local_player.face(spot["yaw"])
	_door_time = _now()


## Removes the inside you were in: in town, no insides are built at all.
func _close_inside() -> void:
	if _inside:
		if _build.house == _inside:
			_build.house = null
		_inside.queue_free()
	_inside = null
	_inside_plot = -1


func _on_plot_door(player: Player, door: int, plot: int) -> void:
	if player == local_player and not _build.active and _now() - _door_time > DOOR_COOLDOWN:
		_enter_home(plot, door)


func _on_inside_door(player: Player, door: int) -> void:
	if player == local_player and not _build.active and _now() - _door_time > DOOR_COOLDOWN:
		_leave_home(door)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


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
	elif _zone.has_meta("homes"):
		_hud.open_homes()
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


## Which land a spot is in: "town", "glade", or "home" (inside a home). They
## are far enough apart that a simple split halfway between works.
static func land_at(pos: Vector3) -> String:
	if pos.x < HOMES_ORIGIN.x / 2.0:
		return "home"
	return "glade" if pos.x > GLADE_ORIGIN.x / 2.0 else "town"


## Who can see whom: everyone outdoors shares one place, and each home's
## inside is a place of its own. "world" or "home:<plot>".
static func place_at(pos: Vector3) -> String:
	if land_at(pos) != "home":
		return "world"
	return "home:%d" % roundi((pos.z - HOMES_ORIGIN.z) / HOME_SPACING)


## Swaps the sky and light for the land the local player is in, and hides the
## other land so it costs nothing to draw. Inside a home, both lands hide.
func _enter_land(land: String) -> void:
	var was := _land
	_land = land
	var light := "town" if land == "home" else land
	_env.environment = Lighting.environment(true, light)
	_sun.light_color = Lighting.LANDS[light]["sun"]
	for key in _lands:
		_lands[key].visible = key == land
	if land != "glade":
		_glade.chase.stop()
	if land != "home":
		# Out of every home (even by falling off the world): no insides stay built.
		_close_inside()
		if was != "home":
			_hud.toast("Welcome to %s!" % LAND_NAMES[land])
		Progress.visit(land)


## Goes inside your own home, through its front door.
func _go_home() -> void:
	var plot := _own_plot()
	if plot >= 0:
		_enter_home(plot, 0)
	elif local_player:
		_hud.toast("The neighborhood is full right now, so there's no plot for a home.")


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
	if _own_plot() < 0:
		_hud.toast("You need a home to decorate. The neighborhood is full right now.")
		return
	# Decorating happens inside your home, so it takes you there first.
	if not _build.active and _own_inside() == null:
		_go_home()
	_glade.chase.stop()
	_build.set_active(not _build.active)
	_hud.show_build(_build.active)
	_show_build_selection()
	# On a touch screen, look down into the home so a tap can place things
	# right away (the catalog covers the bottom of the screen).
	if _build.active and TouchInput.active and local_player:
		local_player.set_camera_view(-0.95, 9.0)


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
		# Only players in the same place show: outdoors, or inside the same home.
		var here := place_at(local_player.global_position)
		for p in _players.get_children():
			if p != local_player and p is Player:
				p.visible = place_at(p.global_position) == here
	if _build.active:
		var shown := "%s:%d:%d" % [_build.house.home_type, _build.house.layout.size(), _build.house.capacity]
		if shown != _build_home_shown:
			_build_home_shown = shown
			_hud.set_build_home(HomeCatalog.home_name(_build.house.home_type), _build.house.layout.size(),
					_build.house.capacity)
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
