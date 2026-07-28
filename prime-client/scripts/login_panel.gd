extends Control
## LoginPanel — écran connexion compte LBG (M11). Branche LbgAuthClient + handoff WS M12.

signal enter_world_requested(ws_url: String, character_id: int, session_token: String)

@onready var _user: LineEdit = %Username
@onready var _pass: LineEdit = %Password
@onready var _char_list: ItemList = %CharacterList
@onready var _status: Label = %StatusLabel
@onready var _btn_login: Button = %LoginButton
@onready var _btn_enter: Button = %EnterButton
@onready var _subtitle: Label = $Center/Panel/VBox/Subtitle

var _auth: Node = null
var _chars: Array = []
var _local_ws: Node = null


func _ready() -> void:
	_btn_enter.disabled = true
	_apply_planet_subtitle()
	_btn_login.pressed.connect(_on_login_pressed)
	_btn_enter.pressed.connect(_on_enter_pressed)
	_auth = get_node_or_null("LbgAuthClient")
	if _auth == null:
		_auth = preload("res://scripts/LbgAuthClient.gd").new()
		_auth.name = "LbgAuthClient"
		add_child(_auth)
	_auth.login_ok.connect(_on_login_ok)
	_auth.login_failed.connect(_on_login_failed)
	_auth.select_ok.connect(_on_select_ok)
	_auth.select_failed.connect(_on_select_failed)
	_auth.enter_zone_ok.connect(_on_enter_zone_ok)
	_auth.enter_zone_failed.connect(_on_enter_zone_failed)


func _apply_planet_subtitle() -> void:
	var planet_label := "Scrapaltai"
	const cfg_path := "res://assets/maps/tatooine_map_config.json"
	if FileAccess.file_exists(cfg_path):
		var f := FileAccess.open(cfg_path, FileAccess.READ)
		var raw: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if raw is Dictionary:
			var dn := str((raw as Dictionary).get("display_name", "")).strip_edges()
			if not dn.is_empty():
				planet_label = dn
	if _subtitle:
		_subtitle.text = "Prime · %s" % planet_label


func get_session_token() -> String:
	if _auth and "session_token" in _auth:
		return str(_auth.session_token)
	return ""


func get_selected_character_name() -> String:
	if _char_list == null or _chars.is_empty():
		return ""
	var idx: PackedInt32Array = _char_list.get_selected_items()
	if idx.is_empty():
		return ""
	var i: int = int(idx[0])
	if i < 0 or i >= _chars.size():
		return ""
	var c: Dictionary = _chars[i]
	return str(c.get("name", ""))


func _on_login_pressed() -> void:
	_status.text = "Connexion…"
	_btn_login.disabled = true
	_auth.login(_user.text, _pass.text)


func _on_login_ok(_session_token: String, characters: Array) -> void:
	_btn_login.disabled = false
	_chars = characters
	_char_list.clear()
	for c in characters:
		var label := str(c.get("name", c.get("id", "?")))
		_char_list.add_item(label)
	_status.text = "OK — choisis un perso"
	if _char_list.item_count > 0:
		_char_list.select(0)
		_btn_enter.disabled = false


func _on_login_failed(code: String, message: String) -> void:
	_btn_login.disabled = false
	_status.text = "%s: %s" % [code, message]


func _on_enter_pressed() -> void:
	var idx := _char_list.get_selected_items()
	if idx.is_empty():
		_status.text = "Sélectionne un personnage"
		return
	var c: Dictionary = _chars[idx[0]]
	var cid := int(c.get("id", 0))
	_status.text = "Select character…"
	_auth.select_character(cid)


func _on_select_ok(_character_id: int, _ws_url: String) -> void:
	_status.text = "Enter zone…"
	_auth.enter_zone("tatooine")


func _on_select_failed(code: String, message: String) -> void:
	_status.text = "%s: %s" % [code, message]


func _on_enter_zone_ok(ws_url: String, your_character_id: int) -> void:
	_status.text = "En zone — ouverture WS…"
	_btn_enter.disabled = true
	var token := get_session_token()
	if token.strip_edges().is_empty():
		on_ws_failed("session_token vide — reconnecte (login HTTP)")
		return
	var main := _find_main()
	if main:
		# Différé : laisse HTTPRequest finir avant le handshake WS (Godot Windows).
		main.call_deferred("_on_enter_world_requested", ws_url, your_character_id, token)
	else:
		call_deferred("_start_ws_handoff", ws_url, your_character_id, token)


