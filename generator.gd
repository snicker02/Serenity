extends Node2D

const MODE_FLOWER = 3
const MODE_CURRENT = 4
const MODE_ORBIT = 5
# --- SETTINGS ---
@export_group("Art Style")
@export var line_color: Color = Color.BLACK:
	set(val): line_color = val; queue_redraw()
@export var line_width: float = 2.0:
	set(val): line_width = val; queue_redraw()
@export var spacing: float = 15.0:
	set(val): spacing = val; queue_redraw()
@export var count: int = 15:
	set(val): count = val; queue_redraw()
@export var wobble: float = 0.0:
	set(val): wobble = val; queue_redraw()
@export var twist: float = 0.1:
	set(val): twist = val; queue_redraw()
@export var spiral_bias: float = 0.5:
	set(val): spiral_bias = val; queue_redraw()
@export var use_bias: bool = false:
	set(val): use_bias = val; queue_redraw()
@export var smooth_joints: bool = true:
	set(val): smooth_joints = val; queue_redraw()
@export var stabilize_ends: bool = true:
	set(val): stabilize_ends = val; queue_redraw()
@export var cell_roundness: float = 0.5:
	set(val): cell_roundness = val; queue_redraw()

var pattern_mode: int = 0:
	set(val): pattern_mode = val; queue_redraw()

# --- NODES ---
@onready var mask_viewport = $"../MaskViewport"
@onready var frozen_art = $"../FrozenArt"

# --- STATE ---
var control_points: PackedVector2Array = []
var drag_index: int = -1
var drag_threshold: float = 15.0
var is_live_editing: bool = false
var current_footprints: Array[PackedVector2Array] = []
var global_mask_polygons: Array[PackedVector2Array] = []

var drawing: bool = false
var start_point: Vector2 = Vector2.ZERO
var current_flower_radius: float = 0.0
var current_end_point: Vector2 = Vector2.ZERO

var noise = FastNoiseLite.new()

func _ready():
	self.z_index = 10
	self.position = Vector2.ZERO
	if frozen_art:
		frozen_art.position = Vector2.ZERO
		frozen_art.z_index = 5
	mask_viewport.size = Vector2i(get_viewport_rect().size)
	mask_viewport.transparent_bg = true
	var mat = self.material as ShaderMaterial
	if mat:
		await get_tree().process_frame
		mat.set_shader_parameter("mask_texture", mask_viewport.get_texture())
	queue_redraw()
	
	# Configure the Noise Source
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM

func _unhandled_input(event):
	# 1. HANDLE KEYBOARD (Spacebar Freeze)
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			if is_live_editing:
				if pattern_mode == MODE_FLOWER:
					freeze_flower_shape()
				elif pattern_mode == MODE_ORBIT:
					freeze_orbit_shape()
				else:
					# This 'else' catches Aura(0), Paradox(1), Cellular(2), and Current(4)
					# freeze_current_shape() handles all of these!
					freeze_current_shape()
				get_viewport().set_input_as_handled()

	# 2. HANDLE MOUSE BUTTONS
	elif event is InputEventMouseButton:
		var mouse_pos = get_local_mouse_position()
		
		# --- LEFT CLICK ---
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# CASE A: Radial Modes (Flower + Orbit)
				if pattern_mode == MODE_FLOWER or pattern_mode == MODE_ORBIT:
					drawing = true
					is_live_editing = true
					start_point = get_global_mouse_position()
					current_flower_radius = 1.0
				
				# CASE B: Current Mode
				elif pattern_mode == MODE_CURRENT:
					drawing = true
					is_live_editing = true
					start_point = get_global_mouse_position()
					current_end_point = start_point 
					
				# CASE C: Point Modes (Aura/Paradox/Cellular)
				elif is_live_editing:
					# If already live, click drags the point
					drag_index = get_point_under_mouse(mouse_pos)
					if drag_index != -1: queue_redraw()
				else:
					# If not live, click adds a new point
					drag_index = get_point_under_mouse(mouse_pos)
					if drag_index == -1:
						control_points.append(mouse_pos)
						drag_index = control_points.size() - 1
					queue_redraw()
			else:
				# Mouse Released
				if pattern_mode >= 3: # Flower, Current, Orbit
					drawing = false
				else:
					drag_index = -1

		# --- RIGHT CLICK ---
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# For Flower/Orbit/Current: Cancel/Stop
			if pattern_mode >= 3:
				is_live_editing = false
				drawing = false
				queue_redraw()
			else:
				# For Point Modes: FINISH drawing and Start Editing
				var min_points = 1 if pattern_mode == 2 else 2
				if control_points.size() >= min_points:
					if not is_live_editing:
						is_live_editing = true
						queue_redraw()

	# 3. HANDLE MOUSE MOTION
	elif event is InputEventMouseMotion:
		if pattern_mode == MODE_FLOWER or pattern_mode == MODE_ORBIT:
			if drawing:
				current_flower_radius = start_point.distance_to(get_global_mouse_position())
				queue_redraw()
		elif pattern_mode == MODE_CURRENT:
			if drawing:
				current_end_point = get_global_mouse_position()
				queue_redraw()
		elif drag_index != -1:
			control_points[drag_index] = get_local_mouse_position()
			queue_redraw()

