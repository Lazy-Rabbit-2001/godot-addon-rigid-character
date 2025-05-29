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
@export_range(-8.0, 8.0, 0.1, "or_greater", "or_less")
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
@export var rotation_sync_enabled: bool = true:
	set(value):
		if motion_mode != MotionMode.MOTION_MODE_GROUNDED:
			printerr("The property 'rotation_sync_enabled' can only be set when the motion mode is 'MOTION_MODE_GROUNDED'.")
			rotation_sync_enabled = false
		else:
			rotation_sync_enabled = value
## 
@export_range(0.0, 360.0, 0.01, "or_greater", "suffix:°/s")
var rotation_sync_rate: float = 360.0
## 
@export_range(0.0, 1024.0, 0.1, "or_greater", "suffix:px")
var rotation_sync_distance: float = 512.0

##
var momentum: Vector2:
	set(value):
		velocity = value / mass
	get:
		return velocity * mass

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

var _body_delta: float:
	set(_value):
		printerr("The property '_body_delta' is read-only.")
	get:
		return get_physics_process_delta_time() if Engine.is_editor_hint() else get_process_delta_time()

var _prev_vel: Vector2 = Vector2.ZERO
var _prev_normal: Vector2 = Vector2.ZERO
var _prev_on_floor: bool = false


## 
func _move(scale: float = 1.0) -> bool:
	_prev_vel = velocity
	_prev_normal = get_last_slide_collision().get_normal()
	_prev_on_floor = is_on_floor()

	var g := get_gravity()
	var gdir := g.normalized()

	if motion_mode == MotionMode.MOTION_MODE_GROUNDED and \
		not is_nan(velocity.x) and \
		not is_nan(velocity.y) and \
		not gdir.is_zero_approx():
			up_direction = -gdir

	if not is_zero_approx(gravity_scale):
		velocity += g * gravity_scale * _body_delta

		var falling_vel := velocity.project(gdir)

		if falling_vel.length_squared() > max_falling_speed ** 2.0:
			velocity += falling_vel.normalized() * max_falling_speed - falling_vel
	
	sync_global_rotation()

	velocity *= scale
	var ret := move_and_slide()
	velocity /= scale

	return ret


## 
func accelerate(acceleration: Vector2, target_velocity: Vector2 = Vector2.INF) -> void:
	var delta := _body_delta
	
	if target_velocity.is_finite():
		velocity = velocity.move_toward(target_velocity, acceleration.length() * delta)
	else:
		velocity += acceleration * _body_delta
##
func accelerate_motion(acceleration: Vector2, target_motion: Vector2 = Vector2.INF) -> void:
	var delta := _body_delta

	if target_motion.is_finite():
		motion = motion.move_toward(target_motion, acceleration.length() * delta)
	else:
		motion += target_motion * delta
##
func accelerate_motion_component(component: MotionComponent, acceleration: float, target: float = INF) -> void:
	var a := acceleration * _body_delta
	
	if is_finite(target):
		motion[component] += a
	else:
		motion[component] = move_toward(motion[component], target, a)
##
func apply_force(force: Vector2) -> void:
	momentum += force * _body_delta
##
func apply_impulse(impulse: Vector2, affect_momentum: bool = true) -> void:
	if affect_momentum:
		momentum += impulse
	else:
		velocity += impulse
##
func bounce() -> void:
	if _prev_normal.is_zero_approx() or not _prev_normal.is_finite():
		return
	velocity = velocity.reflect(_prev_normal)

##
func jump(impulse: float, affect_momentum: bool = false) -> void:
	if motion_mode != MotionMode.MOTION_MODE_GROUNDED:
		printerr("The method 'jump()' can only be called when the motion mode is 'MOTION_MODE_GROUNDED'.")
		return 
	
	var imp := momentum.project(up_direction) if affect_momentum else velocity.project(up_direction)
	
	if affect_momentum:
		momentum += imp.normalized() * impulse - imp
	else:
		velocity += imp.normalized() * impulse - imp
## 
func move(scale: float = 1.0) -> bool:
	return _move(scale)
##
func sync_global_rotation() -> void:
	if not rotation_sync_enabled:
		return
	if motion_mode != MotionMode.MOTION_MODE_GROUNDED:
		return # Non-ground mode does not support up_direction.
	
	# Set the global rotation directly to the up direction rotation when it is on the floor.
	if is_on_floor() or _prev_on_floor or is_equal_approx(global_rotation, up_direction_rotation):
		global_rotation = up_direction_rotation
	# Otherwise, lerp the global rotation to the up direction rotation.
	else:
		global_rotation = lerp_angle(global_rotation, up_direction_rotation, rotation_sync_rate * _body_delta)
##
func turn_back() -> void:
	if is_on_floor():
		velocity = velocity.reflect(get_floor_normal())
	elif motion_mode == MotionMode.MOTION_MODE_GROUNDED:
		velocity = velocity.reflect(up_direction)
	else:
		printerr("The method 'turn_back()' can only be called when the motion mode is 'MOTION_MODE_GROUNDED' or the character is on the floor.")