func _ensure_local_ws() -> Node:
	if _local_ws != null and is_instance_valid(_local_ws) and _local_ws.has_method("connect_session"):
		return _local_ws
	var script_res: Resource = load("res://scripts/LbgWsClient.gd")
	if script_res == null or not (script_res is GDScript):
		push_error("[LoginPanel] load LbgWsClient.gd a échoué (script null)")
		return null
	var gd: GDScript = script_res
	if gd.can_instantiate() == false:
		push_error("[LoginPanel] LbgWsClient.gd non instantiable (parse error — voir console)")
		return null
	_local_ws = gd.new() as Node
	if _local_ws == null or not _local_ws.has_method("connect_session"):
		push_error("[LoginPanel] LbgWsClient.new() sans connect_session")
		_local_ws = null
		return null
	_local_ws.name = "LbgWsClientLocal"
	add_child(_local_ws)
	# Ne pas polluer le groupe global (Main utilise %LbgWsClient).
	if _local_ws.has_signal("connected") and not _local_ws.connected.is_connected(_on_local_ws_connected):
		_local_ws.connected.connect(_on_local_ws_connected)
	if _local_ws.has_signal("disconnected") and not _local_ws.disconnected.is_connected(_on_local_ws_disconnected):
		_local_ws.disconnected.connect(_on_local_ws_disconnected)
	if _local_ws.has_signal("error_message") and not _local_ws.error_message.is_connected(_on_local_ws_error):
		_local_ws.error_message.connect(_on_local_ws_error)
	if _local_ws.has_signal("zone_state_received") and not _local_ws.zone_state_received.is_connected(_on_local_zone_state):
		_local_ws.zone_state_received.connect(_on_local_zone_state)
	if _local_ws.has_signal("login_result") and not _local_ws.login_result.is_connected(_on_local_login_result):
		_local_ws.login_result.connect(_on_local_login_result)
	print("[LoginPanel] LbgWsClient local créé")
	return _local_ws


func _find_ws_client() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var ws: Node = null
	var scene := tree.current_scene
	if scene:
		ws = scene.get_node_or_null("%LbgWsClient")
		if ws and ws.has_method("connect_session"):
			return ws
		ws = scene.get_node_or_null("LbgWsClient")
		if ws and ws.has_method("connect_session"):
			return ws
	ws = tree.get_first_node_in_group("lbg_ws_client")
	if ws and ws.has_method("connect_session") and str(ws.name) != "LbgWsClientLocal":
		return ws
	var n: Node = self
	while n:
		ws = n.get_node_or_null("LbgWsClient")
		if ws and ws.has_method("connect_session"):
			return ws
		n = n.get_parent()
	var root := tree.root
	if root:
		for child in root.get_children():
			ws = child.get_node_or_null("LbgWsClient")
			if ws and ws.has_method("connect_session"):
				return ws
			# Recherche récursive légère (1 niveau de plus)
			for grand in child.get_children():
				if str(grand.name) == "LbgWsClient" and grand.has_method("connect_session"):
					return grand
	return null


func _find_main() -> Node:
	var n: Node = get_parent()
	while n:
		if n.has_method("_on_enter_world_requested"):
			return n
		n = n.get_parent()
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("_on_enter_world_requested"):
		return tree.current_scene
	return null


func _start_ws_handoff(ws_url: String, character_id: int, session_token: String) -> void:
	# 1) Préférer Main (spawn entités + UI globale) s'il est joignable.
	var main := _find_main()
	if main:
		main.call("_on_enter_world_requested", ws_url, character_id, session_token)
		return

	# 2) Fallback autonome : trouver ou créer LbgWsClient (ne dépend plus de Main).
	var ws := _find_ws_client()
	if ws == null or not ws.has_method("connect_session"):
		ws = _ensure_local_ws()

	if ws == null or not ws.has_method("connect_session"):
		_status.text = "WS: impossible de créer LbgWsClient"
		_btn_enter.disabled = false
		var scene_path := ""
		if get_tree() and get_tree().current_scene:
			scene_path = str(get_tree().current_scene.get_path())
		push_error("[LoginPanel] échec création WS — current_scene=%s" % scene_path)
		return

	_status.text = "WS %s…" % ws_url
	var err: int = ws.connect_session(ws_url, session_token, character_id, "tatooine")
	if err != OK:
		_status.text = "WS connect err %s" % err
		_btn_enter.disabled = false


func _on_local_ws_connected(character_id: int, zone: String) -> void:
	on_ws_connected(character_id, zone)
	var main := _find_main()
	if main and main.has_method("_on_ws_connected"):
		main.call("_on_ws_connected", character_id, zone)


func _on_local_ws_disconnected(reason: String) -> void:
	on_ws_failed(reason)


func _on_local_ws_error(message: String) -> void:
	on_ws_failed(message)


func _on_local_login_result(success: bool, reason: String) -> void:
	if success:
		_status.text = "WS auth OK — entrée zone…"
	else:
		on_ws_failed("login_result: %s" % (reason if reason else "auth_failed"))


func _on_local_zone_state(payload: Dictionary) -> void:
	var main := _find_main()
	if main and main.has_method("_on_ws_zone_state"):
		main.call("_on_ws_zone_state", payload)


func _on_enter_zone_failed(code: String, message: String) -> void:
	_btn_enter.disabled = false
	_status.text = "%s: %s" % [code, message]


func set_ws_status(message: String) -> void:
	_status.text = message


func on_ws_connected(_character_id: int, zone: String) -> void:
	_status.text = "Connecté — %s" % zone
	_btn_enter.disabled = false
	visible = false


func on_ws_failed(reason: String) -> void:
	_btn_enter.disabled = false
	visible = true
	var short := reason if reason.length() < 120 else reason.substr(0, 117) + "…"
	_status.text = "WS échoué: %s" % short
