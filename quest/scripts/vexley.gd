class_name Vexley
extends Node3D
## Vexley: just his 2D animated head, bouncing, rolling and climbing around the room.
## Shimeji-style behaviour on the room's surfaces (floor, walls, ceiling, tables).

signal event(name: String)

const RADIUS := 0.11                 # metres; the head is about 22 cm across
const GRAVITY := Vector3(0, -6.5, 0) # a bit floaty, he's a cartoon
const FACES := {
	"happy": [4, 170], "excited": [10, 120], "annoyed": [4, 300], "angry": [10, 180],
	"worried": [4, 300], "scared": [4, 150], "error-404": [4, 350], "glitch": [27, 111],
}

enum S { IDLE, HOP, ROLL, SLEEP, FALL, DRAGGED, JUMP, DANCE, GLITCH }

var room: Room
var camera: Node3D
var sleepiness := 0.05
var excited := false

var state := S.FALL
var surf: Room.Surf = null
var uv := Vector2.ZERO
var target_uv := Vector2.ZERO
var plan := ""
var plan_surf: Room.Surf = null
var plan_uv := Vector2.ZERO
var timer := 1.0
var vel := Vector3.ZERO
var pos := Vector3(0, 1.4, -1.0)
var bounces := 0

# Jump arc
var _j_from := Vector3.ZERO
var _j_v0 := Vector3.ZERO
var _j_t := 0.0
var _j_len := 0.5

# Look
var _up := Vector3.UP
var _hop := 0.0
var _hop_h := 0.0
var _squash := 1.0
var _squash_v := 0.0
var _spin := 0.0
var _lean := 0.0
var _wiggle := 0.0
var _idle_thought_in := 30.0
var _drag_target := Vector3.ZERO
var _drag_samples: Array = []

# Face animation
var _face := "happy"
var _face_frame := 0
var _face_time := 0.0
var _textures := {}

var head: Sprite3D
var bubble: Label3D
var zzz: Label3D
var shadow: MeshInstance3D

func _ready() -> void:
	for f in FACES:
		_textures[f] = load("res://art/faces/%s.png" % f)
	head = Sprite3D.new()
	head.pixel_size = (RADIUS * 2.0 * 1.25) / 192.0
	head.shaded = false
	head.double_sided = true
	head.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	head.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	head.render_priority = 1
	add_child(head)
	set_face("happy")

	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 44
	bubble.outline_size = 14
	bubble.pixel_size = 0.0006
	bubble.modulate = Color.WHITE
	bubble.outline_modulate = Color(0.55, 0.03, 0.36)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 620
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bubble.no_depth_test = true
	bubble.render_priority = 3
	bubble.visible = false
	add_child(bubble)

	zzz = Label3D.new()
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.text = "z z Z"
	zzz.font_size = 48
	zzz.outline_size = 10
	zzz.pixel_size = 0.0007
	zzz.modulate = Color(0.55, 0.95, 1.0)
	zzz.outline_modulate = Color(0.1, 0.2, 0.35)
	zzz.visible = false
	add_child(zzz)

	shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.2, RADIUS * 2.2)
	shadow.mesh = quad
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = gt
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

## Drop him into the room from just above the floor in front of the player.
func spawn(at: Vector3) -> void:
	pos = at
	vel = Vector3.ZERO
	state = S.FALL
	surf = null

## Called when the room is rebuilt (e.g. the room scan arrived): fall onto the new surfaces.
func room_changed() -> void:
	if state == S.DRAGGED:
		return
	surf = null
	state = S.FALL
	vel = Vector3.ZERO

# MARK: Faces

func set_face(f: String) -> void:
	if not FACES.has(f):
		f = "happy"
	if f == _face and head.texture != null:
		return
	_face = f
	head.texture = _textures[f]
	head.hframes = FACES[f][0]
	_face_frame = 0
	head.frame = 0
	_face_time = 0.0

func say(text: String) -> void:
	bubble.text = text
	bubble.visible = text != ""

# MARK: Interaction API

