tool
extends Resource
class_name StateMachine
"""
StateMachine class to manage states -- many state machines can exists.

State Types:
	Stackable States - states whose properties can be stack on top of each other. These can be pushed and popped off the stack and are created on the fly.
	Transitionable States - states whose instance is saved these states is saved across transitions
"""

# TODO: Change all the get_id functions to get_name functions

signal state_pushed(p_pushed_state)
signal state_transitioned(p_from_state, p_to_state, p_transition_data)
signal state_popped(p_pushed_state)

export (Resource) var initial_state_ = null # Holds externally initialized transitionable state instances
export (Array, Resource) var transitionable_states_ = [] # Holds externally initialized transitionable state instances
export (Array, Resource) var stackable_states_ = [] # Holds the state class of the stackable states
export (Array, Dictionary) var transitions_ = []

var m_transitionable_states : Dictionary = {} # Holds the currently saved instances of the transitionable states referenced by their class ID

# The state machine's target object, node, etc
var m_managed_object_weakref : WeakRef = null # using weakref to avoid memory leaks due to cyclic references

# Classes to make it easy to create new objects, and also to track if we are including more than one of the same classes by mistake
var m_stackable_classes : Dictionary = {} # Holds a reference of the state class which is map to its state class contained in a GDScript object

# Dictionary of valid state transitions
var m_transitions : Dictionary = {}

# Reference to the current transitionable state object
var m_current_transitionable_state : State

# TODO: Pushing stackable states to the front (with push_front) for processing
# will affect the position of the transitionable state on the stack which, when
# transitioning over to a new state, increases the complexity of changing
# transition from O(1) to O(n).  In order to keep the state transition change
# at complexity O(1), we could track the current transitionable state index on
# the stack but this would also mean properly implementing a StackableState
# class. I don't think the performance enhancement will be needed, so I'm just
# going to kepe this class as-is.
#var m_current_transitionable_state_index : int

# Stack of state instances currently being processed:
var m_states_stack : Array = []
# TODO: In order to enhance push_unique/pop_unique performance, a dictionary
# that keeps track of what state IDs are on the stack and how many of them
# there are is useful -- implementing this should be trivial, but for now this
# performance enhancement is not needed and may never be.

# Dictionary that backs up the processing state of each state on the stack
# during freeze/unfreeze. This is so that some states can freeze the processing
# of other states until they are done
var m_state_stack_process_backup : Dictionary = {}

func set_managed_object(p_object_weakref : WeakRef) -> void:
	"""
	Sets the managed object
	"""
	m_managed_object_weakref = p_object_weakref


func get_managed_object() -> Object:
	"""
	Returns the objects this state machine is managing the state for
	"""
	return m_managed_object_weakref.get_ref()


func get_transitionable_states() -> Dictionary:
	"""
	Returns the dictionary of transitionable states
	"""
	return m_transitionable_states


func get_stackable_classes() -> Dictionary:
	"""
	Returns the array of stackable states
	"""
	return m_stackable_classes


func get_state_classes() -> Dictionary:
	"""
	Returns the dictionary of stackable states
	"""
	return m_stackable_classes


func get_states_stack() -> Array:
	"""
	Returns the states stack
	"""
	return m_states_stack


func get_transitions() -> Dictionary:
	"""
	Returns the dictionary of transitions
	"""
	return m_transitions


