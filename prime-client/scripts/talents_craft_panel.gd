# talents_craft_panel.gd — M10 UI talents + craft (Control, sidecar :8791)
extends PanelContainer
class_name TalentsCraftPanel

const SIDECAR_DEFAULT := "http://192.168.0.246:8791"

@export var sidecar_base_url: String = SIDECAR_DEFAULT
@export var panel_visible: bool = false

var _skills: Array = []
var _schematics: Array = []
var _status: String = "idle"
var _http: HTTPRequest

var _title: Label
var _status_label: Label
var _skills_list: ItemList
var _schematics_list: ItemList
var _refresh_btn: Button

func _ready() -> void:
	visible = panel_visible
	_apply_mouse_filter()
	_apply_modal_style()
	_ensure_ui()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_done)
	call_deferred("_refresh_sidecar")

func _ensure_ui() -> void:
	var root := get_node_or_null("VBox") as VBoxContainer
	if root == null:
		root = VBoxContainer.new()
		root.name = "VBox"
		root.add_theme_constant_override("separation", 6)
		add_child(root)
	_title = root.get_node_or_null("Title") as Label
	if _title == null:
		_title = Label.new()
		_title.name = "Title"
		_title.text = "Talents & Craft (M10)"
		root.add_child(_title)
	_status_label = root.get_node_or_null("Status") as Label
	if _status_label == null:
		_status_label = Label.new()
		_status_label.name = "Status"
		_status_label.add_theme_font_size_override("font_size", 11)
		root.add_child(_status_label)
	var header := root.get_node_or_null("HeaderRow") as HBoxContainer
	if header == null:
		header = HBoxContainer.new()
		header.name = "HeaderRow"
		root.add_child(header)
	_refresh_btn = header.get_node_or_null("Refresh") as Button
	if _refresh_btn == null:
		_refresh_btn = Button.new()
		_refresh_btn.name = "Refresh"
		_refresh_btn.text = "Rafraîchir"
		header.add_child(_refresh_btn)
	if not _refresh_btn.pressed.is_connected(_refresh_sidecar):
		_refresh_btn.pressed.connect(_refresh_sidecar)
	var skills_lbl := root.get_node_or_null("SkillsLabel") as Label
	if skills_lbl == null:
		skills_lbl = Label.new()
		skills_lbl.name = "SkillsLabel"
		skills_lbl.text = "Skills"
		root.add_child(skills_lbl)
	_skills_list = root.get_node_or_null("SkillsList") as ItemList
	if _skills_list == null:
		_skills_list = ItemList.new()
		_skills_list.name = "SkillsList"
		_skills_list.custom_minimum_size = Vector2(0, 110)
		_skills_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(_skills_list)
	var schem_lbl := root.get_node_or_null("SchematicsLabel") as Label
	if schem_lbl == null:
		schem_lbl = Label.new()
		schem_lbl.name = "SchematicsLabel"
		schem_lbl.text = "Schematics"
		root.add_child(schem_lbl)
	_schematics_list = root.get_node_or_null("SchematicsList") as ItemList
	if _schematics_list == null:
		_schematics_list = ItemList.new()
		_schematics_list.name = "SchematicsList"
		_schematics_list.custom_minimum_size = Vector2(0, 110)
		_schematics_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(_schematics_list)
	_paint_lists()


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


func _apply_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if panel_visible else Control.MOUSE_FILTER_IGNORE


func toggle() -> void:
	panel_visible = not panel_visible
	visible = panel_visible
	_apply_mouse_filter()
	if panel_visible:
		_refresh_sidecar()

func _refresh_sidecar() -> void:
	_status = "fetch…"
	_paint_status()
	var url := sidecar_base_url.rstrip("/") + "/v1/catalog/skills"
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	var err := _http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_apply_local_mock("req_%d" % err)

func _on_http_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_apply_local_mock(code)
	else:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			_skills = parsed.get("skills", [])
			_schematics = parsed.get("schematics", [])
			var fb := bool(parsed.get("fallback", false))
			_status = "live%s — %d skills, %d schematics" % [
				" (fallback catalog)" if fb else "",
				_skills.size(),
				_schematics.size(),
			]
		else:
			_status = "parse error"
			_apply_local_mock("parse")
			return
	_paint_lists()

func _apply_local_mock(code: Variant) -> void:
	_status = "hors ligne (%s) · mock local" % str(code)
	_skills = [
		{"name": "Prospecteur · rang 1"},
		{"name": "Artisan de rue · rang 1"},
		{"name": "Médecine de camp · rang 1"},
		{"name": "Pilotage shuttle · rang 1"},
	]
	_schematics = [
		{"name": "Kit de réparation"},
		{"name": "Ration compacte"},
		{"name": "Badge de quartier"},
	]

func _paint_status() -> void:
	if _status_label:
		_status_label.text = _status
		if _status.begins_with("hors ligne"):
			_status_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.35, 1))
		elif _status.begins_with("live"):
			_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65, 1))
		else:
			_status_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9, 1))

func _paint_lists() -> void:
	_paint_status()
	if _skills_list == null or _schematics_list == null:
		return
	_skills_list.clear()
	if _skills.is_empty():
		_skills_list.add_item("(aucun skill)")
	else:
		for s in _skills:
			var label := str(s.get("name", s)) if typeof(s) == TYPE_DICTIONARY else str(s)
			_skills_list.add_item(label)
	_schematics_list.clear()
	if _schematics.is_empty():
		_schematics_list.add_item("(aucun schematic)")
	else:
		for sc in _schematics:
			var slabel := str(sc.get("name", sc)) if typeof(sc) == TYPE_DICTIONARY else str(sc)
			_schematics_list.add_item(slabel)
