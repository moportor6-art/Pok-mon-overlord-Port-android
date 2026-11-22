extends CanvasLayer
## Botón "Actualizaciones" en la pantalla de título (port Android).
## Abre un panel: Buscar actualización · Historial de versiones · Cerrar.
## Las ventanas de descarga/instalación son nativas (Updater.java vía UpdaterBridge).

const TITLE_SCRIPT := "res://Files/Title/title_scene.gd"
const RELEASES_URL := "https://github.com/moportor6-art/Pok-mon-overlord-Port-android/releases"

var _btn: Button
var _panel: Control
var _title: Node
var _title_prev_state := 1
var _bridge = null


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn = _make_button("⟳ Actualizaciones", Vector2(1150, 22), Vector2(300, 62), 26)
	_btn.pressed.connect(_open)
	add_child(_btn)
	_btn.visible = false
	_build_panel()
	if OS.has_feature("android"):
		_bridge = JavaClassWrapper.wrap("com.godot.game.UpdaterBridge")


func _process(_d: float) -> void:
	if Engine.get_process_frames() % 30 != 0:
		return
	var t = _find_title()
	_btn.visible = t != null and not _panel.visible and int(t.get("state")) == 1


func is_blocking(p: Vector2) -> bool:
	if _panel.visible:
		return true
	return _btn.visible and _btn.get_global_rect().grow(10).has_point(p)


func _open() -> void:
	_title = _find_title()
	if _title:
		_title_prev_state = int(_title.get("state"))
		_title.set("state", 0)  # bloquear el menú del título mientras el panel está abierto
	_panel.visible = true
	_btn.visible = false


func _close() -> void:
	_panel.visible = false
	if _title and is_instance_valid(_title):
		await get_tree().create_timer(0.15).timeout
		_title.set("state", _title_prev_state)


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close()


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _panel and _panel.visible:
		_close()


# ---------------------------------------------------------------- interfaz

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.size = Vector2(1600, 900)
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1600, 900)
	dim.gui_input.connect(_on_dim_input)
	_panel.add_child(dim)

	var box := Panel.new()
	box.position = Vector2(500, 190)
	box.size = Vector2(600, 520)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.22, 0.97)
	sb.border_color = Color(0.98, 0.8, 0.2)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	box.add_theme_stylebox_override("panel", sb)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Actualizaciones"
	title.position = Vector2(0, 26)
	title.size = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.98, 0.8, 0.2))
	box.add_child(title)

	var info := Label.new()
	var app_build := str(ProjectSettings.get_setting("application/config/version", "?"))
	var vname := str(ProjectSettings.get_setting("application/config/port_version", ""))
	var pl = get_node_or_null("/root/PatchLoader")
	var patch: int = pl.loaded_build if pl else 0
	info.text = "Versión %s · build %s" % [vname, app_build]
	if patch > 0:
		info.text += "\nParche del juego: build %d" % patch
	info.text += "\nLa app también busca sola al abrirse."
	info.position = Vector2(20, 90)
	info.size = Vector2(560, 110)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_color_override("font_color", Color(0.85, 0.88, 1))
	box.add_child(info)

	var b1 := _make_button("Buscar actualización", Vector2(60, 220), Vector2(480, 76), 30)
	b1.pressed.connect(_check)
	box.add_child(b1)
	var b2 := _make_button("Historial de versiones", Vector2(60, 312), Vector2(480, 76), 30)
	b2.pressed.connect(_history)
	box.add_child(b2)
	var b3 := _make_button("‹ Cerrar", Vector2(60, 414), Vector2(480, 70), 28, true)
	b3.pressed.connect(_close)
	box.add_child(b3)


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
