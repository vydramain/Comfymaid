extends CharacterBody2D

const PLAYER_WIDTH := 16.0
const PLAYER_HEIGHT := 32.0
const PLAYER_MAX_SPEED := 240.0
const PLAYER_ACCELERATION := 2000.0
const PLAYER_DECELERATION := 2500.0
const PLAYER_GRAVITY := 1400.0
const PLAYER_JUMP_VELOCITY := -480.0
const PLAYER_COYOTE_TIME := 0.12
const PLAYER_JUMP_BUFFER_TIME := 0.12
const PLAYER_MAX_FALL_SPEED := 900.0
const PLAYER_ATTACK_COOLDOWN := 0.35
const PLAYER_ATTACK_DURATION := 0.12
const PLAYER_ATTACK_RADIUS := 28.0
const PLAYER_ATTACK_LOCK_TIME := 0.08
const PLAYER_IFRAME_DURATION := 0.4
const PLAYER_HIT_FLASH_TIME := 0.15
const PLAYER_MAX_HP := 3

const CAMERA_DEADZONE := Vector2(120, 80)
const CAMERA_HINT_OFFSET := Vector2(0, -120)
const CAMERA_HINT_UP_TIME := 0.6
const CAMERA_HINT_HOLD := 0.4
const CAMERA_HINT_DOWN_TIME := 0.6

const INTERACT_PROMPT_OFFSET := Vector2(0, -24)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _attack_timer := 0.0
var _attack_lock_timer := 0.0
var _facing := 1
var _movement_enabled := true
var _hp := PLAYER_MAX_HP
var _invuln := false

var _interactables: Array[Area2D] = []
var _nearest: Area2D

var _bounds_rect := Rect2(Vector2.ZERO, Vector2(1024, 600))
var _hint_used := false

@onready var visual: Node2D = $Visual
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	_hp = PLAYER_MAX_HP
	if interaction_detector:
		interaction_detector.area_entered.connect(_on_area_entered)
		interaction_detector.area_exited.connect(_on_area_exited)
	if SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
	_update_camera_bounds()

func _process(delta: float) -> void:
	_update_interaction_prompt()
	_update_camera(delta)

func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity.x = move_toward(velocity.x, 0.0, PLAYER_DECELERATION * delta)
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
	if Input.is_action_just_pressed("reset") and GameDirector.instance:
		GameDirector.instance.request_reset()

func _handle_horizontal(delta: float) -> void:
	var input_axis := Input.get_axis("move_left", "move_right")
	if abs(input_axis) > 0.0:
		velocity.x = move_toward(velocity.x, input_axis * PLAYER_MAX_SPEED, PLAYER_ACCELERATION * delta)
		_facing = 1 if input_axis > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, PLAYER_DECELERATION * delta)

func _apply_gravity(delta: float) -> void:
	velocity.y += PLAYER_GRAVITY * delta
	if velocity.y > PLAYER_MAX_FALL_SPEED:
		velocity.y = PLAYER_MAX_FALL_SPEED

func _handle_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = PLAYER_JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

func _apply_variable_jump() -> void:
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

