extends CanvasLayer
## Controles táctiles para Android (port de Pokémon Overlord).
## Acciones del juego: up/down/left/right, Accept, Cancel, Info.
## - Cruceta y A/B/i: modo AUTOMÁTICO (solo aparecen donde hacen falta: mapa y batalla;
##   en los menús se juega tocando) · SIEMPRE · OCULTA. Se cambia en ⚙ Ajustes.
## - "‹ Atrás" (arriba a la izquierda) = Cancelar; aparece en los menús. Botón atrás de Android = Cancelar.
## - Todo se acomoda al área visible (modo pantalla completa o ajustada).
## - Pistas cortas en pantalla (show_hint) y efecto + vibración al tocar.

var _holder: Node2D
var _back: TouchScreenButton
var _hit := []  # [rect, nodo]
var _hint_box: PanelContainer
var _hint_label: Label
var _hint_tween: Tween
var _vh := 900.0
var _timer := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		queue_free()
		return
	_build_hint()
	_layout()
	get_tree().root.size_changed.connect(_layout)


func _visible_h() -> float:
	return get_viewport().get_visible_rect().size.y


func _layout() -> void:
	_vh = _visible_h()
	for c in get_children():
		if c != _hint_box:
			c.queue_free()
	_hit.clear()
	_holder = Node2D.new()
	add_child(_holder)
	var by := _vh  # borde inferior visible
	var dpad_c := Vector2(170, by - 190)
	var d := 92.0
	var white := Color(1, 1, 1, 0.32)
	_round_btn(_holder, "up", dpad_c + Vector2(0, -d), 56, white, "▲")
	_round_btn(_holder, "down", dpad_c + Vector2(0, d), 56, white, "▼")
	_round_btn(_holder, "left", dpad_c + Vector2(-d, 0), 56, white, "◀")
	_round_btn(_holder, "right", dpad_c + Vector2(d, 0), 56, white, "▶")
	_round_btn(_holder, "Accept", Vector2(1475, by - 200), 70, Color(0.3, 0.85, 0.4, 0.45), "A", "OK")
	_round_btn(_holder, "Cancel", Vector2(1320, by - 110), 58, Color(0.9, 0.3, 0.3, 0.45), "B", "Atrás")
	_round_btn(_holder, "Info", Vector2(1495, by - 370), 46, Color(0.3, 0.5, 0.95, 0.45), "i", "Info")
	_back = _pill_btn(self, "Cancel", Rect2(12, 10, 150, 56), "‹ Atrás")
	_update_visibility()


func _process(d: float) -> void:
	_timer += d
	if _timer < 0.3:
		return
	_timer = 0.0
	_hide_original_controls()
	_update_visibility()


func _context() -> String:
	var tn = get_node_or_null("/root/TouchNav")
	return str(tn.get("_ctx")) if tn else ""


func _update_visibility() -> void:
	if _holder == null or not is_instance_valid(_back):
		return
	var pu = get_node_or_null("/root/PortUI")
	var mode := str(pu.get_setting("cruceta_modo", "auto")) if pu else "auto"
	var ctx := _context()
	var panel_open: bool = pu != null and pu.has_method("_any_open") and pu._any_open()
	_holder.visible = not panel_open and (mode == "siempre" or (mode == "auto" and ctx == ""))
	# "‹ Atrás" en los menús (en el título no hace nada, y en mapa/batalla ya está B)
	_back.visible = ctx != "" and ctx != "title" and not panel_open


func refresh() -> void:
	_update_visibility()


func _hide_original_controls() -> void:
	# Los controles y la barra de teclas originales del juego (los de este port los reemplazan)
	var g = get_node_or_null("/root/globals")
	var core = g.get("core") if g else null
	if core and is_instance_valid(core):
		var cl = core.get_node_or_null("TouchControls/CanvasLayer")
		if cl and cl.visible:
			cl.hide()
		var sc = core.get_node_or_null("Scenes")
		if sc:
			for ch in sc.get_children():
				var hint = ch.get_node_or_null("InputHint")
				if hint and hint.visible and ch.name.begins_with("TitleScene"):
					hint.hide()


func is_over_controls(p: Vector2) -> bool:
	for h in _hit:
		var n = h[1]
		if is_instance_valid(n) and n.is_visible_in_tree() and (h[0] as Rect2).grow(10).has_point(p):
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # botón atrás de Android = Cancelar
		var pu = get_node_or_null("/root/PortUI")
		if pu and pu.has_method("_any_open") and pu._any_open():
			return
		tap_action("Cancel")


func tap_action(a: String) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(a)


func buzz() -> void:
	var pu = get_node_or_null("/root/PortUI")
	if pu and pu.has_method("get_setting") and bool(pu.get_setting("vibracion", true)):
		Input.vibrate_handheld(12)


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
	_hint_box.position = Vector2((1600.0 - _hint_box.size.x) / 2.0, _vh - _hint_box.size.y - 14.0)
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(secs)
	_hint_tween.tween_property(_hint_box, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(_hide_hint)


func _hide_hint() -> void:
	_hint_box.visible = false


func ripple(p: Vector2) -> void:
	buzz()
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
	b.pressed.connect(buzz)
	parent.add_child(b)
	_hit.append([Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), b])
	return b


func _pill_btn(parent: Node, action: String, r: Rect2, text: String) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = _pill_tex(r.size, Color(0.08, 0.1, 0.2, 0.8))
	b.texture_pressed = _pill_tex(r.size, Color(0.3, 0.35, 0.6, 0.9))
	var sh := RectangleShape2D.new()
	sh.size = r.size
	b.shape = sh
	b.shape_centered = true
	if action != "":
		b.action = action
	b.position = r.position
	b.add_child(_label(text, r.size, 26))
	b.pressed.connect(buzz)
	parent.add_child(b)
	_hit.append([r, b])
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
				var edge := dist > rad - 3
				img.set_pixel(x, y, Color(1, 1, 1, 0.95) if edge else col)
	return ImageTexture.create_from_image(img)
