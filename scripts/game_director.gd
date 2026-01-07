extends Node

enum GameState { HUB_FREE, HUB_DIALOGUE, TRANSITION, BOSSROOM_FREE, BOSS_FIGHT, RESET }

enum InputType { KEYBOARD, GAMEPAD }

static var instance: Node

const INPUT_TYPE_INVALID := -1
const INPUT_UI_CONFIG_PATH := "res://scripts/config/input_ui_config.tres"
const JOYPAD_DEADZONE := 0.2
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
var _last_input_type := InputType.KEYBOARD
var _input_handlers: Dictionary = {}
var _ui_config: input_ui_config

func _ready() -> void:
	instance = self
	_ui_config = load(INPUT_UI_CONFIG_PATH) as input_ui_config
	if _ui_config == null:
		_ui_config = input_ui_config.new()
	_setup_input_handlers()
	_resolve_ui()
	_connect_dialogue()
	if SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true

func _input(event: InputEvent) -> void:
	var handler: Callable = _input_handlers.get(event.get_class(), Callable()) as Callable
	var next: int = INPUT_TYPE_INVALID
	if handler.is_valid():
		next = handler.call(event)
	if next != INPUT_TYPE_INVALID:
		_last_input_type = next as InputType

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(_delta: float) -> void:
	if dialogue_ui == null or prompt_ui == null or overlay_ui == null or whiteout_ui == null:
		_resolve_ui()
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

func _resolve_ui() -> void:
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	prompt_ui = get_tree().get_first_node_in_group("prompt_ui")
	overlay_ui = get_tree().get_first_node_in_group("overlay_ui")
	whiteout_ui = get_tree().get_first_node_in_group("whiteout_ui")
	_connect_dialogue()

func _connect_dialogue() -> void:
	if _dialogue_connected or dialogue_ui == null:
		return
	dialogue_ui.dialogue_started.connect(_on_dialogue_started)
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	_dialogue_connected = true

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
		var root := SceneManager.instance.current_level if SceneManager.instance else null
		if root:
			var mechanic := root.get_node_or_null("MechanicWord")
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
	if _ui_config == null:
		return ""
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
	for event in InputMap.action_get_events(action_name):
		var label := _event_to_label(event, input_type)
		if label != "":
			return label
	return ""

func _event_to_label(event: InputEvent, input_type: InputType) -> String:
	if input_type == InputType.KEYBOARD and event is InputEventKey:
		return event.as_text()
	if input_type == InputType.GAMEPAD:
		if event is InputEventJoypadButton:
			return _ui_config.get_gamepad_button_label(event.button_index)
		if event is InputEventJoypadMotion:
			return _ui_config.get_gamepad_axis_label(event.axis)
	return ""

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
