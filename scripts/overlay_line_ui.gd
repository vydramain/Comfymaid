extends Control

const OVERLAY_DISPLAY_TIME := 2.4
const OVERLAY_ANCHOR_TOP := 0.0
const OVERLAY_ANCHOR_BOTTOM := 0.2
const OVERLAY_LABEL_TOP := 0.2
const OVERLAY_LABEL_BOTTOM := 0.8
@export var display_time: float = OVERLAY_DISPLAY_TIME

@onready var label: Label = $Label

func _ready() -> void:
    anchor_top = OVERLAY_ANCHOR_TOP
    anchor_bottom = OVERLAY_ANCHOR_BOTTOM
    label.anchor_top = OVERLAY_LABEL_TOP
    label.anchor_bottom = OVERLAY_LABEL_BOTTOM
    hide()
    add_to_group("overlay_ui")

func show_line(text: String) -> void:
    label.text = text
    show()
    await get_tree().create_timer(display_time).timeout
    hide()