func _draw():
	# --- CRASH PREVENTION SAFETY CHECK ---
	# If we are in a point-based mode (0, 1, 2) and have no points, STOP.
	if pattern_mode <= 2 and control_points.size() < 1:
		return
	
	# 1. DRAW SKELETON (Only for Point Modes)
	if pattern_mode <= 2 and control_points.size() > 0:
		if pattern_mode != 2 and control_points.size() > 1:
			var col = Color(0.5, 0.5, 0.5, 0.5)
			if is_live_editing: col = Color(1, 0.8, 0, 0.5)
			draw_polyline(control_points, col, 1.0)
			if is_live_editing and pattern_mode == 1:
				draw_line(control_points[-1], control_points[0], col, 1.0)
		
		for i in range(control_points.size()):
			var col = Color.WHITE
			if i == drag_index: col = Color.GREEN
			var radius = 3.0 if pattern_mode == 2 else 5.0
			draw_circle(control_points[i], radius, col)
			draw_circle(control_points[i], radius, Color.BLACK, false)

	# 2. DRAW LIVE PREVIEW (Point Modes)
	if is_live_editing and pattern_mode <= 2:
		var visuals = calculate_current_visuals()
		for line in visuals:
			draw_polyline(line, line_color, line_width, true)
	
	# 3. DRAW RED PREVIEW (Point Modes - Before Live)
	elif pattern_mode <= 2 and control_points.size() > 1:
		if pattern_mode == 0:
			draw_polyline(get_smooth_curve(control_points), Color.RED, 2.0, true)
		elif pattern_mode != 2: # Paradox
			var poly = control_points.duplicate(); poly.append(control_points[0])
			draw_polyline(poly, Color.RED, 2.0, true)
			
	# 4. DRAW FLOWER PREVIEW
	if pattern_mode == MODE_FLOWER:
		if is_live_editing:
			_draw_flower_pattern(start_point, current_flower_radius)

	# 5. DRAW ORBIT PREVIEW (NEW)
	if pattern_mode == MODE_ORBIT:
		if is_live_editing:
			_draw_orbit_pattern(start_point, current_flower_radius)

	# 5. DRAW CURRENT PREVIEW
	if pattern_mode == MODE_CURRENT:
		# Draw if we are live editing (even if NOT drawing/dragging anymore)
		if is_live_editing:
			# FIX: Add .abs() here so dragging Left/Up works!
			var rect = Rect2(start_point, current_end_point - start_point).abs()
			
			if rect.size.length() > 5.0:
				var lines = calculate_current_shapes(rect)
				for line in lines:
					draw_polyline(line, line_color, line_width, true)

# --- CORE LOGIC ---

