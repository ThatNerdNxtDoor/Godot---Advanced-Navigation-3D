## A variation of [CharacterBody3D] that comes pre-built with 4 sets of default navigation behavior
## that can be customised in the inspector.
extends CharacterBody3D
class_name AdvNavigationActor3D

enum NavBehavior {
	## The Actor will remain stationary, effectively disabling its navigation until it has something
	## to pursue.
	IDLE,
	## The Actor moves directly to the specified target position. This position can be set with 
	## [method set_target_position]. This can be used for an enemy walking into position and staying
	## there, or an npc that is being controlled by a player (such as troops in an RTS game).
	DIRECT,
	## The Actor will wander to randomly determined points within a specified circular range within 
	## a specified anchor point. The [param nav_time] will determine how long it will take before a
	## new wandering point is be generated. The Actor will not move beyond this range, and will attempt to
	## re-enter the range if the Actor leaves it.
	WANDERING, 
	## The Actor will move through a set of specified points in a patrol routine. The [param nav_time] will
	## be used to determine how long the Actor will stay at a destination point when it arrives 
	## there. If the actor is moved away from that point, it will attempt to return to it. 
	PATROLLING}

## The preset behavioral nature of the Actor. When not pursuing a target position, this is the
## default behavior of the Actor.
@export var nav_behavior: NavBehavior = NavBehavior.DIRECT

#---------------------------------------------------------------------------------------------------
@export_group("Universal")

## The [NavigationAgent3D] Node the Actor uses to move.
@export var nav_agent : NavigationAgent3D

## The [Timer] Node the Actor Uses when [param NavBehavior.PATROLLING] or [param NavBehavior.WANDERING].
## Signal connections are automatically made in [method _ready].
@export var nav_timer : Timer

## The amount of time (in seconds) the [param nav_timer] will be set to. This effects how long the Actor waits
## until choosing a new spot to wander to when [param NavBehavior.WANDERING], or how long the Actor 
## waits until moving to the next patrol point when [param NavBehavior.PATROLLING].
@export_range(5.0, 60.0) var nav_time : float = 20.0

## The movement speed of the Actor.
@export var movement_speed : float = 2.0

#---------------------------------------------------------------------------------------------------
@export_subgroup("Jumping")
## Determines if the Actor can jump. If the next position in the nav path requires vertical movement,
## the Actor can jump with a predefined [param jump_velocity].
@export var can_jump : bool = true

## The launch velocity the Actor will jump with.
@export var jump_velocity : float = 2.0

#---------------------------------------------------------------------------------------------------
@export_group("Patrolling")

## Determines if the [param patrol_route] will start at a random index in the array. If False, it
## will start from index 0.
@export var random_start_index : bool = false

## An array of Vector3 points that the [param NavBehavior.PATROLLING] Nav Behavior uses. Each
## Vector3 corresponds to a global position. The Nav Behavior resets to index 0 after reaching the
## end of the array.
@export var patrol_route : Array[Vector3] = [Vector3(0, 0, 0)]

## The current destination of he patrol route.
var patrol_index : int = 0

#---------------------------------------------------------------------------------------------------
@export_group("Wandering")

## Defines the central point of the wandering range of the Actor during its [param NavBehavior.WANDERING] Nav Behavior.
@export var anchor_point : Vector3 = Vector3(0, 0, 0)

## The circular range in which a wandering point can be defined for the Actor during its
## [param NavBehavior.WANDERING] Nav Behavior.
@export var wander_range : float = 5

#---------------------------------------------------------------------------------------------------
@export_group("Pursuit")

## When a valid target falls into the aggro range of the Actor, it will tag that entity and use its
## location to pursue it. The variable also determines if the actor is in pursuit mode or not, as
## a null [param pursuit_entity] means the Actor has no reason to continue pursuing.
var pursuit_entity : Node3D

## The distance the Actor will stay in from the target position. If the target comes closer than the
## engage distance, the Actor will back away to the intended distance. If
@export var engage_distance : float = 3.0

## The max distance the Actor can be from the [oaram pursuit_entity]. If the pursuit entity leaves
## this range, the Actor returns to normal behavior.
@export var pursuit_distance : float = 20.0

#---------------------------------------------------------------------------------------------------

## Uses the [param default_gravity] setting from the ProjectSettings folder.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
## The position that the Actor is moving towards when not pursuing.
var base_movement_goal: Vector3

## Sets the position of the navigation target for the Actor.
func set_target_position(target_pos : Vector3):
	print("new target")
	nav_agent.target_position = target_pos

## Activates the pursuit mode for the Actor. The Actor will continue to move towards the 
## [param pursuit_entity]'s position until they are a specified distance away from their original point.
func pursue(target : Node3D):
	# If it is not already pursuing something else, then it will save where it was originally going
	# so that it can return there when the pursuit is over.
	if pursuit_entity == null:
		base_movement_goal = nav_agent.target_position
	
	pursuit_entity = target
	nav_timer.paused = true

