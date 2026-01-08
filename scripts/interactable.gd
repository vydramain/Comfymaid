extends Area2D

@export var prompt_text := "{INTERACT} Interact"
@export var interaction_type := "generic"
@export var target_scene: StringName = ""
@export var spawn_marker: StringName = "PlayerSpawn"
@export var requires_guardian_intro := false
@export var forward_to_parent := false
@export var enabled := true
@export var open_texture: Texture2D
@export var closed_texture: Texture2D

signal interacted(interactor: Node)

var _sprite: Sprite2D
var _last_open_state := false

func _ready() -> void:
    setup_interactable()

func setup_interactable() -> void:
    add_to_group("interactable")
    _sprite = get_node_or_null("Sprite2D") as Sprite2D
    if _sprite and closed_texture == null:
        closed_texture = _sprite.texture
    _last_open_state = not is_enabled()
    _sync_visuals()

func _process(_delta: float) -> void:
    if interaction_type != "door" or _sprite == null:
        return
    _sync_visuals()

func is_enabled() -> bool:
    if not enabled:
        return false
    if interaction_type == "door" and requires_guardian_intro:
        if GameDirector.instance and not GameDirector.instance.guardian_intro_done:
            return false
    return true

func get_prompt_text() -> String:
    return prompt_text

func try_interact(interactor: Node) -> void:
    if not is_enabled():
        return
    interact(interactor)

func interact(interactor: Node) -> void:
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

func _sync_visuals() -> void:
    if _sprite == null or (open_texture == null and closed_texture == null):
        return
    var open_state := is_enabled()
    if _last_open_state == open_state:
        return
    var desired := open_texture if open_state else closed_texture
    if desired != null and _sprite.texture != desired:
        _sprite.texture = desired
    _last_open_state = open_state
