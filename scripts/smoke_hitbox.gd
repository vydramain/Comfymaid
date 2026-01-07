extends Node2D

@export var life_time := 1.0
@export var appear_time := 0.2
@export var disappear_time := 0.2
@export var damage := 1
@export var hitbox_start := 0.05
@export var hitbox_end := 0.9
@export var offset_x := 0.0
@export var push_up := 4.0
@export var appear_scale_from := 0.7
@export var appear_scale_to := 1.0
@export var initial_push_distance := 10.0
@export var initial_push_time := 0.15
@export var follow_time := 0.2
@export var visual_scale := 1.5
@export var auto_align_to_pixels := true

var _elapsed := 0.0
var _dir := 1
var _material: ShaderMaterial
var _follow_root: Node
var _follow_until := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var hurt_area: Area2D = $HurtArea

func _ready() -> void:
	if sprite and sprite.material:
		_material = sprite.material.duplicate()
		sprite.material = _material
	if sprite:
		sprite.scale = Vector2.ONE * visual_scale
		if auto_align_to_pixels:
			_align_sprite_to_pixels()
	if hurt_area:
		hurt_area.collision_layer = 1
		hurt_area.collision_mask = 1
		hurt_area.body_entered.connect(_on_body_entered)
		hurt_area.area_entered.connect(_on_area_entered)
		hurt_area.monitoring = false
	_start_reveal()

func _process(delta: float) -> void:
	_elapsed += delta
	if _follow_root and _elapsed >= _follow_until:
		_detach_to_root()
	if hurt_area:
		hurt_area.monitoring = _elapsed >= hitbox_start and _elapsed <= hitbox_end
	if _elapsed >= life_time:
		queue_free()

func set_direction(direction: int, push_distance: float, push_time: float) -> void:
	_dir = 1 if direction >= 0 else -1
	position.x += offset_x * _dir
	initial_push_distance = push_distance
	initial_push_time = push_time
	if sprite:
		var base_scale := Vector2.ONE * visual_scale
		sprite.scale = Vector2(base_scale.x * _dir, base_scale.y)
	_start_push()

func set_follow_root(root_node: Node, duration: float) -> void:
	if root_node == null or not is_instance_valid(root_node):
		return
	_follow_root = root_node
	follow_time = duration
	_follow_until = _elapsed + follow_time

func _start_reveal() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("reveal", 0.0)
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/reveal", 1.0, appear_time)
	tween.tween_interval(max(life_time - appear_time - disappear_time, 0.0))
	tween.tween_property(_material, "shader_parameter/reveal", 0.0, disappear_time)
	if sprite:
		sprite.scale = Vector2.ONE * appear_scale_from * visual_scale
		tween.tween_property(sprite, "scale", Vector2.ONE * appear_scale_to * visual_scale, appear_time)

func _start_push() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(initial_push_distance * _dir, -push_up), initial_push_time)

func _detach_to_root() -> void:
	if _follow_root == null or not is_instance_valid(_follow_root):
		return
	var global_pos := global_position
	var parent := get_parent()
	if parent and parent != _follow_root:
		parent.remove_child(self)
	if _follow_root:
		_follow_root.add_child(self)
		global_position = global_pos
	_follow_root = null

func _align_sprite_to_pixels() -> void:
	if sprite == null or sprite.texture == null:
		return
	var img := sprite.texture.get_image()
	if img == null:
		return
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var used_size := Vector2(used.size.x, used.size.y)
	var offset := Vector2(used.position.x, used.position.y)
	sprite.centered = false
	sprite.position = Vector2(-used_size.x * 0.5 - offset.x, -used_size.y - offset.y)
	var collider := $HurtArea/CollisionShape2D
	if collider and collider is CollisionShape2D:
		var rect := RectangleShape2D.new()
		rect.size = used_size * visual_scale
		collider.shape = rect
		collider.rotation = 0.0
		collider.position = Vector2(0, -used_size.y * 0.5 * visual_scale)

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player") and body.has_method("take_hit"):
		body.take_hit(damage)

func _on_area_entered(area: Area2D) -> void:
	if area and area.get_parent() and area.get_parent().is_in_group("player"):
		area.get_parent().take_hit(damage)
