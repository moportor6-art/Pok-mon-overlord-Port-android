extends CanvasLayer
## Controles táctiles para Android (port de Pokémon Overlord).
## Mapea a las acciones originales del juego: up/down/left/right, Accept, Cancel.
## El botón "≡" (arriba a la izquierda) oculta o muestra los controles.

const BASE := Vector2(1600, 900)

var _holder: Node2D
var _shown := true


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
	_btn(_holder, "up", dpad_c + Vector2(0, -d), 58, Color(1, 1, 1, 0.35), "▲")
	_btn(_holder, "down", dpad_c + Vector2(0, d), 58, Color(1, 1, 1, 0.35), "▼")
	_btn(_holder, "left", dpad_c + Vector2(-d, 0), 58, Color(1, 1, 1, 0.35), "◀")
	_btn(_holder, "right", dpad_c + Vector2(d, 0), 58, Color(1, 1, 1, 0.35), "▶")

	_btn(_holder, "Accept", Vector2(1470, 690), 72, Color(0.3, 0.85, 0.4, 0.45), "A")
	_btn(_holder, "Cancel", Vector2(1310, 790), 60, Color(0.9, 0.3, 0.3, 0.45), "B")

	var toggle := _btn(self, "", Vector2(48, 48), 34, Color(0, 0, 0, 0.35), "≡")
	toggle.pressed.connect(_on_toggle)


func _on_toggle() -> void:
	_shown = not _shown
	_holder.visible = _shown


func _btn(parent: Node, action: String, center: Vector2, radius: int, col: Color, text: String) -> TouchScreenButton:
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
	var l := Label.new()
	l.text = text
	l.size = Vector2(radius * 2, radius * 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(radius * 0.8))
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	parent.add_child(b)
	return b


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
