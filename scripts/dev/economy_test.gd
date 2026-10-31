extends Node
## Headless check of earning and spending. Run it as the host:
##   godot --headless --path . -- --host --economy-test
## It checks prices and buying, picks up an acorn, plays a little Star Chase,
## uses the shop counter and wears something bought, then puts this device's
## save back the way it was. Prints one line per check and quits with the
## number of failures as its exit code.

var _t := 0.0
var _step := 0
var _fails := 0
var _checks := 0
var _saved := {}
var _before := 0
var _world: Node


func _process(delta: float) -> void:
	_t += delta
	_world = get_tree().current_scene
	if _world == null or _world.name != "World" or _world.local_player == null:
		return
	if _step == 0 and _t > 2.0:
		_step = 1
		_prices_and_buying()
		_start_pickup()
	elif _step == 1 and _t > 2.6:
		_step = 2
		_check_pickup()
		_start_chase()
	elif _step == 2 and _t > 3.4:
		_step = 3
		var chase: StarChase = _world._glade.chase
		_check("Star Chase counts down before the first star", chase.is_playing() and chase.star_position() == Vector3.INF)
	elif _step == 3 and _t > 6.6:
		_step = 4
		var chase: StarChase = _world._glade.chase
		_check("a star has fallen", chase.star_position() != Vector3.INF)
		_world.local_player.teleport(chase.star_position() + Vector3(0, -StarChase.HOVER + 0.5, 0))
	elif _step == 4 and _t > 7.0:
		_step = 5
		_check_chase()
		_start_shop_counter()
	elif _step == 5 and _t > 7.4:
		_step = 6
		_check_shop_counter()
		_check_wear()
	elif _step == 6 and _t > 7.8:
		_step = 7
		var player: Player = _world.local_player
		_check("the player's new hat reached the world", int(_world.player_avatars.get(player.peer_id, {}).get("hat", -1)) == _hat_index())
		_finish()


func _prices_and_buying() -> void:
	_saved = GameState.profile.duplicate(true)
	GameState.profile["acorns"] = 0
	GameState.profile["stardust"] = 0
	GameState.profile["owned"] = []
	# At the top level nothing is level-locked and no level-up pays extra
	# (scripts/dev/levels_test.gd checks levels).
	GameState.profile["xp"] = Levels.max_xp()
	GameState.profile["rewarded_level"] = Levels.MAX_LEVEL
	var sofa_2 := ShopCatalog.furniture_key("sofa", 1)
	_check("the first sofa is free", ShopCatalog.is_free("furniture:sofa:0") and GameState.owns("furniture:sofa:0"))
	_check("other sofas cost 80 Acorns", ShopCatalog.price(sofa_2) == {"currency": "acorns", "amount": 80})
	_check("one sofa costs Stardust", ShopCatalog.price("furniture:sofa:6").get("currency") == "stardust")
	_check("every piano costs something", not ShopCatalog.is_free("furniture:piano:0"))
	_check("the starter home's armchair is free", ShopCatalog.is_free("furniture:armchair:3"))
	_check("faces, colors and walls are free", ShopCatalog.is_free("avatar:face:3") and ShopCatalog.is_free("avatar:skin:2")
			and ShopCatalog.is_free("furniture:wall:0"))
	var default_hair := int(AvatarBuilder.default_config()["hair"])
	_check("the starting hair is free", ShopCatalog.is_free(ShopCatalog.clothes_key("hair", default_hair)))
	var hat := ShopCatalog.clothes_key("hat", _hat_index())
	_check("a fancy hat costs Acorns", ShopCatalog.price(hat).get("currency") == "acorns")
	_check("nonsense keys aren't items", not ShopCatalog.is_item("furniture:sofa:99") and not ShopCatalog.is_item("avatar:hat")
			and not ShopCatalog.is_item("hello"))
	_check("can't buy without Acorns", not GameState.buy(sofa_2) and not GameState.owns(sofa_2))
	GameState.grant("acorns", 100)
	_check("buying takes the price", GameState.buy(sofa_2) and GameState.balance("acorns") == 20 and GameState.owns(sofa_2))
	_check("can't buy the same thing twice", not GameState.buy(sofa_2) and GameState.balance("acorns") == 20)
	_check("can't buy free things", not GameState.buy("furniture:sofa:0"))
	_check("can't buy Stardust things without Stardust", not GameState.buy("furniture:sofa:6"))
	GameState.grant("stardust", 50)
	_check("Stardust buys Stardust things", GameState.buy("furniture:sofa:6") and GameState.balance("stardust") == 30)
	var build: BuildController = _world._build
	build.select_item("piano", 0)
	_check("decorating won't place a piano not bought", not build.owns_item())
	build.select_item("sofa", 1)
	_check("decorating places a bought sofa", build.owns_item())
	var kept := ShopCatalog.priced_keys_in([{"id": "piano", "x": 1, "z": 1, "r": 0, "s": 0}], {"hat": _hat_index()})
	_check("older saves keep what they placed and wear", "furniture:piano:0" in kept and hat in kept)
	_check("the shop sells furniture and clothes", ShopCatalog.furniture_for_sale().size() > 20
			and ShopCatalog.clothes_for_sale().size() > 50)
	print("[economy] %d furniture looks and %d clothes for sale" % [ShopCatalog.furniture_for_sale().size(),
			ShopCatalog.clothes_for_sale().size()])