func calculate_current_visuals() -> Array:
	var raw_lines = []
	current_footprints.clear()
	
	# Safety Check for Point Modes
	if control_points.is_empty(): return []

	if pattern_mode == 0:
		# --- AURA ---
		var spine = get_smooth_curve(control_points)
		raw_lines.append(spine)
		raw_lines.append_array(generate_flush_smart_aura(spine, 1.0))
		
	elif pattern_mode == 1:
		# --- PARADOX ---
		var poly = control_points.duplicate(); poly.append(control_points[0])
		raw_lines = generate_paradox_spiral(poly)

	elif pattern_mode == 2:
		# --- CELLULAR AURA ---
		var bounds = get_viewport_rect()
		var cells = generate_voronoi_cells(control_points, bounds)
		current_footprints = cells

		for i in range(cells.size()):
			var cell = cells[i]
			var seed_point = control_points[i]
			
			# 1. Round Corners
			var radius = cell_roundness * 100.0
			var rounded_cell = round_polygon_corners(cell, radius)
			if !rounded_cell.is_empty() and rounded_cell[0] != rounded_cell[-1]:
				rounded_cell.append(rounded_cell[0])
			
			# 2. GENERATE RINGS
			var rings = []
			rings.append(rounded_cell)
			
			for k in range(1, count + 1):
				var t = float(k) / float(count + 1)
				var inner_ring = PackedVector2Array()
				for vertex in rounded_cell:
					inner_ring.append(vertex.lerp(seed_point, t))
				rings.append(inner_ring)
			
			var center_ring = PackedVector2Array()
			for v in range(rounded_cell.size()):
				center_ring.append(seed_point)
			rings.append(center_ring)
			
			raw_lines.append_array(rings)
			
			# 3. GENERATE WEAVE
			for r in range(rings.size() - 1):
				var outer = rings[r]
				var inner = rings[r+1]
				if outer.size() != inner.size(): continue
				
				var direction = 1.0 if (r % 2 == 0) else -1.0
				
				for j in range(outer.size() - 1):
					var A1 = outer[j]; var A2 = outer[j+1]
					var B1 = inner[j]; var B2 = inner[j+1]
					
					var segment_len = A1.distance_to(A2)
					var inner_len = B1.distance_to(B2)
					
					var safe_spacing = max(2.0, spacing)
					var steps = max(6, int(segment_len / safe_spacing))
					
					for s in range(steps):
						var t_seg = float(s) / float(steps)
						var start = A1.lerp(A2, t_seg)
						var end = B1.lerp(B2, t_seg)
						var mid = (start + end) / 2.0
						var line_vec = end - start
						
						var normal = Vector2.ZERO
						if line_vec.length_squared() > 0.001:
							normal = Vector2(-line_vec.y, line_vec.x).normalized()
						else:
							var fallback = (A2 - A1).normalized()
							normal = Vector2(-fallback.y, fallback.x)
						
						var gap_dist = start.distance_to(end)
						var width_at_mid = (segment_len + inner_len) / 2.0
						var dist_ratio = min(t_seg, 1.0 - t_seg)
						var max_corner_depth = width_at_mid * dist_ratio * 0.9
						var max_ring_depth = gap_dist * 0.45
						var safe_limit = min(max_corner_depth, max_ring_depth)
						var damp = sin(t_seg * PI)
						var desired_depth = gap_dist * twist * 6.0 * damp
						var final_depth = clamp(desired_depth, -safe_limit, safe_limit)
						
						var control = mid + (normal * final_depth * direction)
						var curve_points = get_quadratic_bezier(start, control, end, 8)
						raw_lines.append(curve_points)

	var clipped_visuals = clip_lines_against_global_mask(raw_lines)
	return apply_wobble_to_all(clipped_visuals)

# --- FREEZING LOGIC (UPDATED) ---

func freeze_current_shape():
	# 1. HANDLE CURRENT MODE (Mode 4)
	if pattern_mode == MODE_CURRENT:
		var rect = Rect2(start_point, current_end_point - start_point).abs()
		
		if rect.size.length() < 5.0: return
		
		var raw_lines = calculate_current_shapes(rect)
		var clipped = clip_lines_against_global_mask(raw_lines)
		
		# Save Visuals
		frozen_art.add_aura(clipped, line_color, line_width)
		
		# Save Mask
		var mask_poly = PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		])
		global_mask_polygons.append(mask_poly)
		
		var mask_canvas = mask_viewport.get_node("MaskCanvas")
		var fill = Polygon2D.new()
		fill.polygon = mask_poly
		fill.color = Color.WHITE
		mask_canvas.add_child(fill)
		
		is_live_editing = false
		drawing = false
		queue_redraw()
		return

	# 2. HANDLE POINT MODES (0, 1, 2)
	var final_lines = calculate_current_visuals()
	frozen_art.add_aura(final_lines, line_color, line_width)
	var mask_canvas = mask_viewport.get_node("MaskCanvas")
	var new_masks = []
	
	if pattern_mode == 0:
		var final_spine = get_smooth_curve(control_points)
		var mask_thickness = (count * spacing) + (line_width * 2.0)
		new_masks = Geometry2D.offset_polyline(final_spine, mask_thickness, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT)
		for line in final_lines: 
			var wall = Line2D.new()
			wall.points = line
			wall.width = spacing + line_width
			wall.default_color = Color.WHITE
			mask_canvas.add_child(wall)
	
	elif pattern_mode == 1:
		var closed_poly = control_points.duplicate()
		closed_poly.append(control_points[0])
		new_masks = [closed_poly]
		var fill = Polygon2D.new()
		fill.polygon = closed_poly
		fill.color = Color.WHITE
		mask_canvas.add_child(fill)
	
	elif pattern_mode == 2:
		new_masks = current_footprints
		for cell in new_masks: 
			var fill = Polygon2D.new()
			fill.polygon = cell
			fill.color = Color.WHITE
			mask_canvas.add_child(fill)
			
	global_mask_polygons.append_array(new_masks)
	is_live_editing = false
	control_points.clear()
	drag_index = -1
	queue_redraw()

