extends CharacterBody2D
@export var patrol_speed     : float = 40.0
@export var chase_speed      : float = 80.0
@export var detection_radius : float = 120.0

var is_aggressive := false
var sub : CharacterBody2D

func _ready() -> void:
	add_to_group("enemies")
	# Wait 1 frame to give the sub time to enter the tree
	call_deferred("_late_init")

func _late_init() -> void:
	sub = get_tree().get_first_node_in_group("submarine")

func set_aggressive(state: bool) -> void:
	is_aggressive = state

func _physics_process(delta: float) -> void:
	if sub == null:
		return
	var dir := Vector2.ZERO
	if is_aggressive or global_position.distance_to(sub.global_position) <= detection_radius:
		dir = (sub.global_position - global_position).normalized()
		velocity = dir * chase_speed
	else:
		# Tiny random drift when idle
		if randf() < 0.01:
			velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * patrol_speed
	move_and_slide()

func highlight_if_in_range(ping_origin: Vector2, ping_radius: float) -> void:
	if global_position.distance_to(ping_origin) <= ping_radius:
		$Visual.modulate = Color(1, 1, 0.3)
		await get_tree().create_timer(0.3).timeout
		$Visual.modulate = Color("#cf3542")
