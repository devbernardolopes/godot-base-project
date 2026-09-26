class_name WorldBase
extends Node2D
## WorldBase: runtime contract shared by every tile-based level.
##
## Every level scene roots a script extending this class and holds six
## TileMapLayers (all sharing the same TileSet) as direct children:
## DecoBack / Ground / Gated / Breakable / DecoFront / Triggers.
## Deco* and Triggers never collide; Ground / Gated / Breakable do.
##
## Tile identity carries behavior: any cell painted with a gated atlas tile
## requires its ability wherever it is placed, and any breakable atlas tile
## breaks only with its tool. Collision polygons and custom data for the
## starter tiles are filled in here when missing, so values painted by a
## human in the TileSet editor always win over these defaults.

const TILE_PX: int = 16
const HALF_PX: float = 8.0
const SOURCE_ID: int = 0
const PHYSICS_LAYER: int = 0

const KIND_KEY: String = "kind"
const REQUIRES_KEY: String = "requires_ability"
const TOOL_KEY: String = "break_tool"

const KIND_SOLID: String = "solid"
const KIND_BREAKABLE: String = "breakable"

## Starter atlas tiles in monochrome_tilemap_packed.png (20x20 grid of 16px).
const ATLAS_DARK: Vector2i = Vector2i(11, 7)
const ATLAS_TOP: Vector2i = Vector2i(15, 17)
const ATLAS_BREAK: Vector2i = Vector2i(11, 9)
const ATLAS_GATE: Vector2i = Vector2i(4, 5)

static var FULL_SQUARE: PackedVector2Array = PackedVector2Array([
	Vector2(-8.0, -8.0), Vector2(8.0, -8.0),
	Vector2(8.0, 8.0), Vector2(-8.0, 8.0),
])

## Starter identity table. "requires_ability" names the ability that makes a
## Gated-layer cell passable; "break_tool" names the tool that breaks a
## Breakable-layer cell ("fire", "dash", or "" for any).
const STARTER_TILES: Array[Dictionary] = [
	{"atlas": Vector2i(11, 7), "kind": "solid", "break_tool": "", "requires_ability": ""},
	{"atlas": Vector2i(15, 17), "kind": "solid", "break_tool": "", "requires_ability": ""},
	{"atlas": Vector2i(11, 9), "kind": "breakable", "break_tool": "fire", "requires_ability": ""},
	{"atlas": Vector2i(4, 5), "kind": "solid", "break_tool": "", "requires_ability": "dash"},
]

var _unlocked_abilities: Dictionary = {}
var _gated_cells: Array[Dictionary] = []

@onready var deco_back: TileMapLayer = $DecoBack
@onready var ground: TileMapLayer = $Ground
@onready var gated: TileMapLayer = $Gated
@onready var breakable: TileMapLayer = $Breakable
@onready var deco_front: TileMapLayer = $DecoFront
@onready var triggers: TileMapLayer = $Triggers


func _ready() -> void:
	_ensure_starter_tile_data()
	_cache_gated_cells()
	_apply_ability_states()


func get_tile_custom(layer: TileMapLayer, coords: Vector2i, key: String) -> String:
	if layer == null or layer.get_cell_source_id(coords) == -1:
		return ""
	var tile_data: TileData = layer.get_cell_tile_data(coords)
	if tile_data == null or not tile_data.has_custom_data(key):
		return ""
	return str(tile_data.get_custom_data(key))


func get_tile_kind(layer: TileMapLayer, coords: Vector2i) -> String:
	return get_tile_custom(layer, coords, KIND_KEY)


## Erases a breakable cell when `tool` is accepted. Returns true when a cell
## was broken (simple swap v1: the cell just disappears).
func try_break(coords: Vector2i, tool: StringName) -> bool:
	if breakable.get_cell_source_id(coords) == -1:
		return false
	if get_tile_kind(breakable, coords) != KIND_BREAKABLE:
		return false
	var need: String = get_tile_custom(breakable, coords, TOOL_KEY)
	if not need.is_empty() and need != String(tool):
		return false
	breakable.erase_cell(coords)
	return true


