extends Resource
class_name BossConfig

@export var max_hp: int = 5
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 900.0
@export var iframe_duration: float = 0.3
@export var hit_flash_interval: float = 0.08
@export var invalid_death_shrink_time: float = 0.3
@export var invalid_death_pause: float = 0.5
@export var final_death_fade_time: float = 0.4

@export var move_speed: float = 120.0
@export var acceleration: float = 800.0
@export var stop_distance: float = 12.0
@export var walk_anim_speed_threshold: float = 1.0
@export var smoke_offset_x: float = 12.0
@export var smoke_push_distance: float = 10.0
@export var smoke_push_time: float = 0.15
@export var smoke_follow_time: float = 0.2
