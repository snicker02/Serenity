extends PanelContainer

# --- EXPORT VARIABLES (These create the slots) ---
@export var background_rect: ColorRect 
@export var generator: Node2D

# --- UI NODES ---
@onready var pattern_select = $VBoxContainer/PatternSelect

# SLIDERS
@onready var width_slider = $VBoxContainer/WidthSlider
@onready var spacing_slider = $VBoxContainer/SpacingSlider
@onready var count_slider = $VBoxContainer/CountSlider
@onready var wobble_slider = $VBoxContainer/WobbleSlider

# PARADOX CONTROLS
@onready var twist_slider = $VBoxContainer.get_node_or_null("TwistSlider") 
@onready var bias_slider = $VBoxContainer.get_node_or_null("BiasSlider")
@onready var bias_check = $VBoxContainer.get_node_or_null("BiasCheck")

# CELLULAR CONTROLS
@onready var roundness_slider = $VBoxContainer.get_node_or_null("RoundnessSlider")

# LABELS
@onready var spacing_label = $VBoxContainer.get_node_or_null("SpacingLabel")
@export var twist_label: Label
@onready var bias_label = $VBoxContainer.get_node_or_null("BiasLabel")
@onready var roundness_label = $VBoxContainer.get_node_or_null("RoundnessLabel")
@onready var width_label = $VBoxContainer.get_node_or_null("WidthLabel")
@onready var count_label = $VBoxContainer.get_node_or_null("CountLabel")
@onready var wobble_label = $VBoxContainer.get_node_or_null("WobbleLabel")

# OTHERS
@onready var color_picker = $VBoxContainer/ColorPicker
@onready var bg_color_picker = $VBoxContainer/BGColorPicker
@onready var stabilizer_check = $VBoxContainer/StabilizerCheck
@onready var clear_button = $VBoxContainer/ClearButton
@onready var round_corners_check = $VBoxContainer/RoundCornersCheck 
@onready var instruction_label = $VBoxContainer.get_node_or_null("InstructionLabel")
func _ready():
	# 1. SETUP BACKGROUND
	if background_rect:
		background_rect.size = Vector2(10000, 10000)
		background_rect.position = Vector2(-5000, -5000)
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		if bg_color_picker: bg_color_picker.color = background_rect.color

	# 2. SETUP PATTERN SELECTOR
	if pattern_select:
		pattern_select.clear()
		pattern_select.add_item("Aura (Ripple)")
		pattern_select.add_item("Paradox (Spiral)")
		pattern_select.add_item("Cellular Aura")
		if !pattern_select.item_selected.is_connected(_on_pattern_selected):
			pattern_select.item_selected.connect(_on_pattern_selected)

	# 3. CONNECT SIGNALS
	if generator:
		# Connect Color Pickers
		if color_picker:
			color_picker.color = generator.line_color
			if !color_picker.color_changed.is_connected(_on_color_changed):
				color_picker.color_changed.connect(_on_color_changed)
		
		if bg_color_picker:
			if !bg_color_picker.color_changed.is_connected(_on_bg_color_changed):
				bg_color_picker.color_changed.connect(_on_bg_color_changed)

		# Connect Sliders
		_connect_slider(width_slider, "line_width", _on_width_changed)
		_connect_slider(spacing_slider, "spacing", _on_spacing_changed)
		_connect_slider(count_slider, "count", _on_count_changed)
		_connect_slider(wobble_slider, "wobble", _on_wobble_changed)
		
		# Paradox connections
		_connect_slider(twist_slider, "twist", _on_twist_changed)
		_connect_slider(bias_slider, "spiral_bias", _on_bias_changed)
		if bias_check and !bias_check.toggled.is_connected(_on_bias_toggled):
			if "use_bias" in generator: bias_check.button_pressed = generator.use_bias
			bias_check.toggled.connect(_on_bias_toggled)

		# Cellular connection
		_connect_slider(roundness_slider, "cell_roundness", _on_roundness_changed)

		if stabilizer_check and !stabilizer_check.toggled.is_connected(_on_stabilizer_toggled):
			if "stabilize_ends" in generator: stabilizer_check.button_pressed = generator.stabilize_ends
			stabilizer_check.toggled.connect(_on_stabilizer_toggled)
		
		if round_corners_check and !round_corners_check.toggled.is_connected(_on_round_corners_toggled):
			if "smooth_joints" in generator: round_corners_check.button_pressed = generator.smooth_joints
			round_corners_check.toggled.connect(_on_round_corners_toggled)
				
		if clear_button and !clear_button.pressed.is_connected(_on_clear_pressed):
			clear_button.pressed.connect(_on_clear_pressed)

	# 4. INITIALIZE VISUALS
	_on_pattern_selected(0)
	
	# Force labels to update on startup
	if width_slider: _on_width_changed(width_slider.value)
	if spacing_slider: _on_spacing_changed(spacing_slider.value)
	if count_slider: _on_count_changed(count_slider.value)
	if wobble_slider: _on_wobble_changed(wobble_slider.value)
	if twist_slider: _on_twist_changed(twist_slider.value)
	if bias_slider: _on_bias_changed(bias_slider.value)
	if roundness_slider: _on_roundness_changed(roundness_slider.value)

