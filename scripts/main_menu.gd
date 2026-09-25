extends Control
## MainMenu: boot scene for the base project (Step 0 skeleton).
##
## Initializes the Gm foundation (settings, slots, input defaults, locale)
## and shows a localized placeholder. Full menu panels arrive in Step 1.

@onready var status_label: Label = $Center/StatusLabel


func _ready() -> void:
	Gm.initialize()
	status_label.add_theme_font_override("font", Gm.TITLE_FONT)
	status_label.add_theme_font_size_override("font_size", Gm.LABEL_FONT_SIZE_BIG)
	status_label.text = tr("MENU_BOOT_LOADING")


func _unhandled_input(event: InputEvent) -> void:
	if Gm.is_input_paused:
		return
	if event.is_action_pressed("menu"):
		# Step 1 navigator hook: back / cancel from menus, Settings from gameplay.
		get_viewport().set_input_as_handled()
