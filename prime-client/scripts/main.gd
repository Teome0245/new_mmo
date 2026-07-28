# main.gd — Scene principale Prime Client (Godot 4.6)
extends Node2D

@onready var camera:         Camera2D      = $Camera2D
@onready var entity_manager: EntityManager = $EntityManager
@onready var info_label:     Label         = $UI/HudLayer/InfoPanel/VBox/InfoLabel
@onready var stats_label:    Label         = $UI/HudLayer/InfoPanel/VBox/StatsLabel
@onready var state_label:    Label         = $UI/HudLayer/StatePanel/StateLabel
@onready var hotbar:         Hotbar        = $UI/HudLayer/Hotbar
@onready var inventory_panel: InventoryPanel = $UI/ModalLayer/InventoryPanel
@onready var _talents_panel: TalentsCraftPanel = $UI/ModalLayer/TalentsCraftPanel
@onready var _dialogue_panel: DialoguePortraitPanel = $UI/ModalLayer/DialoguePortraitPanel
@onready var _login_panel: Control = $UI/LoginPanel
@onready var _ws: Node = get_node_or_null("%LbgWsClient")

const CAM_SPEED:     float   = 400.0
const CAM_ZOOM_STEP: float   = 0.15
const CAM_ZOOM_MIN:  Vector2 = Vector2(0.05, 0.05)
const CAM_ZOOM_MAX:  Vector2 = Vector2(8.0, 8.0)

@export var allow_demo_fallback: bool = false
@export var camera_free_pan: bool = true
@export var show_debug_hud: bool = false
@export var show_login_on_start: bool = true

var _cam_target:   Vector2 = Vector2.ZERO
var _play_mode:    bool    = false
var _frame_count:  int     = 0
var _planet_name:  String  = ""         # planete courante (M5)
var _loco_state:   String  = "STANDING" # etat locomotion (M5)
var _is_connected: bool    = false       # vrai quand un vrai joueur est connecté
var _snapshot_live: bool  = false
var _udp_live: bool       = false
var _ws_live: bool        = false
var _ws_handoff_busy: bool = false
var _last_ws_url: String = ""
var _local_character_name: String = ""
var _dialogue_demo_expression_index: int = 0

const FOCUS_BOTS: Array[String] = ["Nix", "Lia", "Mira"]
const FOCUS_ZOOM: Vector2 = Vector2(2.0, 2.0)
const DIALOGUE_DEMO_EXPRESSIONS: Array[String] = [
	"neutral",
	"happy",
	"determined",
	"talk_1",
	"talk_2",
	"angry",
	"sad",
	"surprised",
]

const LOST_HEAVEN_HUB := Vector3(4749.0, 0.0, -737.0)
const LOST_HEAVEN_ZOOM: Vector2 = Vector2(3.0, 3.0)
const HUB_FIT_MARGIN: float = 0.72
const HUMAN_CFG := "res://config/human_player.json"
const _LastPos = preload("res://scripts/last_position_store.gd")

func _ready() -> void:
	# Demo M2 : SnapshotBridge charge demo_entities.json si pas de snapshots
	get_tree().create_timer(0.35).timeout.connect(_maybe_demo_spawn)
	call_deferred("_focus_lost_heaven_hub")
	if hotbar:
		hotbar.slot_activated.connect(_on_hotbar_slot)
	_ensure_ws_client()
	_wire_login_ws()
	_apply_debug_hud()
	_log_build_info()
	_update_info()


func _log_build_info() -> void:
	const path := "res://assets/build_info.json"
	if not FileAccess.file_exists(path):
		print("[Main] build_info absent — sync J: via tools/sync_prime_client_to_j.sh")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if raw is Dictionary:
		var d: Dictionary = raw
		var stamp := str(d.get("synced_at", "?"))
		var schema := int(d.get("map_config_schema", 0))
		print("[Main] prime-client build synced_at=%s map_schema=%d" % [stamp, schema])
		if info_label and OS.is_debug_build():
			info_label.text = "build %s · map v%d" % [stamp.substr(0, min(19, stamp.length())), schema]


