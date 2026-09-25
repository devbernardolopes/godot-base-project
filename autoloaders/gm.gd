extends Node
## Gm: global foundation autoload for the 2D-game base project.
##
## Owns three things and nothing else:
##   1. Global settings  -> user://settings.cfg  (audio, video, locale, controls)
##   2. Save slots       -> user://save_slot_1..3.json (created_at, playtime, resume scene)
##   3. Shared helpers   -> audio playback pool, input defaults, platform checks.
##
## Game-specific state (balances, scores, inventories) lives in per-game code,
## using SlotData.data (Dictionary) as its opaque payload.

#region CONSTANTS

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_VERSION: String = "1.1"
const SLOT_VERSION: String = "1.0"
const SLOT_COUNT: int = 3

const DEFAULT_SFX_DB: float = 0.0
const DEFAULT_MUSIC_DB: float = 0.0
const DEFAULT_LOCALE: String = "en"
const DEFAULT_VIDEO_STYLE: int = VideoWindowStyle.WINDOWED
const DEFAULT_RES_W: int = 1920
const DEFAULT_RES_H: int = 1080

## Resolutions offered by the Video screen (desktop). Extensible per game.
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(320, 200)]

## Theme / layout tokens (Kenney Future titles, Future Narrow body).
const MARGIN_H: int = 16
const MARGIN_V: int = 16
const GRID_H_SEPARATION: int = 2
const GRID_V_SEPARATION: int = 2
const VBOX_V_SEPARATION: int = 4
const MAX_WIDTH: float = 640.0
const FONT_KENNEY_FUTURE: Font = preload("res://assets/fonts/kenney_kenney-fonts/Fonts/Kenney Future.ttf")
const FONT_KENNEY_FUTURE_NARROW: Font = preload("res://assets/fonts/kenney_kenney-fonts/Fonts/Kenney Future Narrow.ttf")
const LABEL_FONT_SIZE_NORMAL: int = 18
const LABEL_FONT_SIZE_BIG: int = 24
const LABEL_FONT_SIZE_SMALL: int = 12
const TITLE_FONT: Font = FONT_KENNEY_FUTURE
const SECTION_FONT: Font = FONT_KENNEY_FUTURE
const TEXT_FONT: Font = FONT_KENNEY_FUTURE_NARROW

enum VideoWindowStyle { EXCLUSIVE_FULLSCREEN = 0, WINDOWED = 1, BORDERLESS = 2 }

## Canonical gameplay actions. Display names (Up, Jump, ...) are mapped in ACTION_LABELS.
const GAME_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"jump", &"fire", &"dash", &"map", &"menu",
]
const ACTION_LABELS: Dictionary = {
	&"move_up": "Up",
	&"move_down": "Down",
	&"move_left": "Left",
	&"move_right": "Right",
	&"jump": "Jump",
	&"fire": "Fire",
	&"dash": "Dash",
	&"map": "Map",
	&"menu": "Menu",
}

## Single default bindings (Controls screen: one key + one pad button each).
## Pad indices use the Wii Remote vocabulary (no Nunchuk); see JOY_GLYPH_NAMES.
const KEY_DEFAULTS: Dictionary = {
	&"move_up": "Up",
	&"move_down": "Down",
	&"move_left": "Left",
	&"move_right": "Right",
	&"jump": "Z",
	&"fire": "X",
	&"dash": "Shift",
	&"map": "Tab",
	&"menu": "Escape",
}
const PAD_DEFAULTS: Dictionary = {
	&"move_up": JOY_BUTTON_DPAD_UP,
	&"move_down": JOY_BUTTON_DPAD_DOWN,
	&"move_left": JOY_BUTTON_DPAD_LEFT,
	&"move_right": JOY_BUTTON_DPAD_RIGHT,
	&"jump": JOY_BUTTON_A,
	&"fire": JOY_BUTTON_X,
	&"dash": 9,
	&"map": JOY_BUTTON_B,
	&"menu": JOY_BUTTON_START,
}

