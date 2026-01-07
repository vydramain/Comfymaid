extends Node

@export var dialogue_ui_path: NodePath
@export var prompt_ui_path: NodePath
@export var overlay_ui_path: NodePath
@export var whiteout_ui_path: NodePath

signal ui_ready(dialogue_ui: Node, prompt_ui: Node, overlay_ui: Node, whiteout_ui: Node)

var _dialogue_ui: Node
var _prompt_ui: Node
var _overlay_ui: Node
var _whiteout_ui: Node
var _missing_reported := {}

func _ready() -> void:
	_resolve_ui()
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
