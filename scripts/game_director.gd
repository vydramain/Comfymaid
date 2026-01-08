extends Node

enum GameState { HUB_FREE, HUB_DIALOGUE, TRANSITION, BOSSROOM_FREE, BOSS_FIGHT, RESET }

enum InputType { KEYBOARD, GAMEPAD }

static var instance: Node

const INPUT_TYPE_INVALID := -1
const INPUT_UI_CONFIG_PATH := "res://scripts/config/input_ui_config.tres"
const JOYPAD_DEADZONE := 0.2
const LABEL_CACHE_DEFAULT_TTL := 0.4
const WHITEOUT_FADE_MIN := 0.5
const WHITEOUT_FADE_MAX := 3.0

var mechanic_broken := false
var boss_defeated := false
var boss_revived_once := false
var guardian_intro_done := false
var guardian_post_dialogue_done := false
var guardian_death_hint_pending := false
var world_reset_count := 0

var state: GameState = GameState.HUB_FREE

var dialogue_ui: Node
var prompt_ui: Node
var overlay_ui: Node
var whiteout_ui: Node
var _scene_manager_connected := false
var _dialogue_connected := false
var _dialogue_source: Node
var _ui_manager: Node
var _ui_manager_connected := false
var _last_input_type := InputType.KEYBOARD
var _last_joypad_device_id := -1
var _last_joypad_name := ""
var _input_handlers: Dictionary = {}
var _ui_config: input_ui_config
var _label_cache: Dictionary = {}
var _label_cache_time := 0.0
var _label_cache_dirty := true

func _ready() -> void:
	instance = self
	_ui_config = load(INPUT_UI_CONFIG_PATH) as input_ui_config
	if _ui_config == null:
		_ui_config = input_ui_config.new()
	_setup_input_handlers()
	_bind_ui_manager()
	get_tree().node_added.connect(_on_node_added)
	if SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true

func _input(event: InputEvent) -> void:
	var handler: Callable = _input_handlers.get(event.get_class(), Callable()) as Callable
	var next: int = INPUT_TYPE_INVALID
	if handler.is_valid():
		next = handler.call(event)
	if next != INPUT_TYPE_INVALID:
		_update_last_input_device(event, next as InputType)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(_delta: float) -> void:
	if not _scene_manager_connected and SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true
		if AudioDirector.instance and SceneManager.instance.current_scene_name != "":
			AudioDirector.instance.start_scene_audio(SceneManager.instance.current_scene_name)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if dialogue_ui and dialogue_ui.has_method("is_active") and dialogue_ui.is_active():
			if dialogue_ui.can_advance():
				dialogue_ui.advance()
			return
		var player := _get_player()
		if player and player.has_method("try_interact"):
			player.try_interact()

func _get_player() -> Node:
	if SceneManager.instance:
		return SceneManager.instance.player
	return null

func _bind_ui_manager() -> void:
	var ui_manager := _get_ui_manager()
	if ui_manager == null or ui_manager == _ui_manager:
		return
	_ui_manager = ui_manager
	if not _ui_manager_connected:
		_ui_manager.ui_ready.connect(_on_ui_ready)
		_ui_manager_connected = true
	_ui_manager.request_ui_ready()

func _get_ui_manager() -> Node:
	return get_tree().get_first_node_in_group("ui_manager")

func _on_node_added(node: Node) -> void:
	if node.is_in_group("ui_manager"):
		_bind_ui_manager()

func _connect_dialogue() -> void:
	if dialogue_ui == null:
		return
	if _dialogue_connected and _dialogue_source == dialogue_ui:
		return
	dialogue_ui.dialogue_started.connect(_on_dialogue_started)
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	_dialogue_connected = true
	_dialogue_source = dialogue_ui

func _disconnect_dialogue() -> void:
	if not _dialogue_connected or _dialogue_source == null:
		return
	if is_instance_valid(_dialogue_source):
		if _dialogue_source.dialogue_started.is_connected(_on_dialogue_started):
			_dialogue_source.dialogue_started.disconnect(_on_dialogue_started)
		if _dialogue_source.dialogue_finished.is_connected(_on_dialogue_finished):
			_dialogue_source.dialogue_finished.disconnect(_on_dialogue_finished)
	_dialogue_connected = false
	_dialogue_source = null

func _on_ui_ready(next_dialogue: Node, next_prompt: Node, next_overlay: Node, next_whiteout: Node) -> void:
	var dialogue_changed := next_dialogue != dialogue_ui
	dialogue_ui = next_dialogue
	prompt_ui = next_prompt
	overlay_ui = next_overlay
	whiteout_ui = next_whiteout
	if dialogue_changed:
		_disconnect_dialogue()
		_connect_dialogue()

func _on_dialogue_started() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
		state = GameState.HUB_DIALOGUE
	else:
		state = GameState.BOSS_FIGHT
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(true)