func _connect_slider(slider, var_name, func_ref):
	if slider:
		if var_name in generator: slider.value = generator.get(var_name)
		if !slider.value_changed.is_connected(func_ref):
			slider.value_changed.connect(func_ref)

# --- VISIBILITY LOGIC ---
func _on_pattern_selected(index):
	if generator: generator.pattern_mode = index
	
	# --- UPDATE INSTRUCTIONS ---
	if instruction_label:
		if index == 0: # AURA
			instruction_label.text = "Left click to place/move points.\nRight click for edit preview.\nSpacebar to commit."
		elif index == 1: # PARADOX
			instruction_label.text = "Left click to place/move points.\nRight click for edit preview.\nSpacebar to commit."
		elif index == 2: # CELLULAR
			instruction_label.text = "Left click to place/move points.\nRight click for edit preview.\nSpacebar to commit."
	
	# --- VISIBILITY TOGGLES (Existing Logic) ---
	var toggle_nodes = func(nodes, show_it):
		for node in nodes: if node: node.visible = show_it

	var aura_only = [stabilizer_check]
	var paradox_only = [bias_slider, bias_label, bias_check]
	var cellular_only = [roundness_slider, roundness_label]
	
	var twist_controls = [twist_slider, twist_label]
	var shared_corners = [round_corners_check] 
	var spacing_controls = [spacing_slider, spacing_label] 

	if index == 0: # AURA
		toggle_nodes.call(aura_only, true)
		toggle_nodes.call(spacing_controls, true)
		toggle_nodes.call(shared_corners, true)
		toggle_nodes.call(paradox_only, false)
		toggle_nodes.call(cellular_only, false)
		toggle_nodes.call(twist_controls, false)
		
	elif index == 1: # PARADOX
		toggle_nodes.call(aura_only, false)
		toggle_nodes.call(spacing_controls, false)
		toggle_nodes.call(shared_corners, false)
		toggle_nodes.call(paradox_only, true)
		toggle_nodes.call(cellular_only, false)
		toggle_nodes.call(twist_controls, true)
		
	elif index == 2: # CELLULAR
		toggle_nodes.call(aura_only, false)
		toggle_nodes.call(spacing_controls, true)
		toggle_nodes.call(paradox_only, false)
		toggle_nodes.call(cellular_only, true)
		toggle_nodes.call(shared_corners, true)
		toggle_nodes.call(twist_controls, true)

# --- SIGNAL FUNCTIONS ---


func _on_width_changed(value): 
	if generator: generator.line_width = value
	if width_label: width_label.text = "Line Width: " + str(snapped(value, 0.01))

func _on_spacing_changed(value): 
	if generator: generator.spacing = value
	if spacing_label: spacing_label.text = "Spacing: " + str(snapped(value, 0.01))

func _on_count_changed(value): 
	if generator: generator.count = int(value)
	if count_label: count_label.text = "Count: " + str(value)

func _on_wobble_changed(value): 
	if generator: generator.wobble = value
	if wobble_label: wobble_label.text = "Wobble: " + str(snapped(value, 0.1)) # Show 1 decimal

func _on_twist_changed(value): 
	# 1. Update the art
	if generator and "twist" in generator: 
		generator.twist = value
	
	# 2. Update the text (WITH DECIMALS)
	if twist_label: 
		# snapped(value, 0.01) turns 0.384 into 0.38
		twist_label.text = "Twist: " + str(snapped(value, 0.01)) 
	else:
		print("ERROR: Twist Label is NOT connected in Inspector!")
func _on_bias_changed(value): 
	if generator and "spiral_bias" in generator: generator.spiral_bias = value
	if bias_label: bias_label.text = "Bias: " + str(snapped(value, 0.01))

func _on_roundness_changed(value):
	if generator and "cell_roundness" in generator: generator.cell_roundness = value
	if roundness_label: roundness_label.text = "Roundness: " + str(snapped(value, 0.1))

# (Keep the color/clear functions as they were)
func _on_color_changed(new_color): if generator: generator.line_color = new_color
func _on_bg_color_changed(new_color): if background_rect: background_rect.color = new_color
func _on_bias_toggled(on): if generator and "use_bias" in generator: generator.use_bias = on
func _on_stabilizer_toggled(on): if generator: generator.stabilize_ends = on
func _on_round_corners_toggled(on): if generator: generator.smooth_joints = on
func _on_clear_pressed(): if generator: generator.clear_all()
