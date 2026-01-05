extends Node2D

var _enabled := false
var _broken := false

@onready var full_label: Label = $FullLabel
@onready var left_label: Label = $LeftLabel
@onready var right_label: Label = $RightLabel
@onready var hurt_area: Area2D = $HurtArea

func _ready() -> void:
    _set_visible(false)

func enable_word() -> void:
    if _broken:
        return
    _enabled = true
    _set_visible(true)

func _set_visible(visible_state: bool) -> void:
    full_label.visible = visible_state and not _broken
    left_label.visible = visible_state and _broken
    right_label.visible = visible_state and _broken
    hurt_area.monitoring = visible_state

func take_hit(_amount: int) -> void:
    if not _enabled or _broken:
        return
    _broken = true
    hurt_area.monitoring = false
    _split_visuals()
    if GameDirector.instance:
        GameDirector.instance.notify_mechanic_broken()

func _split_visuals() -> void:
    full_label.visible = false
    left_label.visible = true
    right_label.visible = true
    left_label.position += Vector2(-12, 0)
    right_label.position += Vector2(12, 0)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
    tween.tween_property(self, "scale", Vector2.ONE, 0.2)
