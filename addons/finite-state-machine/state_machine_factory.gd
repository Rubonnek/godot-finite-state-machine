extends Resource
class_name StateMachineFactory

# State Machine Factory Example:
#
#	state_machine = StateMachineFactory.create_with_dictionary({
#		"managed_object" : self,
#		"initial_state" : idle_state,
#		"transitionable_states" : [
#			idle_state,
#			patrol_state,
#			attack_state,
#			],
#		"stackable_states" : [
#			powerup_state,
#			],
#		"transitions" : [
#			{"from": idle_state, "to_states": [patrol_state, attack_state]},
#			{"from": patrol_state, "to_states": [idle_state, attack_state]},
#			{"from": attack_state, "to_states": [idle_state, patrol_state]},
#			],
#		})


static func create_with_dictionary(p_config : Dictionary) -> StateMachine:
	"""
	Factory method accepting an optional configuration object
	"""
	var state_machine = StateMachine.new()
	state_machine.set_managed_object(weakref(p_config["managed_object"]))
	state_machine.initial_state_ = p_config["initial_state"]
	state_machine.transitionable_states_ = p_config["transitionable_states"]
	state_machine.stackable_states_ = p_config["stackable_states"]
	state_machine.transitions_ = p_config["transitions"]
	state_machine.initialize()
	return state_machine



static func create_with_parameters(p_managed_object : Object, p_initial_state : State, p_transitionable_states : Array, p_stackable_states : Array, p_transitions : Array) -> StateMachine:
	var state_machine = StateMachine.new()
	state_machine.set_managed_object(weakref(p_managed_object))
	state_machine.initial_state_ = p_initial_state
	state_machine.transitionable_states_ = p_transitionable_states
	state_machine.stackable_states_ = p_stackable_states
	state_machine.transitions_ = p_transitions
	state_machine.initialize()
	return state_machine
