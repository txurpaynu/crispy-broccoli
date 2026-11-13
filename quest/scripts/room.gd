class_name Room
extends Node3D
## The surfaces Vexley can stand on: floor, walls, ceiling and tables.
## Built from the Quest's room scan (Meta scene anchors) when available,
## otherwise a pretend room around the player so he still has somewhere to play.

signal rebuilt

const UP := Vector3.UP

## One flat, rectangular surface. Local frame: X and Z lie in the surface, Y is the normal
## (the side Vexley stands on). For walls, Z always points up the wall.
class Surf:
	var kind := "floor"          # floor, ceiling, wall, table
	var xf := Transform3D()
	var size := Vector2.ONE      # extent along X, extent along Z (metres)
	var label := ""

	func normal() -> Vector3: return xf.basis.y
	func ax() -> Vector3: return xf.basis.x
	func az() -> Vector3: return xf.basis.z

	func to_world(uv: Vector2) -> Vector3:
		return xf.origin + xf.basis.x * uv.x + xf.basis.z * uv.y

	func to_uv(p: Vector3) -> Vector2:
		var d := p - xf.origin
		return Vector2(d.dot(xf.basis.x), d.dot(xf.basis.z))

	func height_of(p: Vector3) -> float:
		return (p - xf.origin).dot(xf.basis.y)

	func contains(uv: Vector2, margin: float = 0.0) -> bool:
		return absf(uv.x) <= size.x * 0.5 - margin and absf(uv.y) <= size.y * 0.5 - margin

	func clamp_uv(uv: Vector2, margin: float) -> Vector2:
		var hx := maxf(0.0, size.x * 0.5 - margin)
		var hz := maxf(0.0, size.y * 0.5 - margin)
		return Vector2(clampf(uv.x, -hx, hx), clampf(uv.y, -hz, hz))

	func random_uv(margin: float) -> Vector2:
		var hx := maxf(0.0, size.x * 0.5 - margin)
		var hz := maxf(0.0, size.y * 0.5 - margin)
		return Vector2(randf_range(-hx, hx), randf_range(-hz, hz))

	static func make(kind_: String, center: Vector3, x_axis: Vector3, normal_: Vector3, size_: Vector2) -> Surf:
		var s := Surf.new()
		s.kind = kind_
		var n := normal_.normalized()
		var x := (x_axis - n * x_axis.dot(n)).normalized()
		var z := x.cross(n).normalized()
		if kind_ == "wall" and z.dot(Vector3.UP) < 0.0:
			z = -z
			x = -x
		s.xf = Transform3D(Basis(x, n, z), center)
		s.size = size_
		return s

var surfaces: Array = []      # Array[Surf]
var from_scan := false
var floor_surf: Surf
var ceiling_surf: Surf

var _anchors := {}             # uuid -> {node, entity}
var _rebuild_in := -1.0
var _scene_manager: Node
var _capture_requested := false
var _debug_root: Node3D

func _ready() -> void:
	_debug_root = Node3D.new()
	add_child(_debug_root)

## Pretend room centred on the player: 4 x 4 m floor, 2.5 m ceiling.
func build_fallback(center: Vector3) -> void:
	surfaces.clear()
	from_scan = false
	var c := Vector3(center.x, 0.0, center.z)
	var w := 4.0
	var h := 2.5
	floor_surf = Surf.make("floor", c, Vector3.RIGHT, UP, Vector2(w, w))
	ceiling_surf = Surf.make("ceiling", c + UP * h, Vector3.RIGHT, -UP, Vector2(w, w))
	surfaces.append(floor_surf)
	surfaces.append(ceiling_surf)
	for i in 4:
		var dir := Vector3.FORWARD.rotated(UP, i * PI / 2.0)
		var wc := c + dir * (w * 0.5) + UP * (h * 0.5)
		surfaces.append(Surf.make("wall", wc, dir.cross(UP), -dir, Vector2(w, h)))
	rebuilt.emit()

# MARK: Meta scene anchors

