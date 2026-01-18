extends Panel

# --- DRAG AND DROP IN INSPECTOR ---
@export var sidebar: Control
@export var background_rect: ColorRect
@export var file_dialog: FileDialog
@export var art_viewport: SubViewport 

# --- UI BUTTONS ---
@export var export_btn: Button        
@export var transparent_check: Button
# CHANGE: Now looking for a SpinBox
@export var scale_spin: SpinBox 

func _ready():
	if export_btn and not export_btn.pressed.is_connected(_on_export_pressed):
		export_btn.pressed.connect(_on_export_pressed)

	if file_dialog and not file_dialog.file_selected.is_connected(_on_file_saved):
		file_dialog.file_selected.connect(_on_file_saved)
			
	# NEW SPINBOX CONNECTION
	if scale_spin:
		scale_spin.value = 16 
		if not scale_spin.value_changed.is_connected(_on_scale_changed):
			scale_spin.value_changed.connect(_on_scale_changed)

# --- SIMPLE UPDATE FUNCTION ---
func _on_scale_changed(value):
	var new_size = int(value)
	
	# Update Top Bar
	_force_update_fonts(self, new_size)
	
	# Update Sidebar
	if sidebar:
		_force_update_fonts(sidebar, new_size)

# --- RECURSIVE UPDATER ---
func _force_update_fonts(parent_node, size):
	if parent_node is Control:
		parent_node.add_theme_font_size_override("font_size", size)
		if parent_node is Label and parent_node.label_settings:
			parent_node.label_settings.font_size = size

	for child in parent_node.get_children():
		_force_update_fonts(child, size)

# --- EXPORT LOGIC (Unchanged) ---
func _on_export_pressed():
	if OS.has_feature("web"):
		_export_for_web()
	else:
		if file_dialog: file_dialog.popup_centered()

func _export_for_web():
	_prepare_capture_visuals()
	await get_tree().process_frame
	await get_tree().process_frame
	if art_viewport:
		var img = art_viewport.get_texture().get_image()
		var buffer = img.save_png_to_buffer()
		JavaScriptBridge.download_buffer(buffer, "serenity_art.png", "image/png")
	_restore_capture_visuals()

func _on_file_saved(path):
	_prepare_capture_visuals()
	await get_tree().process_frame
	await get_tree().process_frame
	if art_viewport:
		var img = art_viewport.get_texture().get_image()
		img.save_png(path)
	_restore_capture_visuals()

var _temp_bg_visible = true

func _prepare_capture_visuals():
	if sidebar: sidebar.visible = false
	self.visible = false 
	if background_rect:
		_temp_bg_visible = background_rect.visible
		if transparent_check and transparent_check.button_pressed:
			background_rect.visible = false
			if art_viewport: art_viewport.transparent_bg = true

func _restore_capture_visuals():
	if sidebar: sidebar.visible = true
	self.visible = true
	if background_rect:
		background_rect.visible = _temp_bg_visible
	if art_viewport: 
		art_viewport.transparent_bg = false
