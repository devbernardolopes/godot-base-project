extends Control
## MainMenu: shell scene for the base project (Step 1).
##
## Single scene, panel switching: Main / Slots / Settings hub / stubs
## (Controls, Video, Audio arrive in later steps). Back-stack navigation,
## first-button focus for gamepad/keyboard, Esc = back (exit-confirm on Main),
## Exit hidden on web/mobile.

const PANEL_MAIN: StringName = &"MainPanel"
const PANEL_SLOTS: StringName = &"SlotsPanel"
const PANEL_SETTINGS: StringName = &"SettingsPanel"
const PANEL_CONTROLS: StringName = &"ControlsPanel"
const PANEL_VIDEO: StringName = &"VideoPanel"
const PANEL_AUDIO: StringName = &"AudioPanel"

const LOCALE_CODES: Array[String] = ["en", "fr", "it", "de", "es", "pt_BR"]
const LOCALE_NAMES: Array[String] = ["English", "Français", "Italiano", "Deutsch", "Español", "Português (BR)"]

const TEST_CLICK: AudioStream = preload("res://assets/sounds/sfx/kenney_interface-sounds/Audio/click_001.ogg")

var _history: Array[StringName] = []
var _current: StringName = PANEL_MAIN

@onready var _panels: Dictionary = {
	PANEL_MAIN: $Center/Card/Margin/MainPanel,
	PANEL_SLOTS: $Center/Card/Margin/SlotsPanel,
	PANEL_SETTINGS: $Center/Card/Margin/SettingsPanel,
	PANEL_CONTROLS: $Center/Card/Margin/ControlsPanel,
	PANEL_VIDEO: $Center/Card/Margin/VideoPanel,
	PANEL_AUDIO: $Center/Card/Margin/AudioPanel,
}
@onready var _first_focus: Dictionary = {
	PANEL_MAIN: $Center/Card/Margin/MainPanel/PlayButton,
	PANEL_SLOTS: $Center/Card/Margin/SlotsPanel/Slot1Button,
	PANEL_SETTINGS: $Center/Card/Margin/SettingsPanel/ControlsButton,
	PANEL_CONTROLS: $Center/Card/Margin/ControlsPanel/ControlsBackButton,
	PANEL_VIDEO: $Center/Card/Margin/VideoPanel/ModeRow/ModeOption,
	PANEL_AUDIO: $Center/Card/Margin/AudioPanel/SoundRow/SoundSlider,
}

@onready var _main_title: Label = $Center/Card/Margin/MainPanel/MainTitle
@onready var _play_button: Button = $Center/Card/Margin/MainPanel/PlayButton
@onready var _settings_button: Button = $Center/Card/Margin/MainPanel/SettingsButton
@onready var _exit_button: Button = $Center/Card/Margin/MainPanel/ExitButton

@onready var _slots_title: Label = $Center/Card/Margin/SlotsPanel/SlotsTitle
@onready var _slot_buttons: Array[Button] = [
	$Center/Card/Margin/SlotsPanel/Slot1Button,
	$Center/Card/Margin/SlotsPanel/Slot2Button,
	$Center/Card/Margin/SlotsPanel/Slot3Button,
]
@onready var _slots_back_button: Button = $Center/Card/Margin/SlotsPanel/SlotsBackButton

@onready var _settings_title: Label = $Center/Card/Margin/SettingsPanel/SettingsTitle
@onready var _controls_button: Button = $Center/Card/Margin/SettingsPanel/ControlsButton
@onready var _video_button: Button = $Center/Card/Margin/SettingsPanel/VideoButton
@onready var _audio_button: Button = $Center/Card/Margin/SettingsPanel/AudioButton
@onready var _language_label: Label = $Center/Card/Margin/SettingsPanel/LanguageRow/LanguageLabel
@onready var _language_option: OptionButton = $Center/Card/Margin/SettingsPanel/LanguageRow/LanguageOption
@onready var _settings_back_button: Button = $Center/Card/Margin/SettingsPanel/SettingsBackButton

@onready var _controls_title: Label = $Center/Card/Margin/ControlsPanel/ControlsTitle
@onready var _controls_wip: Label = $Center/Card/Margin/ControlsPanel/ControlsWip
@onready var _controls_back_button: Button = $Center/Card/Margin/ControlsPanel/ControlsBackButton
@onready var _video_title: Label = $Center/Card/Margin/VideoPanel/VideoTitle
@onready var _mode_row: HBoxContainer = $Center/Card/Margin/VideoPanel/ModeRow
@onready var _mode_label: Label = $Center/Card/Margin/VideoPanel/ModeRow/ModeLabel
@onready var _mode_option: OptionButton = $Center/Card/Margin/VideoPanel/ModeRow/ModeOption
@onready var _res_row: HBoxContainer = $Center/Card/Margin/VideoPanel/ResRow
@onready var _res_label: Label = $Center/Card/Margin/VideoPanel/ResRow/ResLabel
@onready var _res_option: OptionButton = $Center/Card/Margin/VideoPanel/ResRow/ResOption
@onready var _video_auto: Label = $Center/Card/Margin/VideoPanel/VideoAuto
@onready var _video_back_button: Button = $Center/Card/Margin/VideoPanel/VideoBackButton
@onready var _audio_title: Label = $Center/Card/Margin/AudioPanel/AudioTitle
@onready var _sound_label: Label = $Center/Card/Margin/AudioPanel/SoundRow/SoundLabel
@onready var _sound_slider: HSlider = $Center/Card/Margin/AudioPanel/SoundRow/SoundSlider
@onready var _sound_value: Label = $Center/Card/Margin/AudioPanel/SoundRow/SoundValue
@onready var _music_label: Label = $Center/Card/Margin/AudioPanel/MusicRow/MusicLabel
@onready var _music_slider: HSlider = $Center/Card/Margin/AudioPanel/MusicRow/MusicSlider
@onready var _music_value: Label = $Center/Card/Margin/AudioPanel/MusicRow/MusicValue
@onready var _test_sound_button: Button = $Center/Card/Margin/AudioPanel/TestSoundButton
@onready var _audio_back_button: Button = $Center/Card/Margin/AudioPanel/AudioBackButton

@onready var _exit_dialog: ConfirmationDialog = $ExitDialog


func _ready() -> void:
	Gm.initialize()
	_apply_theme_tokens()
	_connect_signals()
	_fill_languages()
	_exit_button.visible = Gm.is_exit_allowed()
	_retranslate()
	show_panel(PANEL_MAIN, false)


func _unhandled_input(event: InputEvent) -> void:
	if Gm.is_input_paused:
		return
	if event.is_action_pressed("menu"):
		if _exit_dialog.visible:
			_exit_dialog.hide()
		elif _current != PANEL_MAIN:
			go_back()
		else:
			_on_exit_pressed()
		get_viewport().set_input_as_handled()


#region NAVIGATION

func show_panel(panel: StringName, push: bool = true) -> void:
	if _current == PANEL_AUDIO and panel != PANEL_AUDIO:
		Gm.save_settings()
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
		Gm.save_slot(slot, data)
	# Per-game hook: starting gameplay from the selected slot happens here.
	_refresh_slots()

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


#region EXIT

func _on_exit_pressed() -> void:
	if not Gm.is_exit_allowed():
		return
	_retranslate_exit_dialog()
	_exit_dialog.popup_centered()

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
	for wip: Label in [_controls_wip]:
		wip.text = tr("WIP")
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
	_exit_dialog.confirmed.connect(_on_exit_confirmed)
