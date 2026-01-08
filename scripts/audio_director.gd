extends Node

signal boundary_reached(scene_name: StringName)

static var instance: Node

@export var config: AudioConfig

var hub_layer1: AudioStreamPlayer
var hub_layer2: AudioStreamPlayer
var hub_layer3: AudioStreamPlayer
var boss_layer1: AudioStreamPlayer
var boss_layer2: AudioStreamPlayer

var _current_scene: StringName = ""
var _hub_mode := "intro"
var _boss_mode := "intro"
var _boss_mode_target := "intro"
var _boss_visible := false
var _boss_music_enabled := true
var _transition_fading := false
var _hub_layers_suppressed := false

var _fade_tween: Tween
var _rng := RandomNumberGenerator.new()
var _stream_cache: Dictionary = {}
var _boundary_id := 0

var _boss_last_layer1_path := ""
var _boss_last_layer2_path := ""
var _config: AudioConfig
var _warned_missing_guardian := false
var _warned_missing_boss := false

func _ready() -> void:
	instance = self
	if config == null:
		push_error("AudioDirector requires a configured AudioConfig resource; using defaults.")
	_config = config if config else AudioConfig.new()
	_rng.randomize()
	_setup_players()
	if _validate_config():
		set_process(false)
		stop_all_music()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _setup_players() -> void:
	hub_layer1 = _make_player("HubLayer1")
	hub_layer2 = _make_player("HubLayer2")
	hub_layer3 = _make_player("HubLayer3")
	boss_layer1 = _make_player("BossLayer1")
	boss_layer2 = _make_player("BossLayer2")
	hub_layer1.finished.connect(_on_hub_master_finished)
	boss_layer1.finished.connect(_on_boss_master_finished)
	boss_layer2.finished.connect(_on_boss_slave_finished)

func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = _config.hub_layer_silent_db
	add_child(player)
	return player

func _process(delta: float) -> void:
	if _current_scene == "Hub":
		_update_hub_layers(delta)
	elif _current_scene == "BossRoom":
		_update_boss_visibility()

func start_scene_audio(scene_name: StringName) -> void:
	stop_all_music()
	_current_scene = scene_name
	if scene_name == "Hub":
		_start_hub_intro()
	elif scene_name == "BossRoom":
		_start_boss_intro()

func stop_all_music() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_transition_fading = false
	hub_layer1.stop()
	hub_layer2.stop()
	hub_layer3.stop()
	boss_layer1.stop()
	boss_layer2.stop()

func stop_boss_music() -> void:
	_boss_music_enabled = false
	boss_layer1.stop()
	boss_layer2.stop()

func start_boss_music() -> void:
	if _current_scene != "BossRoom":
		return
	_boss_music_enabled = true
	if not boss_layer1.playing:
		_boss_mode = _boss_mode_target
		_restart_boss_layers()

func fade_out_all(duration: float) -> void:
	_transition_fading = true
	_fade_players([hub_layer1, hub_layer2, hub_layer3, boss_layer1, boss_layer2], _config.hub_layer_silent_db, duration)

func prepare_transition_silence() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_transition_fading = false

func get_time_to_next_boundary() -> float:
	var master := _get_master_player()
	if master == null or master.stream == null or not master.playing:
		return 0.0
	var length := master.stream.get_length()
	if length <= 0.0:
		return 0.0
	var position := master.get_playback_position()
	return max(length - position, 0.0)

func get_segment_length() -> float:
	var master := _get_master_player()
	if master == null or master.stream == null:
		return _config.segment_fallback_length
	var length := master.stream.get_length()
	return length if length > 0.0 else _config.segment_fallback_length

func is_master_playing() -> bool:
	var master := _get_master_player()
	return master != null and master.playing

func set_hub_dialogue_suppressed(enabled: bool) -> void:
	_hub_layers_suppressed = enabled
	if enabled:
		hub_layer2.volume_db = _config.hub_layer_silent_db
		hub_layer3.volume_db = _config.hub_layer_silent_db

func _start_hub_intro() -> void:
	_hub_mode = "intro"
	hub_layer1.stream = _get_stream(_config.hub_layer1_intro_path)
	hub_layer1.volume_db = _config.hub_layer_base_db
	hub_layer1.play()
	hub_layer2.stream = _get_stream(_config.hub_layer2_base_path)
	hub_layer2.volume_db = _config.hub_layer_silent_db
	hub_layer2.stop()
	hub_layer3.stream = _get_stream(_config.hub_layer3_base_path)
	hub_layer3.volume_db = _config.hub_layer_silent_db
	hub_layer3.stop()

