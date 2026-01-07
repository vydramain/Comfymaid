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
@export var xbox_keywords: PackedStringArray = PackedStringArray(["Xbox", "XInput", "Microsoft"])
@export var playstation_keywords: PackedStringArray = PackedStringArray(["PlayStation", "DualSense", "DualShock", "Sony", "PS"])
@export var nintendo_keywords: PackedStringArray = PackedStringArray(["Nintendo", "Switch", "Pro Controller"])
@export var xbox_button_labels: Dictionary = {
	JoyButton.JOY_BUTTON_A: "A",
	JoyButton.JOY_BUTTON_B: "B",
	JoyButton.JOY_BUTTON_X: "X",
	JoyButton.JOY_BUTTON_Y: "Y",
	JoyButton.JOY_BUTTON_RIGHT_STICK: "R3",
}
@export var playstation_button_labels: Dictionary = {
	JoyButton.JOY_BUTTON_A: "Cross",
	JoyButton.JOY_BUTTON_B: "Circle",
	JoyButton.JOY_BUTTON_X: "Square",
	JoyButton.JOY_BUTTON_Y: "Triangle",
	JoyButton.JOY_BUTTON_RIGHT_STICK: "R3",
}
@export var nintendo_button_labels: Dictionary = {
	JoyButton.JOY_BUTTON_A: "B",
	JoyButton.JOY_BUTTON_B: "A",
	JoyButton.JOY_BUTTON_X: "Y",
	JoyButton.JOY_BUTTON_Y: "X",
	JoyButton.JOY_BUTTON_RIGHT_STICK: "R3",
}
@export var display_physical_keys := true
@export var label_cache_ttl := 0.4

func get_gamepad_button_label(button_index: int, device_name: String = "") -> String:
	var label := _get_layout_button_labels(device_name).get(button_index, "")
	if label != "":
		return str(label)
	label = gamepad_button_labels.get(button_index, "")
	if label != "":
		return str(label)
	var fallback := Input.get_joy_button_string(button_index)
	if fallback == "" or fallback.begins_with("Joypad Button"):
		return "Button %d" % button_index
	return fallback

func get_gamepad_axis_label(axis: int) -> String:
	if gamepad_axis_labels.has(axis):
		return str(gamepad_axis_labels[axis])
	return Input.get_joy_axis_string(axis)

func _get_layout_button_labels(device_name: String) -> Dictionary:
	var lower := device_name.to_lower()
	if _matches_keywords(lower, playstation_keywords):
		return playstation_button_labels
	if _matches_keywords(lower, nintendo_keywords):
		return nintendo_button_labels
	if _matches_keywords(lower, xbox_keywords):
		return xbox_button_labels
	return {}

func _matches_keywords(device_name: String, keywords: PackedStringArray) -> bool:
	for keyword in keywords:
		if device_name.find(keyword.to_lower()) != -1:
			return true
	return false