## Hooks up an OpenXRFbSceneManager (from the Godot OpenXR vendors plugin) if it exists.
func attach_scene_manager(origin: Node3D, anchor_scene: PackedScene) -> void:
	if not ClassDB.class_exists("OpenXRFbSceneManager"):
		print("[room] scene manager not available, using pretend room")
		return
	_scene_manager = ClassDB.instantiate("OpenXRFbSceneManager")
	_scene_manager.set("default_scene", anchor_scene)
	_scene_manager.set("auto_create", true)
	_scene_manager.set("visible", false)
	origin.add_child(_scene_manager)
	_scene_manager.connect("openxr_fb_scene_anchor_created", _on_anchor_created)
	_scene_manager.connect("openxr_fb_scene_data_missing", _on_scene_data_missing)
	_scene_manager.connect("openxr_fb_scene_capture_completed", _on_capture_completed)
	print("[room] scene manager attached")

func _on_anchor_created(scene_node: Object, entity: Object) -> void:
	var uuid := str(entity.get("uuid"))
	_anchors[uuid] = {"node": scene_node, "entity": entity}
	_rebuild_in = 0.4

func _on_scene_data_missing() -> void:
	print("[room] no room scan found")
	if not _capture_requested and _scene_manager:
		_capture_requested = true
		# Opens the Quest's own room setup so the user can scan walls and furniture.
		_scene_manager.call("request_scene_capture", "")

func _on_capture_completed(success: bool) -> void:
	print("[room] scene capture completed: ", success)
	if success and _scene_manager and not bool(_scene_manager.call("are_scene_anchors_created")):
		_scene_manager.call("create_scene_anchors")

func request_rescan() -> void:
	if _scene_manager:
		_scene_manager.call("request_scene_capture", "")

func _process(delta: float) -> void:
	if _rebuild_in > 0.0:
		_rebuild_in -= delta
		if _rebuild_in <= 0.0:
			_rebuild_from_anchors()

func _rebuild_from_anchors() -> void:
	var new_surfs: Array = []
	var floor_s: Surf = null
	var ceil_s: Surf = null
	for uuid in _anchors:
		var a: Dictionary = _anchors[uuid]
		var node := a.node as Node3D
		var entity: Object = a.entity
		if node == null or not is_instance_valid(node):
			continue
		var labels := PackedStringArray(entity.call("get_semantic_labels"))
		print("[room] anchor ", labels)
		var label := labels[0].to_lower() if labels.size() > 0 else "other"
		var s := _surf_from_anchor(node, entity, label)
		if s == null:
			continue
		match s.kind:
			"floor":
				if floor_s == null or s.size.x * s.size.y > floor_s.size.x * floor_s.size.y:
					floor_s = s
			"ceiling":
				if ceil_s == null or s.size.x * s.size.y > ceil_s.size.x * ceil_s.size.y:
					ceil_s = s
			_:
				new_surfs.append(s)
	if floor_s == null:
		return   # walls without a floor are not much use; keep what we have
	floor_surf = floor_s
	ceiling_surf = ceil_s
	new_surfs.push_front(floor_s)
	if ceil_s:
		new_surfs.append(ceil_s)
	# Walls must face into the room.
	var room_center := floor_s.xf.origin
	for s: Surf in new_surfs:
		if s.kind == "wall" and s.normal().dot(room_center - s.xf.origin) < 0.0:
			s.xf.basis.y = -s.xf.basis.y
			s.xf.basis.x = -s.xf.basis.x
	surfaces = new_surfs
	from_scan = true
	var counts := {}
	for s: Surf in surfaces:
		counts[s.kind] = counts.get(s.kind, 0) + 1
	print("[room] built from room scan: ", counts)
	rebuilt.emit()

