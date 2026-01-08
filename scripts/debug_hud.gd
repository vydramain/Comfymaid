extends Control

var player: CharacterBody2D

@onready var scene_label: Label = %SceneLabel
@onready var velocity_label: Label = %VelocityLabel
@onready var input_label: Label = %InputLabel
@onready var audio_label: Label = %AudioLabel
@onready var boss_label: Label = %BossLabel

func _ready() -> void:
	set_process(true)
	var manager := SceneManager.instance
	if manager:
		manager.level_changed.connect(_on_level_changed)
		manager.player_spawned.connect(_on_player_spawned)
		_on_level_changed(manager.current_scene_name)
		if manager.player:
			_on_player_spawned(manager.player)

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		var grounded := player.is_on_floor()
		velocity_label.text = "vel: %.1f, %.1f | grounded: %s" % [player.velocity.x, player.velocity.y, grounded]
	else:
		velocity_label.text = "vel: --"
	if InputRouter.instance:
		input_label.text = "Input: %s" % InputRouter.instance.get_input_label()
	else:
		input_label.text = "Input: --"
	_update_audio_labels()

func _update_audio_labels() -> void:
	if AudioDirector.instance == null:
		audio_label.text = "Audio: --"
		boss_label.text = "Boss: --"
		return
	var state: Dictionary = AudioDirector.instance.get_debug_state()
	audio_label.text = "Audio: scene=%s next=%.2f len=%.2f" % [
		state.get("scene", ""),
		state.get("time_to_next_boundary", 0.0),
		state.get("segment_length", 0.0),
	]
	boss_label.text = "Boss: %s->%s vis=%s en=%s L1=%s L2=%s" % [
		state.get("boss_mode", ""),
		state.get("boss_target", ""),
		state.get("boss_visible", false),
		state.get("boss_enabled", false),
		state.get("boss_layer1", ""),
		state.get("boss_layer2", ""),
	]

func _on_level_changed(scene_name: StringName) -> void:
	scene_label.text = "Scene: %s" % scene_name

func _on_player_spawned(new_player: Node) -> void:
	if new_player is CharacterBody2D:
		player = new_player
