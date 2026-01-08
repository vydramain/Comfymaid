extends CharacterBody2D

@export var config: player_config
@export var attack_hitbox_scene: PackedScene
@export var camera_path: NodePath = NodePath("Camera2D")

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _attack_timer := 0.0
var _attack_lock_timer := 0.0
var _attack_anim_timer := 0.0
var _facing := 1
var _movement_enabled := true
var _hp := 0
var _invuln := false
var _flicker_id := 0
var _base_modulate := Color(1, 1, 1)

var _bounds_rect := Rect2(Vector2.ZERO, Vector2(1024, 600))
var _hint_used := false
var _config: player_config
var _reset_hold_timer := 0.0
var _attack_hitbox: Area2D

@onready var visual: Node2D = $Visual
@onready var interaction_resolver: Area2D = $InteractionResolver
@onready var camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var hint_marker: Marker2D = $HintMarker
@onready var attack_marker: Marker2D = $AttackMarker
@onready var attack_hitbox_timer: Timer = $AttackHitboxTimer

func _ready() -> void:
	_config = config if config else player_config.new()
	add_to_group("player")
	_hp = _config.max_hp
	_base_modulate = visual.modulate
	if interaction_resolver:
		interaction_resolver.prompt_offset = _config.interact_prompt_offset
	if SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
	_setup_attack_hitbox()
	_setup_attack_hitbox_timer()
	_update_camera_bounds()

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_animation(delta)

func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity.x = move_toward(velocity.x, 0.0, _config.deceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if _attack_lock_timer > 0.0:
		_attack_lock_timer = max(_attack_lock_timer - delta, 0.0)
	_handle_input_buffering(delta)
	if _attack_lock_timer == 0.0:
		_handle_horizontal(delta)
	_apply_gravity(delta)
	_handle_jump()
	_apply_variable_jump()
	_handle_attack(delta)
	move_and_slide()
	_update_visual_flip()
	_handle_reset(delta)

func _handle_horizontal(delta: float) -> void:
	var input_axis := Input.get_axis("move_left", "move_right")
	if abs(input_axis) > 0.0:
		velocity.x = move_toward(velocity.x, input_axis * _config.max_speed, _config.acceleration * delta)
		_facing = 1 if input_axis > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, _config.deceleration * delta)

func _apply_gravity(delta: float) -> void:
	velocity.y += _config.gravity * delta
	if velocity.y > _config.max_fall_speed:
		velocity.y = _config.max_fall_speed

func _handle_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = _config.jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

func _apply_variable_jump() -> void:
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