func _ensure_ws_client() -> void:
	if _ws != null and is_instance_valid(_ws):
		if not _ws.is_in_group("lbg_ws_client"):
			_ws.add_to_group("lbg_ws_client")
		return
	_ws = get_node_or_null("LbgWsClient")
	if _ws == null:
		_ws = preload("res://scripts/LbgWsClient.gd").new()
		_ws.name = "LbgWsClient"
		add_child(_ws)
		print("[Main] LbgWsClient créé dynamiquement")
	if not _ws.is_in_group("lbg_ws_client"):
		_ws.add_to_group("lbg_ws_client")


func _wire_login_ws() -> void:
	if _login_panel:
		_login_panel.visible = show_login_on_start
		if show_login_on_start:
			_dismiss_modals_for_login()
		if _login_panel.has_signal("enter_world_requested"):
			_login_panel.enter_world_requested.connect(_on_enter_world_requested)
	if _ws:
		if _ws.has_signal("connecting"):
			_ws.connecting.connect(_on_ws_connecting)
		if _ws.has_signal("connected"):
			_ws.connected.connect(_on_ws_connected)
		if _ws.has_signal("zone_state_received"):
			_ws.zone_state_received.connect(_on_ws_zone_state)
		if _ws.has_signal("disconnected"):
			_ws.disconnected.connect(_on_ws_disconnected)
		if _ws.has_signal("error_message"):
			_ws.error_message.connect(_on_ws_error)
		if _ws.has_signal("login_result"):
			_ws.login_result.connect(_on_ws_login_result)
		if _ws.has_signal("handoff_progress"):
			_ws.handoff_progress.connect(_on_ws_handoff_progress)
		var pc: PlayerController = get_node_or_null("PlayerController") as PlayerController
		if pc and pc.has_method("set_ws_client"):
			pc.set_ws_client(_ws)


func _dismiss_modals_for_login() -> void:
	var pmap := get_node_or_null("UI/ModalLayer/PlanetMapPanel") as PlanetMapPanel
	if pmap and pmap.has_method("close_map"):
		pmap.close_map()
	if inventory_panel and inventory_panel.visible:
		inventory_panel.toggle()
	if _talents_panel and _talents_panel.visible:
		_talents_panel.toggle()
	if _dialogue_panel and _dialogue_panel.visible:
		_dialogue_panel.hide_portrait()
	var retail := get_node_or_null("WorldMap/RetailLayoutLayer") as RetailLayoutLayer
	if retail and retail.visible_layout:
		retail.set_visible_layout(false)


func _set_login_status(message: String) -> void:
	if _login_panel and _login_panel.has_method("set_ws_status"):
		_login_panel.set_ws_status(message)
	elif _login_panel and _login_panel.has_node("%StatusLabel"):
		(_login_panel.get_node("%StatusLabel") as Label).text = message


func _on_enter_world_requested(ws_url: String, character_id: int, session_token: String) -> void:
	if _ws_handoff_busy:
		return
	if session_token.strip_edges().is_empty():
		_on_ws_error("session_token vide (login HTTP)")
		return
	_ws_handoff_busy = true
	# Nom perso depuis le LoginPanel (évite double sprite Gally / Vous)
	if _login_panel and _login_panel.has_method("get_selected_character_name"):
		_local_character_name = str(_login_panel.call("get_selected_character_name")).strip_edges()
	print("[Main] M11→M12 handoff ws=%s char=%d name=%s" % [ws_url, character_id, _local_character_name])
	_last_ws_url = ws_url
	# Garder le panel visible jusqu'à enter_world (sinon status « WS… » figé sans feedback).
	if _login_panel:
		_login_panel.visible = true
	_dismiss_modals_for_login()
	_ensure_ws_client()
	_set_login_status("WS %s…" % ws_url)
	if state_label:
		state_label.text = "WS…"
	if _ws and _ws.has_method("connect_session"):
		var err: int = _ws.connect_session(ws_url, session_token, character_id, "tatooine")
		if err != OK:
			_ws_handoff_busy = false
			_on_ws_error("connect_session err %s" % err)
	else:
		_ws_handoff_busy = false
		_on_ws_error("LbgWsClient absent après _ensure_ws_client")


