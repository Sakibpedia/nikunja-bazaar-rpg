extends Node2D
## Real-OSM Sontek Kajla, drawn top-down. Buildings are polygons with doors;
## roads and shops are laid out from the same data as the 3D game.

const SCALE := 3.2
const AREA := 520.0
const MAX_BUILDINGS := 1500
const CELL := 220.0

var buildings: Array = []      # {center, pts, rect, floors, door, kind}
var render_buildings: Array = [] # subset drawn on screen (keeps GPU memory low)
var roads: Array = []          # PackedVector2Array in world pixels
var shops: Array = []          # {pos, kind, name, color}
var plaza_stalls: Array = []   # extra market-row stalls
var plaza: Rect2 = Rect2()     # open market square
var gates: Array = []          # Vector2 positions
var vehicles: Array = []       # {pos, kind, color}
var road_points: Array = []    # Vector2 spawn/interaction points
var extraction: Vector2 = Vector2.ZERO
var amenities: Array = []      # real OSM amenities (mosque, fuel, hospital…)
var named_road_points: Array = []
var road_names: Array = []
var _grid: Dictionary = {}     # cell key -> Array[int]

var _colors := [
	Color(0.42, 0.36, 0.31), Color(0.50, 0.42, 0.34), Color(0.36, 0.39, 0.40),
	Color(0.55, 0.47, 0.36), Color(0.33, 0.35, 0.34), Color(0.47, 0.40, 0.38),
]


func _ready() -> void:
	_build()
	queue_redraw()


