extends Node2D

@export var length          : int   = 12      # how many segments
@export var segment_width   : int   = 240     # half-corridor width
@export var segment_height  : int   = 320
@export var wall_scene      : PackedScene = preload("res://world/wall.tscn")
@export var enemy_scene     : PackedScene = preload("res://world/enemy.tscn")

@onready var submarine := get_node("/root/Main/Submarine")

func _ready() -> void:
	# connect sonar ping → enemies become aggressive
	submarine.get_node("ActiveSonar").sonar_ping_triggered.connect(_on_sonar_ping)

	# _generate_corridor()

func _generate_corridor() -> void:
	for i in length:
		var y := -i * segment_height
		_spawn_wall(Vector2(-segment_width, y))
		_spawn_wall(Vector2( segment_width, y))

		if randf() < 0.35:
			_spawn_enemy(Vector2(randf_range(-segment_width * 0.6, segment_width * 0.6), y - 80))

func _spawn_wall(pos: Vector2) -> void:
	var w := wall_scene.instantiate()
	w.position = pos
	add_child(w)

func _spawn_enemy(pos: Vector2) -> void:
	var e := enemy_scene.instantiate()
	e.position = pos
	add_child(e)

func _on_sonar_ping(origin: Vector2, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(origin) <= radius:
			e.set_aggressive(true)