func distance_to_point(p: Vector3) -> float:
	return pos.distance_to(p) - RADIUS

func start_drag(p: Vector3) -> void:
	state = S.DRAGGED
	surf = null
	_drag_target = p
	_drag_samples.clear()
	zzz.visible = false
	event.emit("picked_up")

func drag_to(p: Vector3) -> void:
	_drag_target = p

func release() -> void:
	if state != S.DRAGGED:
		return
	var v := Vector3.ZERO
	if _drag_samples.size() >= 2:
		var a: Array = _drag_samples[0]
		var b: Array = _drag_samples[_drag_samples.size() - 1]
		var dt: float = b[1] - a[1]
		if dt > 0.001:
			v = (b[0] - a[0]) / dt
	vel = v.limit_length(7.0)
	state = S.FALL
	bounces = 0
	if vel.length() > 1.8:
		event.emit("thrown")

func pet() -> void:
	if state == S.DRAGGED:
		return
	if state == S.SLEEP:
		_wake()
	_wiggle = 1.0
	_squash_v -= 3.0
	event.emit("petted")

## Leap to a point on any surface (the player pointed and pulled the trigger).
func call_to(world_point: Vector3) -> void:
	if state == S.DRAGGED or room == null:
		return
	var best: Room.Surf = null
	var best_d := 0.12
	for s: Room.Surf in room.surfaces:
		var d := absf(s.height_of(world_point))
		if d < best_d and s.contains(s.to_uv(world_point), -0.05):
			best = s
			best_d = d
	if best == null:
		return
	if state == S.SLEEP:
		_wake()
	event.emit("called")
	var tuv := best.clamp_uv(best.to_uv(world_point), RADIUS)
	if best == surf:
		_hop_to(tuv, "")
	else:
		_jump_to(best, tuv)

## Hop over to the player and look up at them.
func come_here() -> void:
	if room == null or room.floor_surf == null or camera == null:
		return
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0.0
	var p := camera.global_position + fwd.normalized() * 0.7
	p.y = room.floor_surf.xf.origin.y
	call_to(p)

func force_behavior(b: String) -> void:
	## Used by the debug/smoke test and the chat ("climb the wall!").
	match b:
		"climb": _plan_climb()
		"table": _plan_table()
		"roll": _start_roll()
		"sleep": _start_sleep()
		"dance": _start_dance()
		"glitch": _start_glitch()
		"come": come_here()

# MARK: Update

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_animate_face(delta)
	if room == null:
		return
	match state:
		S.IDLE: _do_idle(delta)
		S.HOP: _do_hop(delta)
		S.ROLL: _do_roll(delta)
		S.SLEEP: _do_sleep(delta)
		S.FALL: _do_fall(delta)
		S.DRAGGED: _do_drag(delta)
		S.JUMP: _do_jump(delta)
		S.DANCE: _do_dance(delta)
		S.GLITCH: _do_glitch(delta)
	if state != S.SLEEP and state != S.DRAGGED:
		_idle_thought_in -= delta
		if _idle_thought_in <= 0.0:
			_idle_thought_in = randf_range(45.0, 100.0)
			event.emit("idle_thought")
	_update_visuals(delta)

func _animate_face(delta: float) -> void:
	_face_time += delta
	var ms: float = FACES[_face][1] / 1000.0
	if _face_time >= ms:
		_face_time = fmod(_face_time, ms)
		_face_frame = (_face_frame + 1) % int(FACES[_face][0])
		head.frame = _face_frame

func _surface_pos() -> Vector3:
	return surf.to_world(uv) + surf.normal() * (RADIUS + _hop_h)

func _desired_up() -> Vector3:
	if state == S.FALL or state == S.DRAGGED or state == S.JUMP or surf == null:
		return Vector3.UP
	match surf.kind:
		"wall": return surf.az()
		"ceiling": return Vector3.DOWN
	return Vector3.UP

# MARK: Decisions

