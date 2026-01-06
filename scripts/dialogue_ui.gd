extends Control

signal dialogue_started
signal dialogue_finished

@export var chars_per_second: float = 30.0

var _lines: Array[String] = []
var _line_index := 0
var _char_index := 0
var _active := false
var _elapsed := 0.0

@onready var label: Label = $Panel/Label

func _ready() -> void:
	hide()
	add_to_group("dialogue_ui")

func start_dialogue(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = 0
	_start_line()
	_active = true
	show()
	emit_signal("dialogue_started")

func _process(delta: float) -> void:
	if not _active:
		return
	if _char_index < _lines[_line_index].length():
		_elapsed += delta
		var chars_to_add := int(_elapsed * chars_per_second)
		if chars_to_add > 0:
			_elapsed = 0.0
			_char_index = min(_char_index + chars_to_add, _lines[_line_index].length())
			label.text = _lines[_line_index].substr(0, _char_index)

func can_advance() -> bool:
	return _active and _char_index >= _lines[_line_index].length()

func advance() -> void:
	if not can_advance():
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_end_dialogue()
	else:
		_start_line()

func _start_line() -> void:
	_char_index = 0
	_elapsed = 0.0
	label.text = ""

func _end_dialogue() -> void:
	_active = false
	hide()
	emit_signal("dialogue_finished")

func is_active() -> bool:
	return _active
