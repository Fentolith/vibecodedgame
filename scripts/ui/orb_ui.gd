extends Control

@export var fill_color: Color = Color(0.85, 0.1, 0.1, 1.0)
@export var bg_color:   Color = Color(0.22, 0.22, 0.22, 0.9)
@export var label_text: String = "HP"

var _percent: float = 1.0   # 0.0 – 1.0

func set_value(current: float, maximum: float) -> void:
	_percent = clamp(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	queue_redraw()

func _draw() -> void:
	var r:      float   = minf(size.x, size.y) / 2.0 - 2.0
	var center: Vector2 = size / 2.0

	# Grey background circle
	draw_circle(center, r, bg_color)

	# Fluid fill polygon
	if _percent > 0.0:
		if _percent >= 1.0:
			draw_circle(center, r, fill_color)
		else:
			# k = sin(angle) threshold: points with sin(θ) >= k are in the filled region
			# value=1 → k=-1 (whole circle), value=0 → k=1 (nothing)
			var k: float           = clampf(1.0 - 2.0 * _percent, -1.0, 1.0)
			var theta_start: float = asin(k)
			var theta_end:   float = PI - asin(k)
			var pts := PackedVector2Array()
			for i in 81:
				var t:     float = float(i) / 80.0
				var theta: float = theta_start + t * (theta_end - theta_start)
				pts.append(center + Vector2(cos(theta), sin(theta)) * r)
			if pts.size() >= 3:
				draw_colored_polygon(pts, fill_color)

	# Thin dark border
	draw_arc(center, r, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.55), 2.5)

	# Label in centre
	var font: Font  = ThemeDB.fallback_font
	var fs:   int   = 13
	var tw:   float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
