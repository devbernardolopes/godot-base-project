class_name TestMovement
extends WorldBase
## Movement lab: every slot boots here until a real game scene replaces it.
## Paints a starter course only when the Ground layer is empty, so anything a
## human paints in the editor permanently replaces the generated layout.
## Test hooks: `fire` shoots a short hitscan that breaks breakable tiles,
## `map` toggles the demo "dash" ability (gated wall opens/closes),
## `menu` saves playtime and returns to the main menu.

const GAME_SCENE_PATH: String = "res://scenes/playground/test_movement.tscn"
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"
const DEMO_ABILITY: String = "dash"
const FIRE_TOOL: StringName = &"fire"
const FIRE_RANGE_PX: float = 56.0
const FIRE_STEP_PX: float = 8.0
const FALL_RESPAWN_Y: float = 400.0

var _play_seconds: float = 0.0

@onready var player: PlayerPlatformer = $Player
@onready var spawn: Marker2D = $Spawn
@onready var player_camera: Camera2D = $Player/Camera


func _ready() -> void:
	super._ready()
	_paint_starter_if_empty()
	# Painting may have added gated cells after the parent pass.
	_cache_gated_cells()
	_apply_ability_states()
	player.global_position = spawn.global_position
	player.velocity = Vector2.ZERO
	player.fired.connect(_on_player_fired)
	_fit_camera_to_world()


func _process(delta: float) -> void:
	_play_seconds += delta
	if player.global_position.y > FALL_RESPAWN_Y:
		player.global_position = spawn.global_position
		player.velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"menu"):
		_exit_to_menu()
	elif event.is_action_pressed(&"map"):
		set_ability_unlocked(DEMO_ABILITY, not is_ability_unlocked(DEMO_ABILITY))


func _on_player_fired(origin: Vector2, direction: int) -> void:
	var probe: Vector2 = origin
	var step := Vector2(float(direction) * FIRE_STEP_PX, 0.0)
	var count: int = int(FIRE_RANGE_PX / FIRE_STEP_PX)
	for i: int in range(count):
		probe += step
		var coords: Vector2i = breakable.local_to_map(breakable.to_local(probe))
		if breakable.get_cell_source_id(coords) == -1:
			continue
		try_break(coords, FIRE_TOOL)
		break


func _fit_camera_to_world() -> void:
	if player_camera == null:
		return
	var rect: Rect2 = get_play_rect()
	if rect.size == Vector2.ZERO:
		return
	var margin := 64.0
	player_camera.limit_left = int(rect.position.x - margin)
	player_camera.limit_top = int(rect.position.y - margin)
	player_camera.limit_right = int(rect.end.x + margin)
	player_camera.limit_bottom = int(rect.end.y + margin)


func _exit_to_menu() -> void:
	var slot: int = Gm.current_slot
	if slot >= 1 and slot <= Gm.SLOT_COUNT:
		var data: Dictionary = Gm.get_slot_data(slot)
		data["playtime_seconds"] = int(data.get("playtime_seconds", 0)) + int(_play_seconds)
		data["scene_to_resume"] = GAME_SCENE_PATH
		Gm.save_slot(slot, data)
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


## Starter course: flat run with a jump pit, two hop-up platforms, a
## fire-breakable pillar and a dash-gated wall. Runs once per fresh scene.
func _paint_starter_if_empty() -> void:
	if not ground.get_used_cells().is_empty():
		return
	for x: int in range(-4, 36):
		if x >= 10 and x <= 12:
			continue  # Jump pit.
		paint_cell(ground, Vector2i(x, 13), ATLAS_DARK)
		paint_cell(ground, Vector2i(x, 14), ATLAS_DARK)
		paint_cell(ground, Vector2i(x, 12), ATLAS_TOP)
	for x: int in range(4, 7):
		paint_cell(ground, Vector2i(x, 9), ATLAS_TOP)
	for x: int in range(14, 17):
		paint_cell(ground, Vector2i(x, 7), ATLAS_TOP)
	paint_cell(breakable, Vector2i(26, 11), ATLAS_BREAK)
	paint_cell(breakable, Vector2i(26, 10), ATLAS_BREAK)
	for y: int in range(7, 13):
		paint_cell(gated, Vector2i(30, y), ATLAS_GATE)
