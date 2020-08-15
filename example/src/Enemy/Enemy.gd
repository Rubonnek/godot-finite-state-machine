extends Node2D

class_name Enemy

const ENEMY_ATTACK_DISTANCE: float = 200.0
const ENEMY_PATROL_DISTANCE: float = 400.0

var last_shot_time: int = 0
var state_machine : StateMachine

onready var player = $"/root/World/Player"
onready var patrol_circle = $PatrolCircle
onready var attack_circle = $AttackCircle

onready var idle_state : State = IdleState.new()
onready var patrol_state : State = PatrolState.new()
onready var attack_state : State = AttackState.new()
onready var powerup_state : State = PowerUpState.new()

func _ready() -> void:
	state_machine = StateMachine.new()
	state_machine.set_managed_object(weakref(self))
	state_machine.initial_state_ = idle_state
	state_machine.transitionable_states_ = [
			idle_state,
			patrol_state,
			attack_state,
		]
	state_machine.stackable_states_ = [
			powerup_state
		]
	state_machine.transitions_ = [
			{"from": idle_state, "to_states": [ patrol_state, attack_state]},
			{"from": patrol_state, "to_states": [ idle_state, attack_state]},
			{"from": attack_state, "to_states": [ idle_state, patrol_state]}
		]

	# Initialize internal structures
	state_machine.initialize()
	print(state_machine.get_transitions())

	# Here we setup the ranges around the unit for visual aids
	patrol_circle.points = 64
	patrol_circle.color = Color(0, 1, 1)
	patrol_circle.diameter = ENEMY_PATROL_DISTANCE

	attack_circle.points = 64
	attack_circle.color = Color(1, 0, 0)
	attack_circle.diameter = ENEMY_ATTACK_DISTANCE

# This is required so that our FSM can handle updates
func _input(event: InputEvent) -> void:
	state_machine.input(event)

func _process(delta: float) -> void:
	state_machine.process(delta)

func distance_from_player() -> float:
	"""
	Returns the distance to the players position
	"""
	return position.distance_to(player.position)

func should_patrol() -> bool:
	"""
	Returns true if we should be patrolling (the player is close)
	"""
	return distance_from_player() < ENEMY_PATROL_DISTANCE

func has_enemies() -> bool:
	"""
	If we're close to the player, set them as our primary enemy
	"""
	return distance_from_player() < ENEMY_ATTACK_DISTANCE

func can_shoot() -> bool:
	"""
	We should not be able to always fire at the player
	This function only returns true when some time has passed since the last shot
	"""
	return OS.get_system_time_secs() - last_shot_time > 0

func attack_enemies() -> void:
	"""
	Fire at the player if we're reloaded and update the time we shot last
	"""
	if not can_shoot():
		return

	last_shot_time = OS.get_system_time_secs()
	print("Shooting at player")

func say(message: String) -> void:
	print("Target says: ", message)
