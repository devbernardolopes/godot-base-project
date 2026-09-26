class_name PlayerPlatformer
extends CharacterBody2D
## Placeholder hero controller for the movement lab.
## Replace the Polygon2D Sprite with the hero AnimatedSprite2D when the
## per-game art direction lands; movement tuning stays in the @exports.

signal fired(origin: Vector2, direction: int)

@export var move_speed: float = 140.0
@export var accel: float = 1200.0
@export var air_accel: float = 800.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -360.0
@export var jump_cut_factor: float = 0.45
@export var max_fall_speed: float = 420.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var dash_speed: float = 380.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.80
@export var fire_cooldown: float = 0.25

var facing: int = 1

var _coyote: float = 0.0
var _buffer: float = 0.0
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _fire_cd: float = 0.0


func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_tick(delta, gravity)
	move_and_slide()


func _tick(delta: float, gravity: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if is_on_floor():
		_coyote = coyote_time
	var axis: float = Input.get_axis(&"move_left", &"move_right")
	if not is_zero_approx(axis):
		facing = 1 if axis > 0.0 else -1
	if Input.is_action_just_pressed(&"jump"):
		_buffer = jump_buffer
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_factor
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = Vector2(float(facing) * dash_speed, 0.0)
		return
	if Input.is_action_just_pressed(&"dash") and _dash_cd <= 0.0:
		_dash_left = dash_time
		_dash_cd = dash_cooldown
		velocity = Vector2(float(facing) * dash_speed, 0.0)
		return
	var rate: float = accel if is_on_floor() else air_accel
	var target: float = axis * move_speed
	if is_zero_approx(axis):
		rate = friction if is_on_floor() else air_accel * 0.4
		target = 0.0
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if is_on_floor():
		if _buffer > 0.0:
			velocity.y = jump_velocity
			_buffer = 0.0
			_coyote = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		if _buffer > 0.0 and _coyote > 0.0:
			velocity.y = jump_velocity
			_buffer = 0.0
			_coyote = 0.0
	if Input.is_action_just_pressed(&"fire") and _fire_cd <= 0.0:
		_fire_cd = fire_cooldown
		fired.emit(global_position, facing)
