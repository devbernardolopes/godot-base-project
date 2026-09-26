class_name ActorAnimator
extends AnimatedSprite2D
## Reusable interruptible animation-state driver for actors.
##
## The owner computes the desired state every physics frame and calls
## request(): a differing state restarts playback immediately (free
## mid-animation preemption), one-shots auto-chain through their `next` map
## on animation_finished. setup() also pushes loop flags into the
## SpriteFrames resource so the state table is the single source of truth.

var current_state: StringName = &""

var _next: Dictionary = {}


func setup(states: Dictionary) -> void:
	_next.clear()
	var frames: SpriteFrames = sprite_frames
	for state: String in states:
		var spec: Dictionary = states[state]
		var state_name := StringName(state)
		_next[state_name] = StringName(str(spec.get("next", "")))
		if frames != null and frames.has_animation(state_name):
			frames.set_animation_loop(state_name, bool(spec.get("loop", true)))


func request(state: StringName) -> void:
	if state == &"" or state == current_state:
		return
	current_state = state
	play(state)


func set_facing(dir: int) -> void:
	if dir != 0:
		flip_h = dir < 0


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	var nxt: StringName = _next.get(current_state, &"")
	if nxt != &"":
		current_state = nxt
		play(nxt)
