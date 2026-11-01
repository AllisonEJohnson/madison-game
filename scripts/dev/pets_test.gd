extends Node
## Headless check of pets. Run it as the host:
##   godot --headless --path . -- --host --pets-test
## It checks the kinds of pets and old saves, having, finding, buying and
## switching pets, the wild pets in every land, meeting one and making friends
## (with its XP), bringing it along (and telling the other players), My pets,
## and the admin commands, then puts this device's save back the way it was.
## Prints one line per check and quits with the number of failures as its exit
## code.

var _t := 0.0
var _step := 0
var _fails := 0
var _checks := 0
var _saved := {}
var _world: Node
var _wild: WildPet
var _xp_before := 0


func _process(delta: float) -> void:
	_t += delta
	_world = get_tree().current_scene
	if _world == null or _world.name != "World" or _world.local_player == null:
		return
	if _step == 0 and _t > 2.0:
		_step = 1
		_saved = GameState.profile.duplicate(true)
		_fresh()
		_kinds()
		_saves()
		_fresh()
		_collection()
		_fresh()
		_buying()
		_fresh()
		_switching()
		_fresh()
		_admin()
		_fresh()
		_lands()
		_meet()
	elif _step == 1 and _t > 2.3:
		_step = 2
		_befriend()
	elif _step == 2 and _t > 2.6:
		_step = 3
		_bring_along()
		_panel()
		_finish()


## A brand-new player: level 1, a cat, no wild pets, no Stardust.
func _fresh() -> void:
	GameState.profile.merge(Levels.new_save(), true)
	GameState.profile["stardust"] = 0
	GameState.profile["pets"] = {}
	GameState.profile["pet"] = PetBuilder.default_config()
	_world.local_player.set_pet(GameState.profile["pet"], true)
	Progress._cooldowns.clear()


func _kinds() -> void:
	var wild := PetCollection.wild_kinds()
	var for_sale := wild.filter(func(s): return PetBuilder.stardust_price(s) > 0)
	_check("cats, dogs and birds are home pets", PetBuilder.is_home("cat") and PetBuilder.is_home("dog")
			and PetBuilder.is_home("bird") and wild.size() == PetBuilder.SPECIES.size() - 3)
	_check("no more bunnies or dragons", not PetBuilder.SPECIES.has("bunny") and not PetBuilder.SPECIES.has("dragon"))
	_check("the new Animals pack pets are here", ["fox", "raccoon", "panda_cub", "penguin_chick"].all(
			func(s): return PetBuilder.SPECIES.has(s)))
	_check("every land has wild pets", ["town", "glade", "sky"].all(func(l): return not PetBuilder.wild_in(l).is_empty()))
	_check("many wild kinds are for Stardust (%d of %d)" % [for_sale.size(), wild.size()],
			for_sale.size() > wild.size() / 2 and for_sale.size() < wild.size())
	var art := Art.has(PetBuilder.art_paths()[0])
	_check("every pet's model exists (with the art)", not art or PetBuilder.art_paths().all(func(p): return Art.has(p)))
	_check("every kind builds", PetBuilder.SPECIES.keys().all(
			func(s): return _builds(PetBuilder.new_config(s))))


func _builds(config: Dictionary) -> bool:
	var model := PetBuilder.build(config)
	var ok := model.get_child_count() > 0
	model.free()
	return ok


func _saves() -> void:
	_check("old saves: a bunny becomes a koala", PetBuilder.sanitize({"species": 2})["species"] == "koala")
	_check("old saves: a dragon becomes a pegasus", PetBuilder.sanitize({"species": 3.0})["species"] == "pegasus")
	_check("old saves: cats and birds stay", PetBuilder.sanitize({"species": 0})["species"] == "cat"
			and PetBuilder.sanitize({"species": 4})["species"] == "bird")
	_check("unknown kinds become cats", PetBuilder.sanitize({"species": "unicorn"})["species"] == "cat"
			and PetBuilder.sanitize({"species": 99})["species"] == "cat")
	_check("a coat out of range is clamped", PetBuilder.sanitize({"species": "fox", "coat": 9})["coat"] == 0)
	var clean := PetCollection.clean_save({"pets": {"fox": {"name": "Pip", "coat": 3, "fullness": 500},
		"bogus": {}, "koala": "nope", "dog": {"name": "not on the list"}}})
	_check("saved pets keep only real kinds", clean.keys() == ["fox", "dog"])
	_check("saved pets are checked", clean["fox"]["name"] == "Pip" and clean["fox"]["coat"] == 0
			and clean["fox"]["fullness"] == 100.0 and clean["dog"]["name"] == SafeNames.PET_NAMES[0])
	GameState.profile["pet"] = PetBuilder.sanitize({"species": 2})
	_check("a koala from an old bunny is yours", PetCollection.owns("koala"))


