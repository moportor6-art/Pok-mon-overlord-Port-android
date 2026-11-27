extends CanvasLayer
## Interfaz del port:
##  - Pantalla: COMPLETA (sin franjas negras: ocupa todo el ancho y recorta un poco arriba/abajo)
##    u ORIGINAL 16:9 (con franjas).
##  - En el título, dos recuadros con el estilo del juego bajo la caja de información:
##    "⚙ Ajustes" (FPS, pantalla, cruceta, contador, vibración) y "⟳ Actualizaciones".
## Los ajustes se guardan en user://port_ajustes.cfg y se aplican al arrancar.

const TITLE_SCRIPT := "res://Files/Title/title_scene.gd"
const RELEASES_URL := "https://github.com/moportor6-art/Pok-mon-overlord-Port-android/releases"
const CFG := "user://port_ajustes.cfg"
const BASE_H := 900.0

var _cfg := ConfigFile.new()
var _btn_upd: Button
var _btn_set: Button
var _panel_upd: Control
var _panel_set: Control
var _fps_label: Label
var _opt_btns := []  # [boton, clave, valor]
var _toggles := {}
var _title: Node
# Expedición (mundo de prueba de worldgen): botón en partida que lleva a una cueva generada y de vuelta
const Expedicion = preload("res://port/expedicion.gd")
var _btn_exp: Button
var _exp_vuelta = null
var _title_prev_state := 1
var _bridge = null
var _font: Font
var _shift := 0.0   # cuánto se recorta arriba (modo pantalla completa)
var _vh := BASE_H
var _ui_built := false


func _init() -> void:
	_cfg.load(CFG)


func get_setting(key: String, def = null):
	return _cfg.get_value("ajustes", key, def)


func set_setting(key: String, v) -> void:
	_cfg.set_value("ajustes", key, v)
	_cfg.save(CFG)


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://Files/Fonts/power clear bold.ttf"):
		_font = load("res://Files/Fonts/power clear bold.ttf")
	if OS.has_feature("android"):
		_bridge = JavaClassWrapper.wrap("com.godot.game.UpdaterBridge")
	_apply_fps()
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply_screen)
	_apply_screen()


# ---------------------------------------------------------------- pantalla completa

func _apply_screen() -> void:
	var root := get_tree().root
	var fill := str(get_setting("pantalla", "llenar")) == "llenar"
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if fill else Window.CONTENT_SCALE_ASPECT_KEEP
	await get_tree().process_frame
	_vh = root.get_visible_rect().size.y
	_shift = (BASE_H - _vh) / 2.0 if fill else 0.0
	_adjust_all_layers(root)
	_build_ui()
	var tc = get_node_or_null("/root/TouchControls")
	if tc and tc.has_method("_layout"):
		tc._layout()


func _is_port_layer(n: Node) -> bool:
	return n == self or (n.get_parent() == get_tree().root and n.name in ["TouchControls", "PortUI"])


func _on_node_added(n: Node) -> void:
	if n is CanvasLayer and not _is_port_layer(n):
		_adjust_layer.call_deferred(n)


func _adjust_layer(l) -> void:
	if not is_instance_valid(l) or l.follow_viewport_enabled:
		return
	if not l.has_meta("port_oy"):
		l.set_meta("port_oy", l.offset.y)
	l.offset.y = float(l.get_meta("port_oy")) - _shift


func _adjust_all_layers(n: Node) -> void:
	for ch in n.get_children():
		if ch is CanvasLayer and not _is_port_layer(ch):
			_adjust_layer(ch)
		_adjust_all_layers(ch)


func _process(_d: float) -> void:
	# Mundo sin cámara (título, batalla, menús): centrar el recorte. Con cámara, ella ya centra.
	var vp := get_tree().root
	if vp.get_camera_2d() == null:
		var want := Transform2D(0, Vector2(0, -_shift))
		if vp.canvas_transform != want:
			vp.canvas_transform = want
	if _fps_label:
		_fps_label.visible = bool(get_setting("ver_fps", false))
		if _fps_label.visible:
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if Engine.get_process_frames() % 20 != 0 or not _ui_built:
		return
	var t = _find_title()
	var vis: bool = t != null and not _any_open() and int(t.get("state")) == 1
	_btn_set.visible = vis
	_btn_upd.visible = vis and _bridge != null   # en PC (Port Launcher) no hay actualizador propio
	var lv := _nivel()
	var pl = lv.get_node_or_null("Actors/Player") if lv else null
	var gl = get_node_or_null("/root/globals")
	_btn_exp.visible = pl != null and not _any_open() and not (gl != null and bool(gl.get("in_cutscene"))) and int(pl.get("state")) == 0
	_btn_exp.text = "↩ Volver" if _exp_vuelta != null else "🌱 Expedición"


