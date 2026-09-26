extends Control
## MainMenu: shell scene for the base project.
##
## Single scene, panel switching: Main / Slots / Settings hub / Controls /
## Video / Audio. Back-stack navigation, first-button focus for
## gamepad/keyboard, Esc = back (exit-confirm on Main), Exit hidden on
## web/mobile. Jump (Wii 2) = confirm, Fire (Wii 1) = cancel/back in menus.

const PANEL_MAIN: StringName = &"MainPanel"
const PANEL_SLOTS: StringName = &"SlotsPanel"
const PANEL_SETTINGS: StringName = &"SettingsPanel"
const PANEL_CONTROLS: StringName = &"ControlsPanel"
const PANEL_VIDEO: StringName = &"VideoPanel"
const PANEL_AUDIO: StringName = &"AudioPanel"

const LOCALE_CODES: Array[String] = ["en", "fr", "it", "de", "es", "pt_BR"]
const LOCALE_NAMES: Array[String] = ["English", "Français", "Italiano", "Deutsch", "Español", "Português (BR)"]

const TEST_CLICK: AudioStream = preload("res://assets/sounds/sfx/kenney_interface-sounds/Audio/click_001.ogg")

## Controls remap: scene row per action + i18n key per action display name.
const ROW_NODE: Dictionary = {
	&"move_up": "RowMoveUp",
	&"move_down": "RowMoveDown",
	&"move_left": "RowMoveLeft",
	&"move_right": "RowMoveRight",
	&"jump": "RowJump",
	&"fire": "RowFire",
	&"dash": "RowDash",
	&"map": "RowMap",
	&"menu": "RowMenu",
}
const ACTION_I18N: Dictionary = {
	&"move_up": "ACTION_UP",
	&"move_down": "ACTION_DOWN",
	&"move_left": "ACTION_LEFT",
	&"move_right": "ACTION_RIGHT",
	&"jump": "ACTION_JUMP",
	&"fire": "ACTION_FIRE",
	&"dash": "ACTION_DASH",
	&"map": "ACTION_MAP",
	&"menu": "ACTION_MENU",
}
const LISTEN_ARM_MSEC: int = 200

const GAME_SCENE: String = "res://scenes/playground/test_movement.tscn"

var _listening_action: StringName = &""
var _listen_start_msec: int = 0
var _row_box: Dictionary = {}
var _row_name: Dictionary = {}
var _row_key: Dictionary = {}
var _row_pad: Dictionary = {}
var _row_glyph: Dictionary = {}
var _row_empty: Dictionary = {}

var _history: Array[StringName] = []
var _current: StringName = PANEL_MAIN

@onready var _panels: Dictionary = {
	PANEL_MAIN: $Scroll/HCenter/Card/Margin/MainPanel,
	PANEL_SLOTS: $Scroll/HCenter/Card/Margin/SlotsPanel,
	PANEL_SETTINGS: $Scroll/HCenter/Card/Margin/SettingsPanel,
	PANEL_CONTROLS: $Scroll/HCenter/Card/Margin/ControlsPanel,
	PANEL_VIDEO: $Scroll/HCenter/Card/Margin/VideoPanel,
	PANEL_AUDIO: $Scroll/HCenter/Card/Margin/AudioPanel,
}
@onready var _first_focus: Dictionary = {
	PANEL_MAIN: $Scroll/HCenter/Card/Margin/MainPanel/PlayButton,
	PANEL_SLOTS: $Scroll/HCenter/Card/Margin/SlotsPanel/Slot1Button,
	PANEL_SETTINGS: $Scroll/HCenter/Card/Margin/SettingsPanel/ControlsButton,
	PANEL_CONTROLS: $Scroll/HCenter/Card/Margin/ControlsPanel/RowMoveUp/KeyButton,
	PANEL_VIDEO: $Scroll/HCenter/Card/Margin/VideoPanel/ModeRow/ModeOption,
	PANEL_AUDIO: $Scroll/HCenter/Card/Margin/AudioPanel/SoundRow/SoundSlider,
}