func _decide() -> void:
	if surf == null:
		state = S.FALL
		return
	match surf.kind:
		"floor":
			var options := {
				"wander": 3.0, "idle": 1.0, "roll": 1.0, "come": 0.6, "glitch": 0.25,
				"sleep": sleepiness * 6.0, "dance": 1.5 if excited else 0.3,
				"climb": 2.2 if room.walls().size() > 0 else 0.0,
				"table": 1.6 if room.tables().size() > 0 else 0.0,
			}
			match _pick(options):
				"wander": _hop_to(surf.random_uv(RADIUS + 0.15), "")
				"idle": _idle(randf_range(1.5, 4.0))
				"roll": _start_roll()
				"come": come_here()
				"glitch": _start_glitch()
				"sleep": _start_sleep()
				"dance": _start_dance()
				"climb": _plan_climb()
				"table": _plan_table()
		"wall":
			if randf() < 0.75:
				_hop_to(Vector2(clampf(uv.x + randf_range(-0.4, 0.4), -surf.size.x * 0.5 + RADIUS, surf.size.x * 0.5 - RADIUS), surf.size.y * 0.5 - RADIUS - 0.02), "top")
			else:
				_let_go()
		"ceiling":
			match _pick({"wander": 1.2, "drop": 1.4, "idle": 0.6}):
				"wander": _hop_to(surf.random_uv(RADIUS + 0.2), "")
				"drop": _let_go()
				"idle": _idle(randf_range(1.0, 2.5))
		"table":
			match _pick({"wander": 1.4, "down": 1.6, "idle": 1.0, "sleep": sleepiness * 3.0}):
				"wander": _hop_to(surf.random_uv(RADIUS + 0.05), "")
				"down": _plan_jump_down()
				"idle": _idle(randf_range(2.0, 5.0))
				"sleep": _start_sleep()

func _pick(options: Dictionary) -> String:
	var total := 0.0
	for k in options:
		total += float(options[k])
	var r := randf() * total
	for k in options:
		r -= float(options[k])
		if r <= 0.0:
			return k
	return options.keys()[0]

func _idle(seconds: float) -> void:
	state = S.IDLE
	timer = seconds

func _hop_to(t: Vector2, then: String) -> void:
	state = S.HOP
	target_uv = surf.clamp_uv(t, RADIUS)
	plan = then

func _plan_climb() -> void:
	var ws := room.walls()
	if surf == null:
		return
	if ws.is_empty() or surf.kind != "floor":
		_hop_to(surf.random_uv(RADIUS + 0.15), "")
		return
	# Prefer a wall the player can see.
	var wall: Room.Surf = ws.pick_random()
	if camera:
		var best := -INF
		for w: Room.Surf in ws:
			var score := randf() * 0.8 + (-camera.global_transform.basis.z).dot((w.xf.origin - camera.global_position).normalized())
			if score > best:
				best = score
				wall = w
	var u := randf_range(-wall.size.x * 0.5 + 0.3, wall.size.x * 0.5 - 0.3) if wall.size.x > 0.7 else 0.0
	var base := wall.to_world(Vector2(u, -wall.size.y * 0.5)) + wall.normal() * (RADIUS + 0.02)
	plan_surf = wall
	plan_uv = Vector2(u, -wall.size.y * 0.5 + RADIUS)
	_hop_to(surf.to_uv(base), "climb")

func _plan_table() -> void:
	var ts := room.tables()
	if ts.is_empty() or surf == null:
		return
	var t: Room.Surf = ts.pick_random()
	plan_surf = t
	plan_uv = t.random_uv(RADIUS + 0.05)
	# Hop to a spot on the floor next to the table, then leap up.
	var top := t.to_world(plan_uv)
	var to_me := pos - top
	to_me.y = 0.0
	var reach := maxf(t.size.x, t.size.y) * 0.5 + 0.25
	var near := top + to_me.normalized() * reach
	near.y = surf.xf.origin.y
	_hop_to(surf.to_uv(near), "jump_plan")

