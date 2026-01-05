extends Node

enum GameState { HUB_FREE, HUB_DIALOGUE, TRANSITION, BOSSROOM_FREE, BOSS_FIGHT, RESET }

static var instance: Node

var mechanic_broken := false
var boss_defeated := false
var boss_revived_once := false
var guardian_intro_done := false
var guardian_post_dialogue_done := false
var world_reset_count := 0

var state: GameState = GameState.HUB_FREE

var dialogue_ui: Node
var prompt_ui: Node
var overlay_ui: Node
var whiteout_ui: Node
var _scene_manager_connected := false
var _dialogue_connected := false

func _ready() -> void:
	instance = self
	_configure_input_map()
	_resolve_ui()
	_connect_dialogue()
	if SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true

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
	if AudioDirector.instance:
		AudioDirector.instance.fade_out_current_ambient()
		AudioDirector.instance.prepare_transition_silence()
	await whiteout_ui.fade_to_white(0.4)
	if AudioDirector.instance:
		var wait_time: float = AudioDirector.instance.get_time_to_next_bar()
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout
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
	await request_scene_change("Hub", "PlayerSpawn")

func _reset_run_flags() -> void:
	mechanic_broken = false
	boss_defeated = false
	boss_revived_once = false
	guardian_intro_done = false
	guardian_post_dialogue_done = false

func notify_boss_revive() -> void:
	if not boss_revived_once:
		boss_revived_once = true
		if overlay_ui and overlay_ui.has_method("show_line"):
			overlay_ui.show_line("Советы по игре будут?")

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

func _configure_input_map() -> void:
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("jump")
	_ensure_action("attack")
	_ensure_action("interact")
	_ensure_action("reset")

	_add_key("move_left", Key.KEY_A)
	_add_key("move_left", Key.KEY_LEFT)
	_add_key("move_right", Key.KEY_D)
	_add_key("move_right", Key.KEY_RIGHT)
	_add_key("jump", Key.KEY_SPACE)
	_add_key("attack", Key.KEY_J)
	_add_key("interact", Key.KEY_K)
	_add_key("reset", Key.KEY_R)

	_add_joy_button("jump", JoyButton.JOY_BUTTON_A)
	_add_joy_button("attack", JoyButton.JOY_BUTTON_X)
	_add_joy_button("interact", JoyButton.JOY_BUTTON_Y)

	_add_joy_motion("move_left", JoyAxis.JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("move_right", JoyAxis.JOY_AXIS_LEFT_X, 1.0)

func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _add_key(action_name: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	if not _has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _add_joy_button(action_name: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if not _has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _add_joy_motion(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	if not _has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _has_event(action_name: StringName, event: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and event is InputEventKey:
			if existing.keycode == event.keycode:
				return true
		elif existing is InputEventJoypadButton and event is InputEventJoypadButton:
			if existing.button_index == event.button_index:
				return true
		elif existing is InputEventJoypadMotion and event is InputEventJoypadMotion:
			if existing.axis == event.axis and existing.axis_value == event.axis_value:
				return true
	return false

func _set_player_movement(enabled: bool) -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)