func _nivel() -> Node:
	var cs := get_tree().current_scene
	return cs if cs and cs.get_node_or_null("Tiles/Floor") else null


# Expedición: la primera vez guarda dónde estabas y te lleva a una cueva generada; la segunda te devuelve
func _expedicion() -> void:
	var lv := _nivel()
	if lv == null:
		return
	var pl = lv.get_node_or_null("Actors/Player")
	var cam = pl.get_node_or_null("Camera") if pl else null
	if pl == null or bool(pl.get("moving")):
		return
	_buzz()
	if _exp_vuelta == null:
		_exp_vuelta = {"pos": pl.global_position, "l": cam.limit_left, "t": cam.limit_top, "r": cam.limit_right, "b": cam.limit_bottom} if cam else {"pos": pl.global_position}
		if Expedicion.entrar(lv) == null:
			_exp_vuelta = null
	else:
		pl.global_position = _exp_vuelta["pos"]
		if cam and _exp_vuelta.has("l"):
			cam.limit_left = _exp_vuelta["l"]; cam.limit_top = _exp_vuelta["t"]
			cam.limit_right = _exp_vuelta["r"]; cam.limit_bottom = _exp_vuelta["b"]
			cam.reset_smoothing()
		_exp_vuelta = null


# ---------------------------------------------------------------- paneles y botones

func _build_ui() -> void:
	_ui_built = false
	for c in get_children():
		c.queue_free()
	_opt_btns.clear()
	_toggles.clear()
	# Recuadros del título: bajo la caja de información (zona libre del fondo), con el estilo del juego
	var y0 := 470.0 - _shift
	_btn_set = _game_box_button("⚙  Ajustes", Vector2(1195, y0), Vector2(370, 74))
	_btn_set.pressed.connect(_open.bind("set"))
	add_child(_btn_set)
	_btn_upd = _game_box_button("⟳  Actualizaciones", Vector2(1195, y0 + 92), Vector2(370, 74))
	_btn_upd.pressed.connect(_open.bind("upd"))
	add_child(_btn_upd)
	_btn_set.visible = false
	_btn_upd.visible = false
	_btn_exp = _game_box_button("🌱 Expedición", Vector2(1330, 90), Vector2(250, 64))
	_btn_exp.pressed.connect(_expedicion)
	_btn_exp.visible = false
	add_child(_btn_exp)

	_fps_label = Label.new()
	_fps_label.position = Vector2(1480, 8)
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)

	_panel_upd = _build_updates_panel()
	_panel_set = _build_settings_panel()
	_ui_built = true


func _any_open() -> bool:
	return _ui_built and (_panel_upd.visible or _panel_set.visible)


func is_blocking(p: Vector2) -> bool:
	if not _ui_built:
		return false
	if _any_open():
		return true
	for b in [_btn_set, _btn_upd]:
		if b.visible and b.get_global_rect().grow(10).has_point(p):
			return true
	return false


func _open(which: String) -> void:
	_title = _find_title()
	if _title:
		_title_prev_state = int(_title.get("state"))
		_title.set("state", 0)  # bloquear el menú del título mientras el panel está abierto
	if which == "set":
		_refresh_settings()
		_panel_set.visible = true
	else:
		_panel_upd.visible = true
	_btn_set.visible = false
	_btn_upd.visible = false
	_buzz()