func _start_pickup() -> void:
	var town: AcornPickups = _world._pickups[0]
	_check("acorns are out in town", town.active_count() == AcornPickups.ACTIVE)
	_before = GameState.balance("acorns")
	var spot: Vector3 = town.positions()[0]
	_world.local_player.teleport(spot - Vector3(0, AcornPickups.HOVER, 0) + Vector3(0, 0.5, 0))


func _check_pickup() -> void:
	var town: AcornPickups = _world._pickups[0]
	var gained := GameState.balance("acorns") - _before
	_check("walking into an acorn pays for it (+%d)" % gained, gained in [AcornPickups.VALUE, AcornPickups.GOLDEN_VALUE])
	_check("the picked acorn is gone", town.active_count() == AcornPickups.ACTIVE - 1)


func _start_chase() -> void:
	var glade: FantasyLand = _world._glade
	_world.local_player.teleport(glade.to_global(FantasyLand.CHASE_SPOT + Vector3(0, 0.5, 0)))
	glade.chase.start()
	_before = GameState.balance("acorns")


func _check_chase() -> void:
	var chase: StarChase = _world._glade.chase
	_check("Star Chase is shown in the glade's prompt", _world._zone == chase.zone or chase.is_playing())
	chase.stop()
	var gained := GameState.balance("acorns") - _before
	_check("catching a star and stopping pays %d Acorns (got %d)" % [StarChase.ACORNS_PER_STAR, gained],
			gained == StarChase.ACORNS_PER_STAR)


func _start_shop_counter() -> void:
	var stall := _world.find_child("ShopStall", true, false) as ShopStall
	_world.local_player.teleport(stall.zone.global_position + Vector3(0, 0.5, 0))


func _check_shop_counter() -> void:
	var stall := _world.find_child("ShopStall", true, false) as ShopStall
	_check("standing at the counter offers the shop", _world._zone == stall.zone)
	_world._use_zone()
	_check("using the counter opens the shop", _world._hud.shop_open())
	_world._hud.close_popups()


func _check_wear() -> void:
	var hat := ShopCatalog.clothes_key("hat", _hat_index())
	_world._wear("hat", _hat_index())
	_check("can't wear a hat not bought", int(GameState.profile["avatar"]["hat"]) != _hat_index())
	GameState.grant("acorns", 100)
	_check("buying the hat", GameState.buy(hat))
	_world._wear("hat", _hat_index())
	_check("wearing a bought hat", int(GameState.profile["avatar"]["hat"]) == _hat_index())


## A hat that costs Acorns, whichever kind of avatar is in use.
func _hat_index() -> int:
	for i in AvatarBuilder.options("hat").size():
		if ShopCatalog.price(ShopCatalog.clothes_key("hat", i)).get("currency") == "acorns":
			return i
	return 0


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[economy] %s %s" % ["ok  " if ok else "FAIL", what])


func _finish() -> void:
	GameState.profile = _saved
	GameState.save_profile()
	print("[economy] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(_fails)
