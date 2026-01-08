extends Resource
class_name AudioConfig

@export var hub_layer1_intro_path: String = "res://assets/music/hub_layer_1_intro.mp3"
@export var hub_layer1_base_path: String = "res://assets/music/hub_layer_1_base.mp3"
@export var hub_layer2_base_path: String = "res://assets/music/hub_layer_2_base.mp3"
@export var hub_layer3_base_path: String = "res://assets/music/hub_layer_3_base.mp3"
@export var boss_layer1_intro_path: String = "res://assets/music/bossroom_layer_1_intro.mp3"
@export var boss_layer2_intro_path: String = "res://assets/music/bossroom_layer_2_intro.mp3"
@export var boss_layer1_base_paths: Array[String] = [
	"res://assets/music/bossroom_layer_1_base_1.mp3",
	"res://assets/music/bossroom_layer_1_base_2.mp3",
]
@export var boss_layer2_base_paths: Array[String] = [
	"res://assets/music/bossroom_layer_2_base_1.mp3",
	"res://assets/music/bossroom_layer_2_base_2.mp3",
	"res://assets/music/bossroom_layer_2_base_3.mp3",
]
@export var guardian_group: StringName = "Guardian"
@export var boss_group: StringName = "Boss"
@export var segment_fallback_length: float = 4.0
@export var hub_layer_max_distance: float = 1200.0
@export var hub_layer_base_db: float = -8.0
@export var hub_layer_silent_db: float = -80.0
@export var hub_layer2_min_db: float = -26.0
@export var hub_layer2_max_db: float = -10.0
@export var hub_layer3_min_db: float = -38.0
@export var hub_layer3_max_db: float = -10.0
@export var boss_layer_db: float = -6.0
