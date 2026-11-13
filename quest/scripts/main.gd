extends Node3D
## Sets up mixed reality (passthrough + room scan), the controllers, Vexley and his chat.

const ANCHOR_SCENE := preload("res://scenes/anchor.tscn")

var xr_interface: OpenXRInterface
var xr_active := false
var origin: XROrigin3D
var camera: Node3D
var hands: Array[XRController3D] = []
var env: WorldEnvironment

var room: Room
var vexley: Vexley
var companion: Companion
var panel: ChatPanel

var _lasers := {}        # controller -> MeshInstance3D
var _dots := {}          # controller -> MeshInstance3D
var _grip_was := {}      # controller -> bool
var _trigger_was := {}   # controller -> bool
var _last_pos := {}      # controller -> Vector3
var _drag_hand: XRController3D = null
var _pet_cooldown := 0.0
var _mood_tick := 0.0
var _greeted := false
var _start_time := 0.0

# Smoke test (CI): runs every behaviour without a headset.
var smoke := false
var _smoke_t := 0.0
var _smoke_step := 0

func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	_start_time = Time.get_ticks_msec() / 1000.0
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0, 0, 0, 0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	add_child(env)

	origin = XROrigin3D.new()
	add_child(origin)

	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface and xr_interface.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr_interface.session_begun.connect(_on_session_begun)
		xr_interface.session_focussed.connect(_on_focus_gained)
		var cam := XRCamera3D.new()
		origin.add_child(cam)
		camera = cam
		for side in ["left_hand", "right_hand"]:
			var c := XRController3D.new()
			c.tracker = side
			c.pose = "aim"
			origin.add_child(c)
			hands.append(c)
			_make_laser(c)
			c.button_pressed.connect(_on_button.bind(c))
	else:
		print("[main] OpenXR not running, using a desktop camera")
		var cam := Camera3D.new()
		origin.add_child(cam)
		cam.position = Vector3(0, 1.6, 0.6)
		cam.look_at_from_position(cam.position, Vector3(0, 0.5, -1.2))
		camera = cam

	room = Room.new()
	add_child(room)
	room.build_fallback(Vector3(0, 0, -0.5))
	if smoke:
		_add_test_table()
	if xr_active:
		room.attach_scene_manager(origin, ANCHOR_SCENE)
	room.rebuilt.connect(_on_room_rebuilt)

	companion = Companion.new()
	add_child(companion)

	vexley = Vexley.new()
	add_child(vexley)
	vexley.room = room
	vexley.camera = camera
	vexley.spawn(Vector3(0, 1.3, -1.0))
	vexley.event.connect(_on_vexley_event)
	companion.bubble_changed.connect(vexley.say)
	companion.face_changed.connect(vexley.set_face)
	vexley.set_face(companion.face())

	panel = ChatPanel.new()
	add_child(panel)
	panel.bind(companion)
	panel.send_text.connect(_on_chat)
	panel.clear_pressed.connect(companion.clear_chat)
	panel.rescan_pressed.connect(room.request_rescan)

func _on_session_begun() -> void:
	# Passthrough: show the real room behind Vexley.
	var modes := xr_interface.get_supported_environment_blend_modes()
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		get_viewport().transparent_bg = true
		env.environment.background_color = Color(0, 0, 0, 0)
		print("[main] passthrough on")
	else:
		get_viewport().transparent_bg = false
		env.environment.background_color = Color(0.12, 0.1, 0.16)
		print("[main] passthrough not supported, blend modes: ", modes)
	# Prefer a 90 Hz display if available.
	var rates := xr_interface.get_available_display_refresh_rates()
	if 90.0 in rates:
		xr_interface.display_refresh_rate = 90.0
	# Start the pretend room around where the player is actually standing.
	if not room.from_scan and camera:
		room.build_fallback(camera.global_position + _flat_forward() * 0.8)

func _on_focus_gained() -> void:
	if _greeted:
		companion.greet()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if companion:
			companion.change_happiness(0)   # saves

func _on_room_rebuilt() -> void:
	vexley.room_changed()

