extends Node
## LbgAuthClient — login compte LBG (M11) via HTTP gateway + handoff WS.
## Endpoints : POST /v1/auth/login|select_character|enter_zone

signal login_ok(session_token: String, characters: Array)
signal login_failed(code: String, message: String)
signal select_ok(character_id: int, ws_url: String)
signal select_failed(code: String, message: String)
signal enter_zone_ok(ws_url: String, your_character_id: int)
signal enter_zone_failed(code: String, message: String)

@export var gateway_http_base: String = "http://192.168.0.246:8765"
@export var gateway_ws_base: String = "ws://192.168.0.246:50000"
@export var use_mock_fallback: bool = false

var session_token: String = ""
var characters: Array = []
var your_character_id: int = 0
var ws_url: String = ""

var _http: HTTPRequest
var _pending: String = ""  # login | select | enter


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "AuthHTTP"
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)


func login(username: String, password: String) -> void:
	if username.strip_edges().is_empty() or password.is_empty():
		login_failed.emit("auth_failed", "identifiants vides")
		return
	_pending = "login"
	var body := JSON.stringify({"type": "login", "username": username, "password": password})
	var err := _http.request(
		gateway_http_base.rstrip("/") + "/v1/auth/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		if use_mock_fallback:
			_mock_login(username)
			return
		login_failed.emit("zone_unavailable", "HTTPRequest error %s" % err)


func select_character(character_id: int) -> void:
	if session_token.is_empty():
		select_failed.emit("session_expired", "login requis")
		return
	if character_id < 1:
		select_failed.emit("auth_failed", "character_id invalide")
		return
	_pending = "select"
	var body := JSON.stringify({"character_id": character_id, "session_token": session_token})
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % session_token,
	]
	var err := _http.request(
		gateway_http_base.rstrip("/") + "/v1/auth/select_character",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		select_failed.emit("zone_unavailable", "HTTPRequest error %s" % err)


func enter_zone(zone: String = "tatooine") -> void:
	if session_token.is_empty() or your_character_id < 1:
		enter_zone_failed.emit("session_expired", "select_character requis")
		return
	if zone.strip_edges().is_empty():
		enter_zone_failed.emit("zone_unavailable", "zone vide")
		return
	_pending = "enter"
	var body := JSON.stringify({"zone": zone, "session_token": session_token})
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % session_token,
	]
	var err := _http.request(
		gateway_http_base.rstrip("/") + "/v1/auth/enter_zone",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		enter_zone_failed.emit("zone_unavailable", "HTTPRequest error %s" % err)


func clear_session() -> void:
	session_token = ""
	characters.clear()
	your_character_id = 0
	ws_url = ""
	_pending = ""


func _mock_login(username: String) -> void:
	session_token = "dev-mock-token"
	characters = [{"id": 1, "name": username}]
	login_ok.emit(session_token, characters)


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var pending := _pending
	_pending = ""
	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	var d: Dictionary = data

	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_fail(pending, "zone_unavailable", "réseau (%s)" % result)
		return

	if response_code >= 400 or not bool(d.get("ok", false)):
		var code := str(d.get("error", "auth_failed"))
		var msg := str(d.get("message", code))
		_emit_fail(pending, code, msg)
		return

	match pending:
		"login":
			session_token = str(d.get("session_token", ""))
			characters = d.get("characters", [])
			if typeof(characters) != TYPE_ARRAY:
				characters = []
			login_ok.emit(session_token, characters)
		"select":
			your_character_id = int(d.get("character_id", 0))
			ws_url = str(d.get("ws_url", gateway_ws_base))
			select_ok.emit(your_character_id, ws_url)
		"enter":
			your_character_id = int(d.get("your_character_id", your_character_id))
			ws_url = str(d.get("ws_url", gateway_ws_base))
			enter_zone_ok.emit(ws_url, your_character_id)
		_:
			pass


func _emit_fail(pending: String, code: String, message: String) -> void:
	match pending:
		"login":
			login_failed.emit(code, message)
		"select":
			select_failed.emit(code, message)
		"enter":
			enter_zone_failed.emit(code, message)
		_:
			login_failed.emit(code, message)
