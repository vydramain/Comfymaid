extends Resource
class_name PlayerConfig

@export var width: float = 16.0
@export var height: float = 32.0
@export var max_speed: float = 240.0
@export var acceleration: float = 2000.0
@export var deceleration: float = 2500.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -680.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var max_fall_speed: float = 900.0
@export var attack_cooldown: float = 0.35
@export var attack_duration: float = 0.12
@export var attack_radius: float = 32.0
@export var attack_lock_time: float = 0.08
@export var attack_anim_duration: float = 0.12
@export var iframe_duration: float = 0.4
@export var hit_flash_interval: float = 0.08
@export var hit_stun_duration: float = 0.2
@export var variable_jump_multiplier: float = 0.5
@export var run_speed_threshold: float = 5.0
@export var max_hp: int = 3
@export var anim_frame_count: int = 4
@export var anim_duration: float = 0.5
@export var reset_hold_time: float = 0.5
@export var allow_reset_in_release := false

@export var camera_deadzone: Vector2 = Vector2(120, 80)
@export var camera_edge_padding_x: float = 50.0
@export var camera_edge_padding_y: float = 25.0
@export var camera_lerp_speed: float = 6.0
@export var camera_hint_offset: Vector2 = Vector2(0, -120)
@export var camera_hint_up_time: float = 0.6
@export var camera_hint_hold: float = 0.4
@export var camera_hint_down_time: float = 0.6
@export var camera_bounds_default_size: Vector2 = Vector2(1024, 600)

@export var interact_prompt_offset: Vector2 = Vector2(0, -24)
