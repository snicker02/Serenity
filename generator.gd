extends Node2D

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

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			if is_live_editing:
				freeze_current_shape()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_pos = get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_live_editing:
					drag_index = get_point_under_mouse(mouse_pos)
					if drag_index != -1: queue_redraw()
				else:
					drag_index = get_point_under_mouse(mouse_pos)
					if drag_index == -1:
						control_points.append(mouse_pos)
						drag_index = control_points.size() - 1 
					queue_redraw()
			else:
				drag_index = -1
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var min_points = 1 if pattern_mode == 2 else 2
			if control_points.size() >= min_points: 
				if not is_live_editing:
					is_live_editing = true
					queue_redraw()
	elif event is InputEventMouseMotion:
		if drag_index != -1:
			control_points[drag_index] = get_local_mouse_position()
			queue_redraw()

func _draw():
	# 1. DRAW SKELETON
	if control_points.size() > 0:
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

	# 2. DRAW LIVE PREVIEW
	if is_live_editing:
		var visuals = calculate_current_visuals()
		for line in visuals:
			draw_polyline(line, line_color, line_width, true)
	# 3. DRAW RED PREVIEW
	elif control_points.size() > 1 and pattern_mode != 2:
		if pattern_mode == 0:
			draw_polyline(get_smooth_curve(control_points), Color.RED, 2.0, true)
		else:
			var poly = control_points.duplicate(); poly.append(control_points[0])
			draw_polyline(poly, Color.RED, 2.0, true)

# --- CORE LOGIC ---

func calculate_current_visuals() -> Array:
	var raw_lines = []
	current_footprints.clear()
	
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
		# --- CELLULAR AURA (FINAL SAFETY FIX) ---
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
			
			# Draw Structural Rings
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
					
					# FIX: Calculate Inner Length too. This is crucial for safety!
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
						
						# --- FINAL ROBUST SAFETY CLAMP ---
						
						# 1. Calculate Average Width of the "Lane" at this point
						# If inner ring is tiny, this value shrinks correctly.
						var width_at_mid = (segment_len + inner_len) / 2.0
						
						# 2. Horizontal Safety (Corner Distance)
						# Check distance to LEFT wall and RIGHT wall (0.0 to 0.5)
						var dist_ratio = min(t_seg, 1.0 - t_seg)
						
						# We allow the curve to use 90% of the available half-width.
						# This prevents touching the neighbor line.
						var max_corner_depth = width_at_mid * dist_ratio * 0.9
						
						# 3. Vertical Safety (Ring Gap)
						# Don't curve deeper than 45% of the ring height.
						var max_ring_depth = gap_dist * 0.45
						
						# 4. Combine Limits
						var safe_limit = min(max_corner_depth, max_ring_depth)
						
						# 5. Calculate Desired Twist
						var damp = sin(t_seg * PI) 
						var desired_depth = gap_dist * twist * 6.0 * damp
						
						# 6. Apply Clamp
						var final_depth = clamp(desired_depth, -safe_limit, safe_limit)
						
						var control = mid + (normal * final_depth * direction)
						var curve_points = get_quadratic_bezier(start, control, end, 8)
						raw_lines.append(curve_points)

	var clipped_visuals = clip_lines_against_global_mask(raw_lines)
	return apply_wobble_to_all(clipped_visuals)

# --- ALGORITHMS ---

# Simple Quadratic Bezier (3 points)
func get_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var t_inv = 1.0 - t
		# Formula: (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
		var p = (t_inv * t_inv * p0) + (2.0 * t_inv * t * p1) + (t * t * p2)
		points.append(p)
	return points

# ... (Include all previous helper functions: voronoi, round_corners, paradox, clip, etc.) ...
# NOTE: Ensure you copy the 'generate_voronoi_cells', 'round_polygon_corners', 
# 'generate_paradox_spiral', etc., from the previous script here.
# For brevity, I am not repeating them, but they MUST be present.

# --- UTILS COPIED FROM PREVIOUS STEPS FOR COMPLETENESS ---
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

func freeze_current_shape():
	var final_lines = calculate_current_visuals()
	frozen_art.add_aura(final_lines, line_color, line_width)
	var mask_canvas = mask_viewport.get_node("MaskCanvas")
	var new_masks = []
	if pattern_mode == 0:
		var final_spine = get_smooth_curve(control_points); var mask_thickness = (count * spacing) + (line_width * 2.0); new_masks = Geometry2D.offset_polyline(final_spine, mask_thickness, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT)
		for line in final_lines: var wall = Line2D.new(); wall.points = line; wall.width = spacing + line_width; wall.default_color = Color.WHITE; mask_canvas.add_child(wall)
	elif pattern_mode == 1:
		var closed_poly = control_points.duplicate(); closed_poly.append(control_points[0]); new_masks = [closed_poly]; var fill = Polygon2D.new(); fill.polygon = closed_poly; fill.color = Color.WHITE; mask_canvas.add_child(fill)
	elif pattern_mode == 2:
		new_masks = current_footprints; 
		for cell in new_masks: var fill = Polygon2D.new(); fill.polygon = cell; fill.color = Color.WHITE; mask_canvas.add_child(fill)
	global_mask_polygons.append_array(new_masks); is_live_editing = false; control_points.clear(); drag_index = -1; queue_redraw()

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
