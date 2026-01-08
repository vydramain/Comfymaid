extends Area2D

@export var target_scene_name: StringName = "Hub"
@export var target_spawn_marker: StringName = "PlayerSpawn"

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    if GameDirector.instance and target_scene_name != "":
        GameDirector.instance.request_scene_change(target_scene_name, target_spawn_marker)
