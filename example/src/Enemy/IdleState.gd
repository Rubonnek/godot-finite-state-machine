extends State

class_name IdleState

func _init().():
	m_physics_process_enabled = false
	m_input_enabled = false
	resource_name = "idle"

func __process(_delta: float) -> void:
	# Start patrolling when the player gets closer to us
	if m_managed_object_weakref.get_ref().should_patrol():
		# Transitionable state
		m_state_machine_weakref.get_ref().transition("patrol")
		# Uniquely-stackable state
		m_state_machine_weakref.get_ref().push_unique("powerup")

func __on_enter_state(_p_transition_dictionary : Dictionary = {}) -> void:
	m_managed_object_weakref.get_ref().say("I feel at peace.")

func __on_exit_state() -> void:
	m_managed_object_weakref.get_ref().say("I feel uneasy...")
