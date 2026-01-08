extends Resource
class_name PlayerConfig

@export_group("Player Movement")
@export_range(0.0, 512.0, 1.0, "suffix:px") var width: float = 16.0
@export_range(0.0, 512.0, 1.0, "suffix:px") var height: float = 32.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var max_speed: float = 240.0
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var acceleration: float = 2000.0
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var deceleration: float = 2500.0
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var gravity: float = 1400.0
@export_range(-2000.0, 0.0, 1.0, "suffix:px/s") var jump_velocity: float = -680.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var coyote_time: float = 0.12
@export_range(0.0, 1.0, 0.01, "suffix:s") var jump_buffer_time: float = 0.12
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var max_fall_speed: float = 900.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var run_speed_threshold: float = 5.0
@export_range(0.1, 1.0, 0.05) var variable_jump_multiplier: float = 0.5

@export_group("Player Combat")
@export_range(0.0, 5.0, 0.01, "suffix:s") var attack_cooldown: float = 0.35
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_duration: float = 0.12
@export_range(0.0, 256.0, 1.0, "suffix:px") var attack_radius: float = 32.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_lock_time: float = 0.08
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_anim_duration: float = 0.12
@export_range(0.0, 2.0, 0.01, "suffix:s") var iframe_duration: float = 0.4
@export_range(0.0, 1.0, 0.01, "suffix:s") var hit_flash_interval: float = 0.08
@export_range(0.0, 1.0, 0.01, "suffix:s") var hit_stun_duration: float = 0.2
@export_range(1, 20, 1) var max_hp: int = 3

@export_group("Player Animation")
@export_range(1, 12, 1) var anim_frame_count: int = 4
@export_range(0.1, 2.0, 0.01, "suffix:s") var anim_duration: float = 0.5

@export_group("Player UX")
@export_range(0.0, 2.0, 0.01, "suffix:s") var reset_hold_time: float = 0.5
@export var allow_reset_in_release := false

@export_group("Camera")
@export var camera_deadzone: Vector2 = Vector2(120, 80)
@export_range(0.0, 512.0, 1.0, "suffix:px") var camera_edge_padding_x: float = 50.0
@export_range(0.0, 512.0, 1.0, "suffix:px") var camera_edge_padding_y: float = 25.0
@export_range(0.0, 20.0, 0.1) var camera_lerp_speed: float = 6.0
@export var camera_hint_offset: Vector2 = Vector2(0, -120)
@export_range(0.0, 5.0, 0.01, "suffix:s") var camera_hint_up_time: float = 0.6
@export_range(0.0, 5.0, 0.01, "suffix:s") var camera_hint_hold: float = 0.4
@export_range(0.0, 5.0, 0.01, "suffix:s") var camera_hint_down_time: float = 0.6
@export var camera_bounds_default_size: Vector2 = Vector2(1024, 600)

@export_group("Interaction")
@export var interact_prompt_offset: Vector2 = Vector2(0, -24)
