extends Control

@onready var label: Label = $Label

func _ready() -> void:
    hide()
    add_to_group("prompt_ui")

func show_prompt(text: String, world_position: Vector2) -> void:
    if GameDirector.instance:
        label.text = GameDirector.instance.format_prompt_text(text)
    else:
        label.text = text
    var camera := get_viewport().get_camera_2d()
    var viewport_size := get_viewport_rect().size
    if camera:
        var screen_pos := world_position - camera.global_position + viewport_size * 0.5
        position = screen_pos
    else:
        position = viewport_size * 0.5
    show()

func hide_prompt() -> void:
    hide()
