extends Panel

# --- DRAG AND DROP IN INSPECTOR ---
@export var sidebar: Control
@export var background_rect: ColorRect
@export var file_dialog: FileDialog
@export var art_viewport: SubViewport 

# --- UI BUTTONS ---
@export var export_btn: Button        
@export var transparent_check: Button
@export var scale_spin: SpinBox 

func _ready():
	if export_btn and not export_btn.pressed.is_connected(_on_export_pressed):
		export_btn.pressed.connect(_on_export_pressed)

	if file_dialog and not file_dialog.file_selected.is_connected(_on_file_saved):
		file_dialog.file_selected.connect(_on_file_saved)
			
	if scale_spin:
		# 1. OPTIONAL: You can set the code default here if you want 
		# scale_spin.value = 18 
		
		if not scale_spin.value_changed.is_connected(_on_scale_changed):
			scale_spin.value_changed.connect(_on_scale_changed)
			
		# 2. THE FIX: Force the update immediately!
		_on_scale_changed(scale_spin.value)

func _on_scale_changed(value):
	var new_size = int(value)
	_force_update_fonts(self, new_size)
	if sidebar: _force_update_fonts(sidebar, new_size)

func _force_update_fonts(parent_node, size):
	if parent_node is Control:
		parent_node.add_theme_font_size_override("font_size", size)
		if parent_node is Label and parent_node.label_settings:
			parent_node.label_settings.font_size = size
	for child in parent_node.get_children():
		_force_update_fonts(child, size)

# --- EXPORT LOGIC (SIMPLIFIED) ---
func _on_export_pressed():
	if OS.has_feature("web"):
		_export_for_web()
	else:
		if file_dialog:
			# 1. Get the current time from the OS
			var time = Time.get_datetime_dict_from_system()
			
			# 2. Format the string: "Serenity_2026-01-18_16-30-00.png"
			# %02d ensures we get "05" instead of just "5" for minutes/seconds
			var filename = "Serenity_%d-%02d-%02d_%02d-%02d-%02d.png" % [
				time.year, time.month, time.day, 
				time.hour, time.minute, time.second
			]
			
			# 3. Set the default filename in the dialog
			file_dialog.current_file = filename
			
			# 4. Open the window
			file_dialog.popup_centered()

func _export_for_web():
	# We don't hide UI anymore! We just grab the art directly.
	if art_viewport:
		var img = art_viewport.get_texture().get_image()
		var buffer = img.save_png_to_buffer()
		JavaScriptBridge.download_buffer(buffer, "serenity_art.png", "image/png")

func _on_file_saved(path):
	if art_viewport:
		var img = art_viewport.get_texture().get_image()
		img.save_png(path)