func _close() -> void:
	_panel_upd.visible = false
	_panel_set.visible = false
	if _title and is_instance_valid(_title):
		await get_tree().create_timer(0.15).timeout
		_title.set("state", _title_prev_state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _any_open():
		_close()


# ---------------------------------------------------------------- ajustes

func _apply_fps() -> void:
	var fps := int(get_setting("fps", 120))
	if fps == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = fps


func _set_opt(key: String, v) -> void:
	set_setting(key, v)
	_buzz()
	if key == "fps":
		_apply_fps()
		_refresh_settings()
	elif key == "pantalla":
		await _apply_screen()   # reconstruye los paneles con la nueva altura
		_refresh_settings()
		_panel_set.visible = true
	else:
		_refresh_settings()
		var tc = get_node_or_null("/root/TouchControls")
		if tc and tc.has_method("refresh"):
			tc.refresh()


func _toggle(key: String, def: bool) -> void:
	set_setting(key, not bool(get_setting(key, def)))
	_refresh_settings()
	_buzz()


func _buzz() -> void:
	if bool(get_setting("vibracion", true)):
		Input.vibrate_handheld(12)


func _check() -> void:
	if _bridge:
		_bridge.check()   # en PC no hay nada que abrir: lo actualiza el Port Launcher
	_close()


func _history() -> void:
	if _bridge:
		_bridge.history()
	_close()


# ---------------------------------------------------------------- construcción de paneles

func _panel_base(title_text: String, sz: Vector2) -> Array:
	var root := Control.new()
	root.size = Vector2(1600, _vh)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.position = Vector2(-100, -300)
	dim.size = Vector2(1800, _vh + 600)
	dim.gui_input.connect(_on_dim_input)
	root.add_child(dim)
	var box := Panel.new()
	box.position = Vector2((1600 - sz.x) / 2.0, maxf(6.0, (_vh - sz.y) / 2.0))
	box.size = sz
	box.add_theme_stylebox_override("panel", _box_style(Color(0.07, 0.08, 0.13, 0.97)))
	root.add_child(box)
	box.add_child(_text(title_text, Vector2(0, 16), Vector2(sz.x, 50), 40, Color(0.98, 0.8, 0.2)))
	return [root, box]


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close()


func _build_updates_panel() -> Control:
	var pb := _panel_base("Actualizaciones", Vector2(600, 500))
	var box: Control = pb[1]
	var app_build := str(ProjectSettings.get_setting("application/config/version", "?"))
	var vname := str(ProjectSettings.get_setting("application/config/port_version", ""))
	if ResourceLoader.exists("res://port/version.gd"):   # viaja en el parche: siempre la versión real
		vname = str(load("res://port/version.gd").NAME)
	var pl = get_node_or_null("/root/PatchLoader")
	var patch: int = pl.loaded_build if pl else 0
	var t := "Versión %s · app build %s" % [vname, app_build]
	if patch > 0:
		t += "\nParche del juego: build %d" % patch
	t += "\nLa app también busca sola al abrirse."
	box.add_child(_text(t, Vector2(20, 80), Vector2(560, 110), 24, Color(0.85, 0.88, 1)))
	var b1 := _make_button("Buscar actualización", Vector2(60, 205), Vector2(480, 76), 30)
	b1.pressed.connect(_check)
	box.add_child(b1)
	var b2 := _make_button("Historial de versiones", Vector2(60, 295), Vector2(480, 76), 30)
	b2.pressed.connect(_history)
	box.add_child(b2)
	var b3 := _make_button("‹ Cerrar", Vector2(60, 395), Vector2(480, 70), 28, true)
	b3.pressed.connect(_close)
	box.add_child(b3)
	return pb[0]


func _build_settings_panel() -> Control:
	var h := minf(700.0, _vh - 12.0)
	var pb := _panel_base("Ajustes", Vector2(900, h))
	var box: Control = pb[1]
	var hz := int(round(DisplayServer.screen_get_refresh_rate()))
	var lab := Color(0.8, 0.85, 1)
	var y := 74.0
	box.add_child(_text("Límite de FPS  (tu pantalla: %s Hz · más FPS = más fluido, más batería)" % (str(hz) if hz > 0 else "?"),
		Vector2(36, y), Vector2(830, 30), 22, lab, HORIZONTAL_ALIGNMENT_LEFT))
	y += 34.0
	_option_row(box, y, "fps", [[30, "30"], [60, "60"], [90, "90"], [120, "120"], [0, "Sin límite"]])
	y += 92.0
	box.add_child(_text("Pantalla", Vector2(36, y), Vector2(830, 30), 22, lab, HORIZONTAL_ALIGNMENT_LEFT))
	y += 34.0
	_option_row(box, y, "pantalla", [["llenar", "Completa (sin franjas)"], ["ajustar", "Original 16:9"]])
	y += 92.0
	box.add_child(_text("Cruceta y botones A / B / i", Vector2(36, y), Vector2(830, 30), 22, lab, HORIZONTAL_ALIGNMENT_LEFT))
	y += 34.0
	_option_row(box, y, "cruceta_modo", [["auto", "Automática"], ["siempre", "Siempre"], ["nunca", "Ocultar"]])
	y += 92.0
	var tw := 409.0
	var i := 0
	for item in [["ver_fps", false, "Contador de FPS"], ["vibracion", true, "Vibrar al tocar"]]:
		var b := _make_button("", Vector2(36 + i * (tw + 12.0), y), Vector2(tw, 66), 24, true)
		b.pressed.connect(_toggle.bind(item[0], item[1]))
		box.add_child(b)
		_toggles[item[0]] = [b, item[1], item[2]]
		i += 1
	var close := _make_button("‹ Cerrar", Vector2(250, h - 84), Vector2(400, 66), 28)
	close.pressed.connect(_close)
	box.add_child(close)
	return pb[0]


func _option_row(box: Control, y: float, key: String, opts: Array) -> void:
	var gap := 12.0
	var w := (830.0 - gap * (opts.size() - 1)) / opts.size()
	var x := 36.0
	for o in opts:
		var b := _make_button(str(o[1]), Vector2(x, y), Vector2(w, 66), 24, true)
		b.pressed.connect(_set_opt.bind(key, o[0]))
		box.add_child(b)
		_opt_btns.append([b, key, o[0]])
		x += w + gap


func _refresh_settings() -> void:
	var defs := {"fps": 120, "pantalla": "llenar", "cruceta_modo": "auto"}
	for e in _opt_btns:
		_style(e[0], str(get_setting(e[1], defs[e[1]])) == str(e[2]))
	for k in _toggles:
		var t = _toggles[k]
		var on := bool(get_setting(k, t[1]))
		t[0].text = "%s  %s" % ["☑" if on else "☐", t[2]]
		_style(t[0], on)


func _style(b: Button, selected: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.85, 0.2, 0.2) if selected else Color(0.16, 0.19, 0.32)
		if st == "pressed":
			s.bg_color = s.bg_color.lightened(0.25)
		s.border_color = Color(1, 0.85, 0.3) if selected else Color(1, 1, 1, 0.5)
		s.set_border_width_all(3)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, s)


