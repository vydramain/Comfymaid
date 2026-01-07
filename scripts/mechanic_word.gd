extends Node2D

var _enabled := false
var _broken := false

@export var start_visible := false
@export var enable_on_boss_revive := true
@export var chunk_gravity_scale := 1.2
@export var chunk_impulse := Vector2(120, -220)
@export var chunk_torque := 10.0
@export var chunk_linear_damp := 0.6
@export var chunk_angular_damp := 0.9

@onready var full_label: Label = $FullLabel
@onready var left_label: Label = $LeftLabel
@onready var right_label: Label = $RightLabel
@onready var hurt_area: Area2D = $HurtArea
@onready var backdrop: ColorRect = $Backdrop

func _ready() -> void:
	_configure_hurt_area()
	if hurt_area:
		hurt_area.body_entered.connect(_on_hurt_body_entered)
		hurt_area.area_entered.connect(_on_hurt_area_entered)
	if GameDirector.instance and GameDirector.instance.mechanic_broken:
		_apply_broken_state()
	elif start_visible:
		enable_word()
	else:
		_set_visible(false)

func _process(_delta: float) -> void:
	if _enabled or _broken:
		return
	if enable_on_boss_revive and GameDirector.instance and GameDirector.instance.boss_revived_once:
		enable_word()

func enable_word() -> void:
	if _broken:
		return
	_enabled = true
	visible = true
	modulate = Color(1, 1, 1)
	_set_visible(true)
	_pulse_visible()

func _set_visible(visible_state: bool) -> void:
	full_label.visible = visible_state and not _broken
	left_label.visible = visible_state and _broken
	right_label.visible = visible_state and _broken
	hurt_area.monitoring = visible_state
	hurt_area.monitorable = true
	visible = visible_state
	if backdrop:
		backdrop.visible = visible_state

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
	if backdrop:
		backdrop.visible = true
	_spawn_chunk(left_label, Vector2(-chunk_impulse.x, chunk_impulse.y), -chunk_torque)
	_spawn_chunk(right_label, Vector2(chunk_impulse.x, chunk_impulse.y), chunk_torque)
	left_label.visible = false
	right_label.visible = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	_flash_break()

func _apply_broken_state() -> void:
	_enabled = true
	_broken = true
	full_label.visible = false
	left_label.visible = true
	right_label.visible = true
	hurt_area.monitoring = false
	hurt_area.monitorable = true
	if backdrop:
		backdrop.visible = true
	left_label.position = Vector2(-12, 0)
	right_label.position = Vector2(12, 0)

func _configure_hurt_area() -> void:
	hurt_area.collision_layer = 1
	hurt_area.collision_mask = 0

func _on_hurt_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		take_hit(1)

func _on_hurt_area_entered(area: Area2D) -> void:
	if area and area.get_parent() and area.get_parent().is_in_group("player"):
		take_hit(1)

func _pulse_visible() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.4), 0.08)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.12)

func _flash_break() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.6, 1.6), 0.06)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.12)

func _spawn_chunk(label: Label, impulse: Vector2, torque: float) -> void:
	if label == null:
		return
	var parent_node := get_parent() if get_parent() else self
	var global_pos := label.global_position
	var chunk := RigidBody2D.new()
	chunk.gravity_scale = chunk_gravity_scale
	chunk.linear_damp = chunk_linear_damp
	chunk.angular_damp = chunk_angular_damp
	chunk.collision_layer = 1
	chunk.collision_mask = 1
	parent_node.add_child(chunk)
	chunk.global_position = global_pos
	chunk.rotation = 0.0
	var label_copy := label.duplicate()
	if label_copy is Label:
		(label_copy as Label).text = label.text
		(label_copy as Label).theme = label.theme
	_prepare_label_for_chunk(label_copy)
	label_copy.visible = true
	chunk.add_child(label_copy)
	var shape := RectangleShape2D.new()
	var size := label.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = label.get_minimum_size()
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(80, 36)
	label_copy.size = size
	label_copy.custom_minimum_size = size
	label_copy.position = Vector2.ZERO
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = size * 0.5
	chunk.add_child(collider)
	chunk.apply_impulse(impulse)
	chunk.apply_torque_impulse(torque)

func _prepare_label_for_chunk(label: Label) -> void:
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 0.0
	label.anchor_bottom = 0.0
	label.position = Vector2.ZERO
	label.rotation = 0.0
