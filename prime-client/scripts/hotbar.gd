# hotbar.gd — Barre d'actions HUD (icônes flat + badge touche)
extends PanelContainer
class_name Hotbar

signal slot_activated(index: int)

@export var slot_count: int = 10
@export var slot_size: Vector2 = Vector2(50, 50)

var _slots: Array[Button] = []
var _tooltips: PackedStringArray = PackedStringArray([
	"Attaque", "Compétence", "Objet", "Emote", "Carte",
	"Talents", "Inventaire", "Chat", "Monture", "Menu"
])
var _active_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slots()

func _build_slots() -> void:
	var row := get_node_or_null("Row") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "Row"
		add_child(row)
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in row.get_children():
		c.queue_free()
	_slots.clear()
	for i in range(slot_count):
		var btn := Button.new()
		btn.name = "Slot%d" % i
		btn.custom_minimum_size = slot_size
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = &"HotbarSlot"
		btn.text = ""
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icon_tex := UiIconRegistry.tex(UiIconRegistry.hotbar_icon(i))
		if icon_tex:
			btn.icon = icon_tex
		btn.tooltip_text = "%d — %s" % [(i + 1) % 10, _tooltips[i] if i < _tooltips.size() else ""]
		var key_badge := Label.new()
		key_badge.name = "Key"
		key_badge.text = str((i + 1) % 10)
		key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_badge.add_theme_font_size_override("font_size", 9)
		key_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4, 0.95))
		key_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		key_badge.offset_left = 3.0
		key_badge.offset_top = 1.0
		btn.add_child(key_badge)
		var idx := i
		btn.pressed.connect(func() -> void: _activate(idx))
		row.add_child(btn)
		_slots.append(btn)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var idx := -1
	match key.keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
		KEY_4: idx = 3
		KEY_5: idx = 4
		KEY_6: idx = 5
		KEY_7: idx = 6
		KEY_8: idx = 7
		KEY_9: idx = 8
		KEY_0: idx = 9
	if idx >= 0 and idx < slot_count:
		_activate(idx)
		get_viewport().set_input_as_handled()

func _activate(index: int) -> void:
	_active_index = index
	for i in range(_slots.size()):
		_slots[i].button_pressed = (i == index)
	slot_activated.emit(index)

func set_slot_label(index: int, text: String) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index].tooltip_text = text
