extends Node2D

# We now store Dictionaries: { "points": [], "color": Color, "width": float }
var shapes: Array = []

func _draw():
	for shape in shapes:
		if shape.points.size() >= 2:
			draw_polyline(shape.points, shape.color, shape.width, true)

# This function now asks: "What color and size should these lines be?"
func add_aura(new_lines: Array, paint_color: Color, paint_width: float):
	for line in new_lines:
		# Store the line AND its style
		shapes.append({
			"points": line,
			"color": paint_color,
			"width": paint_width
		})
	queue_redraw()
func clear_art():
	shapes.clear()
	queue_redraw()
