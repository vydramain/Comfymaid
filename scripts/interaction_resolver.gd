extends Area2D

@export var prompt_offset := Vector2(0, -24)

var _interactables: Array[Area2D] = []
var _nearest: Area2D

func _ready() -> void:
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
    if GameDirector.instance and GameDirector.instance.dialogue_ui and GameDirector.instance.dialogue_ui.is_active():
        _clear_prompt()
        return
    _nearest = _find_nearest()
    if _nearest:
        _show_prompt(_nearest)
    else:
        _clear_prompt()

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("interactable"):
        _interactables.append(area)

func _on_area_exited(area: Area2D) -> void:
    _interactables.erase(area)

func _find_nearest() -> Area2D:
    var nearest: Area2D = null
    var best_dist := INF
    for item in _interactables:
        if item == null or not is_instance_valid(item):
            continue
        if item.has_method("is_enabled") and not item.is_enabled():
            continue
        var dist := global_position.distance_to(item.global_position)
        if dist < best_dist:
            best_dist = dist
            nearest = item
    return nearest

func _show_prompt(interactable: Area2D) -> void:
    if GameDirector.instance == null or GameDirector.instance.prompt_ui == null:
        return
    var text := "△ Interact"
    if interactable.has_method("get_prompt_text"):
        text = interactable.get_prompt_text()
    GameDirector.instance.prompt_ui.show_prompt(text, interactable.global_position + prompt_offset)

func _clear_prompt() -> void:
    if GameDirector.instance == null or GameDirector.instance.prompt_ui == null:
        return
    GameDirector.instance.prompt_ui.hide_prompt()

func try_interact() -> void:
    if _nearest and _nearest.has_method("interact"):
        _nearest.interact(get_parent())
