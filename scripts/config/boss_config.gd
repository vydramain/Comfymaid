extends Resource
class_name BossConfig

@export_group("Boss Combat")
@export_range(1, 50, 1) var max_hp: int = 5
@export_range(0.0, 2.0, 0.01, "suffix:s") var iframe_duration: float = 0.3
@export_range(0.0, 1.0, 0.01, "suffix:s") var hit_flash_interval: float = 0.08
@export_range(0.0, 2.0, 0.01, "suffix:s") var invalid_death_shrink_time: float = 0.3
@export_range(0.0, 2.0, 0.01, "suffix:s") var invalid_death_pause: float = 0.5
@export_range(0.0, 2.0, 0.01, "suffix:s") var final_death_fade_time: float = 0.4

@export_group("Boss Movement")
@export_range(0.0, 2000.0, 1.0, "suffix:px/s²") var gravity: float = 1400.0
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var max_fall_speed: float = 900.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var move_speed: float = 120.0
@export_range(0.0, 5000.0, 1.0, "suffix:px/s²") var acceleration: float = 800.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var stop_distance: float = 12.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var walk_anim_speed_threshold: float = 1.0

@export_group("Boss Smoke")
@export_range(0.0, 128.0, 1.0, "suffix:px") var smoke_offset_x: float = 12.0
@export_range(0.0, 128.0, 1.0, "suffix:px") var smoke_push_distance: float = 10.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var smoke_push_time: float = 0.15
@export_range(0.0, 2.0, 0.01, "suffix:s") var smoke_follow_time: float = 0.2
