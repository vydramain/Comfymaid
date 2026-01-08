extends Camera2D

@export var deadzone_size := Vector2(120, 80)

var _bounds_rect := Rect2(Vector2.ZERO, Vector2(1024, 600))
var _hint_used := false

func _ready() -> void:
    if SceneManager.instance:
        SceneManager.instance.level_changed.connect(_on_level_changed)
    _update_bounds()

func _process(delta: float) -> void:
    if get_parent() == null:
        return
    var target_pos: Vector2 = global_position
    var player_pos: Vector2 = get_parent().global_position
    var left := target_pos.x - deadzone_size.x * 0.5
    var right := target_pos.x + deadzone_size.x * 0.5
    var top := target_pos.y - deadzone_size.y * 0.5
    var bottom := target_pos.y + deadzone_size.y * 0.5

    if player_pos.x < left:
        target_pos.x = player_pos.x + deadzone_size.x * 0.5
    elif player_pos.x > right:
        target_pos.x = player_pos.x - deadzone_size.x * 0.5
    if player_pos.y < top:
        target_pos.y = player_pos.y + deadzone_size.y * 0.5
    elif player_pos.y > bottom:
        target_pos.y = player_pos.y - deadzone_size.y * 0.5

    target_pos.x = clamp(target_pos.x, _bounds_rect.position.x + deadzone_size.x * 0.5, _bounds_rect.position.x + _bounds_rect.size.x - deadzone_size.x * 0.5)
    target_pos.y = clamp(target_pos.y, _bounds_rect.position.y + deadzone_size.y * 0.5, _bounds_rect.position.y + _bounds_rect.size.y - deadzone_size.y * 0.5)

    global_position = global_position.lerp(target_pos, 6.0 * delta)

func trigger_hint_up() -> void:
    if _hint_used:
        return
    _hint_used = true
    var original := global_position
    var tween := create_tween()
    tween.tween_property(self, "global_position", original + Vector2(0, -120), 0.6).set_trans(Tween.TRANS_SINE)
    tween.tween_interval(0.4)
    tween.tween_property(self, "global_position", original, 0.6).set_trans(Tween.TRANS_SINE)

func _on_level_changed(_scene_name: StringName) -> void:
    _hint_used = false
    await get_tree().process_frame
    _update_bounds()

func _update_bounds() -> void:
    var bounds := SceneManager.instance.find_singleton_in_group("CameraBounds") if SceneManager.instance else null
    if bounds and bounds.has_node("BoundsRect"):
        var rect_node := bounds.get_node("BoundsRect")
        if rect_node is ReferenceRect:
            var rect := rect_node as ReferenceRect
            _bounds_rect = Rect2(rect.global_position, rect.size)
