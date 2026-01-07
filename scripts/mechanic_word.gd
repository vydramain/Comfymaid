extends Node2D

var _enabled := false
var _broken := false

@export var start_visible := false
@export var enable_on_boss_revive := true

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
	left_label.visible = true
	right_label.visible = true
	if backdrop:
		backdrop.visible = true
	left_label.position += Vector2(-12, 0)
	right_label.position += Vector2(12, 0)
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
