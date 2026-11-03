extends RefCounted

const INK := Color("f1eee5")
const MUTED := Color("b5bdbb")
const BRASS := Color("d8bd80")
const PANEL := Color("1c292e")
const DISPLAY_FACE := preload("res://assets/fonts/LibreBaskerville.ttf")
static var _serif: FontVariation
static var _wordmark: FontVariation

static func serif() -> FontVariation:
	# A bundled face keeps the display hierarchy intact on Windows and Deck too.
	if _serif == null:
		_serif = FontVariation.new()
		_serif.base_font = DISPLAY_FACE
		_serif.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	return _serif

static func wordmark() -> Label:
	if _wordmark == null:
		_wordmark = FontVariation.new()
		_wordmark.base_font = DISPLAY_FACE
		_wordmark.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_wordmark.spacing_glyph = 4
	var node := label("OATHSHAPER", 28, INK, true)
	node.add_theme_font_override("font", _wordmark)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	return node

static func label(value: String, size: int, color := INK, heading := false) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heading:
		node.add_theme_font_override("font", serif())
	return node

static func style(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

static func button(caption: String, callback: Callable, accent := BRASS) -> Button:
	var node := Button.new()
	node.text = caption
	node.custom_minimum_size.y = 54
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_focus_color", INK)
	node.add_theme_stylebox_override("normal", style(PANEL, Color("415054")))
	node.add_theme_stylebox_override("hover", style(Color("2a393e"), accent))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, accent, 2))
	node.add_theme_stylebox_override("pressed", style(Color("34474b"), accent, 2))
	node.pressed.connect(func() -> void:
		if node.is_inside_tree(): preload("res://scripts/game_audio.gd").ensure(node).cue("queue")
	)
	node.pressed.connect(callback)
	return node