func is_ability_unlocked(ability_name: String) -> bool:
	return bool(_unlocked_abilities.get(ability_name, false))


## Locks/unlocks every Gated cell requiring `ability_name`. Unlocked art moves
## to DecoBack (no collision) so it stays visible but passable; locking moves
## it back. No TileSet alternative tiles needed.
func set_ability_unlocked(ability_name: String, unlocked: bool) -> void:
	_unlocked_abilities[ability_name] = unlocked
	for entry: Dictionary in _gated_cells:
		if str(entry["ability"]) != ability_name:
			continue
		var coords: Vector2i = entry["coords"]
		var atlas: Vector2i = entry["atlas"]
		var present: bool = gated.get_cell_source_id(coords) != -1
		if unlocked and present:
			deco_back.set_cell(coords, SOURCE_ID, atlas)
			gated.erase_cell(coords)
		elif not unlocked and not present:
			gated.set_cell(coords, SOURCE_ID, atlas)
			if deco_back.get_cell_atlas_coords(coords) == atlas:
				deco_back.erase_cell(coords)


func paint_cell(layer: TileMapLayer, coords: Vector2i, atlas: Vector2i) -> void:
	layer.set_cell(coords, SOURCE_ID, atlas)


## Pixel-space bounding box of all solid-ish cells (camera limits, spawns).
func get_play_rect() -> Rect2:
	var result := Rect2()
	var started := false
	var layers: Array[TileMapLayer] = [ground, gated, breakable]
	for layer: TileMapLayer in layers:
		if layer == null:
			continue
		for coords: Vector2i in layer.get_used_cells():
			var center: Vector2 = layer.map_to_local(coords)
			var cell := Rect2(center - Vector2(HALF_PX, HALF_PX), Vector2(TILE_PX, TILE_PX))
			if not started:
				result = cell
				started = true
			else:
				result = result.merge(cell)
	return result


func _ensure_starter_tile_data() -> void:
	if ground == null:
		push_error("WorldBase: missing Ground layer.")
		return
	var tile_set: TileSet = ground.tile_set
	if tile_set == null:
		push_error("WorldBase: Ground has no TileSet assigned.")
		return
	if not tile_set.has_source(SOURCE_ID):
		push_error("WorldBase: TileSet missing source %d." % SOURCE_ID)
		return
	var source: TileSetAtlasSource = tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	if source == null:
		push_error("WorldBase: source %d is not an atlas." % SOURCE_ID)
		return
	for entry: Dictionary in STARTER_TILES:
		var atlas: Vector2i = entry["atlas"]
		var tile_data: TileData = source.get_tile_data(atlas, 0)
		if tile_data == null:
			push_warning("WorldBase: no tile data at %s." % str(atlas))
			continue
		if tile_data.get_collision_polygons_count(PHYSICS_LAYER) == 0:
			tile_data.add_collision_polygon(PHYSICS_LAYER)
			tile_data.set_collision_polygon_points(PHYSICS_LAYER, 0, FULL_SQUARE)
		_ensure_custom(tile_data, KIND_KEY, str(entry["kind"]))
		_ensure_custom(tile_data, TOOL_KEY, str(entry["break_tool"]))
		_ensure_custom(tile_data, REQUIRES_KEY, str(entry["requires_ability"]))


func _ensure_custom(tile_data: TileData, key: String, value: String) -> void:
	if not tile_data.has_custom_data(key) or str(tile_data.get_custom_data(key)).is_empty():
		tile_data.set_custom_data(key, value)
	# A non-empty human-painted value always wins over the default above.


func _cache_gated_cells() -> void:
	_gated_cells.clear()
	for coords: Vector2i in gated.get_used_cells():
		var ability: String = get_tile_custom(gated, coords, REQUIRES_KEY)
		if ability.is_empty():
			continue
		_gated_cells.append({
			"coords": coords,
			"atlas": gated.get_cell_atlas_coords(coords),
			"ability": ability,
		})


func _apply_ability_states() -> void:
	for ability: String in _unlocked_abilities:
		set_ability_unlocked(ability, bool(_unlocked_abilities[ability]))
