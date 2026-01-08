extends Node

static var instance: Node

const WHITEOUT_FADE_MIN := 0.5
const WHITEOUT_FADE_MAX := 3.0

@export var game_state: GameState = GameState.new()

var _scene_manager_connected := false
var _ui_controller_connected := false

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
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true
	_bind_ui_controller()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(_delta: float) -> void:
	if not _scene_manager_connected and SceneManager.instance:
		SceneManager.instance.level_changed.connect(_on_level_changed)
		_scene_manager_connected = true
		if AudioDirector.instance and SceneManager.instance.current_scene_name != "":
			AudioDirector.instance.start_scene_audio(SceneManager.instance.current_scene_name)
	_bind_ui_controller()

func _bind_ui_controller() -> void:
	if _ui_controller_connected:
		return
	if UIController.instance == null:
		return
	UIController.instance.dialogue_started.connect(_on_dialogue_started)
	UIController.instance.dialogue_finished.connect(_on_dialogue_finished)
	_ui_controller_connected = true

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
	if state == GameState.Phase.TRANSITION:
		return
	state = GameState.Phase.TRANSITION
	_set_player_movement(false)
	if UIController.instance == null or UIController.instance.whiteout_ui == null:
		_do_scene_change(scene_name, spawn_marker)
		state = GameState.Phase.HUB_FREE if scene_name == "Hub" else GameState.Phase.BOSSROOM_FREE
		_set_player_movement(true)
		return
	var fade_time: float = WHITEOUT_FADE_MAX
	var _start_boundary_id := -1
	if AudioDirector.instance:
		_start_boundary_id = AudioDirector.instance.get_boundary_id()
		AudioDirector.instance.fade_out_all(fade_time)
	await UIController.instance.fade_to_white(fade_time)
	if AudioDirector.instance:
		AudioDirector.instance.stop_all_music()
	_do_scene_change(scene_name, spawn_marker)
	if AudioDirector.instance:
		AudioDirector.instance.start_scene_audio(scene_name)
	await UIController.instance.fade_from_white(0.5)
	state = GameState.Phase.HUB_FREE if scene_name == "Hub" else GameState.Phase.BOSSROOM_FREE
	_set_player_movement(true)

func _do_scene_change(scene_name: StringName, spawn_marker: StringName) -> void:
	if SceneManager.instance:
		SceneManager.instance.change_scene(scene_name, spawn_marker)

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
		if UIController.instance:
			UIController.instance.show_overlay_line("Советы по игре будут?")
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