func _on_hub_master_finished() -> void:
	if _current_scene != "Hub":
		return
	if _transition_fading:
		_restart_hub_layers(true)
		_boundary_id += 1
		emit_signal("boundary_reached", _current_scene)
		return
	if _hub_mode == "intro":
		_hub_mode = "base"
	_restart_hub_layers()
	_boundary_id += 1
	emit_signal("boundary_reached", _current_scene)

func _restart_hub_layers(keep_volume: bool = false) -> void:
	hub_layer1.stream = _get_stream(_config.hub_layer1_base_path if _hub_mode == "base" else _config.hub_layer1_intro_path)
	if not keep_volume:
		hub_layer1.volume_db = _config.hub_layer_base_db
	hub_layer1.play()
	hub_layer2.stream = _get_stream(_config.hub_layer2_base_path)
	hub_layer2.play()
	hub_layer3.stream = _get_stream(_config.hub_layer3_base_path)
	hub_layer3.play()

func _update_hub_layers(delta: float) -> void:
	if hub_layer2 == null or hub_layer3 == null:
		return
	var player := SceneManager.instance.player if SceneManager.instance else null
	var guardian_node := SceneManager.instance.find_singleton_in_group(_config.guardian_group) if SceneManager.instance else null
	if player == null or guardian_node == null:
		if guardian_node == null and not _warned_missing_guardian:
			push_warning("Guardian node not found for group '%s'; hub proximity layers disabled." % _config.guardian_group)
			_warned_missing_guardian = true
		return
	if not (guardian_node is Node2D):
		return
	var guardian := guardian_node as Node2D
	var distance := player.global_position.distance_to(guardian.global_position)
	var t: float = clamp(1.0 - (distance / _config.hub_layer_max_distance), 0.0, 1.0)
	var layer2_target: float = lerp(_config.hub_layer2_min_db, _config.hub_layer2_max_db, t)
	var layer3_target: float = lerp(_config.hub_layer3_min_db, _config.hub_layer3_max_db, t * t)
	if _hub_layers_suppressed:
		layer2_target = _config.hub_layer_silent_db
		layer3_target = _config.hub_layer_silent_db
	hub_layer2.volume_db = lerp(hub_layer2.volume_db, layer2_target, _config.hub_layer_lerp_speed * delta)
	hub_layer3.volume_db = lerp(hub_layer3.volume_db, layer3_target, _config.hub_layer_lerp_speed * delta)

func _start_boss_intro() -> void:
	_boss_mode = "intro"
	_boss_mode_target = "intro"
	_boss_music_enabled = true
	_boss_last_layer1_path = _config.boss_layer1_intro_path
	_boss_last_layer2_path = _config.boss_layer2_intro_path
	boss_layer1.stream = _get_stream(_config.boss_layer1_intro_path)
	boss_layer2.stream = _get_stream(_config.boss_layer2_intro_path)
	boss_layer1.volume_db = _config.boss_layer_db
	boss_layer2.volume_db = _config.boss_layer_db
	boss_layer1.play()
	boss_layer2.play()

func _on_boss_master_finished() -> void:
	if _current_scene != "BossRoom":
		return
	if not _boss_music_enabled:
		return
	if _transition_fading:
		_restart_boss_layers(true)
		_boundary_id += 1
		emit_signal("boundary_reached", _current_scene)
		return
	if _boss_mode_target != _boss_mode:
		_boss_mode = _boss_mode_target
	_restart_boss_layers()
	_boundary_id += 1
	emit_signal("boundary_reached", _current_scene)

func _restart_boss_layers(keep_volume: bool = false) -> void:
	if _boss_mode == "intro":
		_boss_last_layer1_path = _config.boss_layer1_intro_path
		_boss_last_layer2_path = _config.boss_layer2_intro_path
	else:
		_boss_last_layer1_path = _pick_random_excluding(_config.boss_layer1_base_paths, _boss_last_layer1_path)
		_boss_last_layer2_path = _pick_random_excluding(_config.boss_layer2_base_paths, _boss_last_layer2_path)
	boss_layer1.stream = _get_stream(_boss_last_layer1_path)
	boss_layer2.stream = _get_stream(_boss_last_layer2_path)
	if not keep_volume:
		boss_layer1.volume_db = _config.boss_layer_db
		boss_layer2.volume_db = _config.boss_layer_db
	boss_layer1.play()
	boss_layer2.play()

func _on_boss_slave_finished() -> void:
	if _current_scene != "BossRoom":
		return
	if not _boss_music_enabled or _transition_fading:
		return
	# Keep layer2 idle until the master restarts both layers on the boundary.
	return

func _pick_random(paths: Array) -> String:
	if paths.is_empty():
		return ""
	return paths[_rng.randi_range(0, paths.size() - 1)]

