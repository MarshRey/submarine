extends StaticBody2D

func highlight_if_in_range(ping_origin: Vector2, ping_radius: float) -> void:
	if global_position.distance_to(ping_origin) <= ping_radius:
		$Visual.modulate = Color(1, 0.6, 0.2)
		await get_tree().create_timer(0.3).timeout
		$Visual.modulate = Color.WHITE
