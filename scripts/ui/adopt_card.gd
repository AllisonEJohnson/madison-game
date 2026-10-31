class_name AdoptCard
extends PanelContainer
## The card for meeting a wild pet: a big picture of it, a name to give it
## (picked from the safe list, with a dice button for another), and "Make
## friends!". Afterwards it cheers, shows the XP, and offers to bring the new
## friend along right away. A kind you already have just says hello.

signal closed
## "Make friends!" was pressed. The world adopts it, then calls show_friend().
signal befriend(species: String, coat: int, pet_name: String)
signal bring_along(species: String)

var _config := {}
var _title: Label
var _pic: TextureRect
var _text: Label
var _name_row: HBoxContainer
var _name: Label
var _xp: Label
var _befriend: Button
var _bring: Button
var _later: Button
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	theme_type_variation = &"Card"
	custom_minimum_size.x = 460
	_rng.randomize()
	var box := UiTheme.vbox(12)
	add_child(box)
	var head := UiTheme.hbox(10)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("paw_prints"), 40))
	_title = UiTheme.label("", &"Heading", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := UiTheme.icon_button("cross_mark", "Close", 44)
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("e8f6e8"), 22, 0, Color.TRANSPARENT,
			Vector4(8, 8, 8, 8)))
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(well)
	_pic = UiTheme.texture_rect(null, 190)
	well.add_child(_pic)
	_text = UiTheme.label("", &"", 18)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size.x = 420
	box.add_child(_text)

	# The name it will have: one from the safe list, and a dice for another.
	_name_row = UiTheme.hbox(10)
	_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_name_row)
	_name_row.add_child(UiTheme.texture_rect(UiTheme.icon("label"), 30))
	_name = UiTheme.label("", &"Heading", 30, UiTheme.PURPLE)
	_name.custom_minimum_size.x = 150
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_row.add_child(_name)
	var dice := UiTheme.button("New name", "game_die", &"ChipButton", "Pick another name")
	dice.custom_minimum_size.y = 48
	dice.pressed.connect(func(): _name.text = _other_name(_name.text))
	_name_row.add_child(dice)
	_xp = UiTheme.label("", &"Heading", 26, UiTheme.PURPLE)
	_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_xp)

	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_befriend = _big_button("Make friends!", "red_heart", &"PinkButton")
	_befriend.pressed.connect(func():
		befriend.emit(_config["species"], int(_config["coat"]), _name.text))
	UiTheme.add_key_badge(_befriend, "E")
	row.add_child(_befriend)
	_bring = _big_button("Bring along", "paw_prints", &"PrimaryButton")
	_bring.pressed.connect(func(): bring_along.emit(_config["species"]))
	row.add_child(_bring)
	_later = _big_button("OK", "thumbs_up", &"Button")
	_later.pressed.connect(func(): closed.emit())
	row.add_child(_later)


func _big_button(text: String, icon_name: String, variation: StringName) -> Button:
	var b := UiTheme.button(text, icon_name, variation)
	b.custom_minimum_size = Vector2(170, 58)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_constant_override("icon_max_width", 30)
	return b


## Meeting a wild pet. `owned_name` is the name of yours of the same kind, or
## "" when this kind is new to you.
func show_wild(config: Dictionary, owned_name: String) -> void:
	_config = PetBuilder.sanitize(config)
	var kind := PetBuilder.species_name(_config).to_lower()
	_pic.texture = PetCollection.thumb(_config)
	_xp.visible = false
	_bring.visible = false
	if owned_name == "":
		_title.text = "A wild %s!" % kind
		_text.text = "It looks friendly! Give it a name, then make friends and it will come home with you."
		_name.text = PetCollection.random_name(_rng)
		_name_row.visible = true
		_befriend.visible = true
		_later.visible = false
	else:
		_title.text = "A wild %s!" % kind
		_text.text = "It says hi! You already have a %s, %s. Look for other kinds of pets in other places." % [
				kind, owned_name]
		_name_row.visible = false
		_befriend.visible = false
		_later.text = "Bye!"
		_later.icon = UiTheme.icon("waving_hand")
		_later.visible = true
	_recenter()


## After making friends: cheers, the XP earned, and "Bring along".
func show_friend(pet_name: String, xp: int) -> void:
	_title.text = "%s is your friend!" % pet_name
	_text.text = "%s will wait for you at home. Bring a different pet along any time from My pets." % pet_name
	_name_row.visible = false
	_befriend.visible = false
	_xp.text = "+%d XP" % xp
	_xp.visible = xp > 0
	_bring.visible = true
	_later.text = "Later"
	_later.icon = UiTheme.icon("house")
	_later.visible = true
	_recenter()


## Fits the card to what it shows now and keeps it in the middle of the screen.
func _recenter() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


## True while "Make friends!" is on screen, so the E key can press it.
func can_befriend() -> bool:
	return visible and _befriend.visible


func press_befriend() -> void:
	if can_befriend():
		_befriend.pressed.emit()


func _other_name(current: String) -> String:
	var next := current
	while next == current and SafeNames.PET_NAMES.size() > 1:
		next = PetCollection.random_name(_rng)
	return next
