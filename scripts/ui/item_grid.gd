class_name ItemGrid
extends HBoxContainer
## A page of picture cards between two big arrow buttons. It fits as many
## cards as its size allows and only builds the ones on the current page, so
## a catalog of thousands of items costs no more than one page. Pictures are
## requested as a page is shown (see the Thumbs autoload).
##
## Items are Dictionaries with a "key" and a "name", plus one of: "thumb" (a
## Callable returning a Texture2D), "icon" (an icon name), or neither for a
## word card. Optional: "tooltip", and "tag", a little label in the card's
## top-left corner such as a price: {"text", "icon", "color" (background)}.

signal chosen(key: String)
signal favorite_toggled(key: String, on: bool)

const GAP := 8.0

var card_size := Vector2(104, 104)
## Optional card sizes, biggest first. The grid uses the one that needs the
## fewest pages for its items, and the bigger one on a tie.
var card_sizes: Array = []
var show_names := false
## key -> true. Set to a Dictionary to show a star on every card.
var favorites = null
var empty_text := "Nothing here yet!"
var empty_icon := "sparkles"

var _items: Array = []
var _page := 0
var _per_page := 1
var _columns := 1
var _selected := ""
var _area: Control
var _grid: GridContainer
var _dots: PageDots
var _prev: Button
var _next: Button
var _empty: VBoxContainer
var _cards: Array[Button] = []


func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prev = _arrow("left_arrow", -1)
	add_child(_prev)
	var middle := UiTheme.vbox(2)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(middle)
	_area = Control.new()
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.clip_contents = true
	_area.resized.connect(_relayout)
	_area.gui_input.connect(_on_area_input)
	middle.add_child(_area)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_area.add_child(_grid)
	_empty = UiTheme.vbox(6)
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_empty)
	_dots = PageDots.new()
	middle.add_child(_dots)
	_next = _arrow("right_arrow", 1)
	add_child(_next)


func set_items(items: Array, keep_page := false) -> void:
	_items = items
	if not keep_page:
		_page = 0
	_fit_cards()
	_show_selected_page()
	_fill()


func select(key: String, show_page := true) -> void:
	_selected = key
	if show_page:
		_show_selected_page()
	_fill()


func page_count() -> int:
	return maxi(1, ceili(float(_items.size()) / _per_page))


func flip(step: int) -> void:
	var page := clampi(_page + step, 0, page_count() - 1)
	if page != _page:
		_page = page
		_fill()


func _show_selected_page() -> void:
	for i in _items.size():
		if _items[i]["key"] == _selected:
			_page = i / _per_page
			return


