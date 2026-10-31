extends Node
## The local player's level: XP earned by playing, level-up rewards, the
## places levels open, and the Star Boost. The rules live in Levels; the
## numbers are saved in GameState's profile ("xp", "rewarded_level",
## "visited", "xp_today", "boost_until").
##
## Like the wallet, XP lives in this device's save for now. Once a game server
## holds profiles, it should be the one to hand out XP and level rewards.

## After any change to XP. `gained` is what was just earned (0 for admin changes).
signal xp_changed(gained: int)
## On reaching a new level for the first time, with everything it brought
## (see Levels.rewards). Reaching several levels at once sends the highest,
## with all their rewards together.
signal leveled_up(level: int, rewards: Array)

## Seconds left before each source with a cooldown pays again. Not saved.
var _cooldowns := {}


func _process(delta: float) -> void:
	for source in _cooldowns.keys():
		_cooldowns[source] -= delta
		if _cooldowns[source] <= 0.0:
			_cooldowns.erase(source)


func xp() -> int:
	return int(GameState.profile.get("xp", 0))


func level() -> int:
	return Levels.level_for(xp())


## {level, into, need}; see Levels.progress().
func progress() -> Dictionary:
	return Levels.progress(xp())


func can_enter(area: String) -> bool:
	return level() >= Levels.area_level(area)


## Gives the XP a source is worth (times `count`, say stars caught), if its
## cooldown and daily limit allow. Returns the XP given.
func award(source: String, count := 1) -> int:
	var rule: Dictionary = Levels.SOURCES.get(source, {})
	if rule.is_empty() or count <= 0 or _cooldowns.has(source):
		return 0
	if rule.has("daily"):
		var counts := _today_counts()
		if int(counts.get(source, 0)) >= int(rule["daily"]):
			return 0
		counts[source] = int(counts.get(source, 0)) + 1
	if rule.has("cooldown"):
		_cooldowns[source] = float(rule["cooldown"])
	return add_xp(int(rule["xp"]) * count)


## The first visit to a place pays the "explore" XP. Returns the XP given.
func visit(area: String) -> int:
	var visited: Array = GameState.profile.get("visited", [])
	if not Levels.AREAS.has(area) or area in visited:
		return 0
	visited.append(area)
	GameState.profile["visited"] = visited
	return award("explore")


## Adds XP (doubled during a Star Boost when `boosted`), then gives any new
## level's rewards. Returns the XP added.
func add_xp(amount: int, boosted := true) -> int:
	if amount <= 0:
		return 0
	if boosted and boost_seconds_left() > 0:
		amount *= Levels.BOOST_MULTIPLIER
	var before := xp()
	GameState.profile["xp"] = mini(before + amount, Levels.max_xp())
	var gained := xp() - before
	_give_rewards()
	GameState.save_profile()
	xp_changed.emit(gained)
	return gained


## Sets XP directly (admin console). Going down takes nothing back, and going
## up again later gives nothing twice.
func set_xp(amount: int) -> void:
	GameState.profile["xp"] = clampi(amount, 0, Levels.max_xp())
	_give_rewards()
	GameState.save_profile()
	xp_changed.emit(0)


func set_level(new_level: int) -> void:
	set_xp(Levels.xp_at(clampi(new_level, 1, Levels.MAX_LEVEL)))


## Gives the rewards of every level reached that hasn't had them yet.
func _give_rewards() -> void:
	var now := level()
	var from := int(GameState.profile.get("rewarded_level", 1))
	if now <= from:
		return
	var all := []
	for lv in range(from + 1, now + 1):
		for reward in Levels.rewards(lv):
			match reward["kind"]:
				"acorns":
					GameState.grant(ShopCatalog.ACORNS, int(reward["amount"]))
				"gift":
					GameState.unlock([reward["key"]])
			all.append(reward)
	GameState.profile["rewarded_level"] = now
	# Acorns from several levels show as one line.
	var acorns := 0
	var lines := []
	for reward in all:
		if reward["kind"] == "acorns":
			acorns += int(reward["amount"])
		else:
			lines.append(reward)
	lines.append({"kind": "acorns", "amount": acorns, "icon": "chestnut", "text": "%d Acorns" % acorns})
	leveled_up.emit(now, lines)


func _today_counts() -> Dictionary:
	var today: Dictionary = GameState.profile.get("xp_today", {})
	if today.get("date", "") != Levels.today():
		today = {"date": Levels.today(), "counts": {}}
		GameState.profile["xp_today"] = today
	return today["counts"]


# --- Star Boost -----------------------------------------------------------------

func boost_seconds_left() -> int:
	return maxi(int(GameState.profile.get("boost_until", 0)) - int(Time.get_unix_time_from_system()), 0)


## Adds boost time (counting from now if it had run out), up to the most
## allowed. Zero or less ends it.
func add_boost(minutes: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	if minutes <= 0:
		GameState.profile["boost_until"] = 0
	else:
		var start := maxi(int(GameState.profile.get("boost_until", 0)), now)
		GameState.profile["boost_until"] = mini(start + minutes * 60, now + Levels.BOOST_MAX_MINUTES * 60)
	GameState.save_profile()
	xp_changed.emit(0)


## True when another boost fits under the most allowed.
func can_add_boost() -> bool:
	return boost_seconds_left() + Levels.BOOST_MINUTES * 60 <= Levels.BOOST_MAX_MINUTES * 60


## Pays Stardust for a Star Boost. Returns false (and changes nothing) when
## there isn't enough Stardust or no more boost time fits.
func buy_boost() -> bool:
	if not can_add_boost() or not GameState.spend(ShopCatalog.STARDUST, Levels.BOOST_COST):
		return false
	add_boost(Levels.BOOST_MINUTES)
	return true
