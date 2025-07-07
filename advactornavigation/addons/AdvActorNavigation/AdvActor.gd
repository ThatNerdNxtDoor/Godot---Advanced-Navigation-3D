## A variation of [CharacterBody3D] that comes pre-built with 4 sets of default navigation behavior
## that can be customised in the inspector.
extends CharacterBody3D
class_name AdvNavigationActor3D

enum NavBehavior {
	## The Actor will remain stationary.
	IDLE,
	## The Actor moves directly to the specified target position.
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
@export var nav_behavior: NavBehavior = NavBehavior.IDLE

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
var patrol_index = 0

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
## location to pursue it.
var target_entity

## The distance the Actor will stay in from the target position. If the target comes closer than the
## engage distance, the Actor will back away to the intended distance.
@export var engage_distance : float = 3.0

## The distance the Actor will when pursuing a target position before returning to normal behavior.
@export var pursuit_distance : float = 20.0

#---------------------------------------------------------------------------------------------------

## Uses the [param default_gravity] setting from the ProjectSettings folder.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
## The position that the Actor is currently moving towards.
var movement_goal: Vector3

## Sets the position of the navigation target for the Actor.
func set_target_position(target_pos : Vector3):
	pass

func pursue():
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	nav_agent.connect("target_reached", _on_navigation_agent_3d_target_reached)
	nav_agent.path_desired_distance = 1
	nav_agent.target_desired_distance = 5
	
	nav_timer.connect("timeout", _nav_timer_timeout)
	nav_timer.wait_time 
	pass # Replace with function body.

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
	#If the actor is pursuing a 
	match(nav_behavior):
		NavBehavior.IDLE:
			pass
		NavBehavior.DIRECT:
			pass
		NavBehavior.WANDERING:
			pass
		NavBehavior.PATROLLING:
			pass

## Calculates the movement velocity of the Actor based on tis current target position.
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
	
	# If the Actor can jump, it will do so if it needs to reach its target.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif ((current_actor_position.direction_to(next_path_position).y >= 0.9) &&
	(abs(current_actor_position.direction_to(next_path_position).x) < 0.01 &&
	abs(current_actor_position.direction_to(next_path_position).z) < 0.01) && can_jump):
		velocity.y = jump_velocity

#---------------------------------------------------------------------------------------------------
#Signal Functions

## 
func _on_navigation_agent_3d_target_reached():
	if nav_behavior == NavBehavior.PATROLLING:
		nav_timer.start()
	pass # Replace with function body.

func _nav_timer_timeout():
	if nav_behavior == NavBehavior.WANDERING:
		pass
	elif nav_behavior == NavBehavior.PATROLLING:
		patrol_index = (patrol_index + 1) % patrol_route.size()
		set_target_position(patrol_route[patrol_index])
