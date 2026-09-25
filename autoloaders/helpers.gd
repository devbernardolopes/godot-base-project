extends Node

const SCREENSHOT_DIR: String = "screenshots"
const FILE_PREFIX: String = "screenshot_"

func setup_screenshot_directory() -> void:
	var user_dir = DirAccess.open("user://")
	if user_dir == null:
		push_error("Cannot access user:// directory")
		return
	
	var target_path = "user://" + SCREENSHOT_DIR
	if not user_dir.dir_exists(SCREENSHOT_DIR):
		var result = user_dir.make_dir_recursive(SCREENSHOT_DIR)
		if result != OK:
			push_error("Failed to create screenshot directory: " + str(result))
		else:
			print("Screenshot directory created: ", target_path)

func take_screenshot() -> void:
	var viewport: Viewport = get_viewport()
	var image: Image = viewport.get_texture().get_image()
	
	if image == null or image.is_empty():
		push_error("Failed to capture viewport image")
		return
	
	# Use Unix timestamp for guaranteed uniqueness
	var timestamp: float = Time.get_unix_time_from_system()
	var filename: String = "%s%d.png" % [FILE_PREFIX, timestamp]
	var full_path: String = "user://%s/%s" % [SCREENSHOT_DIR, filename]
	
	# Ensure directory exists
	var dir_check = DirAccess.open("user://%s" % SCREENSHOT_DIR)
	if dir_check == null:
		setup_screenshot_directory()
		dir_check = DirAccess.open("user://%s" % SCREENSHOT_DIR)
	
	var error: int = image.save_png(full_path)
	
	match error:
		OK:
			print("Screenshot saved successfully: ", full_path)
			# Optional: Show in-game notification
			# show_notification("Screenshot saved!")
		ERR_FILE_CANT_WRITE:
			push_error("Cannot write to file. Check permissions for: ", full_path)
		ERR_FILE_CORRUPT:
			push_error("Image data is corrupted")
		_:
			push_error("Unknown save error: ", error_string(error))

func format_number(value: int, delimiter: String) -> String:
	var str_val := str(abs(value))
	var result := ""
	var count := 0

	# Traverse the string backwards and insert delimiters
	for i in range(str_val.length() - 1, -1, -1):
		result = str_val[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = delimiter + result

	# Add the minus sign back if needed
	if value < 0:
		result = "-" + result

	return result

func get_normalized_value(current: float, max_input: float, min_output: float, max_output: float) -> float:
	if max_input == 0.0:
		return min_output  # Avoid division by zero
	var ratio: float = clamp(current / max_input, 0.0, 1.0)
	return lerp(min_output, max_output, ratio)

func format_time(seconds: int, show_hour: bool = false) -> String:
	var total: int = maxi(seconds, 0)
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if show_hour:
		return "%02d:%02d:%02d" % [h, m, s]
	@warning_ignore("integer_division")
	var mm: int = total / 60
	return "%02d:%02d" % [mm, s]

func get_contrasting_text_color(bg: Color) -> Color:
	# Calculated using perceived luminance (WCAG formula)
	var luminance: float = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	# Threshold is empirical; adjust if needed
	if luminance > 0.6:
		return Color.BLACK
	else:
		return Color.WHITE
