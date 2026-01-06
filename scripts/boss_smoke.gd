extends Area2D

@export var damage := 1
@export var lifetime := 0.4

var _hit := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_start_lifetime_timer()

func set_facing(direction: int) -> void:
	if sprite == null:
		return
	sprite.scale.x = -1 if direction > 0 else 1

func _start_lifetime_timer() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _on_body_entered(body: Node) -> void:
	_try_damage(body)

func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)

func _try_damage(target: Node) -> void:
	if _hit:
		return
	if target and target.is_in_group("player") and target.has_method("take_hit"):
		_hit = true
		target.take_hit(damage)