func _handle_input_buffering(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = _config.jump_buffer_time
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	if is_on_floor():
		_coyote_timer = _config.coyote_time
	elif _coyote_timer > 0.0:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

func _handle_attack(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer = max(_attack_timer - delta, 0.0)
	if Input.is_action_just_pressed("attack") and _attack_timer == 0.0:
		_attack_timer = _config.attack_cooldown
		_attack_lock_timer = _config.attack_lock_time
		_attack_anim_timer = _config.attack_anim_duration
		_play_animation("attack")
		_spawn_attack_hitbox()

func _handle_reset(delta: float) -> void:
	if not _can_reset():
		_reset_hold_timer = 0.0
		return
	if Input.is_action_pressed("reset"):
		_reset_hold_timer += delta
		if _reset_hold_timer >= _config.reset_hold_time:
			_reset_hold_timer = 0.0
			GameDirector.instance.request_reset()
	else:
		_reset_hold_timer = 0.0

func _can_reset() -> bool:
	if GameDirector.instance == null:
		return false
	if not _config.allow_reset_in_release and not OS.has_feature("debug"):
		return false
	if GameDirector.instance.dialogue_ui and GameDirector.instance.dialogue_ui.has_method("is_active"):
		if GameDirector.instance.dialogue_ui.is_active():
			return false
	return true

func _spawn_attack_hitbox() -> void:
	_activate_attack_hitbox()

func _setup_attack_hitbox() -> void:
	if attack_hitbox_scene:
		_attack_hitbox = attack_hitbox_scene.instantiate()
	elif has_node("AttackHitbox"):
		_attack_hitbox = get_node("AttackHitbox")
	if _attack_hitbox == null:
		return
	if _attack_hitbox.get_parent() == null:
		if attack_marker:
			attack_marker.add_child(_attack_hitbox)
		else:
			add_child(_attack_hitbox)
	_attack_hitbox.monitoring = false
	_attack_hitbox.collision_layer = 0
	_attack_hitbox.collision_mask = 1
	if not _attack_hitbox.body_entered.is_connected(_on_attack_hit):
		_attack_hitbox.body_entered.connect(_on_attack_hit)
	if not _attack_hitbox.area_entered.is_connected(_on_attack_hit):
		_attack_hitbox.area_entered.connect(_on_attack_hit)

func _setup_attack_hitbox_timer() -> void:
	if attack_hitbox_timer == null:
		attack_hitbox_timer = Timer.new()
		attack_hitbox_timer.one_shot = true
		add_child(attack_hitbox_timer)
	if not attack_hitbox_timer.timeout.is_connected(_deactivate_attack_hitbox):
		attack_hitbox_timer.timeout.connect(_deactivate_attack_hitbox)

func _activate_attack_hitbox() -> void:
	if _attack_hitbox == null:
		return
	if attack_marker:
		attack_marker.scale.x = _facing
	else:
		_attack_hitbox.position.x = (_facing * (_config.width * 0.5 + _config.attack_radius * 0.1))
		_attack_hitbox.scale.x = _facing
	_attack_hitbox.monitoring = true
	if attack_hitbox_timer:
		attack_hitbox_timer.stop()
		attack_hitbox_timer.start(_config.attack_duration)

func _deactivate_attack_hitbox() -> void:
	if _attack_hitbox:
		_attack_hitbox.monitoring = false

func _on_attack_hit(target: Node) -> void:
	if target == self:
		return
	if target.has_method("take_hit"):
		target.take_hit(1)
	elif target.get_parent() and target.get_parent().has_method("take_hit"):
		target.get_parent().take_hit(1)

func _update_visual_flip() -> void:
	if visual == null:
		return
	visual.scale.x = 1 if _facing == 1 else -1

func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled

func take_hit(amount: int) -> void:
	if _invuln:
		return
	_hp = max(_hp - amount, 0)
	_start_invuln()
	if _hp <= 0 and GameDirector.instance:
		GameDirector.instance.request_death_reset()

func _start_invuln() -> void:
	_invuln = true
	_start_flicker()
	await get_tree().create_timer(_config.iframe_duration).timeout
	_invuln = false
	_stop_flicker()

func _start_flicker() -> void:
	if visual == null:
		return
	_flicker_id += 1
	var current_id := _flicker_id
	_flicker_loop(current_id)

func _flicker_loop(flicker_id: int) -> void:
	while _invuln and _flicker_id == flicker_id:
		visual.modulate = Color(1.6, 1.6, 1.6)
		await get_tree().create_timer(_config.hit_flash_interval).timeout
		if not _invuln or _flicker_id != flicker_id:
			break
		visual.modulate = _base_modulate
		await get_tree().create_timer(_config.hit_flash_interval).timeout

func _stop_flicker() -> void:
	if visual == null:
		return
	_flicker_id += 1
	visual.modulate = _base_modulate

func reset_state() -> void:
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_attack_timer = 0.0
	_attack_lock_timer = 0.0
	_attack_anim_timer = 0.0
	_movement_enabled = true
	_hp = _config.max_hp
	_invuln = false

func try_interact() -> void:
	if interaction_resolver and interaction_resolver.has_method("try_interact"):
		interaction_resolver.try_interact()

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target_pos: Vector2 = camera.global_position
	var player_pos: Vector2 = global_position
	var view_size := camera.get_viewport_rect().size / camera.zoom
	var deadzone := Vector2(
		max(view_size.x - _config.camera_edge_padding_x * 2.0, 0.0),
		max(view_size.y - _config.camera_edge_padding_y * 2.0, 0.0)
	)
	var left := target_pos.x - deadzone.x * 0.5
	var right := target_pos.x + deadzone.x * 0.5
	var top := target_pos.y - deadzone.y * 0.5
	var bottom := target_pos.y + deadzone.y * 0.5

	if player_pos.x < left:
		target_pos.x = player_pos.x + _config.camera_deadzone.x * 0.5
	elif player_pos.x > right:
		target_pos.x = player_pos.x - _config.camera_deadzone.x * 0.5
	if player_pos.y < top:
		target_pos.y = player_pos.y + _config.camera_deadzone.y * 0.5
	elif player_pos.y > bottom:
		target_pos.y = player_pos.y - _config.camera_deadzone.y * 0.5

	var view_half := view_size * 0.5
	var min_x := _bounds_rect.position.x + view_half.x
	var max_x := _bounds_rect.position.x + _bounds_rect.size.x - view_half.x
	var min_y := _bounds_rect.position.y + view_half.y
	var max_y := _bounds_rect.position.y + _bounds_rect.size.y - view_half.y
	if min_x > max_x:
		min_x = _bounds_rect.position.x + _bounds_rect.size.x * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = _bounds_rect.position.y + _bounds_rect.size.y * 0.5
		max_y = min_y
	target_pos.x = clamp(target_pos.x, min_x, max_x)
	target_pos.y = clamp(target_pos.y, min_y, max_y)

	camera.global_position = camera.global_position.lerp(target_pos, 6.0 * delta)

func _update_animation(delta: float) -> void:
	if sprite == null:
		return
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = max(_attack_anim_timer - delta, 0.0)
		if sprite.animation != "attack":
			_play_animation("attack")
		return
	if abs(velocity.x) > 5.0 and is_on_floor():
		_play_animation("run")
	else:
		_play_animation("idle")

func _play_animation(anim_name: StringName) -> void:
	if sprite == null or sprite.animation == anim_name:
		return
	sprite.play(anim_name)

func trigger_hint_up() -> void:
	if camera == null or _hint_used:
		return
	_hint_used = true
	var original := camera.global_position
	var tween := create_tween()
	tween.tween_property(camera, "global_position", original + _config.camera_hint_offset, _config.camera_hint_up_time).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(_config.camera_hint_hold)
	tween.tween_property(camera, "global_position", original, _config.camera_hint_down_time).set_trans(Tween.TRANS_SINE)

func _on_level_changed(_scene_name: StringName) -> void:
	_hint_used = false
	await get_tree().process_frame
	_update_camera_bounds()

func _update_camera_bounds() -> void:
	var bounds := SceneManager.instance.find_singleton_in_group("CameraBounds") if SceneManager.instance else null
	if bounds and bounds.has_node("BoundsRect"):
		var rect_node := bounds.get_node("BoundsRect")
		if rect_node is ReferenceRect:
			var rect := rect_node as ReferenceRect
			_bounds_rect = rect.get_global_rect()