func _on_ws_connecting(ws_url: String) -> void:
	_set_login_status("WS connexion %s…" % ws_url)
	if state_label:
		state_label.text = "WS…"


func _on_ws_handoff_progress(phase: String, detail: String) -> void:
	if phase == "state":
		var host := _last_ws_url
		if host.length() > 48:
			host = host.substr(0, 45) + "…"
		_set_login_status("WS %s — %s" % [detail, host])
	elif phase == "auth":
		_set_login_status("WS %s" % detail)
	elif phase == "error":
		_on_ws_error(detail)


func _on_ws_connected(your_character_id: int, zone: String) -> void:
	_ws_handoff_busy = false
	_ws_live = true
	_planet_name = zone
	print("[Main] WS connected char=%d zone=%s" % [your_character_id, zone])
	if _login_panel and _login_panel.has_method("on_ws_connected"):
		_login_panel.on_ws_connected(your_character_id, zone)
	else:
		_set_login_status("Connecté — %s" % zone)
	_dismiss_modals_for_login()
	if _login_panel:
		_login_panel.visible = false
	if state_label:
		state_label.text = "WS OK"


func _on_ws_disconnected(reason: String) -> void:
	_ws_handoff_busy = false
	_ws_live = false
	print("[Main] WS disconnected: %s" % reason)
	if state_label:
		state_label.text = "WS OFF"
	if not _is_connected:
		if _login_panel:
			_login_panel.visible = true
			_dismiss_modals_for_login()
			if _login_panel.has_method("on_ws_failed"):
				_login_panel.on_ws_failed(reason)
			else:
				_set_login_status("WS échoué: %s" % reason)


func _on_ws_login_result(success: bool, reason: String) -> void:
	if success:
		_set_login_status("WS auth OK — entrée zone…")
		return
	_ws_handoff_busy = false
	_on_ws_error("login_result: %s" % (reason if reason else "auth_failed"))


func _on_ws_error(message: String) -> void:
	_ws_handoff_busy = false
	push_warning("[Main] WS error: %s" % message)
	if _login_panel and not _is_connected:
		_login_panel.visible = true
		_dismiss_modals_for_login()
		if _login_panel.has_method("on_ws_failed"):
			_login_panel.on_ws_failed(message)
		else:
			_set_login_status(message)
	if state_label:
		state_label.text = "WS ERR"