func _plan_jump_down() -> void:
	if room.floor_surf == null:
		_let_go()
		return
	# Pick a floor spot just past a random table edge.
	var dir := Vector2.from_angle(randf() * TAU)
	var edge := Vector2(dir.x * surf.size.x * 0.5, dir.y * surf.size.y * 0.5)
	var p := surf.to_world(edge * 1.0) + (surf.ax() * dir.x + surf.az() * dir.y).normalized() * 0.35
	p.y = room.floor_surf.xf.origin.y
	var fuv := room.floor_surf.clamp_uv(room.floor_surf.to_uv(p), RADIUS + 0.1)
	_jump_to(room.floor_surf, fuv)

func _let_go() -> void:
	var n := surf.normal() if surf else Vector3.ZERO
	surf = null
	state = S.FALL
	vel = n * 0.6
	bounces = 0

func _jump_to(s: Room.Surf, t_uv: Vector2) -> void:
	plan_surf = s
	plan_uv = t_uv
	var end := s.to_world(t_uv) + s.normal() * RADIUS
	var d := pos.distance_to(end)
	_j_len = clampf(d / 2.2, 0.45, 1.1)
	_j_from = pos
	_j_t = 0.0
	_j_v0 = (end - pos - 0.5 * GRAVITY * _j_len * _j_len) / _j_len
	state = S.JUMP
	surf = null
	_squash_v += 4.0

func _start_roll() -> void:
	if surf == null or surf.kind != "floor":
		_decide_soon()
		return
	state = S.ROLL
	target_uv = surf.random_uv(RADIUS + 0.2)

func _start_sleep() -> void:
	if surf == null:
		return
	state = S.SLEEP
	timer = randf_range(8.0, 16.0)
	zzz.visible = true
	event.emit("started_sleeping")

func _wake() -> void:
	zzz.visible = false
	_idle(0.8)
	event.emit("woke_up")

func _start_dance() -> void:
	state = S.DANCE
	timer = 3.5

func _start_glitch() -> void:
	state = S.GLITCH
	timer = 0.7
	event.emit("glitch")

func _decide_soon() -> void:
	_idle(0.3)

# MARK: States

func _do_idle(delta: float) -> void:
	if surf == null:
		state = S.FALL
		return
	pos = _surface_pos()
	timer -= delta
	if timer <= 0.0:
		_decide()

func _hop_speed() -> float:
	match surf.kind:
		"wall": return 0.22
		"ceiling": return 0.28
	return 0.42

func _do_hop(delta: float) -> void:
	var to := target_uv - uv
	var dist := to.length()
	var step := _hop_speed() * delta
	_hop += delta * 2.6
	var ph := fmod(_hop, 1.0)
	_hop_h = sin(ph * PI) * 0.07
	if ph < delta * 2.6:
		_squash_v -= 2.5   # little squish each landing
	if dist <= step:
		uv = target_uv
		_hop_h = 0.0
		_arrive()
	else:
		uv += to / dist * step
		var dir3 := surf.ax() * to.x + surf.az() * to.y
		_lean = lerpf(_lean, clampf(_screen_side(dir3) * 0.25, -0.25, 0.25), 1.0 - exp(-6.0 * delta))
	if state == S.HOP or state == S.IDLE:
		pos = _surface_pos()

func _arrive() -> void:
	var p := plan
	plan = ""
	match p:
		"climb":
			surf = plan_surf
			uv = plan_uv
			event.emit("climbing")
			_decide()
		"top":
			_reach_top()
		"jump_plan":
			_jump_to(plan_surf, plan_uv)
		_:
			_idle(randf_range(1.0, 3.5))

func _reach_top() -> void:
	var c := room.ceiling_surf
	if c and randf() < 0.8:
		var p := surf.to_world(uv) + surf.normal() * (RADIUS * 1.5)
		var cuv := c.to_uv(p)
		if c.contains(cuv, RADIUS * 0.5):
			surf = c
			uv = c.clamp_uv(cuv, RADIUS)
			event.emit("ceiling")
			_hop_to(c.random_uv(RADIUS + 0.3), "")
			return
	if randf() < 0.6:
		_let_go()
	else:
		_idle(1.0)

