extends Node
## Headless check of XP and levels. Run it as the host:
##   godot --headless --path . -- --host --levels-test
## It checks the level curve, what playing is worth (with cooldowns and daily
## limits), level-up rewards (given once), gifts, the Star Boost, level-locked
## shop items and portals, the admin commands, and XP from a real acorn
## pickup, then puts this device's save back the way it was. Prints one line
## per check and quits with the number of failures as its exit code.

var _t := 0.0
var _step := 0
var _fails := 0
var _checks := 0
var _saved := {}
var _before := 0
var _levels_seen: Array = []
var _world: Node


func _process(delta: float) -> void:
	_t += delta
	_world = get_tree().current_scene
	if _world == null or _world.name != "World" or _world.local_player == null:
		return
	if _step == 0 and _t > 2.0:
		_step = 1
		_saved = GameState.profile.duplicate(true)
		Progress.leveled_up.connect(func(level, _rewards): _levels_seen.append(level))
		_curve()
		_saves()
		_fresh()
		_sources()
		_fresh()
		_level_ups()
		_fresh()
		_boost()
		_fresh()
		_shop_and_portals()
		_fresh()
		_admin()
		_fresh()
		_start_pickup()
	elif _step == 1 and _t > 2.6:
		_step = 2
		_check_pickup()
		# A level-up shows its card once nothing else is open.
		Progress.add_xp(Levels.xp_to_next(1), false)
	elif _step == 2 and _t > 2.9:
		_step = 3
		_check("the level-up card shows", _world._hud._level_up.visible)
		_finish()


## A brand-new player: level 1, nothing visited, no boost, no Acorns or Stardust.
func _fresh() -> void:
	GameState.profile.merge(Levels.new_save(), true)
	GameState.profile["acorns"] = 0
	GameState.profile["stardust"] = 0
	GameState.profile["owned"] = []
	Progress._cooldowns.clear()
	Progress.set_xp(0)
	_levels_seen.clear()


func _curve() -> void:
	_check("level 1 starts at 0 XP", Levels.xp_at(1) == 0)
	_check("level 2 takes 50 XP and level 3 75 more", Levels.xp_at(2) == 50 and Levels.xp_at(3) == 125)
	_check("49 XP is level 1, 50 is level 2", Levels.level_for(49) == 1 and Levels.level_for(50) == 2)
	_check("progress counts XP into the level", Levels.progress(60) == {"level": 2, "into": 10, "need": 75})
	_check("the top level stops there", Levels.level_for(Levels.max_xp() + 999) == Levels.MAX_LEVEL
			and Levels.progress(Levels.max_xp())["need"] == 0)
	var two := Levels.rewards(2)
	_check("level 2 opens Starfall Glade", two.any(func(r): return r["kind"] == "area" and r["area"] == "glade"))
	_check("level 2 adds things to the shop", two.any(func(r): return r["kind"] == "shop"))
	_check("level 2 pays %d Acorns" % Levels.reward_acorns(2), two.any(func(r): return r["kind"] == "acorns"))
	var five := Levels.rewards(5)
	_check("level 5 opens the Sky Garden", five.any(func(r): return r["kind"] == "area" and r["area"] == "sky"))
	var gift_ok := not ShopCatalog.is_item("avatar:costume:1") or five.any(func(r): return r["kind"] == "gift")
	_check("level 5 gives a gift (with the art)", gift_ok)
	_check("coming up lists levels with more than Acorns", Levels.upcoming(1, 3).size() == 3
			and Levels.upcoming(1, 3)[0]["level"] == 2)


func _saves() -> void:
	var clean := Levels.clean_save({"xp": -5.0, "rewarded_level": 99.0, "visited": ["glade", "nowhere", "glade", 3],
		"xp_today": {"date": "2026-10-31", "counts": {"decorate": 4.0, "bogus": 2.0}},
		"boost_until": 9e12})
	_check("saved XP can't go below 0", clean["xp"] == 0)
	_check("saved reward level is clamped", clean["rewarded_level"] == Levels.MAX_LEVEL)
	_check("saved visits keep only real places", clean["visited"] == ["glade"])
	_check("saved daily counts keep only real sources", clean["xp_today"]["counts"] == {"decorate": 4})
	_check("a saved boost can't run longer than the most allowed",
			clean["boost_until"] <= int(Time.get_unix_time_from_system()) + Levels.BOOST_MAX_MINUTES * 60)
	_check("a save from before levels starts at level 1", Levels.clean_save({})["xp"] == 0
			and Levels.clean_save({})["rewarded_level"] == 1)


func _sources() -> void:
	_check("an acorn is worth 3 XP", Progress.award("acorn") == 3 and Progress.xp() == 3)
	_check("feeding your pet pays", Progress.award("feed_pet") == 4)
	_check("feeding again right away doesn't", Progress.award("feed_pet") == 0)
	_check("playing has its own cooldown", Progress.award("play_pet") == 4)
	var decorated := 0
	for i in 25:
		decorated += Progress.award("decorate")
	_check("decorating pays up to 20 times a day (got %d XP)" % decorated, decorated == 40)
	_check("the daily visit pays once", Progress.award("daily") == 25 and Progress.award("daily") == 0)
	_check("a first visit to the glade pays 40", Progress.visit("glade") == 40)
	_check("a second visit doesn't", Progress.visit("glade") == 0)
	_check("town isn't a new place", Progress.visit("town") == 0)
	_check("stars count", Progress.award("star", 7) == 14)
	_check("unknown sources pay nothing", Progress.award("nonsense") == 0)
	# A new day resets the daily limits.
	GameState.profile["xp_today"]["date"] = "2000-01-01"
	_check("a new day pays the daily visit again", Progress.award("daily") == 25)