@onready var _main_title: Label = $Scroll/HCenter/Card/Margin/MainPanel/MainTitle
@onready var _play_button: Button = $Scroll/HCenter/Card/Margin/MainPanel/PlayButton
@onready var _settings_button: Button = $Scroll/HCenter/Card/Margin/MainPanel/SettingsButton
@onready var _exit_button: Button = $Scroll/HCenter/Card/Margin/MainPanel/ExitButton

@onready var _slots_title: Label = $Scroll/HCenter/Card/Margin/SlotsPanel/SlotsTitle
@onready var _slot_buttons: Array[Button] = [
	$Scroll/HCenter/Card/Margin/SlotsPanel/Slot1Button,
	$Scroll/HCenter/Card/Margin/SlotsPanel/Slot2Button,
	$Scroll/HCenter/Card/Margin/SlotsPanel/Slot3Button,
]
@onready var _slots_back_button: Button = $Scroll/HCenter/Card/Margin/SlotsPanel/SlotsBackButton

@onready var _settings_title: Label = $Scroll/HCenter/Card/Margin/SettingsPanel/SettingsTitle
@onready var _controls_button: Button = $Scroll/HCenter/Card/Margin/SettingsPanel/ControlsButton
@onready var _video_button: Button = $Scroll/HCenter/Card/Margin/SettingsPanel/VideoButton
@onready var _audio_button: Button = $Scroll/HCenter/Card/Margin/SettingsPanel/AudioButton
@onready var _language_label: Label = $Scroll/HCenter/Card/Margin/SettingsPanel/LanguageRow/LanguageLabel
@onready var _language_option: OptionButton = $Scroll/HCenter/Card/Margin/SettingsPanel/LanguageRow/LanguageOption
@onready var _settings_back_button: Button = $Scroll/HCenter/Card/Margin/SettingsPanel/SettingsBackButton

@onready var _controls_title: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/ControlsTitle
@onready var _ctrls_h_action: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/HeaderRow/HAction
@onready var _ctrls_h_key: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/HeaderRow/HKey
@onready var _ctrls_h_pad: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/HeaderRow/HPad
@onready var _controls_status: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/ControlsStatus
@onready var _reset_button: Button = $Scroll/HCenter/Card/Margin/ControlsPanel/ResetButton
@onready var _pad_debug: Label = $Scroll/HCenter/Card/Margin/ControlsPanel/PadDebug
@onready var _controls_back_button: Button = $Scroll/HCenter/Card/Margin/ControlsPanel/ControlsBackButton
@onready var _video_title: Label = $Scroll/HCenter/Card/Margin/VideoPanel/VideoTitle
@onready var _mode_row: HBoxContainer = $Scroll/HCenter/Card/Margin/VideoPanel/ModeRow
@onready var _mode_label: Label = $Scroll/HCenter/Card/Margin/VideoPanel/ModeRow/ModeLabel
@onready var _mode_option: OptionButton = $Scroll/HCenter/Card/Margin/VideoPanel/ModeRow/ModeOption
@onready var _res_row: HBoxContainer = $Scroll/HCenter/Card/Margin/VideoPanel/ResRow
@onready var _res_label: Label = $Scroll/HCenter/Card/Margin/VideoPanel/ResRow/ResLabel
@onready var _res_option: OptionButton = $Scroll/HCenter/Card/Margin/VideoPanel/ResRow/ResOption
@onready var _video_auto: Label = $Scroll/HCenter/Card/Margin/VideoPanel/VideoAuto
@onready var _video_back_button: Button = $Scroll/HCenter/Card/Margin/VideoPanel/VideoBackButton
@onready var _audio_title: Label = $Scroll/HCenter/Card/Margin/AudioPanel/AudioTitle
@onready var _sound_label: Label = $Scroll/HCenter/Card/Margin/AudioPanel/SoundRow/SoundLabel
@onready var _sound_slider: HSlider = $Scroll/HCenter/Card/Margin/AudioPanel/SoundRow/SoundSlider
@onready var _sound_value: Label = $Scroll/HCenter/Card/Margin/AudioPanel/SoundRow/SoundValue
@onready var _music_label: Label = $Scroll/HCenter/Card/Margin/AudioPanel/MusicRow/MusicLabel
@onready var _music_slider: HSlider = $Scroll/HCenter/Card/Margin/AudioPanel/MusicRow/MusicSlider
@onready var _music_value: Label = $Scroll/HCenter/Card/Margin/AudioPanel/MusicRow/MusicValue
@onready var _test_sound_button: Button = $Scroll/HCenter/Card/Margin/AudioPanel/TestSoundButton
@onready var _audio_back_button: Button = $Scroll/HCenter/Card/Margin/AudioPanel/AudioBackButton

