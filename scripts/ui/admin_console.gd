class_name AdminConsole
extends CanvasLayer
## A small command box for the game's makers, opened with the ` key (the one
## left of 1). It only exists in debug builds (running from the editor) or
## when the game is started with `--admin`, so players never see it:
##   godot --path . -- --admin
## Commands change this device's save only. Once a game server holds the
## wallets, granting moves to a server-side admin tool.

const HELP := [
	"stardust <amount>   give premium currency (negative takes it away)",
	"acorns <amount>     give earned currency (negative takes it away)",
	"member <days>       add membership days (0 ends it)",
	"unlock all          own everything in the shop",
	"unlock reset        take back what was bought (keeps what you wear or placed)",
	"wallet              show balances and membership",
	"xp <amount>         give XP (negative takes it away)",
	"level <n>           jump to a level (level alone shows it)",
	"level reset         start leveling over, as a new player",
	"boost <minutes>     give a Star Boost, double XP (0 ends it)",
	"pets all            make friends with every wild pet",
	"pets reset          forget every wild pet you found",
	"help                show this list",
]
const MAX_AMOUNT := 1_000_000
const LOG_LINES := 12

var _panel: PanelContainer
var _log: Label
var _field: LineEdit
var _lines: Array[String] = []


static func enabled() -> bool:
	return OS.is_debug_build() or "--admin" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 20
	_panel = UiTheme.card()
	_panel.theme = UiTheme.theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 14
	_panel.custom_minimum_size.x = 560
	_panel.visible = false
	add_child(_panel)
	var box := UiTheme.vbox(8)
	_panel.add_child(box)
	var head := UiTheme.hbox(8)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("hammer_and_wrench"), 28))
	head.add_child(UiTheme.label("Admin", &"Heading", 20))
	_log = UiTheme.label("", &"", 15)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_log)
	_field = LineEdit.new()
	_field.placeholder_text = "Type a command, like: stardust 500"
	_field.max_length = 64
	_field.text_submitted.connect(_on_submitted)
	box.add_child(_field)
	_print("Type help for the list of commands.")


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_QUOTELEFT:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and _panel.visible:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_field.clear()
		_field.grab_focus.call_deferred()
	else:
		_field.release_focus()


func _on_submitted(text: String) -> void:
	_field.clear()
	var words := text.strip_edges().to_lower().split(" ", false)
	if words.is_empty():
		return
	_print("> " + " ".join(words))
	_print(run(words))


## Runs one command and returns what to show. Public so tests can call it.
func run(words: PackedStringArray) -> String:
	var command := words[0]
	var arg := words[1] if words.size() > 1 else ""
	match command:
		"help":
			return "\n".join(HELP)
		"wallet":
			return _wallet_text()
		"stardust", "acorns":
			if not arg.is_valid_int() or absi(arg.to_int()) > MAX_AMOUNT:
				return "Give a whole number up to %d, like: %s 500" % [MAX_AMOUNT, command]
			GameState.grant(command, arg.to_int())
			return _wallet_text()
		"member":
			if not arg.is_valid_int() or absi(arg.to_int()) > 3650:
				return "Give a number of days, like: member 30"
			GameState.grant_membership(arg.to_int())
			return _wallet_text()
		"unlock":
			if arg == "all":
				var keys := ShopCatalog.furniture_for_sale().map(
						func(f): return ShopCatalog.furniture_key(f["id"], f["style"]))
				keys.append_array(ShopCatalog.clothes_for_sale().map(
						func(c): return ShopCatalog.clothes_key(c["option"], c["index"])))
				GameState.unlock(keys)
				return "Unlocked %d things. %s" % [keys.size(), _wallet_text()]
			if arg == "reset":
				GameState.reset_owned()
				return "Took back what was bought. You own %d things." % GameState.profile["owned"].size()
			return "Say unlock all, or unlock reset"
		"pets":
			if arg == "all":
				for species in PetCollection.wild_kinds():
					PetCollection.adopt(species, PetCollection.random_name())
			elif arg == "reset":
				PetCollection.reset()
			else:
				return "Say pets all, or pets reset"
			return "You have %d of %d wild pets." % [PetCollection.found_count(), PetCollection.wild_kinds().size()]
		"xp":
			if not arg.is_valid_int() or absi(arg.to_int()) > MAX_AMOUNT:
				return "Give a whole number, like: xp 100"
			if arg.to_int() >= 0:
				Progress.add_xp(arg.to_int(), false)
			else:
				Progress.set_xp(Progress.xp() + arg.to_int())
			return _level_text()
		"level":
			if arg == "":
				return _level_text()
			if arg == "reset":
				GameState.profile.merge(Levels.new_save(), true)
				Progress.set_xp(0)
				return "Starting over. " + _level_text()
			if not arg.is_valid_int() or arg.to_int() < 1 or arg.to_int() > Levels.MAX_LEVEL:
				return "Give a level from 1 to %d, like: level 5" % Levels.MAX_LEVEL
			Progress.set_level(arg.to_int())
			return _level_text()
		"boost":
			if not arg.is_valid_int() or absi(arg.to_int()) > Levels.BOOST_MAX_MINUTES:
				return "Give minutes up to %d, like: boost 30" % Levels.BOOST_MAX_MINUTES
			Progress.add_boost(arg.to_int())
			return _level_text()
	return "Unknown command. Type help for the list."


func _level_text() -> String:
	var p := Progress.progress()
	var boost := Progress.boost_seconds_left()
	return "Level %d, %s, %d XP in all%s" % [p["level"],
			"top level" if int(p["need"]) == 0 else "%d of %d XP to the next" % [p["into"], p["need"]],
			Progress.xp(), ", Star Boost for %d min" % ceili(boost / 60.0) if boost > 0 else ""]


func _wallet_text() -> String:
	var days := GameState.member_days_left()
	return "Acorns %d, Stardust %d, %s, %d things bought" % [GameState.balance("acorns"),
			GameState.balance("stardust"),
			"member for %d more day%s" % [days, "" if days == 1 else "s"] if days > 0 else "not a member",
			GameState.profile["owned"].size()]


func _print(text: String) -> void:
	for line in text.split("\n"):
		_lines.append(line)
	while _lines.size() > LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)
