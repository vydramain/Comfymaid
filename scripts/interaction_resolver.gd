extends Area2D

@export var prompt_offset := Vector2(0, -24)
@export_range(0.0, 0.5, 0.01) var stickiness_ratio := 0.1

var _interactables: Array[Area2D] = []
var _nearest: Area2D
var _last_prompt_target: Area2D
var _last_prompt_text := ""

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if UIController.instance and UIController.instance.is_dialogue_active():
		_clear_prompt()
		return
	_nearest = _find_nearest()
	if _nearest:
		_show_prompt(_nearest)
	else:
		_clear_prompt()

func _on_area_entered(area: Area2D) -> void:
	if not _is_valid_interactable(area):
		return
	_interactables.append(area)
	if not area.tree_exited.is_connected(_on_interactable_tree_exited):
		area.tree_exited.connect(_on_interactable_tree_exited.bind(area))

func _on_area_exited(area: Area2D) -> void:
	_interactables.erase(area)

func _on_interactable_tree_exited(area: Area2D) -> void:
	_interactables.erase(area)
	if area == _nearest:
		_nearest = null

func _is_valid_interactable(area: Area2D) -> bool:
	return area != null and area.is_in_group("interactable") and area.has_method("try_interact")

func _is_active_interactable(area: Area2D) -> bool:
	if not _is_valid_interactable(area):
		return false
	if area.has_method("is_enabled") and not area.is_enabled():
		return false
	return true

func _find_nearest() -> Area2D:
	var best: Area2D = null
	var best_dist := INF
	var invalids: Array[Area2D] = []
	for item in _interactables:
		if item == null or not is_instance_valid(item):
			invalids.append(item)
			continue
		if not _is_active_interactable(item):
			continue
		var dist := global_position.distance_to(item.global_position)
		if dist < best_dist or (is_equal_approx(dist, best_dist) and _is_better_tiebreak(item, best)):
			best_dist = dist
			best = item

	for item in invalids:
		_interactables.erase(item)

	if _nearest and is_instance_valid(_nearest) and _is_active_interactable(_nearest):
		var current_dist := global_position.distance_to(_nearest.global_position)
		if best == null:
			return _nearest
		if best != _nearest and current_dist <= 0.0:
			return _nearest
		if best != _nearest:
			var required_improvement := current_dist * (1.0 - stickiness_ratio)
			if best_dist >= required_improvement:
				return _nearest
	return best

func _is_better_tiebreak(candidate: Area2D, current: Area2D) -> bool:
	if current == null:
		return true
	return candidate.get_instance_id() < current.get_instance_id()

func _show_prompt(interactable: Area2D) -> void:
	if UIController.instance == null:
		return
	var text := "△ Interact"
	if interactable.has_method("get_prompt_text"):
		text = interactable.get_prompt_text()
	if interactable == _last_prompt_target and text == _last_prompt_text:
		return
	_last_prompt_target = interactable
	_last_prompt_text = text
	UIController.instance.show_prompt(text, interactable.global_position + prompt_offset)

func _clear_prompt() -> void:
	if UIController.instance == null:
		return
	if _last_prompt_target == null and _last_prompt_text == "":
		return
	_last_prompt_target = null
	_last_prompt_text = ""
	UIController.instance.hide_prompt()

func try_interact() -> void:
	var target := _find_nearest()
	if target and target.has_method("try_interact"):
		target.try_interact(get_parent())
