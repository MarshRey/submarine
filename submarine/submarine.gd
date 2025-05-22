extends CharacterBody2D

# ────────── Tunables ──────────
@export var max_speed      : float = 500.0      # top speed
@export var accel_rate     : float = 100.0      # how fast we reach top speed
@export var linear_drag    : float = 75.0      # water resistance
@export var max_health     : int   = 100

# ────────── labels ──────────

@onready var decent_velocity : Label = $"/root/Main/Hud/CanvasLayer/DecentVelocity/Velocity"
@onready var horizontal_velocity   : Label = $"/root/Main/Hud/CanvasLayer/HorizontalVelocity/Velocity"

# ────────── Runtime ──────────
var health : int

func _ready() -> void:
	add_to_group("submarine")
	health = max_health
	# Spawn dead-centre of the first corridor segment
	# global_position = Vector2(0, -160)   # segment_height /-2  (320/2=160)
	print("Submarine ready at ", global_position)

	# Camera starts centered; smoothing will kick in automatically

func _physics_process(delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	).normalized()

	# Desired velocity based on input (accelerates toward this)
	var desired_vel := input_vec * max_speed

	# Smooth acceleration / deceleration toward desired_vel
	velocity = velocity.move_toward(desired_vel, accel_rate * delta)

	# Apply linear drag when no input (makes the sub coast & slow)
	if input_vec == Vector2.ZERO:
		var drag_amount := linear_drag * delta
		velocity = velocity.move_toward(Vector2.ZERO, drag_amount)

	move_and_slide()

	
	decent_velocity.text = str(velocity.y).pad_decimals(1)
	
	horizontal_velocity.text = str(velocity.x).pad_decimals(1)

# ────────── Damage hook (unchanged) ──────────
signal health_changed(current: int, max: int)
signal died
func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	emit_signal("health_changed", health, max_health)
	if health == 0:
		emit_signal("died")
