class_name PlayerPlatformer
extends CharacterBody2D
## Hero controller for the movement lab (warpgal art).
## Movement tuning stays in the @exports; the animation state table below
## drives the reusable ActorAnimator child (interruptible states, one-shot
## chaining). Enemies/NPCs reuse ActorAnimator with their own tables.

signal fired(origin: Vector2, direction: int)

const ANIM_IDLE: StringName = &"idle_3"
const ANIM_RUN: StringName = &"run"
const ANIM_BEGIN: StringName = &"jump_begin"
const ANIM_MID: StringName = &"jump_mid"
const ANIM_END: StringName = &"jump_end"
const ANIM_FALL: StringName = &"fall"

## Upward speed (px/s) below which the jump arc counts as rising.
const RISE_THRESHOLD: float = -20.0

const ANIM_STATES: Dictionary = {
	&"idle_3": {"loop": true, "next": &""},
	&"run": {"loop": true, "next": &""},
	&"jump_begin": {"loop": false, "next": &"jump_mid"},
	&"jump_mid": {"loop": true, "next": &""},
	&"jump_end": {"loop": false, "next": &"fall"},
	&"fall": {"loop": true, "next": &""},
}

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
var _moving: bool = false
var _jumped: bool = false
var _was_on_floor: bool = false

@onready var anim: ActorAnimator = $Sprite


func _ready() -> void:
	anim.setup(ANIM_STATES)
	anim.request(ANIM_IDLE)


func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_tick(delta, gravity)
	move_and_slide()
	_update_anim()


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
	_moving = not is_zero_approx(axis)
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
			_jumped = true
			_buffer = 0.0
			_coyote = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		if _buffer > 0.0 and _coyote > 0.0:
			velocity.y = jump_velocity
			_jumped = true
			_buffer = 0.0
			_coyote = 0.0
	if Input.is_action_just_pressed(&"fire") and _fire_cd <= 0.0:
		_fire_cd = fire_cooldown
		fired.emit(global_position, facing)


## Animation state selection. Called after move_and_slide so is_on_floor()
## is current. Every branch funnels through request(), which restarts only
## on change: landing preempts one-shots mid-animation, one-shots otherwise
## play out and chain (begin -> mid, end -> fall).
func _update_anim() -> void:
	anim.set_facing(facing)
	var on_floor: bool = is_on_floor()
	var just_left: bool = _was_on_floor and not on_floor
	_was_on_floor = on_floor
	if on_floor:
		_jumped = false
		anim.request(ANIM_RUN if _moving else ANIM_IDLE)
		return
	if just_left and _jumped:
		anim.request(ANIM_BEGIN)
		return
	if not _jumped:
		anim.request(ANIM_FALL)
		return
	var cur: StringName = anim.current_state
	if cur == ANIM_BEGIN or cur == ANIM_END or cur == ANIM_FALL:
		anim.request(cur)
		return
	if velocity.y < RISE_THRESHOLD:
		anim.request(ANIM_MID)
	else:
		anim.request(ANIM_END)