func _do_roll(delta: float) -> void:
	var to := target_uv - uv
	var dist := to.length()
	var step := 0.65 * delta
	if dist <= step:
		uv = target_uv
		_idle(randf_range(1.0, 2.0))
	else:
		uv += to / dist * step
		var dir3 := surf.ax() * to.x + surf.az() * to.y
		_spin -= _screen_side(dir3) * step / RADIUS
	_hop_h = 0.0
	pos = _surface_pos()

func _do_sleep(delta: float) -> void:
	_hop_h = 0.0
	pos = _surface_pos()
	_squash = 1.0 + sin(Time.get_ticks_msec() / 700.0) * 0.03
	timer -= delta
	if timer <= 0.0:
		_wake()

func _do_dance(delta: float) -> void:
	timer -= delta
	_hop += delta * 4.0
	_hop_h = absf(sin(_hop * PI)) * 0.09
	_spin = sin(_hop * PI) * 0.4
	pos = _surface_pos()
	if timer <= 0.0:
		_spin = 0.0
		_hop_h = 0.0
		_idle(1.0)

func _do_glitch(delta: float) -> void:
	timer -= delta
	head.visible = randf() < 0.5
	if timer <= 0.0:
		head.visible = true
		# Reappear somewhere else in the room.
		var choices: Array = room.surfaces.filter(func(s): return s.kind != "floor" or randf() < 0.5)
		if choices.is_empty():
			choices = room.surfaces
		var s: Room.Surf = choices.pick_random()
		surf = s
		uv = s.random_uv(RADIUS + 0.2)
		if s.kind == "wall":
			uv.y = clampf(uv.y, -s.size.y * 0.5 + RADIUS, s.size.y * 0.5 - RADIUS)
		pos = _surface_pos()
		_idle(1.5)

func _do_fall(delta: float) -> void:
	vel += GRAVITY * delta
	pos += vel * delta
	_hop_h = 0.0
	_spin += vel.length() * delta * 2.0 * signf(vel.x + 0.001)
	# Walls: bounce, or splat and cling if thrown hard.
	for w: Room.Surf in room.walls():
		var wuv: Vector2 = w.to_uv(pos)
		var h: float = w.height_of(pos)
		if h < RADIUS and h > -0.4 and w.contains(wuv, -0.05):
			var into := -vel.dot(w.normal())
			pos += w.normal() * (RADIUS - h)
			if into > 2.6 and randf() < 0.6:
				surf = w
				uv = w.clamp_uv(wuv, RADIUS)
				_spin = 0.0
				_squash_v -= 6.0
				event.emit("landed_hard")
				_idle(1.2)
				return
			if into > 0.0:
				vel += w.normal() * into * 1.55
	# Ceiling.
	var c := room.ceiling_surf
	if c and c.height_of(pos) < RADIUS and c.contains(c.to_uv(pos), -0.1):
		pos += c.normal() * (RADIUS - c.height_of(pos))
		vel.y = -absf(vel.y) * 0.4
	pos = room.keep_inside(pos, RADIUS)
	# Ground.
	var g := room.ground_below(pos + Vector3.UP * RADIUS, RADIUS)
	if g == null:
		if pos.y < -3.0:
			spawn(Vector3(pos.x, 1.2, pos.z))
		return
	var top := g.xf.origin.y
	if pos.y - RADIUS <= top and vel.y <= 0.0:
		var impact := -vel.y
		pos.y = top + RADIUS
		if impact > 2.2 and bounces < 2:
			bounces += 1
			vel.y = impact * 0.42
			vel.x *= 0.7
			vel.z *= 0.7
			_squash_v -= impact * 1.5
			if bounces == 1 and impact > 3.2:
				event.emit("landed_hard")
			return
		surf = g
		uv = g.clamp_uv(g.to_uv(pos), RADIUS)
		_squash_v -= clampf(impact * 2.0, 1.0, 7.0)
		_spin = 0.0
		vel = Vector3.ZERO
		event.emit("landed")
		if g.kind == "table":
			event.emit("table")
		_idle(randf_range(0.8, 1.6))

