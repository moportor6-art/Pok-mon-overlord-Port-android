extends CanvasLayer
## Controles táctiles para Android (port de Pokémon Overlord).
## Mapea a las acciones originales del juego: up/down/left/right, Accept, Cancel, Info.
## - "‹ Atrás" (arriba a la izquierda) = Cancelar, siempre visible: nunca te quedas atrapado en un menú.
## - "≡" (arriba a la derecha) oculta o muestra la cruceta y los botones.
## - Botón atrás de Android = Cancelar.
## - Pistas cortas en pantalla (show_hint) y un efecto al tocar.

const BASE := Vector2(1600, 900)

var _holder: Node2D
var _shown := true
var _hit := []  # [rect, en_holder]
var _hint_box: PanelContainer
var _hint_label: Label
var _hint_tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		queue_free()
		return
	_holder = Node2D.new()
	add_child(_holder)

	var dpad_c := Vector2(180, 700)
	var d := 95.0
	var white := Color(1, 1, 1, 0.35)
	_round_btn(_holder, "up", dpad_c + Vector2(0, -d), 58, white, "▲")
	_round_btn(_holder, "down", dpad_c + Vector2(0, d), 58, white, "▼")
	_round_btn(_holder, "left", dpad_c + Vector2(-d, 0), 58, white, "◀")
	_round_btn(_holder, "right", dpad_c + Vector2(d, 0), 58, white, "▶")

	_round_btn(_holder, "Accept", Vector2(1470, 690), 72, Color(0.3, 0.85, 0.4, 0.5), "A", "OK")
	_round_btn(_holder, "Cancel", Vector2(1310, 790), 60, Color(0.9, 0.3, 0.3, 0.5), "B", "Atrás")
	_round_btn(_holder, "Info", Vector2(1490, 520), 48, Color(0.3, 0.5, 0.95, 0.5), "i", "Info")

	# Siempre visibles
	var back := _pill_btn(self, "Cancel", Rect2(14, 14, 170, 64), "‹ Atrás")
	back.modulate = Color(1, 1, 1, 0.9)
	var toggle := _pill_btn(self, "", Rect2(1500, 14, 86, 64), "≡")
	toggle.pressed.connect(_on_toggle)

	_build_hint()


func _on_toggle() -> void:
	_shown = not _shown
	_holder.visible = _shown
	show_hint("Controles ocultos: toca directamente el juego · ≡ para volver a verlos" if not _shown else "Controles visibles", 2.5)


func is_over_controls(p: Vector2) -> bool:
	for h in _hit:
		if h[1] and not _shown:
			continue
		if (h[0] as Rect2).grow(10).has_point(p):
			return true
	return false


func _notification(what: int) -> void:
	# Botón "atrás" de Android = Cancelar
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var pu = get_node_or_null("/root/PortUI")
		if pu and pu.get("_panel") and pu._panel.visible:
			return
		tap_action("Cancel")


func tap_action(a: String) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(a)


# ---------------------------------------------------------------- pistas y efecto al tocar

func _build_hint() -> void:
	_hint_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.85)
	sb.border_color = Color(0.98, 0.8, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_hint_box.add_theme_stylebox_override("panel", sb)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.add_child(_hint_label)
	_hint_box.visible = false
	add_child(_hint_box)


func show_hint(text: String, secs := 3.5) -> void:
	if _hint_box == null:
		return
	_hint_label.text = text
	_hint_box.visible = true
	_hint_box.modulate.a = 1.0
	_hint_box.reset_size()
	await get_tree().process_frame
	_hint_box.position = Vector2((BASE.x - _hint_box.size.x) / 2.0, 22)
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(secs)
	_hint_tween.tween_property(_hint_box, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(func(): _hint_box.visible = false)


func ripple(p: Vector2) -> void:
	var r := Ripple.new()
	r.position = p
	add_child(r)


class Ripple extends Node2D:
	var t := 0.0

	func _process(d: float) -> void:
		t += d * 3.0
		queue_redraw()
		if t >= 1.0:
			queue_free()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 20.0 + 40.0 * t, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - t), 5.0)


# ---------------------------------------------------------------- botones

func _round_btn(parent: Node, action: String, center: Vector2, radius: int, col: Color, text: String, caption := "") -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_tex(radius, col)
	b.texture_pressed = _circle_tex(radius, Color(col.r, col.g, col.b, minf(col.a + 0.3, 0.9)))
	var sh := CircleShape2D.new()
	sh.radius = radius
	b.shape = sh
	b.shape_centered = true
	if action != "":
		b.action = action
	b.passby_press = action in ["up", "down", "left", "right"]
	b.position = center - Vector2(radius, radius)
	b.add_child(_label(text, Vector2(radius * 2, radius * 2), int(radius * 0.8)))
	if caption != "":
		var cl := _label(caption, Vector2(radius * 2 + 40, 26), 20)
		cl.position = Vector2(-20, radius * 2 + 2)
		b.add_child(cl)
	parent.add_child(b)
	_hit.append([Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), parent != self])
	return b


func _pill_btn(parent: Node, action: String, r: Rect2, text: String) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _pill_tex(r.size, Color(0.08, 0.1, 0.2, 0.75))
	b.texture_pressed = _pill_tex(r.size, Color(0.3, 0.35, 0.6, 0.9))
	var sh := RectangleShape2D.new()
	sh.size = r.size
	b.shape = sh
	b.shape_centered = true
	if action != "":
		b.action = action
	b.position = r.position
	b.add_child(_label(text, r.size, 28))
	parent.add_child(b)
	_hit.append([r, parent != self])
	return b


func _label(text: String, sz: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _circle_tex(r: int, col: Color) -> ImageTexture:
	var s := r * 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(r, r)
	for y in s:
		for x in s:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= r:
				var a := col.a
				if dist > r - 4:
					a = minf(1.0, col.a + 0.35)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func _pill_tex(sz: Vector2, col: Color) -> ImageTexture:
	var w := int(sz.x)
	var h := int(sz.y)
	var rad := h / 2.0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, rad, w - rad)
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, rad))
			if dist <= rad:
				var a := col.a
				if dist > rad - 3:
					a = 0.95
				img.set_pixel(x, y, Color(col.r if dist <= rad - 3 else 1.0, col.g if dist <= rad - 3 else 1.0, col.b if dist <= rad - 3 else 1.0, a))
	return ImageTexture.create_from_image(img)