func _on_ws_zone_state(payload: Dictionary) -> void:
	_ws_live = true
	_snapshot_live = true
	var zone := str(payload.get("zone", payload.get("map", _planet_name)))
	if zone != "":
		_planet_name = zone
		var wm: WorldMap = get_node_or_null("WorldMap") as WorldMap
		if wm:
			wm.set_planet(zone.to_lower())

	var your_id := int(payload.get("your_character_id", 0))
	if your_id == 0 and _ws and "your_character_id" in _ws:
		your_id = int(_ws.your_character_id)
	# Entrée monde : le premier zone_state suffit (enter_world peut être fusionné côté gateway).
	if your_id > 0 and _login_panel and _login_panel.visible:
		_ws_handoff_busy = false
		if _login_panel.has_method("on_ws_connected"):
			_login_panel.on_ws_connected(your_id, zone if zone != "" else "tatooine")
		else:
			_login_panel.visible = false

	var pos := Vector3(LOST_HEAVEN_HUB.x, LOST_HEAVEN_HUB.y, LOST_HEAVEN_HUB.z)
	var has_pos := false
	if payload.get("position") is Array:
		var p: Array = payload["position"]
		if p.size() >= 3:
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
			has_pos = true

	# Entités zone (skip le joueur local pour éviter le double sprite)
	var entities: Array = payload.get("entities", [])
	if typeof(entities) == TYPE_ARRAY:
		for ent in entities:
			if not ent is Dictionary:
				continue
			_apply_ws_entity(ent as Dictionary, your_id)
		var retail := get_node_or_null("WorldMap/RetailLayoutLayer") as RetailLayoutLayer
		if retail:
			retail.merge_zone_entities(entities, your_id)

	# Joueur contrôlé — spawn une fois ; ne pas recentrer à chaque tick zone_state
	if your_id > 0:
		var existing := entity_manager.get_entity(your_id)
		var first_spawn := existing == null
		if first_spawn:
			var label := _local_character_name if _local_character_name != "" else "You"
			var cfg := _load_human_cfg()
			if label == "You" and str(cfg.get("display_name", "")) != "":
				label = str(cfg["display_name"])
			# Secours client : si gateway renvoie le hub défaut, reprendre la dernière pos locale
			var saved := _LastPos.load_pos(your_id)
			if saved != Vector3.INF:
				var near_default := (pos - LOST_HEAVEN_HUB).length_squared() < 4.0
				if near_default or not has_pos:
					pos = saved
					has_pos = true
			entity_manager.spawn(your_id, pos, Entity.COLOR_PLAYER_OFFICIAL, label, "player", "player:human")
		elif has_pos and existing != null:
			# Client-authoritative pendant le play : pas de soft-correct (cause le rebond).
			# On ne recentre que si le joueur est immobile ET très loin (> 40 m).
			var pc_chk: PlayerController = get_node_or_null("PlayerController") as PlayerController
			var moving := pc_chk != null and pc_chk.has_method("is_moving") and bool(pc_chk.is_moving())
			if not moving:
				var dx: float = existing.core3_pos.x - pos.x
				var dz: float = existing.core3_pos.z - pos.z
				if dx * dx + dz * dz > 1600.0:  # > 40 m
					entity_manager.move(your_id, pos)
		var pc: PlayerController = get_node_or_null("PlayerController") as PlayerController
		if pc:
			pc.set_player_id(your_id)
			if first_spawn and pc.has_method("send_initial_position"):
				pc.send_initial_position(pos.x, pos.y, pos.z)
		if not _is_connected:
			on_player_connected(your_id, zone if zone != "" else "tatooine")

	for rid in payload.get("removed_entity_ids", []):
		var oid := LbgWsClient.resolve_oid(rid)
		if oid != 0 and oid != your_id:
			entity_manager.despawn(oid)


func _resolve_ws_oid(raw: Variant) -> int:
	return LbgWsClient.resolve_oid(raw)


func _apply_ws_entity(ent: Dictionary, your_id: int = 0) -> void:
	var oid := _resolve_ws_oid(ent.get("id", ent.get("name", "")))
	if oid == 0:
		return
	if your_id > 0 and oid == your_id:
		return
	var name := str(ent.get("name", ""))
	var kind := str(ent.get("kind", "npc"))
	var name_l := name.strip_edges().to_lower()
	# Stub gateway "Vous (Godot)" + ton propre perso Core3 (Gally, …)
	if kind == "player":
		if name_l.begins_with("vous") or name_l == "you" or name_l == "voyageur":
			return
		if _local_character_name != "" and name_l.begins_with(_local_character_name.to_lower()):
			return
	var pos_raw = ent.get("pos")
	var pos := Vector3.ZERO
	if pos_raw is Array and (pos_raw as Array).size() >= 3:
		var a: Array = pos_raw
		pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	else:
		pos = Vector3(float(ent.get("x", 0)), float(ent.get("y", 0)), float(ent.get("z", 0)))
	if name == "":
		name = str(ent.get("id", ""))
	var color := Entity.COLOR_NPC
	if kind == "player":
		color = Entity.COLOR_PLAYER_BOT
	if entity_manager.get_entity(oid) == null:
		entity_manager.spawn(oid, pos, color, name, kind, str(ent.get("id", "")))
	else:
		entity_manager.move(oid, pos)
