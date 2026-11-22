extends CanvasLayer
## Botones del port en la pantalla de título:
##  - "⚙ Ajustes": límite de FPS (30/60/90/120/sin límite), contador de FPS, vibración, cruceta.
##  - "⟳ Actualizaciones": buscar actualización e historial (ventanas nativas, Updater.java).
## Los ajustes se guardan en user://port_ajustes.cfg y se aplican al arrancar.

const TITLE_SCRIPT := "res://Files/Title/title_scene.gd"
const RELEASES_URL := "https://github.com/moportor6-art/Pok-mon-overlord-Port-android/releases"
const CFG := "user://port_ajustes.cfg"
const FPS_OPTIONS := [30, 60, 90, 120, 0]  # 0 = sin límite

var _cfg := ConfigFile.new()
var _btn_upd: Button
var _btn_set: Button
var _panel_upd: Control
var _panel_set: Control
var _fps_label: Label
var _fps_btns := []
var _toggles := {}
var _title: Node
var _title_prev_state := 1
var _bridge = null


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
	_btn_set = _make_button("⚙ Ajustes", Vector2(880, 22), Vector2(250, 62), 26, true)
	_btn_set.pressed.connect(_open.bind("set"))
	add_child(_btn_set)
	_btn_upd = _make_button("⟳ Actualizaciones", Vector2(1150, 22), Vector2(320, 62), 26)
	_btn_upd.pressed.connect(_open.bind("upd"))
	add_child(_btn_upd)
	_btn_set.visible = false
	_btn_upd.visible = false

	_fps_label = Label.new()
	_fps_label.position = Vector2(200, 24)
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)

	_panel_upd = _build_updates_panel()
	_panel_set = _build_settings_panel()
	if OS.has_feature("android"):
		_bridge = JavaClassWrapper.wrap("com.godot.game.UpdaterBridge")
	_apply_fps()


func _process(_d: float) -> void:
	_fps_label.visible = bool(get_setting("ver_fps", false))
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if Engine.get_process_frames() % 30 != 0:
		return
	var t = _find_title()
	var vis := t != null and not _any_open() and int(t.get("state")) == 1
	_btn_set.visible = vis
	_btn_upd.visible = vis


func _any_open() -> bool:
	return _panel_upd.visible or _panel_set.visible


func is_blocking(p: Vector2) -> bool:
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


func _close() -> void:
	_panel_upd.visible = false
	_panel_set.visible = false
	if _title and is_instance_valid(_title):
		await get_tree().create_timer(0.15).timeout
		_title.set("state", _title_prev_state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _panel_upd and _any_open():
		_close()


# ---------------------------------------------------------------- FPS

func _apply_fps() -> void:
	var fps := int(get_setting("fps", 120))
	if fps == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = fps


func _set_fps(fps: int) -> void:
	set_setting("fps", fps)
	_apply_fps()
	_refresh_settings()
	_buzz()


func _toggle(key: String, def: bool) -> void:
	var v := not bool(get_setting(key, def))
	set_setting(key, v)
	if key == "cruceta":
		var tc = get_node_or_null("/root/TouchControls")
		if tc and tc.has_method("set_dpad_visible"):
			tc.set_dpad_visible(v)
	_refresh_settings()
	_buzz()


func _buzz() -> void:
	if bool(get_setting("vibracion", true)):
		Input.vibrate_handheld(12)


# ---------------------------------------------------------------- actualizaciones

func _check() -> void:
	if _bridge:
		_bridge.check()
	else:
		OS.shell_open(RELEASES_URL)
	_close()


func _history() -> void:
	if _bridge:
		_bridge.history()
	else:
		OS.shell_open(RELEASES_URL)
	_close()


# ---------------------------------------------------------------- paneles

func _panel_base(title_text: String, sz: Vector2) -> Array:
	var root := Control.new()
	root.size = Vector2(1600, 900)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1600, 900)
	dim.gui_input.connect(_on_dim_input)
	root.add_child(dim)
	var box := Panel.new()
	box.position = (Vector2(1600, 900) - sz) / 2.0
	box.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.22, 0.97)
	sb.border_color = Color(0.98, 0.8, 0.2)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", sb)
	root.add_child(box)
	var title := _text(title_text, Vector2(0, 22), Vector2(sz.x, 50), 38, Color(0.98, 0.8, 0.2))
	box.add_child(title)
	return [root, box]


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close()


