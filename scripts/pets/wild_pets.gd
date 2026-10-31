class_name WildPets
extends Node3D
## The wild pets of one land. A few at a time wander near open spots, each a
## kind that lives in this land (see PetBuilder.SPECIES "land"). Kinds the
## player doesn't have yet turn up more often, and rare ones less. Now and
## then one that nobody is near wanders off and another kind turns up
## somewhere else, so coming back finds new faces.
##
## Like acorns, wild pets only exist on this device: each player finds their
## own. Once profiles live on a game server, it should check adoptions.

## A pet nobody is near wanders off after this many seconds.
const STAY := Vector2(80.0, 150.0)
## Seconds before another turns up after one leaves.
const RETURN := Vector2(12.0, 30.0)
## How much more often a kind you don't have yet turns up, and rare ones.
const NEW_WEIGHT := 3.0
const RARE_WEIGHT := 0.35

## The local player, set by the world. Pets look at them and say hi.
var player: Node3D:
	set(value):
		player = value
		for pet in pets():
			pet.player = value

var land := "town"
var active := 2

var _spots: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _ready_frames := 2
var _returns: Array[float] = []
var _stays := {} # WildPet -> seconds left
var _check_marks := 2.0


## `candidates` are open spots in this node's space (spots inside trees or
## rocks are dropped once physics is ready); `count` pets are out at once.
func setup(land_id: String, candidates: Array[Vector3], count: int, seed_value: int) -> WildPets:
	land = land_id
	name = "WildPets"
	_spots = candidates
	active = count
	_rng.seed = seed_value
	return self


func pets() -> Array[WildPet]:
	var out: Array[WildPet] = []
	for child in get_children():
		if child is WildPet and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Refreshes the "New!" marks, after you make friends or buy a pet.
func refresh_owned() -> void:
	for pet in pets():
		var kind := pet.species()
		pet.set_owned(PetCollection.owns(kind), PetCollection.name_of(kind))


func _physics_process(_delta: float) -> void:
	if _ready_frames <= 0:
		return
	_ready_frames -= 1
	if _ready_frames > 0:
		return
	_spots = AcornPickups.clear_spots(self, _spots, 0.9)
	for i in active:
		_spawn()


func _process(delta: float) -> void:
	# Pets can be found or bought elsewhere, so the "New!" marks are checked now and then.
	_check_marks -= delta
	if _check_marks <= 0.0:
		_check_marks = 2.0
		refresh_owned()
	for i in range(_returns.size() - 1, -1, -1):
		_returns[i] -= delta
		if _returns[i] <= 0.0:
			_returns.remove_at(i)
			_spawn()
	if not is_visible_in_tree():
		return
	for pet in _stays.keys():
		if not is_instance_valid(pet):
			_stays.erase(pet)
			continue
		_stays[pet] -= delta
		var near: bool = player != null and is_instance_valid(player) \
				and (player.global_position - pet.global_position).length() < 12.0
		if _stays[pet] <= 0.0 and not near:
			_stays.erase(pet)
			pet.queue_free()
			_returns.append(_rng.randf_range(RETURN.x, RETURN.y) * 0.3)


## Puts out one pet of a kind not already out, at a free spot.
func _spawn() -> void:
	var kinds := PetBuilder.wild_in(land)
	var out_now := pets().map(func(p): return p.species())
	var weights := []
	var total := 0.0
	for kind in kinds:
		var w := 0.0
		if not (kind in out_now):
			w = 1.0
			if not PetCollection.owns(kind):
				w *= NEW_WEIGHT
			if PetBuilder.info(kind).get("rare", false):
				w *= RARE_WEIGHT
		weights.append(w)
		total += w
	var spot := _free_spot()
	if total <= 0.0 or spot == Vector3.INF:
		_returns.append(5.0) # Tries again in a moment.
		return
	var pick := _rng.randf() * total
	var kind: String = kinds[-1]
	for i in kinds.size():
		pick -= weights[i]
		if pick <= 0.0 and weights[i] > 0.0:
			kind = kinds[i]
			break
	var coats := PetBuilder.coat_names({"species": kind}).size()
	var pet := WildPet.new().setup(PetBuilder.new_config(kind, _rng.randi() % maxi(coats, 1)), spot, _rng)
	pet.player = player
	add_child(pet)
	pet.set_owned(PetCollection.owns(kind), PetCollection.name_of(kind))
	pet.left.connect(func(): _returns.append(_rng.randf_range(RETURN.x, RETURN.y)))
	_stays[pet] = _rng.randf_range(STAY.x, STAY.y)


## A spot away from the other pets (and from the player, so none pops up
## right beside you), or Vector3.INF when there's none.
func _free_spot() -> Vector3:
	if _spots.is_empty():
		return Vector3.INF
	for _try in 20:
		var spot := _spots[_rng.randi() % _spots.size()]
		var ok := true
		for pet in pets():
			if pet.position.distance_to(spot) < 8.0:
				ok = false
		if player != null and is_instance_valid(player) and player.is_inside_tree() \
				and (to_global(spot) - player.global_position).length() < 8.0:
			ok = false
		if ok:
			return spot
	return Vector3.INF