func freeze_flower_shape():
	var raw_lines = calculate_flower_shapes(start_point, current_flower_radius)
	var clipped_lines = clip_lines_against_global_mask(raw_lines)
	
	if frozen_art:
		frozen_art.add_aura(clipped_lines, line_color, line_width)
	
	if raw_lines.size() > 0:
		var footprint = raw_lines[0]
		global_mask_polygons.append(footprint)
		var mask_canvas = mask_viewport.get_node("MaskCanvas")
		var fill = Polygon2D.new()
		fill.polygon = footprint
		fill.color = Color.WHITE
		mask_canvas.add_child(fill)
	
	is_live_editing = false
	drawing = false
	queue_redraw()

func _draw_flower_pattern(center_pos, max_radius):
	# 1. Calculate the raw shapes
	var raw_lines = calculate_flower_shapes(center_pos, max_radius)
	
	# 2. CLIP THEM against existing art
	# This ensures the flower looks like it is "behind" older objects
	var clipped_lines = clip_lines_against_global_mask(raw_lines)
	
	# 3. Draw only the visible parts
	for line in clipped_lines:
		draw_polyline(line, line_color, line_width, true)

# --- SHAPE CALCULATIONS ---

func calculate_flower_shapes(center: Vector2, start_radius: float) -> Array:
	var shapes = []
	var master_poly = PackedVector2Array()
	var petal_count = int(wobble * 10) + 3
	var depth = cell_roundness * 0.5
	var resolution = 120
	
	for j in range(resolution + 1):
		var angle = (float(j) / resolution) * TAU
		var wave = 0.0
		
		if smooth_joints:
			wave = cos((angle * petal_count) * 0.5)
			if stabilize_ends: wave = (wave + 1.0) * 0.5
		else:
			wave = abs(cos((angle * petal_count) * 0.5))
			if stabilize_ends: wave = 1.0 - wave
		
		var r_norm = (1.0 - depth) + (depth * wave)
		master_poly.append(Vector2(cos(angle) * r_norm, sin(angle) * r_norm))

	for i in range(count):
		var scale_factor = start_radius - (i * spacing)
		if scale_factor < 5: break
		
		var ring_points = PackedVector2Array()
		for norm_point in master_poly:
			var px = norm_point.x * scale_factor
			var py = norm_point.y * scale_factor
			var dist = scale_factor
			var swirl_angle = (dist * twist) * 0.01
			
			var twisted_x = (px * cos(swirl_angle)) - (py * sin(swirl_angle))
			var twisted_y = (px * sin(swirl_angle)) + (py * cos(swirl_angle))
			
			ring_points.append(Vector2(twisted_x, twisted_y) + center)
		shapes.append(ring_points)

	return shapes