## Wii Remote glyphs (Vector SVGs) per Godot JoyButton index, measured on a
## direct-Bluetooth hid-wiimote remote (Up=11, Down=12, Right=14, Left=13,
## 1=2, 2=0, B=9, A=3, -=1, +=10, Home=6). Unlisted → "?" fallback.
const WII_SVG_DIR: String = "res://assets/images/ui/kenney_input-prompts_1.5/Nintendo Wii/Vector"
const JOY_GLYPH_NAMES: Dictionary = {
	0: "wii_button_2",
	1: "wii_button_minus",
	2: "wii_button_1",
	3: "wii_button_a",
	6: "wii_button_home",
	9: "wii_button_b",
	10: "wii_button_plus",
	11: "wii_dpad_up",
	12: "wii_dpad_down",
	13: "wii_dpad_left",
	14: "wii_dpad_right",
}

## Left-stick directions auto-attached (invisibly) to move actions.
const STICK_AXES: Dictionary = {
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
}

#endregion


#region STATE

var sfx_db: float = DEFAULT_SFX_DB
var music_db: float = DEFAULT_MUSIC_DB
var locale_code: String = DEFAULT_LOCALE
var video_style: int = DEFAULT_VIDEO_STYLE
var video_res_w: int = DEFAULT_RES_W
var video_res_h: int = DEFAULT_RES_H

## -1 means "no slot selected yet".
var current_slot: int = -1
var is_input_paused: bool = false

var _sfx_pool: Array[AudioStreamPlayer] = []
const _SFX_POOL_SIZE: int = 8

#endregion


#region BOOT

## Entry point. Called once from the boot scene (NOT from _ready, so load order
## is deterministic even if autoload order changes).
func initialize() -> void:
	ensure_default_actions()
	load_settings()
	apply_audio_settings()
	apply_video_settings()
	apply_locale()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
		if current_slot >= 1 and current_slot <= SLOT_COUNT:
			# Persist whatever is in memory; games save explicitly via save_slot().
			save_slot(current_slot, get_slot_data(current_slot))

#endregion


#region PLATFORM

func is_mobile() -> bool:
	return OS.get_name() in ["Android", "iOS"]

func is_desktop() -> bool:
	return OS.has_feature("windows") or OS.has_feature("linux") or OS.has_feature("macos")

func is_exit_allowed() -> bool:
	# No quit action on Web / mobile: the OS manages app lifetime.
	return is_desktop() and not OS.has_feature("web")

#endregion


#region SETTINGS (global)

func load_settings() -> void:
	reset_settings_to_defaults(false)
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(SETTINGS_PATH)
	if err != OK:
		return  # First boot: defaults stand.
	var stored_version: String = str(cfg.get_value("meta", "version", SETTINGS_VERSION))
	if stored_version != SETTINGS_VERSION:
		push_warning("Settings version mismatch, some keys may use defaults.")
	sfx_db = float(cfg.get_value("audio", "sfx_db", DEFAULT_SFX_DB))
	music_db = float(cfg.get_value("audio", "music_db", DEFAULT_MUSIC_DB))
	locale_code = str(cfg.get_value("locale", "code", DEFAULT_LOCALE))
	video_style = int(cfg.get_value("video", "mode", DEFAULT_VIDEO_STYLE))
	video_res_w = int(cfg.get_value("video", "resolution_w", DEFAULT_RES_W))
	video_res_h = int(cfg.get_value("video", "resolution_h", DEFAULT_RES_H))
	if stored_version == SETTINGS_VERSION:
		_load_controls_from_cfg(cfg)
	# Else: pre-1.1 controls blobs are incompatible with the single-column
	# model, so fresh defaults (already applied above) stand.

