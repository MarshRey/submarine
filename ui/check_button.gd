# sonar_toggle_button.gd   (attach to the CheckButton)
extends CheckButton

@onready var active_sonar  : Node = get_node("/root/Main/Submarine/ActiveSonar")
@onready var passive_sonar : Node = get_node("/root/Main/Submarine/PassiveSonar")

func _ready() -> void:
	# Ensure UI & sonar start in sync
	_apply_state(button_pressed)
	toggled.connect(_on_toggled)

func _on_toggled(is_pressed: bool) -> void:
	_apply_state(is_pressed)

func _apply_state(is_pressed: bool) -> void:
	# is_pressed == true  -> button DOWN  -> PASSIVE sonar
	# is_pressed == false -> button UP    -> ACTIVE  sonar
	active_sonar.set_active(!is_pressed)
	passive_sonar.set_active(is_pressed)
