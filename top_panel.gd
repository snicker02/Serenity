extends Panel

# --- DRAG AND DROP THESE IN THE INSPECTOR ---
@export var sidebar: Control
@export var background_rect: ColorRect
@export var file_dialog: FileDialog

# --- INTERNAL NODES (These are inside TopPanel, so paths are safe) ---
@onready var export_btn = $HBoxContainer/ExportButton
@onready var transparent_check = $HBoxContainer/TransparentCheck

func _ready():
	
	
	# --- NUCLEAR LAYOUT FIX ---
	# This forces the panel to snap to the top and shrink to 60px height.
	self.set_anchors_preset(Control.PRESET_TOP_WIDE)
	self.size.y = 60
	self.position.y = 0
	# Connect signals safely
	if export_btn and not export_btn.pressed.is_connected(_on_export_pressed):
		export_btn.pressed.connect(_on_export_pressed)

	if file_dialog and not file_dialog.file_selected.is_connected(_on_file_saved):
		file_dialog.file_selected.connect(_on_file_saved)

func _on_export_pressed():
	if file_dialog:
		file_dialog.popup_centered()
	else:
		print("ERROR: File Dialog is missing! Assign it in the Inspector.")

func _on_file_saved(path):
	# 1. HIDE UI
	self.visible = false
	if sidebar: sidebar.visible = false
	
	# 2. HANDLE TRANSPARENCY
	var original_bg_visible = true
	if background_rect:
		original_bg_visible = background_rect.visible
		if transparent_check and transparent_check.button_pressed:
			background_rect.visible = false
			get_viewport().transparent_bg = true
	
	# 3. WAIT FOR DRAWING TO FINISH
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 4. CAPTURE & SAVE
	var img = get_viewport().get_texture().get_image()
	img.save_png(path)
	
	# 5. RESTORE UI
	self.visible = true
	if sidebar: sidebar.visible = true
	
	if background_rect:
		background_rect.visible = original_bg_visible
	get_viewport().transparent_bg = false