func _focus_lost_heaven_hub() -> void:
	if camera == null:
		return
	var center := Projection3D2D.to_screen(LOST_HEAVEN_HUB)
	var fit_z := _hub_fit_zoom()
	camera.position = center
	camera.zoom = Vector2(fit_z, fit_z)
	_cam_target = center
	print("[Main] focus Lost Heaven hub (4749, -737) zoom=%.2f" % fit_z)

func _hub_fit_zoom() -> float:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 64.0 or vp.y < 64.0:
		return LOST_HEAVEN_ZOOM.x
	var bounds := _hub_world_bounds()
	if bounds.is_empty():
		return LOST_HEAVEN_ZOOM.x
	var span_x: float = (float(bounds["max_x"]) - float(bounds["min_x"])) * Projection3D2D.SCALE
	var span_z: float = (float(bounds["max_z"]) - float(bounds["min_z"])) * Projection3D2D.SCALE
	if span_x < 1.0 or span_z < 1.0:
		return LOST_HEAVEN_ZOOM.x
	var zx: float = (vp.x * HUB_FIT_MARGIN) / span_x
	var zy: float = (vp.y * HUB_FIT_MARGIN) / span_z
	return clampf(minf(zx, zy), CAM_ZOOM_MIN.x, CAM_ZOOM_MAX.x)

func _hub_world_bounds() -> Dictionary:
	const path := "res://assets/maps/lost_heaven_buildings.json"
	const pad := 80.0
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not raw is Dictionary:
		return {}
	var min_x := 1.0e12
	var max_x := -1.0e12
	var min_z := 1.0e12
	var max_z := -1.0e12
	for item: Variant in (raw as Dictionary).get("buildings", []):
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		var cx := float(b.get("x", 0.0))
		var cz := float(b.get("z", 0.0))
		var half := float(b.get("size_m", 32.0)) * 0.5 + pad * 0.35
		min_x = minf(min_x, cx - half)
		max_x = maxf(max_x, cx + half)
		min_z = minf(min_z, cz - half)
		max_z = maxf(max_z, cz + half)
	if min_x > max_x:
		return {}
	return {"min_x": min_x - pad, "max_x": max_x + pad, "min_z": min_z - pad, "max_z": max_z + pad}

# ---------------------------------------------------------------------------
# Demo M2 (fallback si SnapshotBridge sans données)
# ---------------------------------------------------------------------------
func _maybe_demo_spawn() -> void:
	if not allow_demo_fallback:
		return
	if _snapshot_live or _udp_live or entity_manager.count() > 0:
		return
	_demo_spawn()

