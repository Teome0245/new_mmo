# inventory_panel.gd — Inventaire grille fixe (stub données)
extends PanelContainer
class_name InventoryPanel

@export var panel_visible: bool = false
@export var columns: int = 5
@export var rows: int = 4
@export var slot_px: float = 52.0

var _grid: GridContainer
var _title: Label
var _hint: Label
var _weight: Label

const STUB_ITEMS: Array[Dictionary] = [
	{"name": "Caisse", "icon": "crate", "qty": 1},
	{"name": "Ration", "icon": "ration", "qty": 3},
	{"name": "Kit", "icon": "kit", "qty": 1},
	{"name": "Cuivre", "icon": "copper", "qty": 12},
	{"name": "Vis", "icon": "screw", "qty": 24},
	{}, {},
	{"name": "Badge", "icon": "badge", "qty": 1},
	{}, {},
	{},
	{"name": "Carte", "icon": "card", "qty": 1},
]

func _ready() -> void:
	visible = panel_visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE if not panel_visible else Control.MOUSE_FILTER_STOP
	_apply_modal_style()
	_ensure_ui()
	_fill_stub()

func _apply_modal_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.94)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.78, 0.52, 0.28, 0.95)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)

func _ensure_ui() -> void:
	var root := get_node_or_null("VBox") as VBoxContainer
	if root == null:
		root = VBoxContainer.new()
		root.name = "VBox"
		add_child(root)
	root.add_theme_constant_override("separation", 8)

	var head := root.get_node_or_null("Header") as HBoxContainer
	if head == null:
		head = HBoxContainer.new()
		head.name = "Header"
		root.add_child(head)
		root.move_child(head, 0)

	var old_title := root.get_node_or_null("Title") as Label
	if old_title and old_title.get_parent() == root:
		old_title.reparent(head)

	_title = head.get_node_or_null("Title") as Label
	if _title == null:
		_title = Label.new()
		_title.name = "Title"
		_title.text = "Inventaire"
		head.add_child(_title)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 15)

	_weight = head.get_node_or_null("Weight") as Label
	if _weight == null:
		_weight = Label.new()
		_weight.name = "Weight"
		_weight.text = "7 / 40"
		_weight.add_theme_font_size_override("font_size", 11)
		_weight.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7, 0.9))
		head.add_child(_weight)

	_hint = root.get_node_or_null("Hint") as Label
	if _hint == null:
		_hint = Label.new()
		_hint.name = "Hint"
		root.add_child(_hint)
	_hint.text = "I fermer · clic objet = aperçu (stub)"
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.6, 0.52, 0.85))

	_grid = root.get_node_or_null("Grid") as GridContainer
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "Grid"
		root.add_child(_grid)
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _fill_stub() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var total := columns * rows
	for i in range(total):
		var item: Dictionary = STUB_ITEMS[i] if i < STUB_ITEMS.size() else {}
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(slot_px, slot_px)
		slot.focus_mode = Control.FOCUS_NONE
		slot.theme_type_variation = &"HotbarSlot"
		slot.text = ""
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if item.is_empty():
			slot.icon = UiIconRegistry.tex("empty")
			slot.disabled = true
			slot.tooltip_text = "Vide"
		else:
			var icon_key := str(item.get("icon", UiIconRegistry.item_icon(str(item.get("name", "")))))
			slot.icon = UiIconRegistry.tex(icon_key)
			var qty := int(item.get("qty", 1))
			var item_name := str(item.get("name", ""))
			slot.tooltip_text = "%s ×%d" % [item_name, qty]
			slot.disabled = false
			var slot_idx := i
			slot.pressed.connect(func() -> void: _on_item_slot(slot_idx, item_name, qty))
			if qty > 1:
				var qty_lbl := Label.new()
				qty_lbl.text = "×%d" % qty
				qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				qty_lbl.add_theme_font_size_override("font_size", 10)
				qty_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7, 1))
				qty_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				qty_lbl.offset_left = -28.0
				qty_lbl.offset_top = -16.0
				qty_lbl.offset_right = -3.0
				qty_lbl.offset_bottom = -2.0
				slot.add_child(qty_lbl)
		_grid.add_child(slot)

func _on_item_slot(_index: int, item_name: String, qty: int) -> void:
	if _hint:
		_hint.text = "%s ×%d — utilisation serveur à brancher (stub)" % [item_name, qty]

func toggle() -> void:
	panel_visible = not panel_visible
	visible = panel_visible
	mouse_filter = Control.MOUSE_FILTER_STOP if panel_visible else Control.MOUSE_FILTER_IGNORE
