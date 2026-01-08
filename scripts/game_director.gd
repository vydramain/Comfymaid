extends Node

static var instance: Node

const WHITEOUT_FADE_MIN := 0.5
const WHITEOUT_FADE_MAX := 3.0

@export var game_state: GameState = GameState.new()

var _scene_manager_connected := false
var _ui_manager_connected := false
var _ui_manager: Node

var mechanic_broken: bool:
	get:
		return game_state.mechanic_broken
	set(value):
		game_state.mechanic_broken = value

var boss_defeated: bool:
	get:
		return game_state.boss_defeated
	set(value):
		game_state.boss_defeated = value

var boss_revived_once: bool:
	get:
		return game_state.boss_revived_once
	set(value):
		game_state.boss_revived_once = value

var guardian_intro_done: bool:
	get:
		return game_state.guardian_intro_done
	set(value):
		game_state.guardian_intro_done = value

var guardian_post_dialogue_done: bool:
	get:
		return game_state.guardian_post_dialogue_done
	set(value):
		game_state.guardian_post_dialogue_done = value

var guardian_death_hint_pending: bool:
	get:
		return game_state.guardian_death_hint_pending
	set(value):
		game_state.guardian_death_hint_pending = value

var world_reset_count: int:
	get:
		return game_state.world_reset_count
	set(value):
		game_state.world_reset_count = value

var state: GameState.Phase:
	get:
		return game_state.phase
	set(value):
		game_state.phase = value

func _ready() -> void:
	instance = self
	if SceneManager.instance:
		set_scene_manager(SceneManager.instance)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func set_scene_manager(scene_manager: SceneManager) -> void:
	if scene_manager == null or _scene_manager_connected:
		return
	scene_manager.level_changed.connect(_on_level_changed)
	_scene_manager_connected = true

func set_ui_manager(ui_manager: Node) -> void:
	if ui_manager == null or ui_manager == _ui_manager:
		return
	_disconnect_ui_manager_signals()
	_ui_manager = ui_manager
	if _ui_manager.has_signal("dialogue_started"):
		if _ui_manager.dialogue_started.is_connected(_on_dialogue_started):
			_ui_manager.dialogue_started.disconnect(_on_dialogue_started)
		_ui_manager.dialogue_started.connect(_on_dialogue_started)
	if _ui_manager.has_signal("dialogue_finished"):
		if _ui_manager.dialogue_finished.is_connected(_on_dialogue_finished):
			_ui_manager.dialogue_finished.disconnect(_on_dialogue_finished)
		_ui_manager.dialogue_finished.connect(_on_dialogue_finished)
	_ui_manager_connected = true

func _disconnect_ui_manager_signals() -> void:
	if not _ui_manager_connected or _ui_manager == null:
		return
	if is_instance_valid(_ui_manager):
		if _ui_manager.has_signal("dialogue_started") and _ui_manager.dialogue_started.is_connected(_on_dialogue_started):
			_ui_manager.dialogue_started.disconnect(_on_dialogue_started)
		if _ui_manager.has_signal("dialogue_finished") and _ui_manager.dialogue_finished.is_connected(_on_dialogue_finished):
			_ui_manager.dialogue_finished.disconnect(_on_dialogue_finished)
	_ui_manager_connected = false

func _on_dialogue_started() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
		state = GameState.Phase.HUB_DIALOGUE
	else:
		state = GameState.Phase.BOSS_FIGHT
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(true)

func _on_dialogue_finished() -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(true)
	if SceneManager.instance and SceneManager.instance.current_scene_name == "Hub":
		state = GameState.Phase.HUB_FREE
	else:
		state = GameState.Phase.BOSSROOM_FREE
	if AudioDirector.instance:
		AudioDirector.instance.set_hub_dialogue_suppressed(false)

func _get_player() -> Node:
	if SceneManager.instance:
		return SceneManager.instance.player
	return null

func request_scene_change(scene_name: StringName, spawn_marker: StringName = "PlayerSpawn") -> void:
	if SceneManager.instance == null:
		push_error("GameDirector requires SceneManager instance for scene transitions.")
		return
	if scene_name == "":
		push_error("GameDirector request_scene_change called with empty scene_name.")
		return
	var resolved_spawn_marker: StringName = spawn_marker if spawn_marker != "" else "PlayerSpawn"
	if state == GameState.Phase.TRANSITION:
		return
	state = GameState.Phase.TRANSITION
	_set_player_movement(false)
	if _ui_manager == null or not _ui_manager.has_method("has_whiteout") or not _ui_manager.has_whiteout():
		_do_scene_change(scene_name, resolved_spawn_marker)
		state = GameState.Phase.HUB_FREE if scene_name == "Hub" else GameState.Phase.BOSSROOM_FREE
		_set_player_movement(true)
		return
	var fade_time: float = WHITEOUT_FADE_MAX
	var _start_boundary_id := -1
	if AudioDirector.instance:
		_start_boundary_id = AudioDirector.instance.get_boundary_id()
		AudioDirector.instance.fade_out_all(fade_time)
	await _ui_manager.fade_to_white(fade_time)
	if AudioDirector.instance:
		AudioDirector.instance.stop_all_music()
	_do_scene_change(scene_name, resolved_spawn_marker)
	if AudioDirector.instance:
		AudioDirector.instance.start_scene_audio(scene_name)
	await _ui_manager.fade_from_white(0.5)
	state = GameState.Phase.HUB_FREE if scene_name == "Hub" else GameState.Phase.BOSSROOM_FREE
	_set_player_movement(true)

func _do_scene_change(scene_name: StringName, spawn_marker: StringName) -> void:
	if SceneManager.instance:
		SceneManager.instance.load_level(scene_name, spawn_marker)

func request_reset() -> void:
	world_reset_count += 1
	if state == GameState.Phase.RESET or state == GameState.Phase.TRANSITION:
		return
	state = GameState.Phase.RESET
	_reset_run_flags()
	await request_scene_change("Hub", "PlayerSpawn")

func request_death_reset() -> void:
	world_reset_count = 0
	if state == GameState.Phase.RESET or state == GameState.Phase.TRANSITION:
		return
	state = GameState.Phase.RESET
	_reset_run_flags()
	guardian_death_hint_pending = true
	await request_scene_change("Hub", "PlayerSpawn")

func _reset_run_flags() -> void:
	mechanic_broken = false
	boss_defeated = false
	boss_revived_once = false
	guardian_intro_done = false
	guardian_post_dialogue_done = false
	guardian_death_hint_pending = false

func notify_boss_revive() -> void:
	if not boss_revived_once:
		boss_revived_once = true
		if _ui_manager and _ui_manager.has_method("show_overlay_line"):
			_ui_manager.show_overlay_line("Советы по игре будут?")
		var mechanic := SceneManager.instance.find_singleton_in_group("MechanicWord") if SceneManager.instance else null
		if mechanic and mechanic.has_method("enable_word"):
			mechanic.enable_word()

func notify_boss_defeated() -> void:
	boss_defeated = true

func notify_mechanic_broken() -> void:
	mechanic_broken = true

func unlock_guardian_intro() -> void:
	guardian_intro_done = true

func unlock_guardian_post_dialogue() -> void:
	guardian_post_dialogue_done = true

func _on_level_changed(scene_name: StringName) -> void:
	if AudioDirector.instance:
		AudioDirector.instance.start_scene_audio(scene_name)
	state = GameState.Phase.HUB_FREE if scene_name == "Hub" else GameState.Phase.BOSSROOM_FREE
	_set_player_movement(true)

func _set_player_movement(enabled: bool) -> void:
	var player := _get_player()
	if player and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)