func _arrow(icon_name: String, step: int) -> Button:
	var b := UiTheme.button("", icon_name, &"IconButton", "Previous page" if step < 0 else "Next page")
	b.custom_minimum_size = Vector2(52, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_constant_override("icon_max_width", 30)
	b.pressed.connect(flip.bind(step))
	return b


func _on_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			flip(-1)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			flip(1)
			accept_event()


## Works out how many cards fit, keeping the first card of the page in view.
func _relayout() -> void:
	var first := _page * _per_page
	_fit_cards()
	_page = first / _per_page
	_fill()


func _fit_cards() -> void:
	var fewest := 0
	for option in card_sizes:
		var room := _fit(option)
		var pages := ceili(float(maxi(_items.size(), 1)) / (room.x * room.y))
		if fewest == 0 or pages < fewest:
			fewest = pages
			card_size = option
	var fit := _fit(card_size)
	_columns = fit.x
	_per_page = fit.x * fit.y
	_grid.columns = _columns


## Columns and rows of cards of this size that fit in the area.
func _fit(card: Vector2) -> Vector2i:
	return Vector2i(maxi(1, floori((_area.size.x + GAP) / (card.x + GAP))),
			maxi(1, floori((_area.size.y + GAP) / (card.y + GAP))))


func _fill() -> void:
	if not is_inside_tree() or _area.size.x <= 0.0:
		return
	_page = clampi(_page, 0, page_count() - 1)
	var start := _page * _per_page
	var count := clampi(_items.size() - start, 0, _per_page)
	while _cards.size() < count:
		var card := _make_card()
		_grid.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < count
		if i < count:
			_show_item(card, _items[start + i])
	# Center the grid in the area.
	var used_cols := mini(_columns, maxi(count, 1))
	var rows := ceili(float(maxi(count, 1)) / _columns)
	var grid_size := Vector2(used_cols * (card_size.x + GAP) - GAP, rows * (card_size.y + GAP) - GAP)
	_grid.size = grid_size
	_grid.position = Vector2(floorf((_area.size.x - grid_size.x) / 2.0), 0.0)
	var pages := page_count()
	_prev.disabled = _page == 0
	_next.disabled = _page >= pages - 1
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	_dots.show_page(_page, pages)
	_show_empty(_items.is_empty())


func _show_empty(on: bool) -> void:
	_empty.visible = on
	if not on or _empty.get_child_count() > 0:
		if on:
			(_empty.get_child(1) as Label).text = empty_text
			(_empty.get_child(0) as TextureRect).texture = UiTheme.icon(empty_icon)
		return
	var pic := UiTheme.texture_rect(UiTheme.icon(empty_icon), 56)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty.add_child(pic)
	var text := UiTheme.label(empty_text, &"Hint", 17)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_child(text)


func _make_card() -> Button:
	var card := UiTheme.button("", "", &"CardButton")
	card.toggle_mode = true
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.clip_contents = true
	var pic := TextureRect.new()
	pic.name = "Pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(pic)
	var words := UiTheme.label("", &"", 14)
	words.name = "Words"
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	var tag := PanelContainer.new()
	tag.name = "Tag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.position = Vector2(4, 4)
	var tag_row := UiTheme.hbox(2)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(tag_row)
	var tag_icon := UiTheme.texture_rect(null, 16)
	tag_icon.name = "Icon"
	tag_row.add_child(tag_icon)
	var tag_text := UiTheme.label("", &"", 13)
	tag_text.name = "Text"
	tag_text.add_theme_font_override("font", UiTheme.font(800))
	tag_row.add_child(tag_text)
	card.add_child(tag)
	var star := TextureButton.new()
	star.name = "Star"
	star.texture_normal = UiTheme.icon("star")
	star.ignore_texture_size = true
	star.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(26, 26)
	star.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -31
	star.offset_right = -5
	star.offset_top = 5
	star.offset_bottom = 31
	star.focus_mode = Control.FOCUS_NONE
	star.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	star.tooltip_text = "Add to favorites"
	card.add_child(star)
	# The star shows on the card under the mouse, and always on favorites.
	card.mouse_entered.connect(func(): star.visible = favorites is Dictionary)
	card.mouse_exited.connect(func(): _show_star(card))
	card.pressed.connect(func():
		var key: String = card.get_meta("key")
		_selected = key
		_fill()
		chosen.emit(key))
	star.pressed.connect(func():
		var key: String = card.get_meta("key")
		var on: bool = not favorites.has(key)
		if on:
			favorites[key] = true
		else:
			favorites.erase(key)
		_fill()
		favorite_toggled.emit(key, on))
	return card


func _show_item(card: Button, item: Dictionary) -> void:
	var key: String = item["key"]
	card.set_meta("key", key)
	card.custom_minimum_size = card_size
	card.set_pressed_no_signal(key == _selected)
	card.tooltip_text = item.get("tooltip", item.get("name", ""))
	var pic := card.get_node("Pic") as TextureRect
	var words := card.get_node("Words") as Label
	var has_pic: bool = item.has("thumb") or item.has("icon")
	pic.visible = has_pic
	if item.has("thumb"):
		pic.texture = item["thumb"].call()
	elif item.has("icon"):
		pic.texture = UiTheme.icon(item["icon"])
	var name_h := 22.0 if show_names and has_pic else 0.0
	var pad := 8.0 if item.has("thumb") else 18.0
	pic.offset_left = pad
	pic.offset_top = pad
	pic.offset_right = -pad
	pic.offset_bottom = -pad - name_h
	words.visible = show_names or not has_pic
	words.text = item.get("name", "")
	if has_pic:
		words.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		words.offset_top = -name_h - 4
		words.offset_bottom = -4
		words.offset_left = 4
		words.offset_right = -4
		words.add_theme_font_size_override("font_size", 14)
		words.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		words.set_anchors_preset(Control.PRESET_FULL_RECT)
		words.offset_left = 6
		words.offset_right = -6
		words.offset_top = 0
		words.offset_bottom = 0
		words.add_theme_font_size_override("font_size", 18)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_show_tag(card, item.get("tag", {}))
	_show_star(card)


func _show_tag(card: Button, tag: Dictionary) -> void:
	var panel := card.get_node("Tag") as PanelContainer
	panel.visible = not tag.is_empty()
	if tag.is_empty():
		return
	var color: Color = tag.get("color", UiTheme.PAPER_DIM)
	panel.add_theme_stylebox_override("panel", UiTheme.box(color, 9, 0, Color.TRANSPARENT, Vector4(4, 1, 6, 1)))
	var icon := panel.find_child("Icon", true, false) as TextureRect
	icon.visible = tag.has("icon")
	if tag.has("icon"):
		icon.texture = UiTheme.icon(tag["icon"])
	var text := panel.find_child("Text", true, false) as Label
	text.text = tag.get("text", "")
	text.visible = text.text != ""
	panel.reset_size()


func _show_star(card: Button) -> void:
	var star := card.get_node("Star") as TextureButton
	var key: String = card.get_meta("key", "")
	var fav: bool = favorites is Dictionary and favorites.has(key)
	var hovered := card.get_global_rect().has_point(card.get_global_mouse_position())
	star.visible = favorites is Dictionary and (fav or key == _selected or hovered)
	star.modulate = Color.WHITE if fav else Color(0.55, 0.5, 0.6, 0.55)
	star.tooltip_text = "Remove from favorites" if fav else "Add to favorites"


## Page dots. They are drawn because the UI fonts have no dot characters and
## the browser build has no fallback font. Past 12 pages it says "Page 3 of 19".
class PageDots extends Control:
	const MAX_DOTS := 12
	var _page := 0
	var _pages := 1
	var _words: Label

	func _init() -> void:
		custom_minimum_size.y = 20
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_words = UiTheme.label("", &"Hint", 14)
		_words.set_anchors_preset(Control.PRESET_FULL_RECT)
		_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_words)

	func show_page(page: int, pages: int) -> void:
		_page = page
		_pages = pages
		_words.text = "Page %d of %d" % [page + 1, pages] if pages > MAX_DOTS else ""
		queue_redraw()

	func _draw() -> void:
		if _pages <= 1 or _pages > MAX_DOTS:
			return
		var step := 14.0
		var x := (size.x - (_pages - 1) * step) / 2.0
		for p in _pages:
			var center := Vector2(x + p * step, size.y / 2.0)
			if p == _page:
				draw_circle(center, 4.5, UiTheme.INK_SOFT, true, -1.0, true)
			else:
				draw_circle(center, 3.5, UiTheme.INK_SOFT, false, 1.5, true)