func _demo_spawn() -> void:
	entity_manager.spawn(
		0x0000_0001_0000_0001,
		Vector3(3500.0, 0.0, -4800.0),
		Entity.COLOR_PLAYER_OFFICIAL,
		"SWG_Client",
		"player"
	)
	entity_manager.spawn(
		0x0000_0001_0000_0002,
		Vector3(3510.0, 0.0, -4795.0),
		Entity.COLOR_PLAYER_BOT,
		"Bot_IA",
		"player"
	)
	entity_manager.spawn(
		0x0000_0002_0000_0001,
		Vector3(3525.0, 8.0, -4810.0),
		Entity.COLOR_NPC,
		"NPC_Guard",
		"npc"
	)
	entity_manager.spawn(0, Vector3(0.0, 0.0, 0.0), Color(1.0, 1.0, 0.0, 0.6), "(0,0)")
	var center := Projection3D2D.to_screen(Vector3(3510.0, 0.0, -4800.0))
	camera.position = center
	_cam_target     = center

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(CAM_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-CAM_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var picked := entity_manager.pick_interactable_at_screen(event.position)
			if picked:
				_open_npc_dialogue(picked)
			elif _dialogue_panel and _dialogue_panel.visible:
				_dialogue_panel.hide_portrait()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				_focus_bot("Lia")
			KEY_F2:
				_focus_bot("Nix")
			KEY_F3:
				_focus_bot("Mira")
			KEY_H:
				_focus_lost_heaven_hub()
			KEY_R:
				_focus_lost_heaven_hub()
			KEY_F:
				var e := entity_manager.get_entity(0x0000_0001_0000_0002)
				if e:
					camera.position = e.position
			KEY_T:
				_toggle_talents()
			KEY_I:
				_toggle_inventory()
			KEY_P:
				_toggle_dialogue_demo()
			KEY_O:
				_cycle_dialogue_expression()
			KEY_L:
				Entity.toggle_nameplates()
				for e in entity_manager.get_all_entities():
					if e:
						e.queue_redraw()
				print("[Main] nameplates=%s" % Entity.show_nameplates)
			KEY_F9:
				show_debug_hud = not show_debug_hud
				_apply_debug_hud()
			KEY_ESCAPE:
				if _login_panel and _login_panel.visible and _is_connected:
					_login_panel.visible = false
				elif _login_panel and not _login_panel.visible and not _is_connected:
					_login_panel.visible = true
				else:
					get_tree().quit()
			KEY_F10:
				if _login_panel:
					_login_panel.visible = not _login_panel.visible


func _apply_debug_hud() -> void:
	var info := get_node_or_null("UI/HudLayer/InfoPanel") as Control
	if info:
		info.visible = show_debug_hud

func _toggle_talents() -> void:
	if _talents_panel == null:
		return
	if inventory_panel and inventory_panel.visible:
		inventory_panel.toggle()
	_talents_panel.toggle()

func _toggle_inventory() -> void:
	if inventory_panel == null:
		return
	if _talents_panel and _talents_panel.visible:
		_talents_panel.toggle()
	inventory_panel.toggle()

func _on_hotbar_slot(index: int) -> void:
	match index:
		0:
			_hotbar_feedback("Attaque — à brancher combat")
		1:
			_hotbar_feedback("Compétence — à brancher")
		2:
			_hotbar_feedback("Objet rapide — à brancher")
		3:
			_hotbar_feedback("Emote — à brancher")
		4: # Carte
			var map_panel := get_node_or_null("UI/ModalLayer/PlanetMapPanel")
			if map_panel and map_panel.has_method("toggle_map"):
				map_panel.call("toggle_map")
				_hotbar_feedback("Carte planétaire")
		5: # Talents
			_toggle_talents()
			_hotbar_feedback("Talents / craft")
		6: # Inventaire
			_toggle_inventory()
			_hotbar_feedback("Inventaire")
		7:
			_toggle_dialogue_demo()
			_hotbar_feedback("Portrait dialogue démo")
		8:
			_hotbar_feedback("Monture — à brancher")
		9:
			_hotbar_feedback("Menu — à brancher")
		_:
			_hotbar_feedback("Slot %d" % index)

func _hotbar_feedback(msg: String) -> void:
	if state_label:
		state_label.text = msg
		state_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1))

func _toggle_dialogue_demo() -> void:
	if _dialogue_panel == null:
		return
	if _dialogue_panel.visible:
		_dialogue_panel.hide_portrait()
		return
	var expr := DIALOGUE_DEMO_EXPRESSIONS[_dialogue_demo_expression_index % DIALOGUE_DEMO_EXPRESSIONS.size()]
	_dialogue_panel.show_portrait(
		"Odo le guide",
		"npc",
		expr,
		"Bienvenue à Lost Heaven. Le portrait dialogue est en place ; il reste à brancher les vraies interactions PNJ.",
		"npc:odo_guide"
	)
	_hotbar_feedback("Portrait %s" % expr)

func _cycle_dialogue_expression() -> void:
	if _dialogue_panel == null:
		return
	_dialogue_demo_expression_index = (_dialogue_demo_expression_index + 1) % DIALOGUE_DEMO_EXPRESSIONS.size()
	if not _dialogue_panel.visible:
		return
	var expr := DIALOGUE_DEMO_EXPRESSIONS[_dialogue_demo_expression_index]
	_dialogue_panel.set_expression(expr)
	_dialogue_panel.set_body_text("Expression active : %s" % expr)
	_hotbar_feedback("Expression %s" % expr)

