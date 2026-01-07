extends CharacterBody2D

const BOSS_MAX_HP := 5
const BOSS_GRAVITY := 1400.0
const BOSS_MAX_FALL_SPEED := 900.0
const BOSS_IFRAME_DURATION := 0.3
const BOSS_HIT_FLASH_INTERVAL := 0.08
const BOSS_INVALID_DEATH_SHRINK_TIME := 0.3
const BOSS_INVALID_DEATH_PAUSE := 0.5
const BOSS_FINAL_DEATH_FADE_TIME := 0.4

@export var ai_enabled := true
@export var move_speed := 45.0
@export var acceleration := 800.0
@export var stop_distance := 12.0
@export var smoke_offset_x := 12.0
@export var smoke_push_distance := 10.0
@export var smoke_push_time := 0.15
@export var smoke_follow_time := 0.2
@export var debug_boss := false
@export var smoke_scene: PackedScene

var _hp := BOSS_MAX_HP
var _invuln := false
var _reviving := false
var _facing := -1
var _flicker_id := 0
var _base_modulate := Color(1, 1, 1)

@onready var damage_area: Area2D = $DamageArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite
@onready var left_foot: Marker2D = $VisualRoot/FootMarkers/LeftFootMarker
@onready var right_foot: Marker2D = $VisualRoot/FootMarkers/RightFootMarker
@onready var smoke_left: Marker2D = $VisualRoot/SmokeEmitters/SmokeEmitterLeft
@onready var smoke_right: Marker2D = $VisualRoot/SmokeEmitters/SmokeEmitterRight

func _ready() -> void:
	_hp = BOSS_MAX_HP
	if damage_area:
		damage_area.body_entered.connect(_on_damage_body)
	if sprite:
		_base_modulate = sprite.modulate
	_play_animation("idle")

func _physics_process(delta: float) -> void:
	_update_ai(delta)
	_apply_gravity(delta)
	move_and_slide()

func _update_ai(delta: float) -> void:
	var can_move := ai_enabled and not _reviving and not _is_defeated()
	var player := SceneManager.instance.player if SceneManager.instance else null
	if can_move and player:
		var to_player := player.global_position - global_position
		var dir_x: float = sign(to_player.x)
		if abs(to_player.x) <= stop_distance:
			dir_x = 0.0
		if dir_x != 0.0:
			_facing = int(dir_x)
		var target_speed := float(dir_x) * move_speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		_update_animation(abs(velocity.x) > 1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		_update_animation(false)

func _apply_gravity(delta: float) -> void:
	velocity.y += BOSS_GRAVITY * delta
	if velocity.y > BOSS_MAX_FALL_SPEED:
		velocity.y = BOSS_MAX_FALL_SPEED

func _update_animation(moving: bool) -> void:
	if anim_player == null:
		return
	if moving:
		_play_animation("walk")
	else:
		_play_animation("idle")

func _play_animation(anim_name: StringName) -> void:
	if anim_player == null:
		return
	if anim_player.current_animation == anim_name:
		return
	anim_player.play(anim_name)
	_update_facing_visual()

func _update_facing_visual() -> void:
	if sprite == null:
		return
	sprite.scale.x = 1 if _facing >= 0 else -1

func _is_defeated() -> bool:
	return GameDirector.instance != null and GameDirector.instance.boss_defeated

func take_hit(amount: int) -> void:
	if _invuln or _reviving:
		return
	_hp = max(_hp - amount, 0)
	if _hp <= 0:
		_start_flicker()
		_handle_death()
	else:
		_start_invuln()

func _handle_death() -> void:
	if GameDirector.instance == null:
		return
	if GameDirector.instance.mechanic_broken:
		_final_death()
	else:
		_invalid_death()

func _invalid_death() -> void:
	_reviving = true
	_invuln = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 0.7), BOSS_INVALID_DEATH_SHRINK_TIME)
	tween.tween_interval(BOSS_INVALID_DEATH_PAUSE)
	await tween.finished
	_hp = BOSS_MAX_HP
	scale = Vector2.ONE
	_reviving = false
	_invuln = false
	_stop_flicker()
	if sprite:
		sprite.modulate = _base_modulate
	GameDirector.instance.notify_boss_revive()
	_enable_mechanic_word()
	_trigger_camera_hint()

func _final_death() -> void:
	_reviving = true
	_invuln = true
	_stop_flicker()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.4, 0.4, 0.4), BOSS_FINAL_DEATH_FADE_TIME)
	await tween.finished
	if AudioDirector.instance:
		AudioDirector.instance.stop_boss_music()
	GameDirector.instance.notify_boss_defeated()

func _enable_mechanic_word() -> void:
	var root := SceneManager.instance.current_level if SceneManager.instance else null
	if root:
		var mechanic := root.get_node_or_null("MechanicWord")
		if mechanic and mechanic.has_method("enable_word"):
			mechanic.enable_word()

func _trigger_camera_hint() -> void:
	if SceneManager.instance and SceneManager.instance.player:
		var player := SceneManager.instance.player
		if player and player.has_method("trigger_hint_up"):
			player.trigger_hint_up()

func _start_invuln() -> void:
	_invuln = true
	_start_flicker()
	await get_tree().create_timer(BOSS_IFRAME_DURATION).timeout
	_invuln = false
	_stop_flicker()

func _start_flicker() -> void:
	if sprite == null:
		return
	_flicker_id += 1
	var current_id := _flicker_id
	_flicker_loop(current_id)

func _flicker_loop(flicker_id: int) -> void:
	while _invuln and _flicker_id == flicker_id:
		sprite.modulate = Color(1.6, 1.6, 1.6)
		await get_tree().create_timer(BOSS_HIT_FLASH_INTERVAL).timeout
		if not _invuln or _flicker_id != flicker_id:
			break
		sprite.modulate = _base_modulate
		await get_tree().create_timer(BOSS_HIT_FLASH_INTERVAL).timeout

func _stop_flicker() -> void:
	if sprite == null:
		return
	_flicker_id += 1
	sprite.modulate = _base_modulate

func _on_damage_body(body: Node) -> void:
	if body and body.has_method("take_hit") and body.is_in_group("player"):
		body.take_hit(1)

func spawn_smoke_step(side: StringName) -> void:
	if side == &"left":
		_spawn_smoke(smoke_left)
	elif side == &"right":
		_spawn_smoke(smoke_right)

func spawn_smoke_left() -> void:
	spawn_smoke_step(&"left")

func spawn_smoke_right() -> void:
	spawn_smoke_step(&"right")

func _spawn_smoke(marker: Marker2D) -> void:
	if smoke_scene == null or marker == null:
		return
	if not ai_enabled or _reviving or _is_defeated():
		return
	var smoke := smoke_scene.instantiate()
	var root := SceneManager.instance.current_level if SceneManager.instance else get_parent()
	var emitter_parent := marker
	if emitter_parent and smoke is Node2D:
		emitter_parent.add_child(smoke)
		var spawn_pos := marker.global_position
		var dir := 1 if spawn_pos.x >= global_position.x else -1
		spawn_pos.x += smoke_offset_x * dir
		(smoke as Node2D).global_position = spawn_pos
		if smoke.has_method("set_direction"):
			smoke.set_direction(dir, smoke_push_distance, smoke_push_time)
		if smoke.has_method("set_follow_root") and root:
			smoke.set_follow_root(root, smoke_follow_time)
	if debug_boss:
		print("Boss smoke at ", marker.global_position)