func _flat_forward() -> Vector3:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

# MARK: Companion wiring

func _on_vexley_event(ev: String) -> void:
	companion.handle(ev)

func _on_chat(text: String) -> void:
	companion.send(text)
	var lower := text.to_lower()
	# Some chat lines also make him do things.
	if lower.contains("climb") or lower.contains("wall") or lower.contains("ceiling"):
		vexley.force_behavior("climb")
	elif lower.contains("dance"):
		vexley.force_behavior("dance")
	elif lower.contains("come") or lower.contains("here"):
		vexley.force_behavior("come")
	elif lower.contains("roll"):
		vexley.force_behavior("roll")
	elif lower.contains("jump") or lower.contains("table"):
		vexley.force_behavior("table")
	elif lower.contains("nap") or lower.contains("goodnight"):
		vexley.force_behavior("sleep")

func _process(delta: float) -> void:
	_mood_tick -= delta
	if _mood_tick <= 0.0:
		_mood_tick = 1.0
		vexley.sleepiness = companion.sleepiness()
		vexley.excited = companion.mood() == "excited"
	if not _greeted and Time.get_ticks_msec() / 1000.0 - _start_time > 2.5:
		_greeted = true
		companion.greet()
	_pet_cooldown -= delta
	for c in hands:
		_update_hand(c, delta)
	if smoke:
		_smoke(delta)

# MARK: Controllers

func _make_laser(c: XRController3D) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.003, 0.003, 1.0)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.6)
	m.material_override = mat
	c.add_child(m)
	_lasers[c] = m
	var d := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	d.mesh = sm
	var dmat := mat.duplicate()
	dmat.albedo_color = Color(1.0, 0.3, 0.7, 0.9)
	d.material_override = dmat
	add_child(d)
	d.visible = false
	_dots[c] = d

func _set_laser(c: XRController3D, length: float, hit: bool, hit_point: Vector3) -> void:
	var m: MeshInstance3D = _lasers[c]
	(m.mesh as BoxMesh).size.z = length
	m.position = Vector3(0, 0, -length * 0.5)
	var d: MeshInstance3D = _dots[c]
	d.visible = hit
	if hit:
		d.global_position = hit_point

func _update_hand(c: XRController3D, delta: float) -> void:
	if not c.get_has_tracking_data():
		_lasers[c].visible = false
		_dots[c].visible = false
		return
	_lasers[c].visible = true
	var from := c.global_position
	var dir := -c.global_transform.basis.z.normalized()
	var grab_point := from + dir * 0.04
	var speed := 0.0
	if _last_pos.has(c):
		speed = (from - _last_pos[c]).length() / maxf(delta, 0.001)
	_last_pos[c] = from

	# Grab and throw with the grip button.
	var grip := c.get_float("grip") > 0.6
	var grip_was: bool = _grip_was.get(c, false)
	_grip_was[c] = grip
	if _drag_hand == c:
		if grip:
			vexley.drag_to(grab_point)
		else:
			vexley.release()
			_drag_hand = null
	elif grip and not grip_was and _drag_hand == null and vexley.distance_to_point(grab_point) < 0.12:
		_drag_hand = c
		vexley.start_drag(grab_point)
		c.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.1, 0.0)
	elif not grip and _pet_cooldown <= 0.0 and speed > 0.25 and vexley.distance_to_point(grab_point) < 0.03:
		# Brushing the controller over his head pets him.
		_pet_cooldown = 1.2
		vexley.pet()
		c.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.08, 0.0)

	# Pointer: the chat panel first, then Vexley, then the room.
	var trigger := c.get_float("trigger") > 0.6
	var trigger_was: bool = _trigger_was.get(c, false)
	_trigger_was[c] = trigger
	var puv := panel.ray_uv(from, dir)
	if puv.x >= 0.0:
		panel.pointer(puv, trigger)
		var hit_d := (panel.global_position - from).dot(panel.global_transform.basis.z) / dir.dot(panel.global_transform.basis.z)
		_set_laser(c, absf(hit_d), true, from + dir * absf(hit_d))
		return
	panel.pointer_exit()
	var hit := _ray_room(from, dir)
	var to_v := vexley.pos - from
	var along := to_v.dot(dir)
	var on_vexley := along > 0.0 and (to_v - dir * along).length() < Vexley.RADIUS * 1.2
	if on_vexley:
		_set_laser(c, along, true, from + dir * along)
	elif hit.size() > 0:
		_set_laser(c, from.distance_to(hit[0]), true, hit[0])
	else:
		_set_laser(c, 1.5, false, Vector3.ZERO)
	if trigger and not trigger_was and _drag_hand == null:
		if on_vexley:
			vexley.pet()
		elif hit.size() > 0:
			vexley.call_to(hit[0])