func _on_dialogue_finished() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(true)
	if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
		state = GameState.HUB_FREE
	else:
		state = GameState.BOSSROOM_FREE
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(false)

func request_scene_change(scene_name: StringName, spawn_marker: StringName = "PlayerSpawn") -> void:
	if state == GameState.TRANSITION:
		return
	state = GameState.TRANSITION
	_set_player_movement(false)
	if whiteout_ui == null:
		_do_scene_change(scene_name, spawn_marker)
		state = GameState.HUB_FREE if scene_name == "Hub" else GameState.BOSSROOM_FREE
		_set_player_movement(true)
		return
	var fade_time: float = WHITEOUT_FADE_MAX
	var _start_boundary_id := -1
	if AudioDirector.instance:
		_start_boundary_id = AudioDirector.instance.get_boundary_id()
		AudioDirector.instance.fade_out_all(fade_time)
	await whiteout_ui.fade_to_white(fade_time)
	if AudioDirector.instance:
		AudioDirector.instance.stop_all_music()
	_do_scene_change(scene_name, spawn_marker)
	if AudioDirector.instance:
		AudioDirector.instance.start_scene_audio(scene_name)
	await whiteout_ui.fade_from_white(0.5)
	state = GameState.HUB_FREE if scene_name == "Hub" else GameState.BOSSROOM_FREE
	_set_player_movement(true)

func _do_scene_change(scene_name: StringName, spawn_marker: StringName) -> void:
	if SceneManager.instance:
		SceneManager.instance.change_scene(scene_name, spawn_marker)

func request_reset() -> void:
	world_reset_count += 1
	if state == GameState.RESET or state == GameState.TRANSITION:
		return
	state = GameState.RESET
	_reset_run_flags()
	await request_scene_change("Hub", "PlayerSpawn")

func request_death_reset() -> void:
	world_reset_count = 0
	if state == GameState.RESET or state == GameState.TRANSITION:
		return
	state = GameState.RESET
	_reset_run_flags()
	guardian_death_hint_pending = true
	await request_scene_change("Hub", "PlayerSpawn")

func _reset_run_flags() -> void:
	mechanic_broken = false
	boss_defeated = false
	boss_revived_once = false
	guardian_intro_done = false
	guardian_post_dialogue_done = false
	guardian_death_hint_pending = false

func notify_boss_revive() -> void:
	if not boss_revived_once:
		boss_revived_once = true
		if overlay_ui and overlay_ui.has_method("show_line"):
			overlay_ui.show_line("Советы по игре будут?")
		var mechanic := SceneManager.instance.find_singleton_in_group("MechanicWord") if SceneManager.instance else null
		if mechanic and mechanic.has_method("enable_word"):
			mechanic.enable_word()

func notify_boss_defeated() -> void:
	boss_defeated = true

func notify_mechanic_broken() -> void:
	mechanic_broken = true

func unlock_guardian_intro() -> void:
	guardian_intro_done = true

func unlock_guardian_post_dialogue() -> void:
	guardian_post_dialogue_done = true

func _on_level_changed(scene_name: StringName) -> void:
	if AudioDirector.instance:
		AudioDirector.instance.start_scene_audio(scene_name)
	state = GameState.HUB_FREE if scene_name == "Hub" else GameState.BOSSROOM_FREE
	_set_player_movement(true)

func _setup_input_handlers() -> void:
	_input_handlers = {
		"InputEventKey": Callable(self, "_input_from_key"),
		"InputEventJoypadButton": Callable(self, "_input_from_joy_button"),
		"InputEventJoypadMotion": Callable(self, "_input_from_joy_motion"),
	}

func _input_from_key(event: InputEventKey) -> int:
	return InputType.KEYBOARD if event.pressed else INPUT_TYPE_INVALID as int

func _input_from_joy_button(event: InputEventJoypadButton) -> int:
	return InputType.GAMEPAD if event.pressed else INPUT_TYPE_INVALID as int

func _input_from_joy_motion(event: InputEventJoypadMotion) -> int:
	return InputType.GAMEPAD if abs(event.axis_value) > JOYPAD_DEADZONE else INPUT_TYPE_INVALID as int

func get_interact_label() -> String:
	return get_action_label("INTERACT")

func get_action_label(action: String) -> String:
	_ensure_label_cache()
	return _label_cache.get(action, "")

func _ensure_label_cache() -> void:
	if _ui_config == null:
		_ui_config = input_ui_config.new()
	var ttl := _ui_config.label_cache_ttl if _ui_config else LABEL_CACHE_DEFAULT_TTL
	var now := Time.get_ticks_msec() / 1000.0
	if not _label_cache_dirty and (now - _label_cache_time) < ttl:
		return
	_label_cache_time = now
	_label_cache_dirty = false
	_label_cache.clear()
	for token in _ui_config.token_actions.keys():
		_label_cache[str(token)] = _build_action_label(str(token))

