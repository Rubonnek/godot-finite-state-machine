extends Resource
class_name StateMachineFactory

# State Machine Factory Example:
# TODO: Fix this
#
#	# State instances must be created first
#	var idle_state = IdleState.new()
#	var patrol_state = PatrolState.new()
#	var attack_state = AttackState.new()
#	var powerup_state = PowerupState.new()
#
#	var smf = StateMachineFactory.new()
#	state_machine = smf.create({
#		"managed_object": self,
#		"transitionable_states": [
#			idle_state,
#			patrol_state,
#			attack_state,
#		],
#		"current_transitionable_state": idle_state,
#		"stackable_states": [
#			powerup_state,
#		],
#		"transitions": [
#			{"from": idle_state, "to_states": [patrol_state, attack_state]},
#			{"from": patrol_state, "to_states": [idle_state, attack_state]},
#			{"from": attack_state, "to_states": [idle_state, patrol_state]}
#		]
#	})
#


func create(p_config : Dictionary) -> StateMachine:
	"""
	Factory method accepting an optional configuration object
	"""
	var state_machine = StateMachine.new()
	state_machine.managed_object_ = p_config["managed_obnject"]
	state_machine.transitionable_states_ = p_config["transitionable_states"]
	state_machine.stackable_states_ = p_config["current_transitionable_state"]
	state_machine.transitions_ = p_config["transitions"]
	state_machine.initialize()
	return state_machine



func create_with_parameters(p_managed_object : NodePath, p_transitionable_states : Array, p_stackable_states : Array, p_transitions : Array) -> StateMachine:
	var state_machine = StateMachine.new()
	state_machine.managed_object_ = p_managed_object
	state_machine.transitionable_states_ = p_transitionable_states
	state_machine.stackable_states_ = p_stackable_states
	state_machine.transitions_ = p_transitions
	state_machine.initialize()
	return state_machine