## [hit_point] on the nearest room surface along the ray, or [].
func _ray_room(from: Vector3, dir: Vector3) -> Array:
	var best_t := INF
	var best := []
	for s in room.surfaces:
		var n: Vector3 = s.normal()
		var denom := dir.dot(n)
		if denom > -0.0001:
			continue
		var t := (s.xf.origin - from).dot(n) / denom
		if t <= 0.0 or t >= best_t:
			continue
		var p := from + dir * t
		if s.contains(s.to_uv(p)):
			best_t = t
			best = [p]
	return best

func _on_button(button: String, c: XRController3D) -> void:
	match button:
		"by_button":
			panel.visible = not panel.visible
			if panel.visible:
				panel.place_in_front(camera)
				panel.refresh()
		"ax_button":
			vexley.come_here()
		"menu_button":
			if c.tracker == "left_hand":
				room.request_rescan()

# MARK: Smoke test

func _add_test_table() -> void:
	var t := Room.Surf.make("table", Vector3(0.8, 0.75, -1.2), Vector3.RIGHT, Vector3.UP, Vector2(1.0, 0.6))
	room.surfaces.append(t)

func _smoke_open_panel() -> void:
	panel.visible = true
	panel.place_in_front(camera)
	panel.refresh()

func _smoke(delta: float) -> void:
	_smoke_t += delta
	var steps := [
		[3.0, func(): _on_chat("hi Vexley!")],
		[5.0, func(): vexley.force_behavior("climb")],
		[16.0, func(): vexley.force_behavior("table")],
		[24.0, func(): vexley.force_behavior("sleep")],
		[26.0, func(): vexley.pet()],
		[28.0, func(): vexley.start_drag(vexley.pos)],
		[28.3, func(): vexley.drag_to(vexley.pos + Vector3(0.3, 0.4, 0))],
		[28.5, func(): vexley.drag_to(vexley.pos + Vector3(1.5, 0.8, 0))],
		[28.6, func(): vexley.release()],
		[33.0, func(): vexley.force_behavior("glitch")],
		[36.0, func(): vexley.call_to(Vector3(0, 1.2, -2.5))],
		[40.0, func(): vexley.force_behavior("dance")],
		[45.0, func(): vexley.force_behavior("roll")],
		[48.0, _smoke_open_panel],
		[48.5, func(): panel.pointer(Vector2(0.5, 0.75), false)],
		[48.6, func(): panel.pointer(Vector2(0.5, 0.75), true)],
		[48.7, func(): panel.pointer(Vector2(0.5, 0.75), false)],
		[49.0, func(): _on_chat("you're just software")],
		[51.0, func(): vexley.come_here()],
		[53.0, func(): companion.handle("idle_thought")],
	]
	if _smoke_step < steps.size() and _smoke_t >= float(steps[_smoke_step][0]):
		var cb: Callable = steps[_smoke_step][1]
		cb.call()
		_smoke_step += 1
	if int(_smoke_t * 2.0) != int((_smoke_t - delta) * 2.0) and int(_smoke_t * 2.0) % 4 == 0:
		print("[smoke] t=%.1f state=%s surf=%s pos=%s face=%s bubble=%s" % [_smoke_t, Vexley.S.keys()[vexley.state], vexley.surf.kind if vexley.surf else "-", vexley.pos.snapped(Vector3.ONE * 0.01), companion.face(), companion.bubble])