func _box_style(bg: Color) -> StyleBoxFlat:
	# Mismo look que las cajas del juego: fondo oscuro y borde blanco
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.97, 0.97, 0.97)
	s.set_border_width_all(5)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


func _game_box_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_stylebox_override("normal", _box_style(Color(0.07, 0.08, 0.13, 0.9)))
	b.add_theme_stylebox_override("hover", _box_style(Color(0.07, 0.08, 0.13, 0.9)))
	b.add_theme_stylebox_override("pressed", _box_style(Color(0.12, 0.25, 0.3, 0.95)))
	for c in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(c, Color(0.97, 0.97, 0.97))
	return b


func _text(t: String, pos: Vector2, sz: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _make_button(text: String, pos: Vector2, sz: Vector2, fs: int, secondary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		var base := Color(0.16, 0.19, 0.32) if secondary else Color(0.85, 0.2, 0.2)
		if st == "pressed":
			base = base.lightened(0.25)
		s.bg_color = base
		s.border_color = Color(1, 1, 1, 0.85)
		s.set_border_width_all(3)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


func _find_title():
	if _title and is_instance_valid(_title) and _title.is_inside_tree():
		return _title
	var g = get_node_or_null("/root/globals")
	var core = g.get("core") if g else null
	_title = null
	var sc = core.get_node_or_null("Scenes") if core and is_instance_valid(core) else null
	if sc:
		for ch in sc.get_children():
			var scr = ch.get_script()
			if scr and scr.resource_path == TITLE_SCRIPT and not ch.is_queued_for_deletion():
				_title = ch
	return _title


func _search(n: Node):
	var s = n.get_script()
	if s and s.resource_path == TITLE_SCRIPT:
		return n
	for ch in n.get_children():
		var r = _search(ch)
		if r:
			return r
	return null