func push(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	"""
	Guarantees state processing order is not modified
	Pushed stackable state will be processed last than the rest
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__push_back", p_state_id, p_transition_data)


func __push_back(p_state_id : String, p_transition_data : Dictionary = {}):
	if p_state_id in m_stackable_classes:
		var p_state : State = __create_state(p_state_id)

		if p_state.m_enter_state_enabled:
			p_state.__on_enter_state(p_transition_data)

		m_states_stack.push_back(p_state)
		emit_signal("state_pushed", p_state)
	else:
		push_error("Cannot push invalid stackable state id \"" + p_state_id + "\" to the back of the stack: " )


func push_front(p_state_class : GDScript, p_transition_data : Dictionary = {}) -> void:
	"""
	Pushed state will be processed first than the rest
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__push_front", p_state_class, p_transition_data)


func __push_front(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	if p_state_id in stackable_states_:
		var p_state : State = __create_state(p_state_id)

		if p_state.m_enter_state_enabled:
			p_state.__on_enter_state(p_transition_data)

		m_states_stack.push_front(p_state)
		emit_signal("state_pushed", p_state)
	else:
		push_error("Cannot push invalid stackable state to the front of the stack: " + str(p_state_id))


func push_unique(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	"""
	Guarantees state processing order is not modified - state will be processed last
	If a previous state with the same ID exists, it will not be added to the stack
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__push_back_unique", p_state_id, p_transition_data)


func __push_back_unique(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	if p_state_id in m_stackable_classes:
		for state in m_states_stack:
			if state.get_id() == p_state_id:
				push_warning("State ID \"" + p_state_id + "\" is already being processed on the stack. Skipping...")
				return

		var p_state : State = __create_state(p_state_id)

		if p_state.m_enter_state_enabled:
			p_state.__on_enter_state(p_transition_data)

		m_states_stack.push_back(p_state)
		emit_signal("state_pushed", p_state)
	else:
		push_error("Cannot push invalid state with id \"" + p_state_id + "\"to the back of the stack: ")


func push_front_unique(p_state_class : GDScript, p_transition_data : Dictionary = {}) -> void:
	"""
	Pushed state will be processed first
	If a previous state with the same ID exists, it will not be added to the stack.
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__push_front_unique", p_state_class, p_transition_data)


func __push_front_unique(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	if p_state_id in m_stackable_classes:
		for state in m_states_stack:
			if state.get_id() == p_state_id:
				push_warning("State ID \"" + p_state_id + "\" is already being processed on the stack. Skipping...")
				return

		var p_state : State = __create_state(p_state_id)

		if p_state.m_enter_state_enabled:
			p_state.__on_enter_state(p_transition_data)

		m_states_stack.push_front(p_state)
		emit_signal("state_pushed", p_state)
	else:
		push_error("Cannot push invalid stackable state with id \"" + p_state_id + "\"to the front of the stack")


func pop() -> void:
	"""
	Guarantees state processing order is not modified
	Removes the state that is being processed last
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__pop_back")


func __pop_back() -> void:
	if len(m_states_stack) == 1:
		push_error("Could not pop state from the stack -- there's is only one element: " + m_states_stack[0].get_id())
		return

	var p_state : State = m_states_stack.pop_back()

	if p_state == m_current_transitionable_state:
		m_states_stack.push_back(p_state)
		push_error("Cannot not pop transitionable state with id \"" + m_current_transitionable_state.new().get_id() + "\"from the stack" )
		return

	if p_state.m_exit_state_enabled:
		p_state.__on_exit_state()

	emit_signal("state_popped", p_state)


func pop_state(p_state : State):
	"""
	Removes a specific state from the stack if found
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__pop_state", p_state)


func __pop_state(p_state : State):
	if len(m_states_stack) == 1:
		push_error("Could not pop state from the stack -- there's is only one element: " + m_states_stack[0].get_id())
		return

	if p_state == m_current_transitionable_state:
		push_error("Cannot not pop transitionable state from the stack: " + m_current_transitionable_state.get_id())
		return

	if p_state in m_states_stack:
		m_states_stack.erase(p_state)
		if p_state.m_exit_state_enabled:
			p_state.__on_exit_state()
		emit_signal("state_popped", p_state)
	else:
		push_error("Could not pop state " + str(p_state) + " with id \"" + p_state.get_id() +"\"")


func pop_front() -> void:
	"""
	Remove state that is being processed first
	"""
	# The stack could be getting processed when this function fires -- better
	# to call it during idle time.
	call_deferred("__pop_front")


func __pop_front() -> void:
	if len(m_states_stack) == 1:
		push_error("Could not pop state from the stack -- there's is only one element: " + m_states_stack[0].get_id())
		return

	var p_state : State = m_states_stack.pop_front()

	if p_state == m_current_transitionable_state:
		m_states_stack.push_front(p_state)
		push_error("Cannot not pop transitionable state from the stack: " + m_current_transitionable_state.get_id())
		return

	if p_state.m_exit_state_enabled:
		p_state.__on_exit_state()

	emit_signal("state_popped", p_state)


func get_current_state() -> State:
	"""
	Returns the string id of the current state
	"""
	return m_current_transitionable_state


func get_current_state_id() -> String:
	"""
	Returns the string id of the current state
	"""
	return m_current_transitionable_state.get_id()


func set_state_machine(p_states : Array) -> void:
	"""
	Expects an array of states to iterate over and pass self to the state's set_machine_state() method
	"""
	for state in p_states:
		state.set_state_machine(weakref(self))


func set_transition(p_state : State, p_to_states : Array) -> void:
	"""
	Set valid transitions for a state. Expects state class and array of to state class.
	If a state class does not exist in states dictionary, the transition will NOT be added.
	"""
	if p_state.get_id() in m_transitionable_states:
		if p_state.get_id() in m_transitions:
			assert(false, "Overwriting transition for state with id: " + p_state.get_id())
		# Need to convert from states to 
		var state_id_array : Array
		for state in p_to_states:
			state_id_array.push_back(state.get_id())
		m_transitions[p_state.get_id()] = {"to_states" : state_id_array}
	else:
		if p_state.get_id() == "":
			assert(false, "Cannot set transition -- state id is empty id!")
		else:
			assert(false, "Cannot set transition, invalid state with id: " + p_state.get_id())


func add_transition(from_state_class : GDScript, p_to_state_class : GDScript) -> void:
	"""
	Add a transition for a state. This adds a single state to transitions whereas
	set_transition is a full replace.
	"""
	if !(from_state_class in m_transitionable_states) || !(p_to_state_class in m_transitionable_states):
		assert(false, "Cannot add transition, one of more invalid state(s)" + 
				"found. Either: from state \"" + from_state_class.new().get_id() + "\" or"
				+ "to state class \"" +  p_to_state_class.new().get_id() + "\"")
		return

	if from_state_class in m_transitions:
		m_transitions[from_state_class]["to_states"].append(p_to_state_class)
	else:
		m_transitions[from_state_class] = {"to_states": [p_to_state_class]}


func get_state(p_state_id : String) -> State:
	"""
	Return the internal transitionable state instance from the states dictionary by state class if it exists
	"""
	if p_state_id in m_transitionable_states:
		return m_transitionable_states[p_state_id]
	else:
		push_warning("Could not find transitionable state with state id: " + p_state_id)
		return null


func get_transition(p_state_class : GDScript) -> Dictionary:
	"""
	Return the transition from the transitions dictionary by state class if it exists
	"""
	var p_state_id = p_state_class.new().get_id()
	if p_state_class in m_transitions:
		return m_transitions[p_state_class]

	assert(false, "Cannot get transition, received invalid state with id: " + p_state_id)
	return {}


func set_current_transitionable_state(p_state : State) -> void:
	"""
	This is a 'just do it' method and does not validate transition change. It's
	important to point out that p_state should NOT be inserted directly into
	the state stack because the State instance we may get here may not be the
	same as the one stored within m_transitionable_states.
	"""
	if p_state.get_id() in m_transitionable_states:
		if len(m_states_stack) == 0: # this is the first state we are settting the StateMachine to
			m_current_transitionable_state = m_transitionable_states[p_state.get_id()]
			m_states_stack.append(m_current_transitionable_state)
		else:
			if m_current_transitionable_state:
				var current_state_index : int = m_states_stack.find(m_current_transitionable_state)
				if current_state_index != -1:
					m_states_stack[current_state_index] = m_transitionable_states[p_state.get_id()]
					m_current_transitionable_state = m_transitionable_states[p_state.get_id()]
					#m_current_transitionable_state_index = current_state_index
				else:
					# There must always be one transitionable state running -- this case should not appen at all
					assert(false, "Cannot set transitionable state! Transitionable state not found within the states stack! This should not happen at all!: " + str(m_current_transitionable_state))
			else:
				assert(false, "Current transitionable state is not set but it should because the state stack has been populated!")

	else:
		push_error("Cannot set current state -- attempted to set invalid non-registered transitionable state with id: " + p_state.get_id())


func transition(p_state_id : String, p_transition_data : Dictionary = {}) -> void:
	"""
	Transition to new state by state class.
	Callbacks will be called on the from and to states if the states have implemented them.
	"""
	if not m_transitions.has(m_current_transitionable_state.get_id()):
		assert(false, "No transitions defined for state %s" % m_current_transitionable_state.get_id())
	if !p_state_id in m_transitionable_states || !p_state_id in m_transitions[m_current_transitionable_state.get_id()]["to_states"]:
		assert(false, "Invalid transition from %s" % m_current_transitionable_state.get_id() + " to %s" % p_state_id)

	var from_state : State = m_current_transitionable_state
	var to_state : State = get_state(p_state_id)

	if from_state.m_exit_state_enabled:
		from_state.__on_exit_state()

	# Update local references
	set_current_transitionable_state(to_state)

	if to_state.m_enter_state_enabled:
		to_state.__on_enter_state(p_transition_data)

	emit_signal("state_transitioned", from_state.get_id(), to_state.get_id(), p_transition_data)


func process(p_delta : float) -> void:
	"""
	Callback to handle _process(). Must be called manually by code
	"""
	for state in m_states_stack:
		if state.m_process_enabled:
			state.__process(p_delta)


func physics_process(p_delta : float) -> void:
	"""
	Callback to handle _physics_process(). Must be called manually by code
	"""
	for state in m_states_stack:
		if state.m_physics_process_enabled:
			state.__physics_process(p_delta)


func input(p_event : InputEvent) -> void:
	"""
	Callback to handle _input(). Must be called manually by code
	"""
	for state in m_states_stack:
		if state.m_input_enabled:
			state.__input(p_event)


func unhandled_input(p_event : InputEvent) -> void:
	"""
	Callback to handle _input(). Must be called manually by code
	"""
	for state in m_states_stack:
		if state.m_unhandled_input_enabled:
			state.__unhandled_input(p_event)


func gui_input(p_event : InputEvent) -> void:
	"""
	Callback to handle _input(). Must be called manually by code
	"""
	for state in m_states_stack:
		if state.m_gui_input_enabled:
			state.__gui_input(p_event)


func freeze_except(p_state : State) -> void:
	"""
	Call to freeze processing on every state except the one specified
	Useful for using on State.__on_enter_state when a single state must be processed
	"""
	if len(m_state_stack_process_backup) > 0:
		push_warning("StateMachine has been frozen previously -- unfreeze data could possibly be lost")

	for state in m_states_stack:
		if state != p_state:
			# Backup State
			m_state_stack_process_backup[state]["is_process_enabled"] = state.is_process_enabled()
			m_state_stack_process_backup[state]["is_physics_process_enabled"] = state.is_physics_process_enabled()
			m_state_stack_process_backup[state]["is_input_enabled"] = state.is_input_enabled()
			m_state_stack_process_backup[state]["is_enter_state_enabled"] = state.is_enter_state_enabled()
			m_state_stack_process_backup[state]["is_exit_state_enabled"] = state.is_exit_state_enabled()

			# Disable processing
			state.set_process_enabled(false)
			state.set_physics_process_enabled(false)
			state.set_input_enabled(false)
			state.set_enter_state_enabled(false)
			state.set_exit_state_enabled(false)


func unfreeze() -> void:
	"""
	Call to unfreeze processing on the remaining states
	Useful for using on State.__on_exit_state when the current state has previously frozen the processing of the remaining states
	"""
	if len(m_state_stack_process_backup) == 0:
		assert(false, "StateMachine has never been freezed previously! Cannot unfreeze state stack!")
		return

	for state in m_states_stack:
		if state in m_state_stack_process_backup:
			state.set_process_enabled(m_state_stack_process_backup[state]["is_process_enabled"])
			state.set_physics_process_enabled(m_state_stack_process_backup[state]["is_physics_process_enabled"])
			state.set_input_enabled(m_state_stack_process_backup[state]["is_input_enabled"])
			state.set_enter_state_enabled(m_state_stack_process_backup[state]["is_enter_state_enabled"])
			state.set_exit_state_enabled(m_state_stack_process_backup[state]["is_exit_state_enabled"])

	# Clear backup
	m_state_stack_process_backup.clear()


# Public function for initializing state machine once the exported values has
# been set properly
func initialize() -> void:
	# Initial error checking:
	if len(m_stackable_classes) > 0:
		push_warning("StateMachine has been previously initialized! Cannot initialize again!")
		return
	if len(transitionable_states_) == 0:
		push_warning("Unable to initialize StateMachine -- there are no transtitionable states to be added")
		return
	if m_managed_object_weakref == null:
		assert(false, "Unable to iniitialize without a valid managed object weakref. Did you forget to call: StateMachine.set_managed_object(weakref(object))?")
		return

	# Note: we are not checking stackable states because they are optional

	# Initialize the transitionable states internally -- we get the class instances when we set them through the editor
	for state_instance in transitionable_states_:
		if state_instance:
			# Add transitionable state to Dictionary
			if state_instance.get_id() in m_transitionable_states:
				assert(false, "Found class with duplicate state class \"" + state_instance.get_id() + "\" -- cannot continue")
			m_transitionable_states[state_instance.get_id()] = state_instance

			# Initialize internal state instance variables
			state_instance.set_state_machine(weakref(self))

			if m_managed_object_weakref:
				state_instance.set_managed_object(m_managed_object_weakref)
			else:
				assert(false, "Managed object is null, could not set managed object to state instances. Make sure to set the managed object on the StateMachine before delegating it's __ready method")
		else:
			assert(false, "Received null state instance")
	# We don't need these instances anymore
	transitionable_states_.clear()


	# Set Stackable Instances
	for state_instance in stackable_states_:
		var state_class = state_instance.get_script()
		if state_instance.get_id() in m_stackable_classes:
			assert(false, "State with id \"" + state_instance.new().state_instance.get_id() + "\" is getting overwritten on m_stackable_classes. This is unsupported.")
		# We only need to keep track of the stackable state class, not the instance itself
		m_stackable_classes[state_instance.get_id()] = state_class
	# No need to hold these instances anymore -- clear memory
	stackable_states_.clear()

	
	# Set Transitions
	for transition_dictionary in transitions_:
		set_transition(transition_dictionary["from"], transition_dictionary["to_states"])
	
	# Finally set initial transitionable state
	set_current_transitionable_state(initial_state_)
	


# Private Functions
func __create_state(p_state_id : String) -> State:
	if !(p_state_id in m_stackable_classes):
		assert(false, "State with id \"" + p_state_id + "\" is not a stackable state")
	var new_state = m_stackable_classes[p_state_id].new()
	new_state.set_state_machine(weakref(self))
	if m_managed_object_weakref:
		new_state.set_managed_object(m_managed_object_weakref)
	else:
		assert(false, "Could not set managed object on created state class with id: " + p_state_id)
	return new_state

func _init():
	# Exported values will always be null during resource initialization -- there's not much we can do here.
	# This is mostly to verify that member variables are set as expected, or to
	# setup variables that are then visible inside the Editor. The latter
	# requires the script to use the tool keyword, which is what we do here.

	# Setup the resource name equal to the class_name so that it's visible within the Editor
	resource_name = "StateMachine"

func __ready():
	# To access exported variables instances you have to use a delegated Node._ready callback

	# At this point the exported variables in the editor have been initialized
	# in the editor -- we can use them.

	# Forward initialization to public function
	initialize()
