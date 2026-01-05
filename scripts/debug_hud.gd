extends Control

var player: CharacterBody2D

@onready var scene_label: Label = %SceneLabel
@onready var velocity_label: Label = %VelocityLabel

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

func _on_level_changed(scene_name: StringName) -> void:
    scene_label.text = "Scene: %s" % scene_name

func _on_player_spawned(new_player: Node) -> void:
    if new_player is CharacterBody2D:
        player = new_player
