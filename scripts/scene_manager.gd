extends Node
class_name SceneManager

@export var initial_scene: StringName = "Hub"
@export var scenes: Dictionary = {
	"Hub": "res://scenes/Hub.tscn",
	"BossRoom": "res://scenes/BossRoom.tscn",
}
@export var player_scene: PackedScene = preload("res://scenes/Player.tscn")
@export var level_container_path: NodePath

var player: CharacterBody2D
var current_level: Node
var current_scene_name: StringName = ""
var current_spawn_name: StringName = "PlayerSpawn"

signal level_changed(scene_name: StringName)
signal player_spawned(player: Node)

static var instance: SceneManager

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if GameDirector.instance == null:
		push_error("SceneManager requires GameDirector autoload to be ready.")
		if OS.has_feature("debug"):
			assert(false, "GameDirector autoload missing for SceneManager.")
	else:
		if GameDirector.instance.has_method("set_scene_manager"):
			GameDirector.instance.set_scene_manager(self)
	load_level(initial_scene, current_spawn_name)

func load_level(scene_name: StringName, spawn_marker: StringName = "PlayerSpawn") -> void:
	if not scenes.has(scene_name):
		push_error("Scene '%s' not configured." % scene_name)
		return
	var path: String = String(scenes.get(scene_name, ""))
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Failed to load scene at %s" % path)
		return
	current_scene_name = scene_name
	current_spawn_name = spawn_marker
	var container := _resolve_level_container()
	if current_level and is_instance_valid(current_level):
		current_level.queue_free()
	current_level = packed.instantiate()
	container.add_child(current_level)
	_ensure_player_instance()
	_place_player(spawn_marker)
	emit_signal("level_changed", current_scene_name)

func _ensure_player_instance() -> void:
	if player and is_instance_valid(player):
		if player.get_parent():
			player.get_parent().remove_child(player)
	else:
		player = player_scene.instantiate()
	current_level.add_child(player)

func _place_player(spawn_marker: StringName) -> void:
	if player == null:
		return
	var spawn_point := _find_node_recursive(current_level, str(spawn_marker))
	if spawn_point:
		player.global_position = spawn_point.global_position
		if player.has_method("reset_state"):
			player.reset_state()
	else:
		push_warning("Spawn marker '%s' not found." % spawn_marker)
	emit_signal("player_spawned", player)

func _find_node_recursive(parent: Node, node_name: String) -> Node:
	if parent == null:
		return null
	if parent.name == node_name:
		return parent
	for child in parent.get_children():
		var result := _find_node_recursive(child, node_name)
		if result:
			return result
	return null

func _resolve_level_container() -> Node:
	if level_container_path != NodePath("") and has_node(level_container_path):
		return get_node(level_container_path)
	return get_parent()

func find_singleton_in_group(group_name: StringName, root: Node = null) -> Node:
	var search_root := root if root else current_level
	if search_root == null:
		return null
	var matches: Array[Node] = []
	_collect_group_nodes(search_root, group_name, matches)
	if matches.is_empty():
		push_warning("Group '%s' not found in current level." % group_name)
		return null
	if matches.size() > 1:
		push_error("Group '%s' has %d nodes in current level." % [group_name, matches.size()])
		if OS.has_feature("debug"):
			assert(false, "Expected singleton group '%s' in current level." % group_name)
	return matches[0]

func _collect_group_nodes(node: Node, group_name: StringName, results: Array[Node]) -> void:
	if node.is_in_group(group_name):
		results.append(node)
	for child in node.get_children():
		_collect_group_nodes(child, group_name, results)