func calculate_current_shapes(bounds: Rect2) -> Array:
	var shapes = []
	var frequency = 0.005 + (twist * 0.05)
	var wave_height = wobble * 50.0
	
	# DETECT DIRECTION: Is the box taller than it is wide?
	var is_vertical = bounds.size.y > bounds.size.x
	
	var safe_break = 0
	
	# --- VERTICAL FLOW (Rain / Waterfall) ---
	if is_vertical:
		var step_y = 5.0
		
		# 1. Snap to Grid (Y-Axis)
		var start_y = floor(bounds.position.y / step_y) * step_y
		if start_y < bounds.position.y: start_y += step_y
		var steps = int((bounds.end.y - start_y) / step_y)
		
		if steps < 0: return []
		
		# 2. Initialize the "Wall" (X-positions starting at left)
		var current_x_values = []
		for i in range(steps + 1):
			current_x_values.append(bounds.position.x)
			
		# 3. Stack layers Left-to-Right
		while safe_break < 500:
			safe_break += 1
			
			# Stop if we pass the right edge
			var min_x = 99999
			for x in current_x_values: if x < min_x: min_x = x
			if min_x > bounds.end.x: break
			
			var line_points = PackedVector2Array()
			var next_x_values = []
			
			for i in range(steps + 1):
				var y_pos = start_y + (i * step_y)
				
				# Noise moves the X position
				var noise_val = noise.get_noise_2d(safe_break * 10.0, y_pos * frequency)
				var flow_force = abs(noise_val)
				
				# Add gap to X
				var added_gap = spacing + (flow_force * wave_height)
				added_gap = max(added_gap, 2.0)
				
				var new_x = current_x_values[i] + added_gap
				
				line_points.append(Vector2(new_x, y_pos))
				next_x_values.append(new_x)
				
			shapes.append(line_points)
			current_x_values = next_x_values

	# --- HORIZONTAL FLOW (River) ---
	else:
		var step_x = 5.0
		
		# 1. Snap to Grid (X-Axis)
		var start_x = floor(bounds.position.x / step_x) * step_x
		if start_x < bounds.position.x: start_x += step_x
		var steps = int((bounds.end.x - start_x) / step_x)
		
		if steps < 0: return []
		
		# 2. Initialize the "Floor" (Y-positions starting at top)
		var current_y_values = []
		for i in range(steps + 1):
			current_y_values.append(bounds.position.y)
			
		# 3. Stack layers Top-to-Bottom
		while safe_break < 500:
			safe_break += 1
			
			# Stop if we pass the bottom edge
			var min_y = 99999
			for y in current_y_values: if y < min_y: min_y = y
			if min_y > bounds.end.y: break
				
			var line_points = PackedVector2Array()
			var next_y_values = []
			
			for i in range(steps + 1):
				var x_pos = start_x + (i * step_x)
				
				# Noise moves the Y position
				var noise_val = noise.get_noise_2d(x_pos * frequency, safe_break * 10.0)
				var flow_force = abs(noise_val)
				
				# Add gap to Y
				var added_gap = spacing + (flow_force * wave_height)
				added_gap = max(added_gap, 2.0)
				
				var new_y = current_y_values[i] + added_gap
				
				line_points.append(Vector2(x_pos, new_y))
				next_y_values.append(new_y)
				
			shapes.append(line_points)
			current_y_values = next_y_values

	return shapes

# --- UTILS ---

func get_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var t_inv = 1.0 - t
		var p = (t_inv * t_inv * p0) + (2.0 * t_inv * t * p1) + (t * t * p2)
		points.append(p)
	return points

func generate_voronoi_cells(points: PackedVector2Array, bounds: Rect2) -> Array[PackedVector2Array]:
	if points.is_empty(): return []
	var cells: Array[PackedVector2Array] = []
	var canvas_poly = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y), bounds.position])
	for i in range(points.size()): cells.append(canvas_poly)
	var diag = bounds.size.length() * 2.0
	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			var p1 = points[i]; var p2 = points[j]; var midpoint = (p1 + p2) / 2.0; var dir = (p2 - p1).normalized(); var normal = Vector2(-dir.y, dir.x)
			var hp1 = PackedVector2Array([midpoint + normal*diag, midpoint - normal*diag, midpoint - normal*diag - dir*diag, midpoint + normal*diag - dir*diag, midpoint + normal*diag]); var res1 = Geometry2D.intersect_polygons(cells[i], hp1)
			if not res1.is_empty(): cells[i] = res1[0]
			var hp2 = PackedVector2Array([midpoint + normal*diag, midpoint - normal*diag, midpoint - normal*diag + dir*diag, midpoint + normal*diag + dir*diag, midpoint + normal*diag]); var res2 = Geometry2D.intersect_polygons(cells[j], hp2)
			if not res2.is_empty(): cells[j] = res2[0]
	return cells

