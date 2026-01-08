extends Area2D

@export var target_scene_name: StringName = "Hub"
@export var target_spawn_marker: StringName = "PlayerSpawn"

var _triggered := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    if _triggered:
        return
    _triggered = true
    if GameDirector.instance == null:
        push_error("Door requires GameDirector instance for scene transitions.")
        return
    if target_scene_name == "":
        push_error("Door target_scene_name is empty.")
        return
    GameDirector.instance.request_scene_change(target_scene_name, target_spawn_marker)
