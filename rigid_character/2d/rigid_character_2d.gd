@icon("../icons/rigid_character_2d.svg")
class_name RigidCharacter2D
extends CharacterBody2D

##
##
##

enum MotionBase {
	DEFAULT, ##
	UP_DIRECTION, ##
	GLOBAL_ROTATION ##
}

enum MotionComponent {
	X, ##
	Y, ##
}

##
@export_range(0.0, 9999.9, 0.1, "or_greater", "hide_slider", "suffix:kg")
var mass: float = 1.0:
	set(value):
		PhysicsServer2D.body_set_param(get_rid(), PhysicsServer2D.BODY_PARAM_MASS, value)
	get:
		return PhysicsServer2D.body_get_param(get_rid(), PhysicsServer2D.BODY_PARAM_MASS)
## 
@export var motion_base: MotionBase = MotionBase.UP_DIRECTION:
	set(value):
		if value == motion_base:
			return
		motion_base = value
		motion = motion # Updates the motion by triggering the setter
##
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") 
var motion: Vector2:
	set(value):
		match motion_base:
			MotionBase.DEFAULT:
				velocity = value
			MotionBase.UP_DIRECTION:
				velocity = value.rotated(up_direction_rotation)
			MotionBase.GLOBAL_ROTATION:
				velocity = value.rotated(global_rotation)
	get:
		match motion_base:
			MotionBase.DEFAULT:
				return velocity
			MotionBase.UP_DIRECTION:
				return velocity.rotated(-up_direction_rotation)
			MotionBase.GLOBAL_ROTATION:
				return velocity.rotated(-global_rotation)
		return Vector2.INF # This should never happen, but just in case.

@export_group("Gravity")
##
@export_range(0.0, 10.0, 0.1, "or_greater")
var gravity_scale: float = 1.0:
	set(value):
		PhysicsServer2D.body_set_param(get_rid(), PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, value)
	get:
		return PhysicsServer2D.body_get_param(get_rid(), PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE)

##
@export_range(0.0, 9999.9, 0.1, "or_greater", "hide_slider", "suffix:px/s")
var max_falling_speed: float = 1500.0

@export_group("Rotation Sync", "rotation_sync_")
##
@export_range(0.0, 360.0, 0.01, "or_greater", "suffix:°/s")
var rotation_sync_rate: float = 360.0
##
@export_range(0.0, 1024.0, 0.1, "or_greater", "suffix:px")
var rotation_sync_distance: float = 512.0

##
var up_direction_rotation: float:
	set(_value):
		printerr("The property 'up_direction_rotation' is read-only.")
	get:
		return Vector2.UP.angle_to(up_direction)
##
var previous_velocity: Vector2:
	set(_value):
		printerr("The property 'previous_velocity' is read-only.")
	get:
		return _prev_vel
##
var previous_was_on_floor: bool:
	set(_value):
		printerr("The property 'previous_was_on_floor' is read-only.")
	get:
		return _prev_on_floor


var _prev_vel: Vector2 = Vector2.ZERO
var _prev_on_floor: bool = false