func save_settings() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("meta", "version", SETTINGS_VERSION)
	cfg.set_value("audio", "sfx_db", sfx_db)
	cfg.set_value("audio", "music_db", music_db)
	cfg.set_value("locale", "code", locale_code)
	cfg.set_value("video", "mode", video_style)
	cfg.set_value("video", "resolution_w", video_res_w)
	cfg.set_value("video", "resolution_h", video_res_h)
	_save_controls_to_cfg(cfg)
	var err: int = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save settings to %s (err %d)." % [SETTINGS_PATH, err])
		return false
	return true

func reset_settings_to_defaults(persist: bool = true) -> void:
	sfx_db = DEFAULT_SFX_DB
	music_db = DEFAULT_MUSIC_DB
	locale_code = DEFAULT_LOCALE
	video_style = DEFAULT_VIDEO_STYLE
	video_res_w = DEFAULT_RES_W
	video_res_h = DEFAULT_RES_H
	reset_controls_to_defaults()
	apply_audio_settings()
	apply_video_settings()
	apply_locale()
	if persist:
		save_settings()

func apply_audio_settings() -> void:
	_set_bus_volume(&"SFX", sfx_db)
	_set_bus_volume(&"Music", music_db)

func apply_video_settings() -> void:
	if OS.has_feature("web") or is_mobile():
		return  # Adaptive rule: window management stays with the OS.
	match video_style:
		VideoWindowStyle.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		VideoWindowStyle.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(Vector2i(video_res_w, video_res_h))
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(video_res_w, video_res_h))

func apply_locale() -> void:
	TranslationServer.set_locale(locale_code)