func _level_ups() -> void:
	var acorns := GameState.balance("acorns")
	Progress.add_xp(50, false)
	_check("50 XP reaches level 2", Progress.level() == 2)
	_check("the level-up is announced", _levels_seen == [2])
	_check("level 2 paid its Acorns", GameState.balance("acorns") - acorns == Levels.reward_acorns(2))
	Progress.set_level(1)
	acorns = GameState.balance("acorns")
	Progress.add_xp(50, false)
	_check("reaching level 2 again pays nothing more", GameState.balance("acorns") == acorns and _levels_seen == [2])
	_levels_seen.clear()
	acorns = GameState.balance("acorns")
	Progress.set_level(5)
	var expected := Levels.reward_acorns(3) + Levels.reward_acorns(4) + Levels.reward_acorns(5)
	_check("jumping to level 5 pays levels 3 to 5 at once", GameState.balance("acorns") - acorns == expected)
	_check("and is announced once, as level 5", _levels_seen == [5])
	if ShopCatalog.is_item("avatar:costume:1"):
		_check("level 5's gift is yours", GameState.owns("avatar:costume:1"))
		_check("level 3's gift is yours", GameState.owns("furniture:toy_box:1"))


func _boost() -> void:
	_check("no boost without Stardust", not Progress.buy_boost() and Progress.boost_seconds_left() == 0)
	GameState.grant("stardust", Levels.BOOST_COST)
	_check("Stardust buys a boost", Progress.buy_boost() and GameState.balance("stardust") == 0)
	_check("the boost lasts %d minutes" % Levels.BOOST_MINUTES,
			absi(Progress.boost_seconds_left() - Levels.BOOST_MINUTES * 60) <= 2)
	_check("boosted XP is doubled", Progress.award("acorn") == 6)
	_check("admin XP isn't", Progress.add_xp(10, false) == 10)
	Progress.add_boost(Levels.BOOST_MAX_MINUTES)
	GameState.grant("stardust", Levels.BOOST_COST)
	_check("no more boost than the most allowed", not Progress.buy_boost() and GameState.balance("stardust") == Levels.BOOST_COST)
	Progress.add_boost(0)
	_check("a boost can be ended", Progress.boost_seconds_left() == 0)


func _shop_and_portals() -> void:
	var sofa := ShopCatalog.furniture_key("sofa", 1)
	var stardust_sofa := ShopCatalog.furniture_key("sofa", 6)
	GameState.grant("acorns", 1000)
	_check("a sofa needs level 2", ShopCatalog.level_needed(sofa) == 2 and ShopCatalog.level_locked(sofa))
	_check("Stardust looks need no level", ShopCatalog.level_needed(stardust_sofa) == 1)
	_check("free things need no level", ShopCatalog.level_needed(ShopCatalog.furniture_key("sofa", 0)) == 1)
	_check("level-locked things show a lock tag", BuyCard.price_tag(sofa).get("icon", "") == "locked")
	_check("can't buy a level-locked sofa, even with Acorns", not GameState.buy(sofa) and not GameState.owns(sofa))
	var glade: Portal = _world._area_portals["glade"]
	var sky: Portal = _world._area_portals["sky"]
	_check("the glade portal is locked at level 1", glade.locked and sky.locked)
	Progress.set_level(2)
	_check("level 2 unlocks the sofa", not ShopCatalog.level_locked(sofa) and GameState.buy(sofa))
	_check("level 2 opens the glade portal but not the Sky Garden", not glade.locked and sky.locked)
	Progress.set_level(5)
	_check("level 5 opens the Sky Garden portal", not sky.locked)
	Progress.set_xp(0)
	_check("going back to level 1 locks the portals again", glade.locked and sky.locked)
	_check("level 1 only can't enter the glade", not Progress.can_enter("glade") and Progress.can_enter("town"))


func _admin() -> void:
	var console := AdminConsole.new()
	add_child(console)
	console.run(PackedStringArray(["level", "4"]))
	_check("admin: level 4", Progress.level() == 4)
	console.run(PackedStringArray(["xp", "-10000"]))
	_check("admin: xp -10000 goes back to level 1", Progress.level() == 1 and Progress.xp() == 0)
	console.run(PackedStringArray(["xp", "60"]))
	_check("admin: xp 60 gives exactly 60", Progress.xp() == 60)
	_check("admin: level 99 is refused", console.run(PackedStringArray(["level", "99"])).begins_with("Give")
			and Progress.xp() == 60)
	console.run(PackedStringArray(["boost", "15"]))
	_check("admin: boost 15", absi(Progress.boost_seconds_left() - 15 * 60) <= 2)
	console.run(PackedStringArray(["level", "reset"]))
	_check("admin: level reset", Progress.xp() == 0 and Progress.boost_seconds_left() == 0
			and int(GameState.profile["rewarded_level"]) == 1)
	console.queue_free()


func _start_pickup() -> void:
	var town: AcornPickups = _world._pickups[0]
	_before = Progress.xp()
	var spot: Vector3 = town.positions()[0]
	_world.local_player.teleport(spot - Vector3(0, AcornPickups.HOVER, 0) + Vector3(0, 0.5, 0))


func _check_pickup() -> void:
	var gained := Progress.xp() - _before
	_check("walking into an acorn gives XP (+%d)" % gained, gained in [3, 10])


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[levels] %s %s" % ["ok  " if ok else "FAIL", what])


func _finish() -> void:
	GameState.profile = _saved
	GameState.save_profile()
	print("[levels] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(_fails)