func _build() -> void:
	var f := FileAccess.open("res://assets/maps/nikunja.json", FileAccess.READ)
	if f == null:
		push_error("kajla.json missing")
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("bad map data")
		return

	var candidates: Array = []
	for b in (raw.get("buildings", []) as Array):
		var bd: Dictionary = b
		var pts_in: Array = bd.get("pts", [])
		if pts_in.size() < 4:
			continue
		var c := Vector2.ZERO
		var poly := PackedVector2Array()
		for p in pts_in:
			var pa: Array = p
			var v := Vector2(float(pa[0]), float(pa[1]))
			c += v
			poly.append(v * SCALE)
		c /= float(pts_in.size())
		if c.length() > AREA:
			continue
		var rect := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			rect = rect.expand(v)
		candidates.append({
			"center": c * SCALE, "pts": poly, "rect": rect,
			"floors": clampi(int(float(bd.get("h", 6.0)) / 3.0) + 1, 2, 20),
			"kind": str(bd.get("kind", "yes")),
		})
	candidates.sort_custom(func(a, b): return (a as Dictionary)["center"].length_squared() < (b as Dictionary)["center"].length_squared())
	for i in mini(candidates.size(), MAX_BUILDINGS):
		var b: Dictionary = (candidates[i] as Dictionary).duplicate(true)
		var r: Rect2 = b["rect"]
		b["door"] = Vector2(r.position.x + r.size.x * 0.5, r.end.y + 4.0)
		buildings.append(b)
		_add_to_grid(buildings.size() - 1, r)
	# Only a near-centre subset is drawn; all 1,500 remain in the collision grid.
	render_buildings = buildings.slice(0, mini(buildings.size(), 600))

	var road_idx := 0
	for rd in (raw.get("roads", []) as Array):
		var pts: Array = (rd as Dictionary).get("pts", [])
		if pts.size() < 2:
			continue
		var line := PackedVector2Array()
		for p in pts:
			var pa: Array = p
			line.append(Vector2(float(pa[0]), float(pa[1])) * SCALE)
		var nm := str((rd as Dictionary).get("name", ""))
		roads.append({"pts": line, "w": clampf(float((rd as Dictionary).get("w", 4.0)), 2.0, 12.0),
			"kind": str((rd as Dictionary).get("kind", "")), "name": nm})
		if nm != "":
			road_names.append(nm)
			for k in range(0, line.size(), maxi(1, line.size() / 4)):
				named_road_points.append(line[k])
		if road_idx % 3 == 0:
			for k in range(0, line.size(), maxi(1, line.size() / 6)):
				road_points.append(line[k])
		road_idx += 1
	while road_points.size() < 80:
		road_points.append(Vector2(sin(float(road_points.size())) * 400.0, cos(float(road_points.size() * 0.7)) * 400.0))

	for am in (raw.get("amenities", []) as Array):
		var a: Dictionary = am
		var pa: Array = a.get("p", [0, 0])
		amenities.append({"pos": Vector2(float(pa[0]), float(pa[1])) * SCALE,
			"kind": str(a.get("kind", "")), "name": str(a.get("name", ""))})

	var kinds := ["pharmacy", "clinic", "arms", "grocery", "general", "mobile", "tea", "hardware"]
	var names := ["ফার্মাসি", "ক্লিনিক", "অস্ত্র বিক্রেতা", "গ্রোসারি", "জেনারেল স্টোর", "মোবাইল শপ", "চায়ের দোকান", "হার্ডওয়্যার"]
	var shop_points: Array = named_road_points if named_road_points.size() >= 30 else road_points
	for i in 30:
		var p: Vector2 = shop_points[(i * 7 + 3) % shop_points.size()]
		var k := i % kinds.size()
		shops.append({"pos": p, "kind": kinds[k], "name": names[k],
			"color": Color(0.85, 0.68, 0.32) if k == 1 or k == 0 else Color(0.35, 0.72, 0.68)})
	for i in 15:
		gates.append(road_points[(i * 11 + 5) % road_points.size()])
	var kinds_v := ["car", "cng", "rickshaw", "pickup"]
	var colors_v := [Color(0.55, 0.62, 0.66), Color(0.85, 0.62, 0.20),
		Color(0.35, 0.70, 0.55), Color(0.62, 0.45, 0.36)]
	for i in 9:
		vehicles.append({"pos": road_points[(i * 13 + 7) % road_points.size()],
			"kind": kinds_v[i % kinds_v.size()], "color": colors_v[i % colors_v.size()]})
	# Find an open square near the centre for a proper market plaza.
	var found := false
	for sz in [Vector2(280, 190), Vector2(220, 150), Vector2(160, 110)]:
		for rad in [120.0, 220.0, 340.0, 480.0, 640.0, 820.0, 1000.0, 1200.0]:
			for k in 24:
				var a := TAU * float(k) / 24.0
				var c: Vector2 = Vector2(cos(a), sin(a)) * rad
				var candidate := Rect2(c - sz * 0.5, sz)
				var clear := true
				for b in buildings:
					if (b as Dictionary)["rect"].intersects(candidate):
						clear = false
						break
				if clear:
					plaza = candidate
					found = true
					break
			if found:
				break
		if found:
			break
	if found:
		var step_x: float = maxf(24.0, (plaza.size.x - 40.0) / 4.0)
		var step_y: float = maxf(20.0, (plaza.size.y - 30.0) / 4.0)
		for row in 4:
			for col in 4:
				var pp: Vector2 = plaza.position + Vector2(20, 15) + Vector2(float(col) * step_x, float(row) * step_y)
				var ki: int = (row * 6 + col) % kinds.size()
				plaza_stalls.append({"pos": pp, "kind": kinds[ki], "name": names[ki],
					"color": Color(0.85, 0.68, 0.32) if ki % 3 == 0 else Color(0.35, 0.72, 0.68)})
	# Spawn in the dense centre so the first view shows the real colony.
	var best_idx := 0
	var best_d := 1.0e12
	for i in road_points.size():
		var d: float = (road_points[i] as Vector2).length_squared()
		if d < best_d:
			best_d = d
			best_idx = i
	extraction = road_points[best_idx]


func _add_to_grid(idx: int, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELL))
	var y0 := int(floor(rect.position.y / CELL))
	var x1 := int(floor(rect.end.x / CELL))
	var y1 := int(floor(rect.end.y / CELL))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := "%d|%d" % [x, y]
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(idx)


func candidates_near(p: Vector2) -> Array:
	var key := "%d|%d" % [int(floor(p.x / CELL)), int(floor(p.y / CELL))]
	return _grid.get(key, [])


func is_blocked(p: Vector2, radius: float = 8.0) -> bool:
	for idx in candidates_near(p):
		var r: Rect2 = (buildings[idx as int] as Dictionary)["rect"]
		var nearest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if nearest.distance_squared_to(p) < radius * radius:
			return true
	return false