func _set_bus_volume(bus: StringName, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		push_warning("Audio bus '%s' not found, volume not applied." % bus)
		return
	AudioServer.set_bus_volume_db(idx, db)

#endregion


#region SAVE SLOTS (per-slot gameplay data)

func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

## Minimal slot payload. Games extend `data` freely; the four top-level keys
## are reserved by the base (used by the slot-select screen).
func new_slot_data() -> Dictionary:
	return {
		"version": SLOT_VERSION,
		"created_at": Time.get_datetime_string_from_system(true, false),
		"playtime_seconds": 0,
		"scene_to_resume": "",
		"data": {},
	}

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

## Small in-memory cache so pause/quit can flush without a game reference.
var _slot_cache: Dictionary = {}

func get_slot_data(slot: int) -> Dictionary:
	if _slot_cache.has(slot):
		return _slot_cache[slot]
	var loaded: Dictionary = load_slot(slot)
	if loaded.is_empty():
		loaded = new_slot_data()
	_slot_cache[slot] = loaded
	return loaded

func load_slot(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("Failed to open slot %d for reading." % slot)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Slot %d is corrupt (not a Dictionary)." % slot)
		return {}
	var data: Dictionary = parsed
	if data.get("version", SLOT_VERSION) != SLOT_VERSION:
		push_warning("Slot %d version mismatch, some fields may use defaults." % slot)
	_slot_cache[slot] = data
	return data

func save_slot(slot: int, data: Dictionary) -> bool:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = SLOT_VERSION
	var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Failed to open slot %d for writing." % slot)
		return false
	file.store_string(JSON.stringify(payload))
	_slot_cache[slot] = payload
	return true

func delete_slot(slot: int) -> bool:
	_slot_cache.erase(slot)
	if not slot_exists(slot):
		return true
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("Cannot access user:// directory.")
		return false
	var err: int = dir.remove("save_slot_%d.json" % slot)
	if err != OK:
		push_error("Failed to delete slot %d (err %d)." % [slot, err])
		return false
	return true

## Light summary for the slot-select screen without exposing full payloads.
func get_slot_summary(slot: int) -> Dictionary:
	var data: Dictionary = load_slot(slot)
	if data.is_empty():
		return {"exists": false, "slot": slot}
	return {
		"exists": true,
		"slot": slot,
		"created_at": data.get("created_at", ""),
		"playtime_seconds": int(data.get("playtime_seconds", 0)),
		"scene_to_resume": str(data.get("scene_to_resume", "")),
	}

#endregion


#region AUDIO PLAYBACK

## Polyphonic SFX via a small player pool on the SFX bus (no click-cutting).
func play_effect(stream: AudioStream, bus: StringName = &"SFX", stop_previous: bool = false) -> void:
	if stream == null:
		return
	_prune_sfx_pool()
	if stop_previous:
		for p: AudioStreamPlayer in _sfx_pool:
			p.stop()
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	_sfx_pool.append(player)
	player.finished.connect(_on_sfx_finished.bind(player))
	player.play()

func start_music(player: AudioStreamPlayer, music: AudioStream, loop: bool = false, random_pos: bool = false) -> void:
	if player == null or music == null:
		push_error("start_music called with null player or music.")
		return
	player.bus = &"Music"
	player.stream = music
	if music is AudioStreamOggVorbis and loop:
		(music as AudioStreamOggVorbis).loop = true
	var from_position: float = 0.0
	if random_pos:
		from_position = randf_range(0.0, music.get_length())
	player.play(from_position)

func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	_sfx_pool.erase(player)
	if is_instance_valid(player):
		player.queue_free()

func _prune_sfx_pool() -> void:
	for i: int in range(_sfx_pool.size() - 1, -1, -1):
		var p: AudioStreamPlayer = _sfx_pool[i]
		if not is_instance_valid(p):
			_sfx_pool.remove_at(i)

#endregion


#region INPUT DEFAULTS

## Idempotent: also repairs duplicates of this base whose project.godot
## InputMap section was lost. Called from initialize().
## Model: exactly one keyboard event + one pad-button event per action
## (plus invisible stick axes on move actions, see _attach_stick_if_move).
func ensure_default_actions() -> void:
	for action: StringName in GAME_ACTIONS:
		_ensure_single_binding(action)

func reset_controls_to_defaults() -> void:
	for action: StringName in GAME_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	ensure_default_actions()

func _ensure_single_binding(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var key_ev: InputEventKey = InputEventKey.new()
		key_ev.physical_keycode = OS.find_keycode_from_string(str(KEY_DEFAULTS.get(action, "Escape")))
		InputMap.action_add_event(action, key_ev)
		var bev: InputEventJoypadButton = InputEventJoypadButton.new()
		bev.button_index = int(PAD_DEFAULTS.get(action, 0)) as JoyButton
		InputMap.action_add_event(action, bev)
		_attach_stick_if_move(action)

func _attach_stick_if_move(action: StringName) -> void:
	if not STICK_AXES.has(action):
		return
	var spec: Array = STICK_AXES[action]
	_add_pad_motion(action, spec[0], spec[1])

func _add_pad_motion(action: StringName, axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

#region controls persistence (remap screen in Step 5 builds on this)

func _save_controls_to_cfg(cfg: ConfigFile) -> void:
	for action: StringName in GAME_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var key_d: Dictionary = {}
		var btn_d: Dictionary = {}
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey and key_d.is_empty():
				key_d = _event_to_dict(ev)
			elif ev is InputEventJoypadButton and btn_d.is_empty():
				btn_d = _event_to_dict(ev)
		cfg.set_value("controls", String(action), {"key": key_d, "button": btn_d})

func _load_controls_from_cfg(cfg: ConfigFile) -> void:
	if not cfg.has_section("controls"):
		return
	for action: StringName in GAME_ACTIONS:
		if not cfg.has_section_key("controls", String(action)):
			continue
		var slot: Variant = cfg.get_value("controls", String(action), {})
		if typeof(slot) != TYPE_DICTIONARY:
			continue  # Pre-1.1 blob: ignore, fresh defaults stand.
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var kev: InputEvent = _dict_to_event((slot as Dictionary).get("key", {}) as Dictionary)
		if kev != null:
			InputMap.action_add_event(action, kev)
		var bev: InputEvent = _dict_to_event((slot as Dictionary).get("button", {}) as Dictionary)
		if bev != null:
			InputMap.action_add_event(action, bev)
		_attach_stick_if_move(action)

#region remap accessors (Controls screen builds on these)

func get_action_key(action: StringName) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev as InputEventKey
	return null

func get_action_button(action: StringName) -> InputEventJoypadButton:
	if not InputMap.has_action(action):
		return null
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return ev as InputEventJoypadButton
	return null

func set_action_key(action: StringName, ev: InputEventKey) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for old: InputEvent in InputMap.action_get_events(action):
		if old is InputEventKey:
			InputMap.action_erase_event(action, old)
	if ev != null:
		InputMap.action_add_event(action, ev)

func set_action_button(action: StringName, ev: InputEventJoypadButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for old: InputEvent in InputMap.action_get_events(action):
		if old is InputEventJoypadButton:
			InputMap.action_erase_event(action, old)
	if ev != null:
		InputMap.action_add_event(action, ev)

## Steal rule: clear the same-column binding on every OTHER action.
func clear_matching_key(ev: InputEventKey, except: StringName) -> void:
	for action: StringName in GAME_ACTIONS:
		if action == except:
			continue
		var cur: InputEventKey = get_action_key(action)
		if cur != null and _same_key(cur, ev):
			set_action_key(action, null)

func clear_matching_button(ev: InputEventJoypadButton, except: StringName) -> void:
	for action: StringName in GAME_ACTIONS:
		if action == except:
			continue
		var cur: InputEventJoypadButton = get_action_button(action)
		if cur != null and cur.button_index == ev.button_index:
			set_action_button(action, null)

func _same_key(a: InputEventKey, b: InputEventKey) -> bool:
	var ac: int = int(a.physical_keycode if a.physical_keycode != 0 else a.keycode)
	var bc: int = int(b.physical_keycode if b.physical_keycode != 0 else b.keycode)
	return ac != 0 and ac == bc

func key_event_label(ev: InputEventKey) -> String:
	if ev == null:
		return "—"
	var code: int = int(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	if code == 0:
		return "—"
	return OS.get_keycode_string(code as Key)

func joy_glyph_path(button_index: int) -> String:
	var stem: String = str(JOY_GLYPH_NAMES.get(button_index, ""))
	if stem.is_empty():
		return ""
	return "%s/%s.svg" % [WII_SVG_DIR, stem]

## Dev aid: one-line description of the last physical input (pad debugging).
func describe_input_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		var code: int = int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
		return "key %s (phys %d)" % [OS.get_keycode_string(code as Key), code]
	if ev is InputEventJoypadButton:
		return "pad btn %d" % int((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return "axis %d = %.2f" % [int(m.axis), float(m.axis_value)]
	if ev is InputEventMouseButton:
		return "mouse %d" % int((ev as InputEventMouseButton).button_index)
	return ev.get_class()

#endregion

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return {"type": "key", "code": int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)}
	if ev is InputEventJoypadButton:
		return {"type": "button", "index": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return {"type": "axis", "axis": int(m.axis), "value": float(m.axis_value)}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "index": int((ev as InputEventMouseButton).button_index)}
	return {}

func _dict_to_event(d: Dictionary) -> InputEvent:
	match str(d.get("type", "")):
		"key":
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = int(d.get("code", 0)) as Key
			return k
		"button":
			var b: InputEventJoypadButton = InputEventJoypadButton.new()
			b.button_index = int(d.get("index", 0)) as JoyButton
			return b
		"axis":
			var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
			m.axis = int(d.get("axis", 0)) as JoyAxis
			m.axis_value = float(d.get("value", 1.0))
			return m
		"mouse":
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = int(d.get("index", 1)) as MouseButton
			return mb
	return null

#endregion

#endregion


#region SCENE

func get_current_scene() -> Node:
	return get_tree().current_scene

#endregion