func _build_updates_panel() -> Control:
	var pb := _panel_base("Actualizaciones", Vector2(600, 520))
	var box: Control = pb[1]
	var app_build := str(ProjectSettings.get_setting("application/config/version", "?"))
	var vname := str(ProjectSettings.get_setting("application/config/port_version", ""))
	if ResourceLoader.exists("res://port/version.gd"):   # viaja en el parche: siempre la versión real
		vname = str(load("res://port/version.gd").NAME)
	var pl = get_node_or_null("/root/PatchLoader")
	var patch: int = pl.loaded_build if pl else 0
	var t := "Versión %s · build %s" % [vname, app_build]
	if patch > 0:
		t += "\nParche del juego: build %d" % patch
	t += "\nLa app también busca sola al abrirse."
	box.add_child(_text(t, Vector2(20, 90), Vector2(560, 110), 22, Color(0.85, 0.88, 1)))
	var b1 := _make_button("Buscar actualización", Vector2(60, 220), Vector2(480, 76), 30)
	b1.pressed.connect(_check)
	box.add_child(b1)
	var b2 := _make_button("Historial de versiones", Vector2(60, 312), Vector2(480, 76), 30)
	b2.pressed.connect(_history)
	box.add_child(b2)
	var b3 := _make_button("‹ Cerrar", Vector2(60, 414), Vector2(480, 70), 28, true)
	b3.pressed.connect(_close)
	box.add_child(b3)
	return pb[0]


func _build_settings_panel() -> Control:
	var pb := _panel_base("Ajustes", Vector2(860, 640))
	var box: Control = pb[1]
	var hz := int(round(DisplayServer.screen_get_refresh_rate()))
	box.add_child(_text("Límite de fotogramas (FPS)", Vector2(40, 92), Vector2(780, 36), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_text("Tu pantalla: %s Hz. Más FPS = más fluido, pero gasta más batería." % (str(hz) if hz > 0 else "?"),
		Vector2(40, 128), Vector2(780, 30), 20, Color(0.75, 0.8, 1), HORIZONTAL_ALIGNMENT_LEFT))
	var x := 40.0
	for f in FPS_OPTIONS:
		var w := 196.0 if f == 0 else 140.0
		var b := _make_button(("Sin límite" if f == 0 else str(f)), Vector2(x, 170), Vector2(w, 70), 28, true)
		b.pressed.connect(_set_fps.bind(f))
		box.add_child(b)
		_fps_btns.append([b, f])
		x += w + 12.0
	var y := 270.0
	for item in [["ver_fps", false, "Mostrar contador de FPS"], ["vibracion", true, "Vibrar al tocar"], ["cruceta", true, "Mostrar cruceta y botones A / B / i"]]:
		var b := _make_button("", Vector2(40, y), Vector2(780, 70), 26, true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_toggle.bind(item[0], item[1]))
		box.add_child(b)
		_toggles[item[0]] = [b, item[1], item[2]]
		y += 84.0
	var close := _make_button("‹ Cerrar", Vector2(190, 540), Vector2(480, 70), 28)
	close.pressed.connect(_close)
	box.add_child(close)
	return pb[0]


func _refresh_settings() -> void:
	var cur := int(get_setting("fps", 120))
	for e in _fps_btns:
		_style(e[0], e[1] == cur)
	for k in _toggles:
		var t = _toggles[k]
		var on := bool(get_setting(k, t[1]))
		t[0].text = "   %s  %s" % ["☑" if on else "☐", t[2]]
		_style(t[0], on)


func _style(b: Button, selected: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.85, 0.2, 0.2) if selected else Color(0.2, 0.24, 0.42)
		if st == "pressed":
			s.bg_color = s.bg_color.lightened(0.25)
		s.border_color = Color(1, 0.85, 0.3) if selected else Color(1, 1, 1, 0.6)
		s.set_border_width_all(3)
		s.set_corner_radius_all(14)
		b.add_theme_stylebox_override(st, s)


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
		var base := Color(0.25, 0.3, 0.55) if secondary else Color(0.85, 0.2, 0.2)
		if st == "pressed":
			base = base.lightened(0.25)
		s.bg_color = base
		s.border_color = Color(1, 1, 1, 0.85)
		s.set_border_width_all(3)
		s.set_corner_radius_all(14)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


func _find_title():
	if _title and is_instance_valid(_title) and _title.is_inside_tree():
		return _title
	_title = _search(get_tree().root)
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