func clamp_move(from: Vector2, to: Vector2, radius: float = 8.0) -> Vector2:
	if not is_blocked(to, radius):
		return to
	if not is_blocked(Vector2(to.x, from.y), radius):
		return Vector2(to.x, from.y)
	if not is_blocked(Vector2(from.x, to.y), radius):
		return Vector2(from.x, to.y)
	return from


func random_road_point(seed_value: int = 0) -> Vector2:
	if road_points.is_empty():
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return road_points[rng.randi_range(0, road_points.size() - 1)]


func nearest_building(p: Vector2) -> int:
	var best := -1
	var best_d := 1.0e12
	for i in buildings.size():
		var d: float = (buildings[i] as Dictionary)["center"].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0),
		clampf(c.b * f, 0.0, 1.0), c.a)


func _draw_box(p: Vector2, size: Vector2, h: float, col: Color) -> void:
	var half := size * 0.5
	var off := Vector2(h * 0.3, -h)
	var ground := PackedVector2Array([
		p + Vector2(-half.x, -half.y), p + Vector2(half.x, -half.y),
		p + Vector2(half.x, half.y), p + Vector2(-half.x, half.y)])
	var shadow := PackedVector2Array()
	for q in ground:
		shadow.append(q + Vector2(h * 0.45, 8.0))
	draw_colored_polygon(shadow, Color(0.01, 0.02, 0.03, 0.45))
	draw_colored_polygon(PackedVector2Array([ground[3], ground[2], ground[2] + off, ground[3] + off]), _shade(col, 0.55))
	draw_colored_polygon(PackedVector2Array([ground[0], ground[3], ground[3] + off, ground[0] + off]), _shade(col, 0.70))
	var roof := PackedVector2Array()
	for q in ground:
		roof.append(q + off)
	draw_colored_polygon(roof, _shade(col, 1.25))
	draw_polyline(roof, Color(0.05, 0.06, 0.07), 1.2, true)


func _draw_building(b: Dictionary) -> void:
	var pts: PackedVector2Array = b["pts"]
	var n: int = pts.size()
	if n < 3:
		return
	var floors: int = clampi(int(b["floors"]), 2, 20)
	var h: float = clampf(float(floors) * 3.2, 10.0, 64.0)
	var off: Vector2 = Vector2(h * 0.28, -h)
	var base_col: Color = _colors[abs(int((b["center"].x + b["center"].y) / 40.0)) % _colors.size()]

	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(h * 0.42, 9.0))
	draw_colored_polygon(shadow, Color(0.01, 0.02, 0.03, 0.40))

	var centroid: Vector2 = b["center"]
	for i in n:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[(i + 1) % n]
		var edge: Vector2 = c - a
		if edge.length_squared() < 1.0:
			continue
		var outward := Vector2(edge.y, -edge.x).normalized()
		if outward.dot((a + c) * 0.5 - centroid) < 0.0:
			outward = -outward
		if outward.y <= 0.05:
			continue
		var light: float = clampf(0.50 + 0.38 * outward.y, 0.45, 0.90)
		draw_colored_polygon(PackedVector2Array([a, c, c + off, a + off]), _shade(base_col, light))
		# A few floor bands only on long front walls keeps the canvas light
		# enough for integrated GPUs (one draw list for all 1,500 towers).
		if edge.length() > 22.0:
			for f in range(1, mini(floors, 5)):
				var t: float = float(f) / float(floors)
				draw_line(a + off * t, c + off * t, Color(0.06, 0.08, 0.09, 0.55), 1.0)

	var roof := PackedVector2Array()
	for p in pts:
		roof.append(p + off)
	draw_colored_polygon(roof, _shade(base_col, 1.22))
	draw_polyline(roof, Color(0.05, 0.06, 0.07), 1.6, true)
	var r: Rect2 = b["rect"]
	if r.size.length() > 34.0:
		# Stair hut / water tank on the roof, drawn as a small 2.5D box.
		var rc: Vector2 = centroid + off + Vector2(2.0, -4.0)
		var hs := Vector2(9.0, 6.0)
		var hut := PackedVector2Array([
			rc + Vector2(-hs.x, -hs.y), rc + Vector2(hs.x, -hs.y),
			rc + Vector2(hs.x, hs.y), rc + Vector2(-hs.x, hs.y)])
		var hoff := Vector2(3.0, -5.0)
		draw_colored_polygon(PackedVector2Array([hut[3], hut[2], hut[2] + hoff, hut[3] + hoff]), _shade(base_col, 0.55))
		var hroof := PackedVector2Array()
		for q in hut:
			hroof.append(q + hoff)
		draw_colored_polygon(hroof, _shade(base_col, 1.42))
		draw_polyline(hroof, Color(0.05, 0.06, 0.07), 1.0, true)
	draw_circle(b["door"], 3.2, Color(0.95, 0.76, 0.34))


