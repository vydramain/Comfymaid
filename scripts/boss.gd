extends CharacterBody2D

const BOSS_MAX_HP := 5
const BOSS_GRAVITY := 1400.0
const BOSS_MAX_FALL_SPEED := 900.0
const BOSS_IFRAME_DURATION := 0.3
const BOSS_INVALID_DEATH_SHRINK_TIME := 0.3
const BOSS_INVALID_DEATH_PAUSE := 0.5
const BOSS_FINAL_DEATH_FADE_TIME := 0.4

var _hp := BOSS_MAX_HP
var _invuln := false
var _reviving := false

@onready var visual: Node2D = $Visual
@onready var damage_area: Area2D = $DamageArea

func _ready() -> void:
	_hp = BOSS_MAX_HP
	if damage_area:
		damage_area.body_entered.connect(_on_damage_body)

func _physics_process(delta: float) -> void:
	velocity.y += BOSS_GRAVITY * delta
	if velocity.y > BOSS_MAX_FALL_SPEED:
		velocity.y = BOSS_MAX_FALL_SPEED
	move_and_slide()

func take_hit(amount: int) -> void:
	if _invuln or _reviving:
		return
	_hp = max(_hp - amount, 0)
	_flash_white()
	if _hp <= 0:
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
	tween.tween_property(visual, "scale", Vector2(0.7, 0.7), BOSS_INVALID_DEATH_SHRINK_TIME)
	tween.tween_interval(BOSS_INVALID_DEATH_PAUSE)
	await tween.finished
	_hp = BOSS_MAX_HP
	visual.scale = Vector2.ONE
	_reviving = false
	_invuln = false
	GameDirector.instance.notify_boss_revive()
	_enable_mechanic_word()
	_trigger_camera_hint()

func _final_death() -> void:
	_reviving = true
	_invuln = true
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(0.4, 0.4, 0.4), BOSS_FINAL_DEATH_FADE_TIME)
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

func _flash_white() -> void:
	if visual == null:
		return
	visual.modulate = Color(1.6, 1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.15)

func _start_invuln() -> void:
	_invuln = true
	await get_tree().create_timer(BOSS_IFRAME_DURATION).timeout
	_invuln = false

func _on_damage_body(body: Node) -> void:
	if body and body.has_method("take_hit") and body.is_in_group("player"):
		body.take_hit(1)