func _do_drag(delta: float) -> void:
	pos = pos.lerp(_drag_target, 1.0 - exp(-25.0 * delta))
	var t := Time.get_ticks_msec() / 1000.0
	_drag_samples.append([_drag_target, t])
	while _drag_samples.size() > 2 and t - float(_drag_samples[0][1]) > 0.1:
		_drag_samples.pop_front()
	_spin = sin(t * 9.0) * 0.15

func _do_jump(delta: float) -> void:
	_j_t += delta
	var t := minf(_j_t, _j_len)
	pos = _j_from + _j_v0 * t + 0.5 * GRAVITY * t * t
	_spin += delta * 9.0
	if _j_t >= _j_len:
		_spin = 0.0
		surf = plan_surf
		uv = plan_uv
		_squash_v -= 4.0
		_hop_h = 0.0
		pos = _surface_pos()
		if surf.kind == "table":
			event.emit("table")
		elif surf.kind == "ceiling":
			event.emit("ceiling")
		elif surf.kind == "wall":
			event.emit("climbing")
		_idle(randf_range(0.8, 1.5))

## +1 when a world direction points to the player's right, -1 to the left.
func _screen_side(dir: Vector3) -> float:
	if camera == null:
		return 0.0
	return signf(dir.dot(camera.global_transform.basis.x))

# MARK: Visuals

func _update_visuals(delta: float) -> void:
	# Squash and stretch spring.
	_squash_v += (1.0 - _squash) * 140.0 * delta
	_squash_v *= exp(-9.0 * delta)
	_squash += _squash_v * delta
	_squash = clampf(_squash, 0.6, 1.4)
	_wiggle = maxf(0.0, _wiggle - delta * 1.5)
	var want_up := _desired_up()
	_up = (_up.lerp(want_up, 1.0 - exp(-7.0 * delta))).normalized()
	if _up.length() < 0.5:
		_up = want_up

	var cam_pos := camera.global_position if camera else pos + Vector3(0, 0, 1)
	var z := (cam_pos - pos).normalized()
	var y := _up - z * _up.dot(z)
	if y.length() < 0.15:
		y = Vector3.UP - z * z.y
		if y.length() < 0.15:
			y = Vector3.FORWARD
	y = y.normalized()
	var x := y.cross(z).normalized()
	var b := Basis(x, y, z)
	var roll := _spin + _lean + sin(Time.get_ticks_msec() / 60.0) * 0.25 * _wiggle
	b = b * Basis(Vector3(0, 0, 1), roll)
	var sx := 1.0 / sqrt(_squash)
	# Squash toward the surface: keep the bottom of the head on the ground.
	var squash_off := y * (RADIUS * (_squash - 1.0)) if state != S.FALL and state != S.DRAGGED else Vector3.ZERO
	head.global_transform = Transform3D(b * Basis.from_scale(Vector3(sx, _squash, 1.0)), pos + squash_off)

	var cam_up := camera.global_transform.basis.y if camera else Vector3.UP
	bubble.global_position = pos + cam_up * (RADIUS + 0.05)
	zzz.global_position = pos + cam_up * (RADIUS + 0.02) + (camera.global_transform.basis.x if camera else Vector3.RIGHT) * 0.12

	# Contact shadow on the surface below him.
	var s := surf
	if s == null and room:
		s = room.ground_below(pos + Vector3.UP * RADIUS, RADIUS)
	if s:
		var h := s.height_of(pos)
		shadow.visible = h < 2.5
		var p := pos - s.normal() * h + s.normal() * 0.004
		var n := s.normal()
		var sxv := s.ax()
		shadow.global_transform = Transform3D(Basis(sxv, n.cross(sxv), n), p)
		var k := clampf(1.0 - (h - RADIUS) / 1.5, 0.15, 1.0)
		shadow.scale = Vector3(k, k, 1.0)
		shadow.transparency = 1.0 - k
	else:
		shadow.visible = false
