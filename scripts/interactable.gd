extends Area2D

@export var prompt_text := "{INTERACT} Interact"
@export var interaction_type := "generic"
@export var target_scene: StringName = ""
@export var spawn_marker: StringName = "PlayerSpawn"
@export var requires_guardian_intro := false
@export var forward_to_parent := false
@export var enabled := true

signal interacted(interactor: Node)

func _ready() -> void:
    add_to_group("interactable")

func is_enabled() -> bool:
    return enabled

func get_prompt_text() -> String:
    return prompt_text

func interact(interactor: Node) -> void:
    if not enabled:
        return
    if forward_to_parent and get_parent() and get_parent().has_method("interact"):
        get_parent().interact(interactor)
        return
    emit_signal("interacted", interactor)
    if interaction_type == "door":
        if requires_guardian_intro and GameDirector.instance and not GameDirector.instance.guardian_intro_done:
            return
        if GameDirector.instance:
            GameDirector.instance.request_scene_change(target_scene, spawn_marker)
    elif interaction_type == "reset":
        if GameDirector.instance:
            GameDirector.instance.request_reset()