func _build_action_label(action: String) -> String:
	var action_names := _ui_config.token_actions.get(action, PackedStringArray()) as PackedStringArray
	if action_names.is_empty():
		return ""
	var labels: Array[String] = []
	for action_name in action_names:
		var label := _get_action_label_for_action(action_name, _last_input_type)
		if label != "" and not labels.has(label):
			labels.append(label)
	var joiner := _ui_config.keyboard_joiner if _last_input_type == InputType.KEYBOARD else _ui_config.gamepad_joiner
	return joiner.join(labels)

func _get_action_label_for_action(action_name: StringName, input_type: InputType) -> String:
	var event := _select_action_event(action_name, input_type)
	if event == null:
		return ""
	return _event_to_label(event, input_type)

func _select_action_event(action_name: StringName, input_type: InputType) -> InputEvent:
	var events := InputMap.action_get_events(action_name)
	if input_type == InputType.KEYBOARD:
		return _select_key_event(events)
	if input_type == InputType.GAMEPAD:
		return _select_gamepad_event(events, _last_joypad_device_id)
	return null

func _select_key_event(events: Array) -> InputEventKey:
	var preferred: InputEventKey
	var fallback: InputEventKey
	for event in events:
		if event is InputEventKey:
			if _is_modifier_free(event):
				if preferred == null:
					preferred = event
			elif fallback == null:
				fallback = event
	return preferred if preferred != null else fallback

func _select_gamepad_event(events: Array, device_id: int) -> InputEvent:
	var button_event := _find_gamepad_event(events, device_id, true)
	if button_event != null:
		return button_event
	var axis_event := _find_gamepad_event(events, device_id, false)
	if axis_event != null:
		return axis_event
	if device_id == -1:
		return null
	button_event = _find_gamepad_event(events, -1, true, true)
	if button_event != null:
		return button_event
	return _find_gamepad_event(events, -1, false, true)

func _find_gamepad_event(events: Array, device_id: int, prefer_button: bool, allow_any: bool = false) -> InputEvent:
	for event in events:
		if prefer_button and event is InputEventJoypadButton:
			if _gamepad_device_matches(event.device, device_id, allow_any):
				return event
		if not prefer_button and event is InputEventJoypadMotion:
			if _gamepad_device_matches(event.device, device_id, allow_any):
				return event
	return null

func _gamepad_device_matches(event_device: int, device_id: int, allow_any: bool) -> bool:
	if allow_any:
		return true
	if device_id == -1:
		return event_device == -1
	return event_device == -1 or event_device == device_id

func _event_to_label(event: InputEvent, input_type: InputType) -> String:
	if input_type == InputType.KEYBOARD and event is InputEventKey:
		return _format_key_label(event)
	if input_type == InputType.GAMEPAD:
		if event is InputEventJoypadButton:
			return _ui_config.get_gamepad_button_label(event.button_index, _last_joypad_name)
		if event is InputEventJoypadMotion:
			return _ui_config.get_gamepad_axis_label(event.axis)
	return ""

func _format_key_label(event: InputEventKey) -> String:
	var keycode := event.keycode
	if _ui_config and _ui_config.display_physical_keys:
		keycode = event.physical_keycode
	var base := OS.get_keycode_string(keycode)
	if base == "":
		return ""
	var prefixes: Array[String] = []
	if event.ctrl_pressed:
		prefixes.append("Ctrl")
	if event.alt_pressed:
		prefixes.append("Alt")
	if event.shift_pressed:
		prefixes.append("Shift")
	if event.meta_pressed:
		prefixes.append("Meta")
	if prefixes.is_empty():
		return base
	return "+".join(prefixes) + "+" + base

func _is_modifier_free(event: InputEventKey) -> bool:
	return not event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed and not event.meta_pressed

func _update_last_input_device(event: InputEvent, input_type: InputType) -> void:
	var changed := false
	if _last_input_type != input_type:
		_last_input_type = input_type
		changed = true
	if input_type == InputType.KEYBOARD:
		if _last_joypad_device_id != -1:
			_last_joypad_device_id = -1
			_last_joypad_name = ""
			changed = true
	elif input_type == InputType.GAMEPAD:
		var next_device := -1
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			next_device = event.device
		if next_device != -1 and next_device != _last_joypad_device_id:
			_last_joypad_device_id = next_device
			_last_joypad_name = Input.get_joy_name(next_device)
			changed = true
	if changed:
		_label_cache_dirty = true

func format_prompt_text(text: String) -> String:
	var result := text
	result = result.replace("{MOVE}", get_action_label("MOVE"))
	result = result.replace("{JUMP}", get_action_label("JUMP"))
	result = result.replace("{ATTACK}", get_action_label("ATTACK"))
	result = result.replace("{INTERACT}", get_action_label("INTERACT"))
	result = result.replace("{RESET}", get_action_label("RESET"))
	return result

func get_input_label() -> String:
	return "Gamepad" if _last_input_type == InputType.GAMEPAD else "Keyboard"

func _set_player_movement(enabled: bool) -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)
