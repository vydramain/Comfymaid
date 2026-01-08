extends Node

@export var dialogue_ui_path: NodePath
@export var prompt_ui_path: NodePath
@export var overlay_ui_path: NodePath
@export var whiteout_ui_path: NodePath

signal dialogue_started
signal dialogue_finished
signal ui_ready(dialogue_ui: Node, prompt_ui: Node, overlay_ui: Node, whiteout_ui: Node)

var _dialogue_ui: Node
var _prompt_ui: Node
var _overlay_ui: Node
var _whiteout_ui: Node
var _missing_reported := {}
var _dialogue_connected := false
var _dialogue_source: Node

func _ready() -> void:
	_resolve_ui()
	_register_with_game_director()
	var tree := get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)

func request_ui_ready() -> void:
	_resolve_ui()

func _on_node_added(node: Node) -> void:
	if node == null:
		return
	if node.is_in_group("dialogue_ui") \
		or node.is_in_group("prompt_ui") \
		or node.is_in_group("overlay_ui") \
		or node.is_in_group("whiteout_ui"):
		_resolve_ui()

func _resolve_ui() -> void:
	var next_dialogue := _get_ui_node(dialogue_ui_path, "DialogueUI")
	var next_prompt := _get_ui_node(prompt_ui_path, "PromptUI")
	var next_overlay := _get_ui_node(overlay_ui_path, "OverlayLineUI")
	var next_whiteout := _get_ui_node(whiteout_ui_path, "WhiteoutUI")
	var changed := next_dialogue != _dialogue_ui \
		or next_prompt != _prompt_ui \
		or next_overlay != _overlay_ui \
		or next_whiteout != _whiteout_ui
	_dialogue_ui = next_dialogue
	_prompt_ui = next_prompt
	_overlay_ui = next_overlay
	_whiteout_ui = next_whiteout
	if changed:
		_refresh_dialogue_connections()
		ui_ready.emit(_dialogue_ui, _prompt_ui, _overlay_ui, _whiteout_ui)

func _get_ui_node(path: NodePath, label: String) -> Node:
	if path.is_empty():
		_report_missing(label, "<empty>")
		return null
	var node := get_node_or_null(path)
	if node == null:
		_report_missing(label, str(path))
	return node

func _report_missing(label: String, path: String) -> void:
	if _missing_reported.get(label, false):
		return
	_missing_reported[label] = true
	push_warning("UIManager: missing %s at path %s" % [label, path])

func _register_with_game_director() -> void:
	if GameDirector.instance == null:
		push_error("UIManager requires GameDirector autoload to be ready.")
		if OS.has_feature("debug"):
			assert(false, "GameDirector autoload missing for UIManager.")
		return
	if GameDirector.instance.has_method("set_ui_manager"):
		GameDirector.instance.set_ui_manager(self)

func _refresh_dialogue_connections() -> void:
	if _dialogue_ui == _dialogue_source and _dialogue_connected:
		return
	_disconnect_dialogue()
	_connect_dialogue()

func _connect_dialogue() -> void:
	if _dialogue_ui == null:
		return
	if _dialogue_ui.dialogue_started.is_connected(_on_dialogue_started):
		_dialogue_ui.dialogue_started.disconnect(_on_dialogue_started)
	if _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_ui.dialogue_finished.disconnect(_on_dialogue_finished)
	_dialogue_ui.dialogue_started.connect(_on_dialogue_started)
	_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	_dialogue_connected = true
	_dialogue_source = _dialogue_ui

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
	dialogue_started.emit()

func _on_dialogue_finished() -> void:
	dialogue_finished.emit()

func has_whiteout() -> bool:
	return _whiteout_ui != null and _whiteout_ui.has_method("fade_to_white")

func fade_to_white(duration: float) -> void:
	if _whiteout_ui and _whiteout_ui.has_method("fade_to_white"):
		await _whiteout_ui.fade_to_white(duration)

func fade_from_white(duration: float) -> void:
	if _whiteout_ui and _whiteout_ui.has_method("fade_from_white"):
		await _whiteout_ui.fade_from_white(duration)

func show_overlay_line(text: String) -> void:
	if _overlay_ui and _overlay_ui.has_method("show_line"):
		_overlay_ui.show_line(text)
