extends Node2D

const PING_INTERVAL := 2.0        # every 2 s while active
@export var ping_radius := 350.0

var sonar_active := false
@onready var ping_timer := Timer.new()

signal sonar_ping_triggered

func _ready():
	add_child(ping_timer)
	ping_timer.one_shot = false
	ping_timer.wait_time = PING_INTERVAL
	ping_timer.timeout.connect(_emit_ping)

func set_active(state: bool):
	sonar_active = state
	if sonar_active:
		_emit_ping()          # immediate first ping
		ping_timer.start()
	else:
		ping_timer.stop()
	queue_redraw()

func _emit_ping():
	if !sonar_active:
		return
	sonar_ping_triggered.emit(global_position, ping_radius)
	queue_redraw()
	await get_tree().create_timer(0.3).timeout
	queue_redraw()

func _draw():
	if !sonar_active:
		return
	draw_circle(Vector2.ZERO, ping_radius, Color(1, 1, 1, 0.2))
