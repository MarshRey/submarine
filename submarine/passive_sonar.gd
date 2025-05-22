extends Node2D

const PING_INTERVAL := 2.0
@export var detection_radius := 150.0

var sonar_active := true
@onready var ping_timer := Timer.new()

signal sonar_ping_triggered   # keep using your signal if needed

func _ready():
	add_child(ping_timer)
	ping_timer.one_shot = false
	ping_timer.wait_time = PING_INTERVAL
	ping_timer.timeout.connect(_emit_ping)
	if sonar_active:
		ping_timer.start()

func set_active(state: bool):
	sonar_active = state
	if sonar_active:
		ping_timer.start()
	else:
		ping_timer.stop()
	queue_redraw()

func _emit_ping():
	if !sonar_active:
		return
	sonar_ping_triggered.emit(global_position, detection_radius)
	queue_redraw()
	await get_tree().create_timer(0.15).timeout
	queue_redraw()

func _draw():
	if !sonar_active:
		return
	draw_circle(Vector2.ZERO, detection_radius, Color(0.3, 0.6, 1, 0.1))
