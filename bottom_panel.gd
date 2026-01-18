extends PanelContainer

@export var point_btn: Button
@export var stop_btn: Button
@export var commit_btn: Button
@export var generator: Node2D # <--- CRITICAL: Make sure this is connected!

func _ready():
	# Connect buttons (Standard stuff)
	if point_btn and !point_btn.pressed.is_connected(_on_point_pressed):
		point_btn.pressed.connect(_on_point_pressed)
		point_btn.focus_mode = Control.FOCUS_NONE
		
	if stop_btn and !stop_btn.pressed.is_connected(_on_stop_pressed):
		stop_btn.pressed.connect(_on_stop_pressed)
		stop_btn.focus_mode = Control.FOCUS_NONE
		
	if commit_btn and !commit_btn.pressed.is_connected(_on_commit_pressed):
		commit_btn.pressed.connect(_on_commit_pressed)
		commit_btn.focus_mode = Control.FOCUS_NONE

func _on_point_pressed():
	print("DEBUG: Point Pressed")
	# Simulate Left Click in the CENTER of the screen (away from UI)
	var center = get_viewport().get_visible_rect().size / 2
	_force_input_to_generator(MOUSE_BUTTON_LEFT, true, center)
	await get_tree().process_frame # Wait a split second
	_force_input_to_generator(MOUSE_BUTTON_LEFT, false, center)

func _on_stop_pressed():
	print("DEBUG: Stop Pressed")
	# Simulate Right Click in the CENTER (Position usually doesn't matter for stopping)
	var center = get_viewport().get_visible_rect().size / 2
	_force_input_to_generator(MOUSE_BUTTON_RIGHT, true, center)
	_force_input_to_generator(MOUSE_BUTTON_RIGHT, false, center)

func _on_commit_pressed():
	print("DEBUG: Commit Pressed")
	# Force the Generator to see the Spacebar event
	var ev = InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	
	if generator:
		# Try both input methods to ensure one sticks
		if generator.has_method("_input"): generator._input(ev)
		if generator.has_method("_unhandled_input"): generator._unhandled_input(ev)

# --- THE SECRET WEAPON ---
func _force_input_to_generator(btn_index, is_pressed, pos):
	if not generator: 
		print("ERROR: Generator not connected in Inspector!")
		return

	var ev = InputEventMouseButton.new()
	ev.button_index = btn_index
	ev.pressed = is_pressed
	ev.position = pos
	ev.global_position = pos
	
	# Force feed the event directly to the generator script
	if generator.has_method("_unhandled_input"):
		generator._unhandled_input(ev)
	elif generator.has_method("_input"):
		generator._input(ev)
