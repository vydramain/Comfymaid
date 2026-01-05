extends ColorRect

@export var fade_duration := 0.4

func _ready() -> void:
	color = Color(1, 1, 1, 0)
	hide()
	add_to_group("whiteout_ui")

func fade_to_white(duration: float = fade_duration) -> void:
	show()
	var tween := create_tween()
	tween.tween_property(self, "color", Color(1, 1, 1, 1), duration)
	await tween.finished

func fade_from_white(duration: float = fade_duration) -> void:
	var tween := create_tween()
	tween.tween_property(self, "color", Color(1, 1, 1, 0), duration)
	await tween.finished
	hide()