@onready var _exit_dialog: ConfirmationDialog = $ExitDialog
@onready var _scroll: ScrollContainer = $Scroll


func _ready() -> void:
	Gm.initialize()
	_apply_theme_tokens()
	_connect_signals()
	_fill_languages()
	_collect_control_rows()
	_size_control_rows()
	_pad_debug.visible = OS.is_debug_build()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	($Scroll/HCenter as CenterContainer).size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	_exit_button.visible = Gm.is_exit_allowed()
	_retranslate()
	show_panel(PANEL_MAIN, false)


func _input(event: InputEvent) -> void:
	if Gm.is_input_paused:
		return
	if _current == PANEL_CONTROLS and _is_debug_press(event):
		_pad_debug.text = "IN: " + Gm.describe_input_event(event)
	if _listening_action != &"":
		_capture_remap(event)
		return
	# Jump (Wii 2) = confirm, Fire (Wii 1) = cancel/back. Handled here (before
	# the GUI) so pad buttons can't double-trigger via builtin ui_accept.
	# Pad buttons are stripped from ui_accept/ui_cancel at boot (see Gm), so
	# the game actions own pad confirm/cancel outright.
	if event.is_action_pressed("fire"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		_activate_focused()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if Gm.is_input_paused:
		return
	if event.is_action_pressed("menu"):
		_on_cancel_pressed()


#region NAVIGATION

func show_panel(panel: StringName, push: bool = true) -> void:
	if _current == PANEL_AUDIO and panel != PANEL_AUDIO:
		Gm.save_settings()
	if _current == PANEL_CONTROLS and panel != PANEL_CONTROLS:
		_stop_listening()
	if push and _current != &"" and _current != panel:
		_history.push_back(_current)
	_current = panel
	for key: StringName in _panels:
		(_panels[key] as Control).visible = (key == panel)
	if panel == PANEL_SLOTS:
		_refresh_slots()
	if panel == PANEL_AUDIO:
		_refresh_audio()
	if panel == PANEL_VIDEO:
		_refresh_video()
	if panel == PANEL_CONTROLS:
		_refresh_controls()
	var first: Control = _first_focus.get(panel)
	if first != null:
		first.grab_focus()

func go_back() -> void:
	if _history.is_empty():
		return
	var previous: StringName = _history.pop_back()
	show_panel(previous, false)

#endregion


#region SLOTS

func _refresh_slots() -> void:
	for i: int in range(_slot_buttons.size()):
		var slot: int = i + 1
		var summary: Dictionary = Gm.get_slot_summary(slot)
		var label: String = tr("SLOT_LABEL") % slot
		if bool(summary.get("exists", false)):
			var playtime: String = Helpers.format_time(int(summary.get("playtime_seconds", 0)))
			var marker: String = " ▶" if Gm.current_slot == slot else ""
			_slot_buttons[i].text = "%s · %s%s" % [label, playtime, marker]
		else:
			_slot_buttons[i].text = "%s · %s" % [label, tr("SLOT_EMPTY")]

func _on_slot_pressed(slot: int) -> void:
	Gm.current_slot = slot
	var data: Dictionary = Gm.get_slot_data(slot)
	if data.is_empty():
		data = Gm.new_slot_data()
	data["scene_to_resume"] = GAME_SCENE
	Gm.save_slot(slot, data)
	_refresh_slots()
	get_tree().change_scene_to_file(GAME_SCENE)

#endregion


#region LANGUAGE

func _fill_languages() -> void:
	_language_option.clear()
	for i: int in range(LOCALE_CODES.size()):
		_language_option.add_item(LOCALE_NAMES[i], i)
	_language_option.selected = clampi(LOCALE_CODES.find(Gm.locale_code), 0, LOCALE_CODES.size() - 1)

func _on_language_selected(index: int) -> void:
	Gm.locale_code = LOCALE_CODES[index]
	Gm.apply_locale()
	Gm.save_settings()
	_retranslate()

#endregion


#region AUDIO

func _db_to_percent(db: float) -> float:
	return clampf(db_to_linear(db), 0.0, 1.0) * 100.0

func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -60.0
	return linear_to_db(clampf(percent / 100.0, 0.0, 1.0))

func _refresh_audio() -> void:
	_sound_slider.set_value_no_signal(_db_to_percent(Gm.sfx_db))
	_music_slider.set_value_no_signal(_db_to_percent(Gm.music_db))
	_update_audio_labels()

func _update_audio_labels() -> void:
	_sound_value.text = "%d%%" % int(round(_sound_slider.value))
	_music_value.text = "%d%%" % int(round(_music_slider.value))

func _on_sound_changed(value: float) -> void:
	Gm.sfx_db = _percent_to_db(value)
	Gm.apply_audio_settings()
	_update_audio_labels()

func _on_music_changed(value: float) -> void:
	Gm.music_db = _percent_to_db(value)
	Gm.apply_audio_settings()
	_update_audio_labels()

func _on_audio_drag_ended(_value_changed: bool) -> void:
	Gm.save_settings()

func _on_test_sound() -> void:
	Gm.play_effect(TEST_CLICK)

#endregion


#region VIDEO

func _find_resolution_index() -> int:
	for i: int in range(Gm.SUPPORTED_RESOLUTIONS.size()):
		var r: Vector2i = Gm.SUPPORTED_RESOLUTIONS[i]
		if r.x == Gm.video_res_w and r.y == Gm.video_res_h:
			return i
	return 0

func _fill_video_options() -> void:
	_mode_option.clear()
	_mode_option.add_item(tr("VIDEO_EXCLUSIVE"), 0)
	_mode_option.add_item(tr("VIDEO_WINDOWED"), 1)
	_mode_option.add_item(tr("VIDEO_BORDERLESS"), 2)
	_res_option.clear()
	for i: int in range(Gm.SUPPORTED_RESOLUTIONS.size()):
		var r: Vector2i = Gm.SUPPORTED_RESOLUTIONS[i]
		_res_option.add_item("%d x %d" % [r.x, r.y], i)

func _refresh_video() -> void:
	var adaptive: bool = OS.has_feature("web") or Gm.is_mobile()
	_mode_row.visible = not adaptive
	_res_row.visible = not adaptive
	_video_auto.visible = adaptive
	if adaptive:
		return
	_mode_option.selected = clampi(Gm.video_style, 0, 2)
	_res_option.selected = _find_resolution_index()

func _on_mode_selected(index: int) -> void:
	Gm.video_style = clampi(index, 0, 2)
	Gm.apply_video_settings()
	Gm.save_settings()

func _on_resolution_selected(index: int) -> void:
	var r: Vector2i = Gm.SUPPORTED_RESOLUTIONS[clampi(index, 0, Gm.SUPPORTED_RESOLUTIONS.size() - 1)]
	Gm.video_res_w = r.x
	Gm.video_res_h = r.y
	Gm.apply_video_settings()
	Gm.save_settings()

#endregion


#region CONTROLS

func _collect_control_rows() -> void:
	var base: String = "Scroll/HCenter/Card/Margin/ControlsPanel"
	for action: StringName in Gm.GAME_ACTIONS:
		var row: HBoxContainer = get_node(base + "/" + str(ROW_NODE[action])) as HBoxContainer
		_row_box[action] = row
		_row_name[action] = row.get_node("RowName") as Label
		_row_key[action] = row.get_node("KeyButton") as Button
		_row_pad[action] = row.get_node("PadButton") as Button
		_row_glyph[action] = row.get_node("PadButton/PadGlyph") as TextureRect
		_row_empty[action] = row.get_node("PadButton/PadEmpty") as Label
		(_row_key[action] as Button).pressed.connect(_start_listening.bind(action))
		(_row_pad[action] as Button).pressed.connect(_start_listening.bind(action))

func _size_control_rows() -> void:
	for action: StringName in Gm.GAME_ACTIONS:
		(_row_name[action] as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(_row_key[action] as Button).custom_minimum_size = Vector2(110, 44)
		(_row_pad[action] as Button).custom_minimum_size = Vector2(72, 44)
		var glyph: TextureRect = _row_glyph[action] as TextureRect
		glyph.custom_minimum_size = Vector2(40, 40)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		var empty: Label = _row_empty[action] as Label
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.set_anchors_preset(Control.PRESET_FULL_RECT)

func _refresh_controls() -> void:
	for action: StringName in Gm.GAME_ACTIONS:
		(_row_name[action] as Label).text = tr(str(ACTION_I18N.get(action, "ACTION_MENU")))
		(_row_key[action] as Button).text = Gm.key_event_label(Gm.get_action_key(action))
		var glyph: TextureRect = _row_glyph[action] as TextureRect
		var empty: Label = _row_empty[action] as Label
		var bev: InputEventJoypadButton = Gm.get_action_button(action)
		var tex: Texture2D = null
		if bev != null:
			var path: String = Gm.joy_glyph_path(int(bev.button_index))
			if not path.is_empty() and ResourceLoader.exists(path):
				tex = load(path) as Texture2D
		if tex != null:
			glyph.texture = tex
			glyph.visible = true
			empty.visible = false
		else:
			glyph.visible = false
			empty.visible = true

func _start_listening(action: StringName) -> void:
	_listening_action = action
	_listen_start_msec = Time.get_ticks_msec()
	_controls_status.text = tr("CTRLS_LISTENING")
	_refresh_row_highlight()

func _stop_listening() -> void:
	_listening_action = &""
	if is_node_ready():
		_controls_status.text = ""
		_refresh_row_highlight()

func _refresh_row_highlight() -> void:
	for action: StringName in Gm.GAME_ACTIONS:
		var box: HBoxContainer = _row_box.get(action) as HBoxContainer
		if box != null:
			box.modulate = Color(1.0, 0.95, 0.6) if action == _listening_action else Color.WHITE

func _is_debug_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) > 0.3
	return false

func _capture_remap(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed("menu"):
		_stop_listening()
		get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() - _listen_start_msec < LISTEN_ARM_MSEC:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var kev: InputEventKey = ((event as InputEventKey).duplicate() as InputEventKey)
		Gm.clear_matching_key(kev, _listening_action)
		Gm.set_action_key(_listening_action, kev)
		Gm.save_settings()
		_stop_listening()
		_refresh_controls()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bev: InputEventJoypadButton = ((event as InputEventJoypadButton).duplicate() as InputEventJoypadButton)
		Gm.clear_matching_button(bev, _listening_action)
		Gm.set_action_button(_listening_action, bev)
		Gm.save_settings()
		_stop_listening()
		_refresh_controls()
		get_viewport().set_input_as_handled()

func _on_reset_controls() -> void:
	_stop_listening()
	Gm.reset_controls_to_defaults()
	Gm.save_settings()
	_refresh_controls()

func _activate_focused() -> void:
	# The exit dialog lives in its own Window/viewport, so the main
	# viewport's focus owner can't reach it: confirm inside the dialog's
	# own viewport, falling back to OK when nothing there has focus.
	if _exit_dialog.visible:
		var dlg_focus: Control = _exit_dialog.get_viewport().gui_get_focus_owner()
		if dlg_focus is Button and dlg_focus.visible and not (dlg_focus as Button).disabled:
			(dlg_focus as Button).pressed.emit()
		else:
			_exit_dialog.get_ok_button().pressed.emit()
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is Button and focus.visible and not (focus as Button).disabled:
		(focus as Button).pressed.emit()

func _on_cancel_pressed() -> void:
	if _exit_dialog.visible:
		_exit_dialog.hide()
	elif _current != PANEL_MAIN:
		go_back()
	else:
		_on_exit_pressed()

#endregion


#region EXIT

func _on_exit_pressed() -> void:
	if not Gm.is_exit_allowed():
		return
	_retranslate_exit_dialog()
	_exit_dialog.popup_centered()
	_exit_dialog.get_ok_button().grab_focus()

func _on_exit_confirmed() -> void:
	get_tree().quit()

#endregion


#region TEXT + THEME

func _apply_theme_tokens() -> void:
	for title: Label in [_main_title, _slots_title, _settings_title, _controls_title, _video_title, _audio_title]:
		title.add_theme_font_override("font", Gm.TITLE_FONT)
		title.add_theme_font_size_override("font_size", Gm.LABEL_FONT_SIZE_BIG)

func _retranslate() -> void:
	_main_title.text = tr("MAIN_MENU")
	_play_button.text = tr("MENU_PLAY")
	_settings_button.text = tr("MENU_SETTINGS")
	_exit_button.text = tr("MENU_EXIT")
	_slots_title.text = tr("PLAY_TITLE")
	_slots_back_button.text = tr("MENU_BACK")
	_settings_title.text = tr("SETTINGS_TITLE")
	_controls_button.text = tr("SETTINGS_CONTROLS")
	_video_button.text = tr("SETTINGS_VIDEO")
	_audio_button.text = tr("SETTINGS_AUDIO")
	_language_label.text = tr("SETTINGS_LANGUAGE")
	_settings_back_button.text = tr("MENU_BACK")
	_controls_title.text = tr("CONTROLS_TITLE")
	_ctrls_h_action.text = tr("CTRLS_ACTION")
	_ctrls_h_key.text = tr("CTRLS_KEY")
	_ctrls_h_pad.text = tr("CTRLS_PAD")
	_reset_button.text = tr("CTRLS_RESET")
	if _listening_action != &"":
		_controls_status.text = tr("CTRLS_LISTENING")
	else:
		_controls_status.text = ""
	_refresh_controls()
	_video_title.text = tr("VIDEO_TITLE")
	_mode_label.text = tr("VIDEO_MODE")
	_res_label.text = tr("VIDEO_RESOLUTION")
	_video_auto.text = tr("VIDEO_AUTO")
	_fill_video_options()
	_refresh_video()
	_audio_title.text = tr("AUDIO_TITLE")
	_sound_label.text = tr("AUDIO_SOUND")
	_music_label.text = tr("AUDIO_MUSIC")
	_test_sound_button.text = tr("AUDIO_TEST")
	_update_audio_labels()
	_controls_back_button.text = tr("MENU_BACK")
	_video_back_button.text = tr("MENU_BACK")
	_audio_back_button.text = tr("MENU_BACK")
	_refresh_slots()
	if _exit_dialog.visible:
		_retranslate_exit_dialog()

func _retranslate_exit_dialog() -> void:
	_exit_dialog.title = tr("MENU_EXIT")
	_exit_dialog.dialog_text = tr("EXIT_CONFIRM")

#endregion


func _connect_signals() -> void:
	_play_button.pressed.connect(show_panel.bind(PANEL_SLOTS))
	_settings_button.pressed.connect(show_panel.bind(PANEL_SETTINGS))
	_exit_button.pressed.connect(_on_exit_pressed)
	_slots_back_button.pressed.connect(go_back)
	_settings_back_button.pressed.connect(go_back)
	_controls_back_button.pressed.connect(go_back)
	_video_back_button.pressed.connect(go_back)
	_audio_back_button.pressed.connect(go_back)
	_controls_button.pressed.connect(show_panel.bind(PANEL_CONTROLS))
	_video_button.pressed.connect(show_panel.bind(PANEL_VIDEO))
	_audio_button.pressed.connect(show_panel.bind(PANEL_AUDIO))
	for i: int in range(_slot_buttons.size()):
		_slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i + 1))
	_language_option.item_selected.connect(_on_language_selected)
	_sound_slider.value_changed.connect(_on_sound_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sound_slider.drag_ended.connect(_on_audio_drag_ended)
	_music_slider.drag_ended.connect(_on_audio_drag_ended)
	_test_sound_button.pressed.connect(_on_test_sound)
	_mode_option.item_selected.connect(_on_mode_selected)
	_res_option.item_selected.connect(_on_resolution_selected)
	_reset_button.pressed.connect(_on_reset_controls)
	_exit_dialog.confirmed.connect(_on_exit_confirmed)
