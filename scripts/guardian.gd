extends Area2D

const GUARDIAN_DIALOGUE_SUPPRESS_COLOR := Color(0.6, 0.6, 0.6)
const GUARDIAN_IDLE_COLOR := Color(0.9, 0.9, 0.6)
@export var prompt_text := "{INTERACT} Talk"
@export var enabled := true
@export var pre_boss_lines: Array[String] = [
	"Ты здесь?",
	"Пусто, но звучит знакомо.",
	"Дверь вниз… откроется, если ты спросишь."
]
@export var extra_lines: Array[String] = [
	"Я не помню, что было до этого.",
	"Но ты можешь спуститься."
]
@export var post_boss_lines: Array[String] = [
	"Ты повлиял на баланс сил в мире.",
	"А что титов?",
	"Требуется перезапустить мир."
]

var _extra_index := 0

@onready var sprite: Sprite2D = $Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("interactable")
	_play_animation("playing")

func _process(_delta: float) -> void:
	_update_prompt()
	_update_visual_state()

func is_enabled() -> bool:
	return enabled

func get_prompt_text() -> String:
	return prompt_text

func interact(_interactor: Node) -> void:
	if not enabled:
		return
	if GameDirector.instance == null or GameDirector.instance.dialogue_ui == null:
		return
	if GameDirector.instance.boss_defeated:
		_play_post_boss()
		return
	_play_pre_boss()

func _play_pre_boss() -> void:
	var dialogue: Node = GameDirector.instance.dialogue_ui
	if not GameDirector.instance.guardian_intro_done:
		dialogue.start_dialogue(pre_boss_lines)
		dialogue.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	elif _extra_index < extra_lines.size():
		dialogue.start_dialogue([extra_lines[_extra_index]])
		_extra_index += 1
	else:
		dialogue.start_dialogue([extra_lines.back()])

func _on_intro_finished() -> void:
	if GameDirector.instance:
		GameDirector.instance.unlock_guardian_intro()

func _play_post_boss() -> void:
	var dialogue: Node = GameDirector.instance.dialogue_ui
	dialogue.start_dialogue(post_boss_lines)
	dialogue.dialogue_finished.connect(_on_post_dialogue_finished, CONNECT_ONE_SHOT)

func _on_post_dialogue_finished() -> void:
	if GameDirector.instance:
		GameDirector.instance.unlock_guardian_post_dialogue()
		GameDirector.instance.request_reset()

func _update_prompt() -> void:
	prompt_text = "{INTERACT} Talk"

func _update_visual_state() -> void:
	if sprite == null or GameDirector.instance == null:
		return
	if GameDirector.instance.dialogue_ui and GameDirector.instance.dialogue_ui.is_active():
		sprite.modulate = GUARDIAN_DIALOGUE_SUPPRESS_COLOR
		_play_animation("idle")
	else:
		sprite.modulate = GUARDIAN_IDLE_COLOR
		_play_animation("playing")

func _play_animation(name: StringName) -> void:
	if anim_player == null:
		return
	if anim_player.current_animation == name:
		return
	anim_player.play(name)