func _collection() -> void:
	_check("a new player has a cat, a dog and a bird", PetCollection.owned() == ["cat", "dog", "bird"])
	_check("and no wild pets yet", PetCollection.found_count() == 0 and not PetCollection.owns("fox"))
	_check("making friends with a fox", PetCollection.adopt("fox", "Pickles", 0) and PetCollection.owns("fox"))
	_check("only one fox", not PetCollection.adopt("fox", "Pip", 0))
	_check("not a real kind", not PetCollection.adopt("unicorn", "Pip", 0))
	_check("the fox remembers its name", PetCollection.name_of("fox") == "Pickles" and PetCollection.found_count() == 1)
	_check("the fox waits at home", PetCollection.active_species() == "cat")
	_check("adopting pays 40 XP", Progress.award(PetCollection.ADOPT_XP) == 40)
	_check("level 2 shows the glade's wild pets", Levels.rewards(2).any(func(r): return r["kind"] == "pets"))


func _buying() -> void:
	_check("can't buy a panda cub without Stardust", not PetCollection.buy("panda_cub"))
	GameState.grant(ShopCatalog.STARDUST, 100)
	_check("a panda cub costs 50 Stardust, at level 1", PetCollection.buy("panda_cub")
			and PetCollection.owns("panda_cub") and GameState.balance(ShopCatalog.STARDUST) == 50)
	_check("can't buy one twice", not PetCollection.buy("panda_cub") and GameState.balance(ShopCatalog.STARDUST) == 50)
	_check("a pegasus can only be found", PetBuilder.stardust_price("pegasus") == 0 and not PetCollection.buy("pegasus")
			and GameState.balance(ShopCatalog.STARDUST) == 50)
	_check("home pets aren't for sale", not PetCollection.buy("dog"))


func _switching() -> void:
	PetCollection.adopt("raccoon", "Rascal", 0)
	var cat: Dictionary = GameState.profile["pet"].duplicate()
	cat["name"] = "Mochi"
	cat["fullness"] = 33.0
	var raccoon := PetCollection.switch_to("raccoon", cat)
	_check("bringing the raccoon along", raccoon["species"] == "raccoon" and raccoon["name"] == "Rascal"
			and PetCollection.active_species() == "raccoon")
	_check("the cat waits at home with its name and needs", GameState.profile["pets"]["cat"]["name"] == "Mochi"
			and GameState.profile["pets"]["cat"]["fullness"] == 33.0)
	var back := PetCollection.switch_to("cat", raccoon)
	_check("switching back keeps everything", back["name"] == "Mochi" and back["fullness"] == 33.0
			and PetCollection.name_of("raccoon") == "Rascal")
	_check("can't bring a pet you don't have", PetCollection.switch_to("lion_cub", back).is_empty())
	var dog: Dictionary = PetCollection.config_of("dog")
	_check("a home pet never brought along has a name", dog["name"] in SafeNames.PET_NAMES)


func _admin() -> void:
	AdminConsole.run(PackedStringArray(["pets", "all"]))
	_check("admin: pets all", PetCollection.found_count() == PetCollection.wild_kinds().size())
	PetCollection.switch_to("pegasus", GameState.profile["pet"])
	AdminConsole.run(PackedStringArray(["pets", "reset"]))
	_check("admin: pets reset (the pegasus with you goes home)", PetCollection.found_count() == 0
			and PetCollection.active_species() == "cat")


