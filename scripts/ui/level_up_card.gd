class_name LevelUpCard
extends PanelContainer
## The celebration when you reach a new level: a big star with the number,
## everything the level brought (Acorns, a gift, a newly opened place, new
## things in the shop), and confetti.

signal closed

const CONFETTI_COLORS := [Color("ff6fa8"), Color("ffcf3a"), Color("4b9cff"), Color("35c26b"), Color("9b6bff"),
	Color("ffa53c")]

var _star: Control
var _subtitle: Label
var _rewards: VBoxContainer
var _confetti: Array[CPUParticles2D] = []


func _init() -> void:
	theme_type_variation = &"Card"
	custom_minimum_size.x = 440
	var box := UiTheme.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var head := UiTheme.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("party_popper"), 44))
	head.add_child(UiTheme.label("Level up!", &"Heading", 36, UiTheme.PURPLE))
	var flipped := UiTheme.texture_rect(UiTheme.icon("party_popper"), 44)
	flipped.flip_h = true
	head.add_child(flipped)
	_star = LevelBadge.star(110.0, 48)
	_star.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_star)
	_subtitle = UiTheme.label("", &"Heading", 24)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("f3edff"), 18, 0, Color.TRANSPARENT,
			Vector4(14, 10, 14, 10)))
	box.add_child(well)
	_rewards = UiTheme.vbox(8)
	well.add_child(_rewards)
	var yay := UiTheme.button("Yay!", "star-struck", &"PrimaryButton")
	yay.custom_minimum_size = Vector2(170, 58)
	yay.add_theme_font_size_override("font_size", 24)
	yay.add_theme_constant_override("icon_max_width", 32)
	yay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	yay.pressed.connect(func(): closed.emit())
	box.add_child(yay)


## Fills the card for a level and its rewards (see Levels.rewards).
func show_level(level: int, rewards: Array) -> void:
	(_star.get_child(1) as Label).text = str(level)
	_subtitle.text = "You're level %d!" % level
	for child in _rewards.get_children():
		child.free()
	for reward in rewards:
		_rewards.add_child(LevelCard.reward_line(reward, 32, 18))
	reset_size()


## Bursts confetti from the top of `parent`, which should cover the screen.
func burst(parent: Control) -> void:
	if _confetti.is_empty():
		for i in 2:
			var c := CPUParticles2D.new()
			c.emitting = false
			c.one_shot = true
			c.amount = 90
			c.lifetime = 2.6
			c.explosiveness = 0.85
			c.direction = Vector2(0.5 if i == 0 else -0.5, 1)
			c.spread = 50.0
			c.initial_velocity_min = 260.0
			c.initial_velocity_max = 520.0
			c.gravity = Vector2(0, 420)
			c.angular_velocity_min = -360.0
			c.angular_velocity_max = 360.0
			c.scale_amount_min = 6.0
			c.scale_amount_max = 11.0
			# Each piece picks a color from these bands.
			var ramp := Gradient.new()
			ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			var offsets := PackedFloat32Array()
			for j in CONFETTI_COLORS.size():
				offsets.append(float(j) / CONFETTI_COLORS.size())
			ramp.offsets = offsets
			ramp.colors = PackedColorArray(CONFETTI_COLORS)
			c.color_initial_ramp = ramp
			parent.add_child(c)
			_confetti.append(c)
	var width := parent.get_viewport_rect().size.x
	for i in _confetti.size():
		var c := _confetti[i]
		c.position = Vector2(width * (0.12 if i == 0 else 0.88), -10)
		c.restart()
