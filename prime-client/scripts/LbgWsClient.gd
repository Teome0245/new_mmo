extends Node
class_name LbgWsClient
## LbgWsClient — WebSocket lbg-ws/2 (M12) après auth HTTP M11.
## Connecte avec session_token, consomme enter_world / zone_state, envoie move.

# preload (pas class_name) : reste compilable même si le cache global .godot est incomplet.
const _Crc32Util = preload("res://scripts/crc32_util.gd")

signal connected(your_character_id: int, zone: String)
signal disconnected(reason: String)
signal zone_state_received(payload: Dictionary)
signal login_result(success: bool, reason: String)
signal error_message(message: String)
signal connecting(ws_url: String)
signal handoff_progress(phase: String, detail: String)

@export var proto: String = "lbg-ws/2"
@export var auto_enter_world: bool = true
## Après login_result : `enter_world` si HTTP M11 a déjà fait select+enter_zone (défaut).
@export var post_login_ws_action: String = "enter_world"
@export var connect_timeout_s: float = 12.0
@export var response_timeout_s: float = 25.0

var _peer: WebSocketPeer = WebSocketPeer.new()
var _url: String = ""
var _session_token: String = ""
var _character_id: int = 0
var _zone: String = "tatooine"
var _ready_sent: bool = false
var _entered: bool = false
var _seq: int = 0
var _active: bool = false
var _connect_elapsed: float = 0.0
var _last_state: int = -1
var _open_elapsed: float = 0.0
var your_character_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("lbg_ws_client")


func is_open() -> bool:
	return _active and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func connect_session(ws_url: String, session_token: String, character_id: int, zone: String = "tatooine") -> int:
	disconnect_session()
	_url = ws_url.strip_edges()
	_session_token = session_token
	_character_id = character_id
	_zone = zone if not zone.is_empty() else "tatooine"
	_ready_sent = false
	_entered = false
	_connect_elapsed = 0.0
	_open_elapsed = 0.0
	_last_state = -1
	your_character_id = character_id
	if _url.is_empty() or _session_token.is_empty():
		var why := "ws_url vide" if _url.is_empty() else "session_token vide"
		handoff_progress.emit("error", why)
		disconnected.emit(why)
		return ERR_INVALID_PARAMETER
	var err := _peer.connect_to_url(_url)
	if err != OK:
		disconnected.emit("connect_to_url err %s" % err)
		return err
	_active = true
	connecting.emit(_url)
	print("[LbgWs] connecting %s char=%d" % [_url, character_id])
	return OK


func disconnect_session() -> void:
	_active = false
	_ready_sent = false
	_entered = false
	_connect_elapsed = 0.0
	_open_elapsed = 0.0
	_last_state = -1
	if _peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_peer.close()
	_peer = WebSocketPeer.new()


func send_move(pos: Vector3, heading: float = 0.0, cell: int = 0) -> void:
	if not is_open():
		return
	_seq += 1
	_send({
		"type": "move",
		"proto": proto,
		"pos": [pos.x, pos.y, pos.z],
		"heading": heading,
		"cell": cell,
		"seq": _seq,
	})


func send_raw(payload: Dictionary) -> void:
	if not is_open():
		return
	_send(payload)


func _ws_state_name(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING:
			return "CONNECTING"
		WebSocketPeer.STATE_OPEN:
			return "OPEN"
		WebSocketPeer.STATE_CLOSING:
			return "CLOSING"
		WebSocketPeer.STATE_CLOSED:
			return "CLOSED"
		_:
			return str(state)


func _process(delta: float) -> void:
	if not _active:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state != _last_state:
		_last_state = state
		print("[LbgWs] state=%s url=%s" % [_ws_state_name(state), _url])
		handoff_progress.emit("state", _ws_state_name(state))
	if state == WebSocketPeer.STATE_CONNECTING:
		_connect_elapsed += delta
		if connect_timeout_s > 0.0 and _connect_elapsed >= connect_timeout_s:
			_active = false
			_peer.close()
			var hint := " (pare-feu Windows ? test: Test-NetConnection 192.168.0.246 -Port 50000)"
			disconnected.emit("timeout TCP %ss %s%s" % [int(connect_timeout_s), _url, hint])
			return
	elif state == WebSocketPeer.STATE_OPEN and not _entered:
		_open_elapsed += delta
		if response_timeout_s > 0.0 and _open_elapsed >= response_timeout_s:
			_active = false
			_peer.close()
			disconnected.emit("timeout réponse gateway %ss après OPEN" % int(response_timeout_s))
			return
	if state == WebSocketPeer.STATE_OPEN:
		if not _ready_sent:
			_ready_sent = true
			handoff_progress.emit("auth", "login WS…")
			_send({
				"type": "login",
				"proto": proto,
				"session_token": _session_token,
			})
		while _peer.get_available_packet_count() > 0:
			var raw := _peer.get_packet().get_string_from_utf8()
			if raw.is_empty():
				error_message.emit("paquet WS vide (binaire ?)")
				continue
			_dispatch(raw)
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		if _active:
			_active = false
			var code := _peer.get_close_code()
			var reason := _peer.get_close_reason()
			if reason.is_empty():
				disconnected.emit("closed code=%s" % code)
			else:
				disconnected.emit("closed code=%s %s" % [code, reason])


func _send(payload: Dictionary) -> void:
	var text := JSON.stringify(payload)
	_peer.send_text(text)


func _dispatch(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[LbgWs] JSON invalide: %s" % text.substr(0, min(120, text.length())))
		error_message.emit("réponse gateway illisible")
		return
	var d: Dictionary = data
	var t := str(d.get("type", ""))
	match t:
		"login_result":
			var ok := bool(d.get("success", false))
			var reason := str(d.get("reason", ""))
			login_result.emit(ok, reason)
			if not ok:
				error_message.emit("login_result: %s" % (reason if reason else "auth_failed"))
				return
			handoff_progress.emit("auth", "OK — enter_world…")
			_open_elapsed = 0.0
			if auto_enter_world:
				if post_login_ws_action == "select_character" and _character_id > 0:
					_send({
						"type": "select_character",
						"proto": proto,
						"character_id": _character_id,
					})
				else:
					_send({"type": "enter_world", "proto": proto, "zone": _zone})
		"enter_world", "zone_state":
			if d.has("your_character_id"):
				your_character_id = int(d.get("your_character_id"))
			var zone := str(d.get("zone", d.get("map", _zone)))
			if not _entered:
				_entered = true
				connected.emit(your_character_id, zone)
			zone_state_received.emit(d)
		"characters_list":
			pass
		"error":
			error_message.emit(str(d.get("message", "error")))
		"chat":
			pass
		_:
			pass


## Convertit un id gateway (string|int) en oid EntityManager.
static func resolve_oid(raw: Variant) -> int:
	if typeof(raw) == TYPE_INT:
		return int(raw)
	var s := str(raw)
	if s.is_valid_int():
		return int(s)
	if s.is_empty():
		return 0
	return _Crc32Util.entity_oid(s)