func _lands() -> void:
	var wilds := _world.find_children("WildPets", "WildPets", true, false)
	_check("every land has wild pets", wilds.size() == 3)
	for wild: WildPets in wilds:
		var kinds := PetBuilder.wild_in(wild.land)
		var pets := wild.pets()
		_check("%s has %d wild pets of its own kinds" % [wild.land, pets.size()], pets.size() == wild.active
				and pets.all(func(p): return p.species() in kinds))


## Stands by a wild pet in town and says hi.
func _meet() -> void:
	var town: WildPets = _world._pets._wild[0]
	_wild = town.pets()[0]
	town.refresh_owned()
	_check("a new kind wears New!", _wild._new_mark.visible)
	_world.local_player.teleport(_wild.global_position + Vector3(1.2, 0.5, 0))
	_world._process(0.0)
	_check("standing by it offers Say hi", _world._zone == _wild.zone)
	_world._use_zone()
	_check("saying hi opens the meet card", _world._hud.adopt_card.visible and _world._hud.adopt_card.can_befriend())


func _befriend() -> void:
	_xp_before = Progress.xp()
	var kind := _wild.species()
	_world._use_zone() # E presses "Make friends!"
	_check("making friends adds the %s" % kind, PetCollection.owns(kind))
	_check("and pays 40 XP (+%d)" % (Progress.xp() - _xp_before), Progress.xp() - _xp_before == 40)
	_check("the card cheers and offers Bring along", _world._hud.adopt_card._bring.visible
			and not _world._hud.adopt_card.can_befriend())
	_check("the wild pet hops away", _wild._leaving >= 0.0)


func _bring_along() -> void:
	var kind := _wild.species()
	_world._hud.adopt_card._bring.pressed.emit()
	var pet: Pet = _world.local_player.pet
	_check("bringing it along swaps the pet with you", pet.config["species"] == kind
			and PetCollection.active_species() == kind)
	_check("the pet card shows it", _world._hud._pet_name.text == PetCollection.name_of(kind))
	_check("the cat waits at home", GameState.profile["pets"].has("cat"))
	_check("everyone is told (host keeps it for late joiners)", _world._pets.player_pets.get(1, {}).get("species") == kind)
	_check("the card closed", not _world._hud.adopt_card.visible)


func _panel() -> void:
	var hud: Hud = _world._hud
	hud.open_pets()
	_check("My pets opens", hud.pets_panel.visible)
	_check("the pet with you has a paw tag", PetsPanel.card_item(PetCollection.active_species())["tag"]["icon"] == "paw_prints")
	_check("kinds for sale show their price", PetsPanel.card_item("penguin_chick")["tag"]["text"] == "60")
	_check("find-only kinds in a locked land show the level", PetsPanel.card_item("pegasus")["tag"]["text"] == "Lv 5")
	Progress.set_level(5)
	_check("and Wild once it's open", PetsPanel.card_item("pegasus")["tag"]["text"] == "Wild")
	hud.pets_panel.pick("bird")
	_check("picking a home pet offers Bring along", hud.pets_panel._bring.visible and not hud.pets_panel._get.visible)
	hud.pets_panel.pick("lion_cub")
	_check("picking one for sale offers Get now", hud.pets_panel._get.visible and hud.pets_panel._get.disabled)
	GameState.grant(ShopCatalog.STARDUST, 60)
	hud.pets_panel.pick("lion_cub")
	hud.pets_panel._get.pressed.emit()
	_check("the first tap asks to be sure", hud.pets_panel._get.text.begins_with("Spend") and not PetCollection.owns("lion_cub"))
	hud.pets_panel._get.pressed.emit()
	_check("the second tap buys it", PetCollection.owns("lion_cub") and GameState.balance(ShopCatalog.STARDUST) == 0)
	hud.close_popups()


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[pets] %s %s" % ["ok  " if ok else "FAIL", what])


func _finish() -> void:
	GameState.profile = _saved
	# The world saves the pet with you when it closes, so that goes back too.
	_world.local_player.set_pet(_saved["pet"], true)
	GameState.save_profile()
	print("[pets] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(_fails)