func _open_npc_dialogue(entity: Entity) -> void:
	if entity == null or _dialogue_panel == null:
		return
	var speaker := entity.label_text if entity.label_text != "" else "PNJ"
	var anchor := NpcAnchorResolver.resolve(entity.entity_key, entity.label_text)
	var role := str(anchor.get("role", ""))
	var body := _npc_dialogue_stub(role, speaker)
	_dialogue_demo_expression_index = 0
	_dialogue_panel.show_portrait(
		speaker,
		entity.kind,
		"neutral",
		body,
		entity.entity_key
	)
	_hotbar_feedback("Interaction %s" % speaker)

func _npc_dialogue_stub(role: String, speaker: String) -> String:
	match role:
		"guide", "quest_giver", "archivist", "rumormonger":
			return "%s : bienvenue à Lost Heaven. Nous brancherons ici les vraies lignes de dialogue et les expressions." % speaker
		"bartender", "host", "performer", "patron", "cantina_fallback":
			return "%s : un portrait vivant type Warcraft 3 fonctionne bien pour les échanges courts et lisibles." % speaker
		"merchant", "resident":
			return "%s : le panneau dialogue est prêt ; il reste à relier l'inventaire, les quêtes ou le commerce." % speaker
		_:
			return "%s : interaction PNJ MVP active." % speaker

func _process(delta: float) -> void:
	_handle_camera_move(delta)
	_frame_count += 1
	if _frame_count % 60 == 0:
		_update_info()

func _handle_camera_move(delta: float) -> void:
	if camera == null or _play_mode or not camera_free_pan:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_EQUAL):
		_zoom_camera(CAM_ZOOM_STEP * delta * 4.0)
	if Input.is_key_pressed(KEY_MINUS):
		_zoom_camera(-CAM_ZOOM_STEP * delta * 4.0)
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta / camera.zoom.x

func _zoom_camera(step: float) -> void:
	if camera == null:
		return
	camera.zoom = (camera.zoom + Vector2(step, step)).clamp(CAM_ZOOM_MIN, CAM_ZOOM_MAX)

# ---------------------------------------------------------------------------
# UI debug
# ---------------------------------------------------------------------------
func _update_info() -> void:
	if camera == null:
		return
	if not show_debug_hud:
		return
	var center := camera.get_screen_center_position()
	var core3  := Projection3D2D.from_screen(center)
	if info_label:
		var mode := "PLAY" if _play_mode else ("WS LIVE" if _ws_live else ("UDP LIVE" if _udp_live else ("PRIME" if _snapshot_live else "ATTENTE")))
		var players := entity_manager.count()
		info_label.text = (
			"Prime Client v0.2  |  %s  |  Bots: %d\n" % [mode, players] +
			"Zoom: %.2fx   Core3 cam: (%.0f, -, %.0f)" % [camera.zoom.x, core3.x, core3.z]
		)
	if stats_label:
		if _play_mode:
			stats_label.text = "[ZQSD] move  [T/I] panels  [L] labels  [1-0] hotbar  [Ctrl+M] carte"
		else:
			stats_label.text = "[H/R] hub  [M] minimap  [Ctrl+M] carte  [L] labels  [1-0] hotbar"

# ---------------------------------------------------------------------------
# API reseau — appelee par NetworkBridge
# ---------------------------------------------------------------------------
func on_data_transform(object_id: int, x: float, y: float, z: float) -> void:
	entity_manager.move(object_id, Vector3(x, y, z))

func on_object_destroy(object_id: int) -> void:
	entity_manager.despawn(object_id)

func on_zone_change() -> void:
	entity_manager.clear()
	_is_connected = false

func on_mirror_udp_active() -> void:
	_udp_live = true
	_snapshot_live = true
	_update_info()

func on_snapshot_feed_active() -> void:
	_snapshot_live = true
	_update_info()
	# Garder la vue hub Lost Heaven ; F1/F2/F3 pour cibler un bot
	call_deferred("_focus_lost_heaven_hub")
	print("[Main] flux snapshot actif — Ctrl+H hub · F1/F2/F3 bots")