func _draw() -> void:
	# Ground with a faint survey grid.
	draw_rect(Rect2(-2400, -2400, 4800, 4800), Color(0.075, 0.105, 0.105))
	for g in range(-2400, 2401, 120):
		draw_line(Vector2(g, -2400), Vector2(g, 2400), Color(0.11, 0.14, 0.14), 1.0)
		draw_line(Vector2(-2400, g), Vector2(2400, g), Color(0.11, 0.14, 0.14), 1.0)
	# Roads
	for rd in roads:
		var pts: PackedVector2Array = rd["pts"]
		var w: float = rd["w"] * SCALE
		draw_polyline(pts, Color(0.055, 0.065, 0.07), w + 8.0)
		draw_polyline(pts, Color(0.17, 0.19, 0.20), w + 2.0)
		draw_polyline(pts, Color(0.22, 0.23, 0.23), w)
		draw_polyline(pts, Color(0.38, 0.34, 0.22), 1.4)
	# Market square paving.
	if not plaza_stalls.is_empty():
		draw_rect(plaza, Color(0.14, 0.18, 0.15))
		draw_rect(plaza, Color(0.70, 0.56, 0.30), false, 2.0)
		for i in range(int(plaza.size.x / 28.0)):
			draw_line(Vector2(plaza.position.x + i * 28, plaza.position.y),
				Vector2(plaza.position.x + i * 28, plaza.end.y), Color(0.20, 0.23, 0.19), 1.0)
	# Depth-sorted OSM towers (back to front).
	var order := render_buildings.duplicate()
	order.sort_custom(func(a, b):
		var ra: Rect2 = (a as Dictionary)["rect"]
		var rb: Rect2 = (b as Dictionary)["rect"]
		return ra.end.y < rb.end.y)
	for item in order:
		_draw_building(item)
	# Shops as small extruded kiosks.
	for s in shops + plaza_stalls:
		var p: Vector2 = s["pos"]
		_draw_box(p, Vector2(22, 16), 11.0, s["color"])
		# Striped market awning and hanging sign so stalls read as market stalls.
		var awning := PackedVector2Array([
			p + Vector2(-16, -9), p + Vector2(16, -9),
			p + Vector2(13, -21), p + Vector2(-13, -21)])
		draw_colored_polygon(awning, _shade(s["color"], 1.18))
		draw_rect(Rect2(p + Vector2(-7, -30), Vector2(14, 8)), _shade(s["color"], 1.35))
	# BCS gates.
	for g in gates:
		_draw_box(g, Vector2(18, 12), 9.0, Color(0.86, 0.46, 0.18))
	# Vehicles as little 3D boxes.
	for v in vehicles:
		_draw_box(v["pos"], Vector2(24, 13), 8.0, v["color"])
	# Real OSM amenities (mosques, fuel stations, hospital, bus stops…).
	for a in amenities:
		var p: Vector2 = a["pos"]
		draw_circle(p, 6.0, Color(0.95, 0.78, 0.38, 0.85))
		draw_circle(p, 6.0, Color(1.0, 0.90, 0.55), false, 1.5)
	# Extraction pad.
	draw_circle(extraction, 32.0, Color(0.10, 0.60, 0.50, 0.20))
	draw_circle(extraction, 32.0, Color(0.25, 0.85, 0.70), false, 3.0)
	draw_circle(extraction, 14.0, Color(0.25, 0.85, 0.70, 0.35))
