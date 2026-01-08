extends Node

static var instance: Node

var dialogue_ui: Node
var prompt_ui: Node
var overlay_ui: Node
var whiteout_ui: Node

var _dialogue_connected := false
var _dialogue_source: Node
var _ui_manager: Node
var _ui_manager_connected := false

func _ready() -> void:
	instance = self
	_bind_ui_manager()
	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if instance == self:
		instance = null

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

func _on_ui_ready(next_dialogue: Node, next_prompt: Node, next_overlay: Node, next_whiteout: Node) -> void:
	var dialogue_changed := next_dialogue != dialogue_ui
	dialogue_ui = next_dialogue
	prompt_ui = next_prompt
	overlay_ui = next_overlay
	whiteout_ui = next_whiteout
	if dialogue_changed:
		_disconnect_dialogue()
		_connect_dialogue()

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

func _on_dialogue_started() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	if GameDirector.instance:
		if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
			GameDirector.instance.state = GameState.Phase.HUB_DIALOGUE
		else:
			GameDirector.instance.state = GameState.Phase.BOSS_FIGHT
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(true)

func _on_dialogue_finished() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(true)
	if GameDirector.instance:
		if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
			GameDirector.instance.state = GameState.Phase.HUB_FREE
		else:
			GameDirector.instance.state = GameState.Phase.BOSSROOM_FREE
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(false)

func _get_player() -> Node:
	if SceneManager.instance:
		return SceneManager.instance.player
	return null

func is_dialogue_active() -> bool:
	return dialogue_ui != null and dialogue_ui.has_method("is_active") and dialogue_ui.is_active()

func can_advance_dialogue() -> bool:
	return dialogue_ui != null and dialogue_ui.has_method("can_advance") and dialogue_ui.can_advance()

func advance_dialogue() -> void:
	if dialogue_ui and dialogue_ui.has_method("advance"):
		dialogue_ui.advance()

func start_dialogue(lines: Array[String]) -> void:
	if dialogue_ui and dialogue_ui.has_method("start_dialogue"):
		dialogue_ui.start_dialogue(lines)

func show_prompt(text: String, world_position: Vector2) -> void:
	if prompt_ui and prompt_ui.has_method("show_prompt"):
		prompt_ui.show_prompt(text, world_position)

func hide_prompt() -> void:
	if prompt_ui and prompt_ui.has_method("hide_prompt"):
		prompt_ui.hide_prompt()

func show_overlay_line(text: String) -> void:
	if overlay_ui and overlay_ui.has_method("show_line"):
		overlay_ui.show_line(text)

func fade_to_white(duration: float) -> void:
	if whiteout_ui and whiteout_ui.has_method("fade_to_white"):
		await whiteout_ui.fade_to_white(duration)

func fade_from_white(duration: float) -> void:
	if whiteout_ui and whiteout_ui.has_method("fade_from_white"):
		await whiteout_ui.fade_from_white(duration)
