class_name PetKeeper
extends Node
## The world's side of pets beyond the one following you: the wild pets in
## each land, making friends with them, bringing a different pet along, and
## telling everyone when a player's pet changes.
##
## It's a child of the world named "Pets" on every peer, so its RPCs reach the
## same node everywhere. Like a new outfit, a new pet goes to the host, which
## checks it and passes it on to everyone; late joiners get the latest pets.

const SWITCH_COOLDOWN := 0.5

var _world: Node3D
var _hud: Hud
var _wild: Array[WildPets] = []
## The wild pet whose card is open.
var _meeting: WildPet
## Pets changed since their players joined: peer id -> config, on every peer.
var player_pets := {}
var _last_switch := {} # host only: peer id -> time of the last change


func setup(world: Node3D, hud: Hud) -> PetKeeper:
	name = "Pets"
	_world = world
	_hud = hud
	_hud.adopt_card.befriend.connect(_on_befriend)
	_hud.adopt_card.bring_along.connect(func(species):
		_hud.close_popups()
		choose(species))
	_hud.adopt_card.closed.connect(func(): _hud.close_popups())
	_hud.pets_panel.chosen.connect(func(species):
		choose(species)
		_hud.pets_panel.refresh())
	_hud.pets_panel.bought.connect(_on_bought)
	return self


func _ready() -> void:
	multiplayer.peer_connected.connect(_catch_up)
	multiplayer.peer_disconnected.connect(func(id):
		player_pets.erase(id)
		_last_switch.erase(id))
	var players := _world.get_node_or_null("Players")
	if players:
		players.child_entered_tree.connect(_on_player_added)


## Puts wild pets in a land: `count` at a time, near open `spots` in
## `parent`'s space (they show and hide with it).
func add_wild(land: String, parent: Node3D, spots: Array[Vector3], count: int, seed_value: int) -> WildPets:
	var wild := WildPets.new().setup(land, spots, count, seed_value)
	parent.add_child(wild)
	_wild.append(wild)
	return wild


func set_player(player: Node3D) -> void:
	for wild in _wild:
		wild.player = player


## Handles "Say hi" at a wild pet. Returns false for any other zone. While the
## card can make friends, E presses its button.
func use_zone(zone: InteractZone) -> bool:
	var pet := zone.get_parent() as WildPet
	if pet == null:
		return false
	if _hud.adopt_card.can_befriend():
		_hud.adopt_card.press_befriend()
		return true
	_meeting = pet
	pet.greet()
	var kind := pet.species()
	_hud.open_adopt(pet.config, PetCollection.name_of(kind))
	return true


func _on_befriend(species: String, coat: int, pet_name: String) -> void:
	if not PetCollection.adopt(species, pet_name, coat):
		return
	var xp := Progress.award(PetCollection.ADOPT_XP)
	_hud.adopt_card.show_friend(pet_name, xp)
	if _meeting and is_instance_valid(_meeting):
		_meeting.leave()
	_meeting = null
	_refresh_wild()


func _on_bought(species: String) -> void:
	var config := PetCollection.config_of(species)
	_hud.toast("Say hi to %s the %s! Tap Bring along to take them with you." % [config["name"],
			PetBuilder.species_name(config).to_lower()])
	_refresh_wild()


func _refresh_wild() -> void:
	for wild in _wild:
		wild.refresh_owned()


## Brings one of your other pets along in place of the one with you.
func choose(species: String) -> void:
	var player: Player = _world.get("local_player")
	if player == null or not is_instance_valid(player) or not PetCollection.owns(species):
		return
	if species == PetCollection.active_species():
		_hud.toast("%s is already with you!" % PetCollection.name_of(species))
		return
	var config := PetCollection.switch_to(species, player.pet.save_state())
	if config.is_empty():
		return
	player.set_pet(config, true)
	_hud.set_pet(config["name"], PetBuilder.species_name(config), config)
	_hud.toast("%s is coming along!" % config["name"])
	_submit(config)


# --- Telling everyone ----------------------------------------------------------

func _submit(config: Dictionary) -> void:
	var public := PetBuilder.sanitize(config)
	if multiplayer.is_server():
		_receive(1, public)
	else:
		submit_pet.rpc_id(1, public)


@rpc("any_peer", "reliable")
func submit_pet(config: Dictionary) -> void:
	if multiplayer.is_server():
		_receive(multiplayer.get_remote_sender_id(), config)


func _receive(id: int, config: Variant) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var players: Dictionary = _world.get("player_plots")
	if not players.has(id) or now - float(_last_switch.get(id, -10.0)) < SWITCH_COOLDOWN:
		return
	_last_switch[id] = now
	apply_pet.rpc(id, PetBuilder.sanitize(config))


@rpc("authority", "call_local", "reliable")
func apply_pet(id: int, config: Dictionary) -> void:
	var clean := PetBuilder.sanitize(config)
	player_pets[id] = clean
	# The local player already has their new pet.
	if id == multiplayer.get_unique_id():
		return
	var player := _world.get_node_or_null("Players/%d" % id) as Player
	if player:
		player.set_pet(clean, false)


## The host tells a newcomer about every pet changed so far.
func _catch_up(id: int) -> void:
	if not multiplayer.is_server():
		return
	for other in player_pets:
		apply_pet.rpc_id(id, other, player_pets[other])


## A player who changed pets before this peer saw them spawns with their
## first pet; this swaps in the new one.
func _on_player_added(node: Node) -> void:
	var player := node as Player
	if player and player_pets.has(player.peer_id) and player.peer_id != multiplayer.get_unique_id():
		player.set_pet.call_deferred(player_pets[player.peer_id], false)