##
func actor_setup():
	await get_tree().physics_frame

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the navigation agent to its needed functions.
	nav_agent.target_reached.connect(_on_navigation_agent_3d_target_reached)
	nav_agent.path_desired_distance = 1.5
	nav_agent.target_desired_distance = 1.5
	
	# Connect the navigation timer to the needed functions.
	nav_timer.timeout.connect(_nav_timer_timeout)
	nav_timer.wait_time = nav_time
	nav_timer.one_shot = true
	
	# Wait for the physics frame in the scene to be initialized.
	actor_setup.call_deferred()
	
	print("starting nav")
	#kick-off the navigation for relevant behavioral subsets
	match(nav_behavior):
		NavBehavior.WANDERING:
			( set_target_position(Vector3(anchor_point.x + randf_range(-wander_range, wander_range),
			anchor_point.y, anchor_point.z + randf_range(-wander_range, wander_range))) )
			nav_timer.start()
		NavBehavior.PATROLLING:
			set_target_position(patrol_route[randi_range(0, patrol_route.size()) if random_start_index else 0])
	print(nav_agent.target_position)

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	behavior_calculation()
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		movement_calculation(delta)
	move_and_slide()

## Calculates the target position based on the Actor's behavioral subset.
func behavior_calculation():
	#If the actor is pursuing a pursuit_enity, attempt to resolve that first
	if pursuit_entity != null:
		# If pursuit_entity is out of pursuit_range, the Actor will end its pursuit.
		if global_position.distance_to(pursuit_entity.global_position) > pursuit_distance:
			pursuit_entity = null
			nav_timer.paused = false
			set_target_position(base_movement_goal)
		# If pursuit_entity is not withing the engage_distance, it will attempt to move closer or 
		# farther away.
		elif engage_distance - .25 > global_position.distance_to(pursuit_entity.global_position):
			( set_target_position(global_position.direction_to(pursuit_entity.global_position)
			* -(engage_distance - global_position.distance_to(pursuit_entity.global_position))) )
		elif global_position.distance_to(pursuit_entity.global_position) > engage_distance + .25:
			set_target_position(pursuit_entity.global_position)
	else:
		pass
		# Any special fram-by-frame behavior will be here.
		#match(nav_behavior):
		#	NavBehavior.IDLE:
		#		pass
		#	NavBehavior.DIRECT:
		#		pass
		#	NavBehavior.WANDERING:
		#		pass
		#	NavBehavior.PATROLLING:
		#		pass

## Calculates the movement velocity of the Actor based on its current postion and the target position.
func movement_calculation(delta):
	# The Actor's current position.
	var current_actor_position : Vector3 = global_position
	# The next point in the navigation path according to the nav agent.
	var next_path_position : Vector3 = nav_agent.get_next_path_position()
	# The next point in the nav path is 'flattened' to the current y position to give a
	# normalized x and z vector.
	var next_path_pos_flattened : Vector3 = Vector3(next_path_position.x, current_actor_position.y, next_path_position.z)
	
	# The Actor is made to face the direction it will move in.
	self.look_at(next_path_pos_flattened)
	velocity.x = current_actor_position.direction_to(next_path_pos_flattened).x * (movement_speed)
	velocity.z = current_actor_position.direction_to(next_path_pos_flattened).z * (movement_speed)
	
	# If the actor is not on the floor, it will be affected by gravity.
	# If the Actor can jump, it will do so if it needs to reach its target.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif ((current_actor_position.direction_to(next_path_position).y >= 0.9) &&
	(abs(current_actor_position.direction_to(next_path_position).x) < 0.01 &&
	abs(current_actor_position.direction_to(next_path_position).z) < 0.01) && can_jump):
		velocity.y = jump_velocity

#---------------------------------------------------------------------------------------------------
#Signal Functions

## Triggers when the Actor reaches its target destination.
func _on_navigation_agent_3d_target_reached():
	print("destination")
	if nav_behavior == NavBehavior.PATROLLING && pursuit_entity == null:
		nav_timer.start()
	pass # Replace with function body.

## Triggers when the [param nav_timer] is timed out.
func _nav_timer_timeout():
	print("timeout")
	if nav_behavior == NavBehavior.WANDERING:
		( set_target_position(Vector3(anchor_point.x + randf_range(-wander_range, wander_range),
		anchor_point.y, anchor_point.z + randf_range(-wander_range, wander_range))) )
		nav_timer.start()
	elif nav_behavior == NavBehavior.PATROLLING:
		patrol_index = (patrol_index + 1) % patrol_route.size()
		set_target_position(patrol_route[patrol_index])
