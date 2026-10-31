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
	"wallet              show balances and membership",
	"help                show this list",
]
const MAX_AMOUNT := 1_000_000
const LOG_LINES := 8

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
	return "Unknown command. Type help for the list."


func _wallet_text() -> String:
	var days := GameState.member_days_left()
	return "Acorns %d, Stardust %d, %s" % [GameState.balance("acorns"), GameState.balance("stardust"),
			"member for %d more day%s" % [days, "" if days == 1 else "s"] if days > 0 else "not a member"]


func _print(text: String) -> void:
	for line in text.split("\n"):
		_lines.append(line)
	while _lines.size() > LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)