func _handle_input_buffering(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = PLAYER_JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	if is_on_floor():
		_coyote_timer = PLAYER_COYOTE_TIME
	elif _coyote_timer > 0.0:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

func _handle_attack(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer = max(_attack_timer - delta, 0.0)
	if Input.is_action_just_pressed("attack") and _attack_timer == 0.0:
		_attack_timer = PLAYER_ATTACK_COOLDOWN
		_attack_lock_timer = PLAYER_ATTACK_LOCK_TIME
		_spawn_attack_hitbox()

func _spawn_attack_hitbox() -> void:
	var hitbox := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_ATTACK_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)
	hitbox.position = Vector2(PLAYER_ATTACK_RADIUS * _facing, -4)
	hitbox.monitoring = true
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	add_child(hitbox)
	hitbox.body_entered.connect(_on_attack_hit)
	hitbox.area_entered.connect(_on_attack_hit)
	get_tree().create_timer(PLAYER_ATTACK_DURATION).timeout.connect(hitbox.queue_free)

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
	_flash_white()
	_start_invuln()
	if _hp <= 0 and GameDirector.instance:
		GameDirector.instance.request_death_reset()

func _flash_white() -> void:
	if visual == null:
		return
	visual.modulate = Color(1.6, 1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(1, 1, 1), PLAYER_HIT_FLASH_TIME)

func _start_invuln() -> void:
	_invuln = true
	await get_tree().create_timer(PLAYER_IFRAME_DURATION).timeout
	_invuln = false

func reset_state() -> void:
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_attack_timer = 0.0
	_attack_lock_timer = 0.0
	_movement_enabled = true
	_hp = PLAYER_MAX_HP
	_invuln = false

func try_interact() -> void:
	if _nearest and _nearest.has_method("interact"):
		_nearest.interact(self)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		_interactables.append(area)

func _on_area_exited(area: Area2D) -> void:
	_interactables.erase(area)

func _find_nearest() -> Area2D:
	var nearest: Area2D = null
	var best_dist := INF
	for item in _interactables:
		if item == null or not is_instance_valid(item):
			continue
		if item.has_method("is_enabled") and not item.is_enabled():
			continue
		var dist := global_position.distance_to(item.global_position)
		if dist < best_dist:
			best_dist = dist
			nearest = item
	return nearest

func _update_interaction_prompt() -> void:
	if GameDirector.instance and GameDirector.instance.dialogue_ui and GameDirector.instance.dialogue_ui.is_active():
		_clear_prompt()
		return
	_nearest = _find_nearest()
	if _nearest:
		_show_prompt(_nearest)
	else:
		_clear_prompt()

func _show_prompt(interactable: Area2D) -> void:
	if GameDirector.instance == null or GameDirector.instance.prompt_ui == null:
		return
	var text := "△ Interact"
	if interactable.has_method("get_prompt_text"):
		text = interactable.get_prompt_text()
	GameDirector.instance.prompt_ui.show_prompt(text, interactable.global_position + INTERACT_PROMPT_OFFSET)

func _clear_prompt() -> void:
	if GameDirector.instance == null or GameDirector.instance.prompt_ui == null:
		return
	GameDirector.instance.prompt_ui.hide_prompt()

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target_pos: Vector2 = camera.global_position
	var player_pos: Vector2 = global_position
	var left := target_pos.x - CAMERA_DEADZONE.x * 0.5
	var right := target_pos.x + CAMERA_DEADZONE.x * 0.5
	var top := target_pos.y - CAMERA_DEADZONE.y * 0.5
	var bottom := target_pos.y + CAMERA_DEADZONE.y * 0.5

	if player_pos.x < left:
		target_pos.x = player_pos.x + CAMERA_DEADZONE.x * 0.5
	elif player_pos.x > right:
		target_pos.x = player_pos.x - CAMERA_DEADZONE.x * 0.5
	if player_pos.y < top:
		target_pos.y = player_pos.y + CAMERA_DEADZONE.y * 0.5
	elif player_pos.y > bottom:
		target_pos.y = player_pos.y - CAMERA_DEADZONE.y * 0.5

	target_pos.x = clamp(target_pos.x, _bounds_rect.position.x + CAMERA_DEADZONE.x * 0.5, _bounds_rect.position.x + _bounds_rect.size.x - CAMERA_DEADZONE.x * 0.5)
	target_pos.y = clamp(target_pos.y, _bounds_rect.position.y + CAMERA_DEADZONE.y * 0.5, _bounds_rect.position.y + _bounds_rect.size.y - CAMERA_DEADZONE.y * 0.5)

	camera.global_position = camera.global_position.lerp(target_pos, 6.0 * delta)

func trigger_hint_up() -> void:
	if camera == null or _hint_used:
		return
	_hint_used = true
	var original := camera.global_position
	var tween := create_tween()
	tween.tween_property(camera, "global_position", original + CAMERA_HINT_OFFSET, CAMERA_HINT_UP_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(CAMERA_HINT_HOLD)
	tween.tween_property(camera, "global_position", original, CAMERA_HINT_DOWN_TIME).set_trans(Tween.TRANS_SINE)

func _on_level_changed(_scene_name: StringName) -> void:
	_hint_used = false
	await get_tree().process_frame
	_update_camera_bounds()

func _update_camera_bounds() -> void:
	var root := SceneManager.instance.current_level if SceneManager.instance else null
	if root == null:
		return
	var bounds := root.get_node_or_null("CameraBounds")
	if bounds and bounds.has_node("BoundsRect"):
		var rect_node := bounds.get_node("BoundsRect")
		if rect_node is ReferenceRect:
			var rect := rect_node as ReferenceRect
			_bounds_rect = Rect2(rect.global_position, rect.size)
