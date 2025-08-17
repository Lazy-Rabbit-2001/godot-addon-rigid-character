@icon("uid://dyd0heol7wple")
class_name RigidCharacter2D
extends CharacterBody2D

## A 2D character body with some rigid body physics and quality-of-life improvements for platform development.
## 
## [RigidCharacter2D] enhances the usability of [CharacterBody2D]: You can handle the [member gravity_scale] of the body to control the strength of the gravity, meaning you don't need to write your own gravity code.
## [br][br]
## 
## Introducing gravity direction meaning that you need to handle the transform of the [member CharacterBody2D.velocity], which is annoying when you just want to think things more easily. Therefore, [member motion] is introduced to solve this problem. It is the [member CharacterBody2D.velocity] transformed by the rotation of [member CharacterBody2D.up_direction], and the [member motion] will help you tranform it to the desired coordinate system.
## [br][br]
## 
## For developers preferring to use momentum, the [member mass] and [member momentum] are your first choice. 
## The method [method force] and [method impulse] are also welcome for those who want to simulate physical effects on the character.
## [br][br]
##
## If you want to move a [RigidCharacter2D], you should call [method move] instead of [method CharacterBody2D.move_and_slide] to ensure the gravity and some other process are handled correctly.
## The method also provides a param that allows you to scale the movement speed, which is useful when the character is in a space where the time goes faster or slower.
## 

enum MotionComponent {
	X, ## Refers to the X component of the [member motion].
	Y, ## Refers to the Y component of the [member motion].
}

enum UpDirectionBase {
	DEFAULT, ## The [member CharacterBody2D.up_direction] does not change.
	REVERSED_GRAVITY_DIRECTION ## The [member CharacterBody2D.up_direction] is the opposite direction of the gravity.
}

## The mass of the body. And it affects the [member momentum] of the body.
## [br][br]
##
## [b]Note:[/b] This is a property encapsulating the setter and getter of [method PhysicsServer2D.body_set_param] and [method PhysicsServer2D.body_get_param].
## In C# version, due to some technical issues with C# getters, an incorrect value will be given via this property if you try to set the mass by calling [method PhysicsServer2D.body_set_param] on the body.
## To avoid this, you should access the [code]Mass[/code] property instead.
@export_range(0.0, 9999.9, 0.1, "or_greater", "hide_slider", "suffix:kg")
var mass: float = 1.0:
	set(value):
		PhysicsServer2D.body_set_param(get_rid(), PhysicsServer2D.BODY_PARAM_MASS, value)
	get:
		return float(PhysicsServer2D.body_get_param(get_rid(), PhysicsServer2D.BODY_PARAM_MASS))
## Current velocity vector transformed by the [member motion_base]. Sometimes this can be regarded as "local velocity".
## [br][br]
## 
## [b]Note:[/b] The motion will be the same as the [member CharacterBody2D.velocity] transformed under the rule of [enum MotionBase][code].GLOBAL_ROTATION[/code] when the motion mode is [code]MOTION_MODE_FLOATING[/code].
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") 
var motion: Vector2:
	set(value):
		velocity = value.rotated(up_direction_rotation if motion_mode == MOTION_MODE_GROUNDED else global_rotation)
	get:
		return velocity.rotated(-up_direction_rotation if motion_mode == MOTION_MODE_GROUNDED else -global_rotation)
## The transfrom base of the [member CharacterBody2D.up_direction]. See [enum UpDirectionBase] for more information.
## [br][br]
## [b]Note:[/b] The up direction is configurable only when the motion mode is [code]MOTION_MODE_GROUNDED[/code].
@export var up_direction_base: UpDirectionBase = UpDirectionBase.REVERSED_GRAVITY_DIRECTION:
	set(value):
		up_direction_base = value
		update_up_direction()

@export_group("Gravity")
## The scale of the gravity applied to the body.
## [br][br]
##
## [b]Note:[/b] This is a property encapsulating the setter and getter of [method PhysicsServer2D.body_set_param] and [method PhysicsServer2D.body_get_param].
## In C# version, due to some technical issues with C# getters, an incorrect value will be given via this property if you try to set the mass by calling [method PhysicsServer2D.body_set_param] on the body.
## To avoid this, you should access the [code]GravityScale[/code] property instead.
@export_range(-8.0, 8.0, 0.1, "or_greater", "or_less")
var gravity_scale: float = 1.0:
	set(value):
		PhysicsServer2D.body_set_param(get_rid(), PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, value)
	get:
		return float(PhysicsServer2D.body_get_param(get_rid(), PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE))
## The maximum falling speed of the body.
## [br][br]
## 
## [b]Note:[/b] This doesn't work when [member gravity_scale] is negative.
@export_range(0.0, 9999.9, 0.1, "or_greater", "hide_slider", "suffix:px/s")
var max_falling_speed: float = 1500.0