func _focus_bot(name: String) -> bool:
	if camera == null:
		return false
	var oid := Crc32Util.entity_oid("player:%s" % name)
	var e := entity_manager.get_entity(oid)
	if e == null:
		print("[Main] focus %s : absent — lance run_m3_mirror.sh ?" % name)
		return false
	camera.position = e.position
	camera.zoom = FOCUS_ZOOM
	_cam_target = e.position
	print("[Main] focus %s" % name)
	return true

func _focus_first_bot() -> void:
	for name in FOCUS_BOTS:
		if _focus_bot(name):
			return

# M5 — Joueur connecté (reçu via NetworkBridge "cn")
func on_player_connected(obj_id: int, planet: String) -> void:
	_planet_name  = planet
	_is_connected = true
	_play_mode    = true
	camera_free_pan = false
	_ws_handoff_busy = false
	if _login_panel:
		if _login_panel.has_method("on_ws_connected"):
			_login_panel.on_ws_connected(obj_id, planet)
		else:
			_login_panel.visible = false
	var cfg := _load_human_cfg()
	var pc: PlayerController = get_node_or_null("PlayerController") as PlayerController
	if pc:
		pc.enabled = true
		pc.set_player_id(obj_id)
	# Couper le flux snapshot fichier (sinon Gally Core3 = 2e sprite + rebond visuel)
	var sb := get_node_or_null("SnapshotBridge")
	if sb and sb.has_method("set_paused"):
		sb.call("set_paused", true)
	_despawn_local_player_ghosts(obj_id)
	var wm: WorldMap = get_node_or_null("WorldMap") as WorldMap
	if wm and planet != "":
		wm.set_planet(planet.to_lower())
	if bool(cfg.get("hide_npc_nameplates_on_play", true)):
		Entity.show_nameplates = false
		for e in entity_manager.get_all_entities():
			if e:
				e.queue_redraw()
	if bool(cfg.get("auto_focus_on_connect", true)):
		var e := entity_manager.get_entity(obj_id)
		if e and camera:
			camera.position = e.position
			var zf := float(cfg.get("play_zoom", 2.2))
			camera.zoom = Vector2(zf, zf)
			_cam_target = e.position
	if state_label:
		state_label.text = "CONNECTED"
	_update_info()
	print("[Main] Joueur humain 0x%016x connecté sur %s (name=%s)" % [obj_id, planet, _local_character_name])


func _despawn_local_player_ghosts(your_id: int) -> void:
	## Retire les doublons "Vous (Godot)" / Gally snapshot à côté du sprite contrôlé.
	var names: Array[String] = []
	if _local_character_name != "":
		names.append(_local_character_name.to_lower())
	names.append("vous (godot)")
	names.append("voyageur")
	var to_kill: Array[int] = []
	for e in entity_manager.get_all_entities():
		if e == null:
			continue
		if int(e.object_id) == your_id:
			continue
		if str(e.kind) != "player":
			continue
		var label := str(e.label_text).strip_edges().to_lower()
		var key := str(e.entity_key).strip_edges().to_lower()
		var hit := false
		for n in names:
			if n == "":
				continue
			if label.begins_with(n) or key == ("player:%s" % n) or key.ends_with(":%s" % n):
				hit = true
				break
		if hit:
			to_kill.append(int(e.object_id))
	for oid in to_kill:
		entity_manager.despawn(oid)
		print("[Main] ghost joueur despawn oid=%d" % oid)

func _load_human_cfg() -> Dictionary:
	if not FileAccess.file_exists(HUMAN_CFG):
		return {}
	var f := FileAccess.open(HUMAN_CFG, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return raw if raw is Dictionary else {}

# M5 — Etat locomotion depuis prime_controller.py ("ls")
func on_locomotion_state(state: String) -> void:
	_loco_state = state.to_upper()
	if state_label:
		state_label.text = _loco_state
		# Couleur selon l'etat
		match _loco_state:
			"RUNNING":  state_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
			"JUMPING","FALLING": state_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
			"SWIMMING": state_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1))
			"WALKING":  state_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
			_:          state_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
