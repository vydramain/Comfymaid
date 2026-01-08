extends Control

@onready var label: Label = $Label

func _ready() -> void:
    hide()
    add_to_group("prompt_ui")

func show_prompt(text: String, world_position: Vector2) -> void:
    if InputRouter.instance:
        label.text = InputRouter.instance.format_prompt_text(text)
    else:
        label.text = text
    var camera := get_viewport().get_camera_2d()
    var viewport_size := get_viewport_rect().size
    if camera:
        var center := camera.get_screen_center_position()
        var screen_pos := (world_position - center) * camera.zoom + viewport_size * 0.5
        position = screen_pos
    else:
        position = viewport_size * 0.5
    show()

func hide_prompt() -> void:
    hide()