@export_group("Rotation Sync", "rotation_sync_")
## If [code]true[/code], the body will be rotated to match the up direction.
@export var rotation_sync_enabled: bool = true
## The rate at which the body rotates to match the gravity direction.
@export_range(0.0, 360.0, 0.1, "or_greater", "radians_as_degrees", "suffix:°/s")
var rotation_sync_angle_speed: float = TAU

## The product of [member CharacterBody2D.velocity] and [member mass]. This is used to describe the inertia of the body.
var momentum: Vector2:
	set(value):
		velocity = value / mass
	get:
		return velocity * mass

## The rotation of [member CharacterBody2D.up_direction]. This is mainly used to transform the [member motion].
## [br][br]
##
## [b]Note:[/b] This is read-only property, and try to assign any value to it will result in an error.
## [br][br]
## 
## [b]Note:[/b] The up direction only works when the motion mode is [code]MOTION_MODE_GROUNDED[/code].
## Otherwise, the value will be the same as the [member Node2D.global_rotation].
var up_direction_rotation: float:
	set(_value):
		printerr("The property 'up_direction_rotation' is read-only.")
	get:
		return global_rotation if motion_mode == MOTION_MODE_GROUNDED else Vector2.UP.angle_to(up_direction)
## The velocity vector of the body at the last call of [method move]
## [br][br]
##
## [b]Note:[/b] This is read-only property, and try to assign any value to it will result in an error.
var previous_velocity: Vector2:
	set(_value):
		printerr("The property 'previous_velocity' is read-only.")
	get:
		return _prev_vel

var _body_delta: float:
	set(_value):
		printerr("The property '_body_delta' is read-only.")
	get:
		return get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
var _update_up_direction_from_inner: bool = false

var _prev_vel: Vector2 = Vector2.ZERO
var _prev_normal: Vector2 = Vector2.ZERO
var _prev_on_floor: bool = false


## A virtual method that you can override to customize your own movement behavior.
## [br][br]
##
## [b]Note:[/b] You should call [method move] instead to ensure some extra encapsulation can be done as expected.
func _move(speed_scale: float) -> bool:
	_prev_vel = velocity
	_prev_on_floor = is_on_floor()

	var lsc := get_last_slide_collision()
	if lsc:
		_prev_normal = lsc.get_normal()

	update_up_direction()

	var g := get_gravity()
	var gdir := g.normalized()

	if not is_zero_approx(gravity_scale):
		velocity += g * gravity_scale * _body_delta

		var falling_vel := velocity.project(gdir)

		if falling_vel.length_squared() > max_falling_speed ** 2.0:
			velocity += falling_vel.normalized() * max_falling_speed - falling_vel
	
	_update_up_direction_from_inner = true
	sync_global_rotation()

	velocity *= speed_scale
	var ret := move_and_slide()
	velocity /= speed_scale

	return ret


## Accelerates the body by adding [member CharacterBody2D.velocity] by the given acceleration vector.
## If the [param target_velocity] is given, the body will move towards the target velocity.
## [br][br]
## [b]Note:[/b] When [param target_velocity] is given, the acceleration will be the length of the given acceleration vector.
func accelerate(acceleration: Vector2, target_velocity: Vector2 = Vector2.INF) -> void:
	if target_velocity.is_finite():
		velocity = velocity.move_toward(target_velocity, acceleration.length() * _body_delta)
	else:
		velocity += acceleration * _body_delta

## Accelerates the body by adding [member motion] by the given acceleration vector.
## If the [param target_motion] is given, the body will move towards the target motion.
## [br][br]
## [b]Note:[/b] When [param target_motion] is given, the acceleration will be the length of the given acceleration vector.
func accelerate_motion(acceleration: Vector2, target_motion: Vector2 = Vector2.INF) -> void:
	if target_motion.is_finite():
		motion = motion.move_toward(target_motion, acceleration.length() * _body_delta)
	else:
		motion += target_motion * _body_delta

## Accelerates the [member motion] by adding one of the components by the given acceleration scalar in the motion vector.
## If the [param target_motion] is given, the body will move towards the target motion.
func accelerate_motion_component(component: MotionComponent, acceleration: float, target: float = INF) -> void:
	var a := acceleration * _body_delta
	if is_finite(target):
		motion[component] = move_toward(motion[component], target, a)
	else:
		motion[component] += a

## Applies the given force to the body.
## The force applied in this method is a central force, and it is [b]time-dependent[/b], meaning that you can call this method in each frame.
func apply_force(force: Vector2) -> void:
	momentum += force * _body_delta

