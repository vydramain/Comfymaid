extends Resource
class_name input_ui_config

@export var token_actions: Dictionary = {
	"MOVE": PackedStringArray(["move_left", "move_right"]),
	"JUMP": PackedStringArray(["jump"]),
	"ATTACK": PackedStringArray(["attack"]),
	"INTERACT": PackedStringArray(["interact"]),
	"RESET": PackedStringArray(["reset"]),
}
@export var keyboard_joiner: String = "/"
@export var gamepad_joiner: String = "/"
@export var gamepad_button_labels: Dictionary = {
	JoyButton.JOY_BUTTON_A: "A",
	JoyButton.JOY_BUTTON_X: "X",
	JoyButton.JOY_BUTTON_Y: "△",
	JoyButton.JOY_BUTTON_RIGHT_STICK: "R3",
}
@export var gamepad_axis_labels: Dictionary = {
	JoyAxis.JOY_AXIS_LEFT_X: "LS",
}

func get_gamepad_button_label(button_index: int) -> String:
	if gamepad_button_labels.has(button_index):
		return str(gamepad_button_labels[button_index])
	return Input.get_joy_button_string(button_index)

func get_gamepad_axis_label(axis: int) -> String:
	if gamepad_axis_labels.has(axis):
		return str(gamepad_axis_labels[axis])
	return Input.get_joy_axis_string(axis)
