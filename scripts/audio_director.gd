extends Node

static var instance: Node

const BAR_LENGTH := 4.0
const HUB_LAYER_MAX_DISTANCE := 420.0

var hub_base: AudioStreamPlayer
var hub_layer: AudioStreamPlayer
var hub_layer2: AudioStreamPlayer
var ambient: AudioStreamPlayer
var boss_music: AudioStreamPlayer

var music_start_time := 0.0
var dialogue_suppressed := false
var target_layer_volume := -80.0
var target_layer2_volume := -80.0

func _ready() -> void:
	instance = self
	_setup_players()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _setup_players() -> void:
	hub_base = _make_player("HubBase")
	hub_layer = _make_player("HubLayer")
	hub_layer2 = _make_player("HubLayer2")
	ambient = _make_player("Ambient")
	boss_music = _make_player("BossMusic")

func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = _make_silent_stream()
	player.volume_db = -8.0
	add_child(player)
	return player

func _make_silent_stream() -> AudioStreamGenerator:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.5
	return generator

func _process(_delta: float) -> void:
	_fill_silence(hub_base)
	_fill_silence(hub_layer)
	_fill_silence(hub_layer2)
	_fill_silence(ambient)
	_fill_silence(boss_music)

	hub_layer.volume_db = lerp(hub_layer.volume_db, target_layer_volume, 4.0 * _delta)
	hub_layer2.volume_db = lerp(hub_layer2.volume_db, target_layer2_volume, 4.0 * _delta)

	if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
		var player: CharacterBody2D = SceneManager.instance.player
		var guardian_node: Node = SceneManager.instance.current_level.get_node_or_null("Guardian") if SceneManager.instance.current_level else null
		if player and guardian_node and guardian_node is Node2D:
			var guardian: Node2D = guardian_node
			var distance := player.global_position.distance_to(guardian.global_position)
			set_hub_layers_distance(distance, HUB_LAYER_MAX_DISTANCE)

func _fill_silence(player: AudioStreamPlayer) -> void:
	if player == null or not player.playing:
		return
	var playback := player.get_stream_playback()
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	for i in range(frames):
		playback.push_frame(Vector2.ZERO)

func start_scene_audio(scene_name: StringName) -> void:
	if scene_name == "Hub":
		_start_hub_audio()
	elif scene_name == "BossRoom":
		_start_boss_audio()

func _start_hub_audio() -> void:
	_stop_all_music()
	ambient.play()
	ambient.volume_db = -6.0
	hub_base.play()
	hub_layer.play()
	hub_layer2.play()
	hub_layer.volume_db = -80.0
	hub_layer2.volume_db = -80.0
	target_layer_volume = -80.0
	target_layer2_volume = -80.0
	music_start_time = Time.get_ticks_msec() / 1000.0

func _start_boss_audio() -> void:
	_stop_all_music()
	ambient.play()
	ambient.volume_db = -6.0
	boss_music.stop()
	music_start_time = Time.get_ticks_msec() / 1000.0

func _stop_all_music() -> void:
	hub_base.stop()
	hub_layer.stop()
	hub_layer2.stop()
	boss_music.stop()

func fade_out_current_ambient() -> void:
	if ambient:
		ambient.volume_db = -24.0

func set_hub_layers_distance(distance: float, max_distance: float) -> void:
	if dialogue_suppressed:
		target_layer_volume = -80.0
		target_layer2_volume = -80.0
		return
	var t: float = clamp(1.0 - (distance / max_distance), 0.0, 1.0)
	target_layer_volume = lerp(-30.0, -6.0, t)
	target_layer2_volume = lerp(-42.0, -8.0, t * t)

func set_hub_dialogue_suppressed(enabled: bool) -> void:
	dialogue_suppressed = enabled
	if enabled:
		target_layer_volume = -80.0
		target_layer2_volume = -80.0

func get_time_to_next_bar() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var elapsed := now - music_start_time
	if elapsed < 0.0:
		return 0.0
	var mod := fmod(elapsed, BAR_LENGTH)
	if mod < 0.05:
		return 0.0
	return BAR_LENGTH - mod

func stop_boss_music() -> void:
	boss_music.stop()

func start_boss_music() -> void:
	if not boss_music.playing:
		boss_music.play()
		music_start_time = Time.get_ticks_msec() / 1000.0

func stop_all_music() -> void:
	_stop_all_music()

func prepare_transition_silence() -> void:
	target_layer_volume = -80.0
	target_layer2_volume = -80.0