## Applies the given impulse to the body.
## Equals to [code]momentum += impulse[/code], for better readability.
## [br][br]
##
## The impulse applied in this method is a central impulse, and it is [b]time-independent[/b], meaning that calling the method in each frame will apply a new impulse related to the frame rate.
## You should call this method only when you want to apply an immediate impulse to the body.
func apply_impulse(impulse: Vector2) -> void:
	momentum += impulse

## Applies the given vector to the body's velocity.
## Equals to [code]velocity += vector[/code], for better readability.
## [br][br]
##
## The velocity applied in this method is [b]time-independent[/b], meaning that calling the method in each frame will apply a new velocity related to the frame rate.
## You should call this method only when you want to apply an immediate velocity to the body.
func apply_velocity(vector: Vector2) -> void:
	velocity += vector

## Makes the body bounce back.
func bounce() -> void:
	if _prev_normal.is_zero_approx() or not _prev_normal.is_finite():
		return
	velocity = (velocity if _prev_vel.is_zero_approx() else _prev_vel).bounce(_prev_normal)
## Returns the friction of the floor.
## If the character is not on the floor, it returns [code]0.0[/code].
func get_floor_friction() -> float:
	if not is_on_floor(): return 0.0
	
	var kc := KinematicCollision2D.new()
	test_move(global_transform, -get_floor_normal() * floor_snap_length, kc)

	if kc and kc.get_collider():
		return PhysicsServer2D.body_get_param(kc.get_collider_rid(), PhysicsServer2D.BODY_PARAM_FRICTION)

	return 0.0

## Makes the body jump along the [member CharacterBody2D.up_direction].
## [br][br]
##
## [b]Note:[/b] This method only works when the [member CharacterBody2D.motion_mode] is [constant MOTION_MODE_GROUNDED].
## [br][br]
## 
## [b]Note:[/b] This method will reset the velocity along the [member CharacterBody2D.up_direction].
## If you don't hope to do so, please consider using [method apply_impulse] or [method apply_velocity] instead.
func jump(impulse: float, affect_momentum: bool = false) -> void:
	if motion_mode == MotionMode.MOTION_MODE_FLOATING:
		printerr("The method 'jump()' can only be called when the motion mode is 'MOTION_MODE_GROUNDED'.")
		return
	
	var imp := momentum.project(up_direction) if affect_momentum else velocity.project(up_direction)
	var result := imp.normalized() * impulse - imp

	if affect_momentum:
		momentum += result
	else:
		velocity += result

## Moves the body and handles the gravity and other physics related stuff.
## You can override [method _move] to customize your own movement behavior.
func move(speed_scale: float = 1.0) -> bool:
	return _move(speed_scale)

## Synchronizes the global rotation of the body and matches it with the [member CharacterBody2D.up_direction].
func sync_global_rotation() -> void:
	if motion_mode == MotionMode.MOTION_MODE_FLOATING:
		return
	if not rotation_sync_enabled:
		return
	
	if global_rotation != up_direction_rotation:
		if is_on_floor() or _prev_on_floor or is_equal_approx(global_rotation, up_direction_rotation):
			global_rotation = up_direction_rotation
		else:
			global_rotation = lerp_angle(global_rotation, up_direction_rotation, rotation_sync_angle_speed * _body_delta)
		
	if _update_up_direction_from_inner:
		_update_up_direction_from_inner = false
		return
	
	update_up_direction()

## Turns the body back.
## [br][br]
##
## [b]Note:[/b] As this method relies on the floor normal and up direction, this method only works when the [member CharacterBody2D.motion_mode] is [constant MOTION_MODE_GROUNDED] or the character is on the floor.
## If you want to turn a body whose motion mode is [constant MOTION_MODE_FLOATING], please consider reversing [member CharacterBody2D.velocity] or [member motion] instead, or calling [method bounce].
func turn() -> void:
	if motion_mode == MotionMode.MOTION_MODE_FLOATING:
		printerr("The method 'turn_back()' can only be called when the motion mode is 'MOTION_MODE_GROUNDED' or the character is on the floor.")
		return

	var v := velocity if _prev_vel.is_zero_approx() else _prev_vel

	if is_on_floor():
		velocity = v.reflect(get_floor_normal())
	else:
		velocity = v.reflect(up_direction)


## Updates the up direction based on the [member up_direction_base].
## Used internally by the setter of [member up_direction_base].
func update_up_direction() -> void:
	if motion_mode == MotionMode.MOTION_MODE_FLOATING: return

	if up_direction_base == UpDirectionBase.REVERSED_GRAVITY_DIRECTION and is_inside_tree():
		var gdir := get_gravity().normalized()
		up_direction = up_direction if gdir.is_zero_approx() else -gdir
