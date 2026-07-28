# dialogue_portrait_panel.gd — panneau portrait type Warcraft 3 (MVP)
extends PanelContainer
class_name DialoguePortraitPanel

@export var panel_visible: bool = false

var _title: Label
var _body: Label
var _portrait: TextureRect
var _hint: Label
var _current_speaker_key: String = ""
var _current_kind: String = "npc"
var _current_name: String = ""
var _current_entity_key: String = ""
var _current_expression: String = "neutral"

func _ready() -> void:
	visible = panel_visible
	mouse_filter = Control.MOUSE_FILTER_STOP if panel_visible else Control.MOUSE_FILTER_IGNORE
	_apply_modal_style()
	_ensure_ui()
	_apply_current_portrait()

func _apply_modal_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.78, 0.52, 0.28, 0.95)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10
	sb.content_margin_top = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)

func _ensure_ui() -> void:
	var root := get_node_or_null("Root") as HBoxContainer
	if root == null:
		root = HBoxContainer.new()
		root.name = "Root"
		root.add_theme_constant_override("separation", 10)
		add_child(root)

	var portrait_wrap := root.get_node_or_null("PortraitWrap") as PanelContainer
	if portrait_wrap == null:
		portrait_wrap = PanelContainer.new()
		portrait_wrap.name = "PortraitWrap"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.095, 0.08, 1.0)
		sb.border_color = Color(0.66, 0.46, 0.24, 0.95)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		portrait_wrap.add_theme_stylebox_override("panel", sb)
		root.add_child(portrait_wrap)

	_portrait = portrait_wrap.get_node_or_null("Portrait") as TextureRect
	if _portrait == null:
		_portrait = TextureRect.new()
		_portrait.name = "Portrait"
		_portrait.custom_minimum_size = Vector2(96, 96)
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_wrap.add_child(_portrait)

	var vbox := root.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		root.add_child(vbox)

	_title = vbox.get_node_or_null("Title") as Label
	if _title == null:
		_title = Label.new()
		_title.name = "Title"
		_title.text = "Portrait dialogue"
		_title.add_theme_font_size_override("font_size", 16)
		_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1))
		vbox.add_child(_title)

	_body = vbox.get_node_or_null("Body") as Label
	if _body == null:
		_body = Label.new()
		_body.name = "Body"
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.text = "Fenêtre portrait prête."
		_body.custom_minimum_size = Vector2(0, 72)
		_body.add_theme_font_size_override("font_size", 12)
		_body.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84, 1))
		vbox.add_child(_body)

	_hint = vbox.get_node_or_null("Hint") as Label
	if _hint == null:
		_hint = Label.new()
		_hint.name = "Hint"
		_hint.text = "P fermer · O expression suivante · hotbar chat = démo"
		_hint.add_theme_font_size_override("font_size", 10)
		_hint.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5, 0.95))
		vbox.add_child(_hint)

func show_portrait(
	speaker_name: String,
	kind: String = "npc",
	expression: String = "neutral",
	body_text: String = "",
	entity_key: String = ""
) -> void:
	_current_name = speaker_name
	_current_kind = kind
	_current_expression = expression
	_current_entity_key = entity_key
	panel_visible = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _title:
		_title.text = speaker_name if speaker_name != "" else "Interaction"
	if _body:
		_body.text = body_text if body_text != "" else "..."
	_apply_current_portrait()

func set_expression(expression: String) -> void:
	_current_expression = expression
	_apply_current_portrait()

func set_body_text(body_text: String) -> void:
	if _body:
		_body.text = body_text

func hide_portrait() -> void:
	panel_visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle_demo(
	speaker_name: String,
	kind: String = "npc",
	expression: String = "neutral",
	body_text: String = "",
	entity_key: String = ""
) -> void:
	if panel_visible:
		hide_portrait()
	else:
		show_portrait(speaker_name, kind, expression, body_text, entity_key)

func _apply_current_portrait() -> void:
	if _portrait == null:
		return
	var tex := PortraitRegistry.resolve_texture(
		_current_kind,
		_current_name,
		_current_entity_key,
		_current_expression
	)
	_portrait.texture = tex
	if _hint:
		_hint.text = (
			"P fermer · O expression suivante · actuelle : %s" % _current_expression
		)