func round_polygon_corners(poly: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius < 1.0 or poly.size() < 3: return poly
	var inset = Geometry2D.offset_polygon(poly, -radius, Geometry2D.JOIN_MITER)
	if inset.is_empty(): return poly
	var rounded = Geometry2D.offset_polygon(inset[0], radius, Geometry2D.JOIN_ROUND)
	return rounded[0] if not rounded.is_empty() else poly

func generate_paradox_spiral(corners: PackedVector2Array) -> Array:
	var result = [corners]; var current_poly = corners.duplicate(); var base_twist = twist
	for i in range(count):
		var next_poly = PackedVector2Array()
		for j in range(current_poly.size() - 1):
			var A = current_poly[j]; var B = current_poly[j+1]; var effective_t = base_twist
			if use_bias:
				var strength = (spiral_bias - 0.5) * 2.0; var direction = 1.0 if (j % 2 == 0) else -1.0
				effective_t += (strength * direction * 0.35)
			effective_t = clamp(effective_t, 0.05, 0.95); next_poly.append(A.lerp(B, effective_t))
		next_poly.append(next_poly[0]); if get_poly_area(next_poly) < 500: break
		result.append(next_poly); current_poly = next_poly
	return result

func generate_flush_smart_aura(spine: PackedVector2Array, direction_mult: float = 1.0) -> Array:
	var all_shapes = []; var joint_type = Geometry2D.JOIN_ROUND if smooth_joints else Geometry2D.JOIN_MITER; var end_type = Geometry2D.END_BUTT
	for i in range(1, count + 1):
		var offset = float(i) * spacing * direction_mult; var polygons = Geometry2D.offset_polyline(spine, offset, joint_type, end_type)
		for poly in polygons: all_shapes.append(poly)
	return all_shapes

func clip_lines_against_global_mask(lines: Array) -> Array:
	if global_mask_polygons.is_empty(): return lines
	var clipped = []
	for line in lines:
		var result = [line]
		for mask in global_mask_polygons:
			var new_pieces = []
			for piece in result: new_pieces.append_array(Geometry2D.clip_polyline_with_polygon(piece, mask))
			result = new_pieces
		clipped.append_array(result)
	return clipped

func apply_wobble_to_all(lines: Array) -> Array:
	if wobble == 0: return lines
	var wobbled_lines = []
	for line in lines:
		var wobbly = PackedVector2Array()
		for p in line: wobbly.append(Vector2(p.x + randf_range(-wobble, wobble), p.y + randf_range(-wobble, wobble)))
		wobbled_lines.append(wobbly)
	return wobbled_lines

func get_point_under_mouse(m_pos: Vector2) -> int:
	for i in range(control_points.size()): if m_pos.distance_to(control_points[i]) < drag_threshold: return i
	return -1

func get_smooth_curve(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2: return points
	var curve = Curve2D.new(); for i in range(points.size()):
		var p = points[i]; var dir = Vector2.ZERO
		if i > 0 and i < points.size() - 1: dir = (points[i+1] - points[i-1]).normalized()
		elif i == 0: dir = (points[i+1] - p).normalized()
		elif i == points.size() - 1: dir = (p - points[i-1]).normalized()
		var handle_strength = 0.0; if i > 0 and i < points.size() - 1: handle_strength = min(p.distance_to(points[i-1]), p.distance_to(points[i+1])) * 0.3
		curve.add_point(p, -dir * handle_strength, dir * handle_strength)
	curve.bake_interval = 2.0; return curve.get_baked_points()

func get_poly_area(points: PackedVector2Array) -> float:
	if points.size() < 3: return 0.0
	var area = 0.0; for i in range(points.size()): var j = (i + 1) % points.size(); area += points[i].x * points[j].y; area -= points[j].x * points[i].y
	return abs(area / 2.0)

func clear_all():
	global_mask_polygons.clear(); var mask_canvas = mask_viewport.get_node("MaskCanvas"); for child in mask_canvas.get_children(): child.queue_free()
	if frozen_art: frozen_art.clear_art(); control_points.clear(); drag_index = -1; is_live_editing = false; queue_redraw()

# --- ORBIT (SPIROGRAPH) LOGIC ---

func _draw_orbit_pattern(center_pos, max_radius):
	# 1. Calculate
	var raw_lines = calculate_orbit_shapes(center_pos, max_radius)
	if raw_lines.is_empty(): return
	
	# 2. CLIP IT (So the preview looks like it's behind old art)
	var clipped_lines = clip_lines_against_global_mask(raw_lines)
	
	# 3. DRAW LINES ONLY
	for line in clipped_lines:
		draw_polyline(line, line_color, line_width, true)

func freeze_orbit_shape():
	var raw_lines = calculate_orbit_shapes(start_point, current_flower_radius)
	if raw_lines.is_empty(): return
	
	# 1. CLIP IT (So it respects old art)
	var clipped_lines = clip_lines_against_global_mask(raw_lines)
	
	# 2. SAVE THE LINES (Visuals)
	if frozen_art:
		# We only add the wireframe lines! No solid background.
		frozen_art.add_aura(clipped_lines, line_color, line_width)
	
	# 3. CREATE THE MASK (Invisible Logic)
	# We take the outermost ring to define the "territory" of this shape.
	if raw_lines.size() > 0:
		var footprint = raw_lines[0]
		
		# Convert the looping wire into a solid math footprint
		var solid_bg = get_solid_silhouette(footprint)
		
		var mask_canvas = mask_viewport.get_node("MaskCanvas")
		
		for poly in solid_bg:
			# A. Add to Math Mask (Stops future lines from drawing here)
			global_mask_polygons.append(poly)
			
			# B. Add to Shader Mask (Updates the 'behind' buffer)
			var fill = Polygon2D.new()
			fill.polygon = poly
			fill.color = Color.WHITE 
			mask_canvas.add_child(fill)
			
			# C. DO NOT add anything to 'frozen_art'. 
			# This keeps it transparent/wireframe on screen!

	is_live_editing = false
	drawing = false
	queue_redraw()

func calculate_orbit_shapes(center: Vector2, start_radius: float) -> Array:
	var shapes = []
	
	# --- 1. SETUP PARAMETERS ---
	var master_poly = PackedVector2Array()
	
	# Resolution: Sharp corners need fewer points to look "sharp" sometimes, 
	# but for Triangle Waves we need high resolution to catch the tips.
	var resolution = 360
	
	# Twist = How many loops (Integer locked)
	var k = int(twist * 10.0) + 1 
	
	# Wobble = Loop Depth
	var loop_depth = wobble * 0.8
	
	# CHECKBOX 1: STABILIZE ENDS (In vs Out)
	# OFF = Hypotrochoid (Standard Spirograph, loops inside)
	# ON  = Epitrochoid (Loops outside, like a flower)
	var direction = 1.0 
	if stabilize_ends:
		direction = -1.0 # Inverts the secondary rotation
	
	for i in range(resolution + 1):
		var t = (float(i) / resolution) * TAU
		
		# 1. Primary Circle Motion
		var x1 = cos(t)
		var y1 = sin(t)
		
		# 2. Secondary Loop Motion
		var angle_2 = (k + 1) * t
		var x2 = 0.0
		var y2 = 0.0
		
		# CHECKBOX 2: ROUND CORNERS (Smooth vs Sharp)
		if smooth_joints:
			# Standard smooth circles
			x2 = cos(angle_2)
			y2 = sin(angle_2)
		else:
			# Triangle Wave (Sharp Points)
			# Formula: (2/PI) * asin(sin(theta)) creates a zigzag line
			x2 = (2.0 / PI) * asin(sin(angle_2))
			y2 = (2.0 / PI) * asin(sin(angle_2 - (PI/2.0))) # Shift for Y phase
			
		# 3. Combine with Direction
		# 'direction' flips the math to make loops point Out vs In
		var x = x1 + (loop_depth * x2 * direction)
		var y = y1 + (loop_depth * y2 * direction)
		
		master_poly.append(Vector2(x, y))

	# --- 2. GENERATE RINGS ---
	for i in range(count):
		var scale_factor = start_radius - (i * spacing)
		if scale_factor < 5: break
		
		var ring_points = PackedVector2Array()
		var rot_offset = (i * 0.02) if twist > 0.5 else 0.0
		
		for pt in master_poly:
			# Scale
			var px = pt.x * scale_factor
			var py = pt.y * scale_factor
			
			# Rotate
			var rx = (px * cos(rot_offset)) - (py * sin(rot_offset))
			var ry = (px * sin(rot_offset)) + (py * cos(rot_offset))
			
			ring_points.append(center + Vector2(rx, ry))
			
		shapes.append(ring_points)
		
	return shapes
# --- HELPER: CREATES THE INVISIBLE MASK ---
func get_solid_silhouette(points: PackedVector2Array) -> Array:
	# This creates a solid polygon shape that matches the outline of your loops.
	# We use this for the INVISIBLE mask layer, so new shapes don't draw over this one.
	return Geometry2D.offset_polygon(points, 2.0, Geometry2D.JOIN_ROUND)
