class_name ChatPanel
extends Node3D
## A floating chat window: message history, mood and happiness, quick replies
## and an on-screen keyboard. Rendered from a SubViewport onto a quad you point at.

signal send_text(text: String)
signal clear_pressed
signal rescan_pressed

const PX := Vector2i(1000, 860)
const SIZE := Vector2(0.56, 0.4816)   # metres, same aspect as PX

const PINK := Color(1.0, 0.18, 0.62)
const CYAN := Color(0.25, 0.88, 1.0)
const BG := Color(0.11, 0.05, 0.15, 0.96)

var viewport: SubViewport
var quad: MeshInstance3D
var companion: Companion

var _log: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _bar: ProgressBar
var _typed: Label
var _text := ""
var _mouse_down := false

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = PX
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	viewport.gui_disable_input = false
	add_child(viewport)
	_build_ui()

	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = SIZE
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = mat
	add_child(quad)
	visible = false

func bind(c: Companion) -> void:
	companion = c
	c.messages_changed.connect(refresh)
	c.happiness_changed.connect(func(_v): refresh())
	refresh()

# MARK: UI

func _style(color: Color, radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.set_border_width_all(4)
		sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _button(text: String, cb: Callable, w: int = 0, color: Color = Color(0.25, 0.12, 0.3)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_stylebox_override("normal", _style(color, 14))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.25), 14, CYAN))
	b.add_theme_stylebox_override("pressed", _style(PINK, 14))
	b.custom_minimum_size = Vector2(w, 58)
	b.pressed.connect(cb)
	return b

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _style(BG, 36, PINK))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2(PX)
	viewport.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", PINK.lightened(0.3))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(220, 30)
	_bar.show_percentage = false
	_bar.max_value = 100
	_bar.add_theme_stylebox_override("fill", _style(PINK, 10))
	_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 10))
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_bar)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 250)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 6)
	_scroll.add_child(_log)

	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 8)
	quick.add_theme_constant_override("v_separation", 8)
	col.add_child(quick)
	for q in Personality.QUICK_SAYS:
		var line: String = q
		quick.add_child(_button(line, func(): send_text.emit(line), 0, Color(0.32, 0.1, 0.32)))

	var input_row := HBoxContainer.new()
	col.add_child(input_row)
	var typed_bg := PanelContainer.new()
	typed_bg.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.1), 14, CYAN))
	typed_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(typed_bg)
	_typed = Label.new()
	_typed.add_theme_font_size_override("font_size", 32)
	_typed.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	_typed.clip_text = true
	typed_bg.add_child(_typed)
	input_row.add_child(_button("Send", _send_typed, 140, Color(0.75, 0.1, 0.45)))

	for row in ["1234567890", "qwertyuiop", "asdfghjkl'", "zxcvbnm,.?"]:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 6)
		col.add_child(hb)
		for ch in row:
			var c: String = ch
			hb.add_child(_button(c, func(): _type(c), 86))
	var last := HBoxContainer.new()
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	last.add_theme_constant_override("separation", 6)
	col.add_child(last)
	last.add_child(_button("Clear chat", func(): clear_pressed.emit(), 190))
	last.add_child(_button("space", func(): _type(" "), 330))
	last.add_child(_button("<- del", _backspace, 150))
	last.add_child(_button("Rescan room", func(): rescan_pressed.emit(), 210))
	_refresh_typed()

func _type(c: String) -> void:
	if _text.length() < 120:
		_text += c
	_refresh_typed()

func _backspace() -> void:
	_text = _text.substr(0, maxi(0, _text.length() - 1))
	_refresh_typed()

func _send_typed() -> void:
	if _text.strip_edges() == "":
		return
	send_text.emit(_text)
	_text = ""
	_refresh_typed()

func _refresh_typed() -> void:
	if _typed:
		_typed.text = (_text + "_") if _text != "" else "Type to Vexley, or tap a quick reply..."
		_typed.modulate = Color.WHITE if _text != "" else Color(1, 1, 1, 0.5)

func refresh() -> void:
	if companion == null or _log == null:
		return
	var m := companion.mood()
	_title.text = "%s  -  %s" % [companion.companion_name, m.capitalize()]
	_bar.value = companion.happiness
	for c in _log.get_children():
		c.queue_free()
	var recent: Array = companion.messages.slice(maxi(0, companion.messages.size() - 14))
	if recent.is_empty():
		var hint := Label.new()
		hint.text = "Say hi! Grab him with the grip button, point and pull the trigger to call him somewhere, A/X brings him to you, B/Y opens this chat."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 28)
		hint.modulate = Color(1, 1, 1, 0.6)
		_log.add_child(hint)
	for msg in recent:
		var is_user: bool = msg.get("role", "") == "user"
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if is_user else BoxContainer.ALIGNMENT_BEGIN
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", _style(Color(0.2, 0.45, 0.6) if is_user else Color(0.6, 0.1, 0.38), 18))
		bubble.custom_minimum_size = Vector2(0, 0)
		var l := Label.new()
		l.text = str(msg.get("text", ""))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(700.0, 40.0 + l.text.length() * 15.0), 0)
		l.add_theme_font_size_override("font_size", 28)
		bubble.add_child(l)
		row.add_child(bubble)
		_log.add_child(row)
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

# MARK: Pointer input

## Where a ray hits the panel, in 0..1 UV, or Vector2(-1, -1) if it misses.
func ray_uv(from: Vector3, dir: Vector3) -> Vector2:
	if not visible:
		return Vector2(-1, -1)
	var n := global_transform.basis.z.normalized()
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		return Vector2(-1, -1)
	var t := (global_position - from).dot(n) / denom
	if t < 0.0:
		return Vector2(-1, -1)
	var lp := global_transform.affine_inverse() * (from + dir * t)
	var u := lp.x / SIZE.x + 0.5
	var v := 0.5 - lp.y / SIZE.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u, v)

func pointer(uv: Vector2, pressed: bool) -> void:
	var p := Vector2(uv.x * PX.x, uv.y * PX.y)
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _mouse_down else 0
	viewport.push_input(mm)
	if pressed != _mouse_down:
		_mouse_down = pressed
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = p
		mb.global_position = p
		viewport.push_input(mb)

func pointer_exit() -> void:
	if _mouse_down:
		_mouse_down = false
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = false
		viewport.push_input(mb)

## Put the panel in front of the player's eyes, facing them.
func place_in_front(cam: Node3D) -> void:
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var p := cam.global_position + fwd * 0.6 + Vector3.DOWN * 0.18
	# looking_at(fwd) points local -Z away from the player, so the front (+Z) faces them.
	global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p)
	global_transform.basis = global_transform.basis.rotated(global_transform.basis.x.normalized(), -0.25)