func _pick_random_excluding(paths: Array, last_path: String) -> String:
	if paths.is_empty():
		return ""
	if paths.size() == 1:
		return paths[0]
	var next := last_path
	var safety := 0
	while next == last_path and safety < 8:
		next = paths[_rng.randi_range(0, paths.size() - 1)]
		safety += 1
	return next

func _update_boss_visibility() -> void:
	var player := SceneManager.instance.player if SceneManager.instance else null
	if player == null:
		return
	var camera := player.camera
	if camera == null:
		return
	var boss := SceneManager.instance.find_singleton_in_group(_config.boss_group) if SceneManager.instance else null
	if boss == null:
		if not _warned_missing_boss:
			push_warning("Boss node not found for group '%s'; boss visibility checks disabled." % _config.boss_group)
			_warned_missing_boss = true
		return
	var view_size: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var center: Vector2 = camera.get_screen_center_position()
	var rect := Rect2(center - view_size * 0.5, view_size)
	var visible := rect.has_point(boss.global_position)
	if visible != _boss_visible:
		_boss_visible = visible
		_boss_mode_target = "base" if _boss_visible else "intro"

func _get_master_player() -> AudioStreamPlayer:
	return hub_layer1 if _current_scene == "Hub" else boss_layer1 if _current_scene == "BossRoom" else null

func _get_stream(path: String) -> AudioStream:
	if path.is_empty():
		push_warning("AudioDirector received an empty audio path.")
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream: AudioStream = load(path)
	_stream_cache[path] = stream
	return stream

func _validate_config() -> bool:
	var issues := false
	if _config.guardian_group.is_empty():
		push_error("AudioConfig.guardian_group is empty.")
		issues = true
	if _config.boss_group.is_empty():
		push_error("AudioConfig.boss_group is empty.")
		issues = true
	var hub_paths := {
		"hub_layer1_intro_path": _config.hub_layer1_intro_path,
		"hub_layer1_base_path": _config.hub_layer1_base_path,
		"hub_layer2_base_path": _config.hub_layer2_base_path,
		"hub_layer3_base_path": _config.hub_layer3_base_path,
	}
	var boss_intro_paths := {
		"boss_layer1_intro_path": _config.boss_layer1_intro_path,
		"boss_layer2_intro_path": _config.boss_layer2_intro_path,
	}
	for key in hub_paths.keys():
		issues = _validate_audio_path(key, hub_paths[key]) or issues
	for key in boss_intro_paths.keys():
		issues = _validate_audio_path(key, boss_intro_paths[key]) or issues
	issues = _validate_audio_array("boss_layer1_base_paths", _config.boss_layer1_base_paths) or issues
	issues = _validate_audio_array("boss_layer2_base_paths", _config.boss_layer2_base_paths) or issues
	if issues:
		push_error("AudioConfig validation failed; audio playback may be silent.")
	return issues

func _validate_audio_path(label: String, path: String) -> bool:
	if path.is_empty():
		push_error("AudioConfig.%s is empty." % label)
		return true
	if not ResourceLoader.exists(path):
		push_error("AudioConfig.%s missing resource at %s." % [label, path])
		return true
	var stream := load(path)
	if stream == null:
		push_error("AudioConfig.%s failed to load %s." % [label, path])
		return true
	if not (stream is AudioStream):
		push_error("AudioConfig.%s is not an AudioStream: %s." % [label, path])
		return true
	return false

func _validate_audio_array(label: String, paths: Array[String]) -> bool:
	var has_issue := false
	if paths.is_empty():
		push_error("AudioConfig.%s is empty." % label)
		return true
	var expected_length := -1.0
	for index in range(paths.size()):
		var path := paths[index]
		if _validate_audio_path("%s[%d]" % [label, index], path):
			has_issue = true
			continue
		var stream := load(path)
		if stream is AudioStream:
			var length := stream.get_length()
			if expected_length < 0.0:
				expected_length = length
			elif length > 0.0 and abs(length - expected_length) > 0.01:
				push_warning("AudioConfig.%s[%d] length %.2f differs from %.2f; loops may desync." % [label, index, length, expected_length])
	return has_issue

func _fade_players(players: Array, target_db: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	for player in players:
		if player:
			_fade_tween.tween_property(player, "volume_db", target_db, duration)

func get_debug_state() -> Dictionary:
	return {
		"scene": _current_scene,
		"hub_mode": _hub_mode,
		"boss_mode": _boss_mode,
		"boss_target": _boss_mode_target,
		"boss_visible": _boss_visible,
		"boss_enabled": _boss_music_enabled,
		"time_to_next_boundary": get_time_to_next_boundary(),
		"segment_length": get_segment_length(),
		"boundary_id": _boundary_id,
		"boss_layer1": _boss_last_layer1_path,
		"boss_layer2": _boss_last_layer2_path,
	}

func get_boundary_id() -> int:
	return _boundary_id