func _surf_from_anchor(node: Node3D, entity: Object, label: String) -> Surf:
	var gx := node.global_transform
	# 3 = COMPONENT_TYPE_BOUNDED_2D, 4 = COMPONENT_TYPE_BOUNDED_3D
	var bounded_2d := bool(entity.call("is_component_supported", 3))
	var bounded_3d := bool(entity.call("is_component_supported", 4))
	if bounded_2d:
		var rect: Rect2 = entity.call("get_bounding_box_2d")
		if rect.size.x < 0.2 or rect.size.y < 0.2:
			return null
		var c2 := rect.position + rect.size * 0.5
		var center := gx * Vector3(c2.x, c2.y, 0.0)
		var ax := gx.basis.x.normalized()
		var ay := gx.basis.y.normalized()
		var n := gx.basis.z.normalized()
		var kind := ""
		if label.begins_with("floor"):
			kind = "floor"
		elif label.begins_with("ceiling"):
			kind = "ceiling"
		elif label == "wall_face" or label == "invisible_wall_face":
			kind = "wall"
		elif absf(n.dot(UP)) > 0.85 and center.y > 0.2 and center.y < 1.6:
			kind = "table"   # tables, couches, beds, desks: any flat top at furniture height
		if kind == "":
			return null
		if kind == "floor" and n.dot(UP) < 0.0: n = -n
		if kind == "ceiling" and n.dot(UP) > 0.0: n = -n
		if kind == "table" and n.dot(UP) < 0.0: n = -n
		var s := Surf.make(kind, center, ax, n, Vector2(rect.size.x, rect.size.y))
		# Surf.make orthogonalises: keep the rect's second axis as the surface Z extent.
		if absf(s.az().dot(ay)) < 0.5:
			s.size = Vector2(rect.size.y, rect.size.x)
		s.label = label
		return s
	if bounded_3d:
		# Furniture volume: use its top face as a table.
		var box: AABB = entity.call("get_bounding_box_3d")
		var top_y := -INF
		var pts: Array[Vector3] = []
		for i in 8:
			var p := gx * box.get_endpoint(i)
			pts.append(p)
			top_y = maxf(top_y, p.y)
		if top_y < 0.2 or top_y > 1.6:
			return null
		# Horizontal axes from the anchor basis, whichever two are most horizontal.
		var axes := [gx.basis.x.normalized(), gx.basis.y.normalized(), gx.basis.z.normalized()]
		axes.sort_custom(func(a, b): return absf(a.dot(UP)) < absf(b.dot(UP)))
		var hx: Vector3 = axes[0]
		hx = Vector3(hx.x, 0.0, hx.z).normalized()
		var hz := hx.cross(UP).normalized()
		var min_x := INF; var max_x := -INF; var min_z := INF; var max_z := -INF
		var centroid := Vector3.ZERO
		for p in pts:
			centroid += p / 8.0
		for p in pts:
			var d := p - centroid
			min_x = minf(min_x, d.dot(hx)); max_x = maxf(max_x, d.dot(hx))
			min_z = minf(min_z, d.dot(hz)); max_z = maxf(max_z, d.dot(hz))
		var size := Vector2(max_x - min_x, max_z - min_z)
		if size.x < 0.25 or size.y < 0.25:
			return null
		var top := centroid + hx * (min_x + max_x) * 0.5 + hz * (min_z + max_z) * 0.5
		top.y = top_y
		var s := Surf.make("table", top, hx, UP, size)
		s.label = label
		return s
	return null

# MARK: Queries

func walls() -> Array:
	return surfaces.filter(func(s): return s.kind == "wall")

func tables() -> Array:
	return surfaces.filter(func(s): return s.kind == "table")

## Highest floor or table directly below p, or null.
func ground_below(p: Vector3, radius: float) -> Surf:
	var best: Surf = null
	var best_y := -INF
	for s: Surf in surfaces:
		if s.kind != "floor" and s.kind != "table":
			continue
		var top := s.xf.origin.y
		if top > p.y + 0.02 or top < best_y:
			continue
		if s.kind == "table" and not s.contains(s.to_uv(p), -radius * 0.3):
			continue
		best = s
		best_y = top
	return best

## Keeps a point inside the walls (used while falling or being thrown).
func keep_inside(p: Vector3, radius: float) -> Vector3:
	for s: Surf in surfaces:
		if s.kind != "wall":
			continue
		var uv: Vector2 = s.to_uv(p)
		if not s.contains(uv, -0.3):
			continue
		var h: float = s.height_of(p)
		if h < radius:
			p += s.normal() * (radius - h)
	if floor_surf:
		var fuv := floor_surf.to_uv(p)
		if not floor_surf.contains(fuv, radius):
			var c := floor_surf.clamp_uv(fuv, radius)
			var q := floor_surf.to_world(c)
			p.x = q.x
			p.z = q.z
	return p

func ceiling_height() -> float:
	return ceiling_surf.xf.origin.y if ceiling_surf else 2.5
