extends Node
## Toques directos en los menús de Pokémon Overlord (port Android).
## El juego solo entiende teclado (up/down/left/right/Accept/Cancel), así que
## cada toque se traduce a las pulsaciones necesarias para llevar el cursor
## hasta la opción tocada. Tocar la opción que ya está seleccionada = Aceptar.

const TITLE_SCRIPT := "res://Files/Title/title_scene.gd"
const LC_SCRIPT := "res://Files/Scenes/LeagueChallenge/lc_menu.gd"

var busy := false
var _down_pos := Vector2.ZERO
var _down_time := 0
var _tracking := false
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()):
		set_process_input(false)


func _input(e: InputEvent) -> void:
	if not (e is InputEventScreenTouch) or e.index != 0:
		return
	if e.pressed:
		_tracking = true
		_down_pos = e.position
		_down_time = Time.get_ticks_msec()
		return
	if not _tracking:
		return
	_tracking = false
	if busy:
		return
	if e.position.distance_to(_down_pos) > 40 or Time.get_ticks_msec() - _down_time > 600:
		return
	var tc = get_node_or_null("/root/TouchControls")
	if tc and tc.has_method("is_over_controls") and tc.is_over_controls(e.position):
		return
	var pu = get_node_or_null("/root/PortUI")
	if pu and pu.has_method("is_blocking") and pu.is_blocking(e.position):
		return
	if tc and tc.has_method("ripple"):
		tc.ripple(e.position)
	_handle_tap(e.position)


# ---------------------------------------------------------------- lógica

func _handle_tap(p: Vector2) -> void:
	if _volume_tap(p):
		return
	for entry in _active_entries():
		var seq = _resolve(entry, p)
		if seq != null:
			_press_seq(seq)
			return
	if _speech_visible():
		_press_seq(["Accept"])


func _resolve(entry: Dictionary, p: Vector2):
	var lines: Array = entry.lines
	var best_line := -1
	var best_idx := -1
	var best_area := INF
	for li in lines.size():
		var items: Array = lines[li]
		for i in items.size():
			var r = _item_rect(items[i])
			if r == null:
				continue
			r = (r as Rect2).grow(8)
			if r.has_point(p) and r.get_area() < best_area:
				best_area = r.get_area()
				best_line = li
				best_idx = i
	if best_line < 0:
		return null

	var cur_line: int = entry.get("cur_line", 0)
	var cur_idx: int = entry.cur
	var seq := []

	var g: int = entry.get("grid", 0)
	if g != 0:
		# rejilla: g > 0 = nº de filas (column-major), g < 0 = nº de columnas (row-major)
		var cr := 0
		var cc := 0
		var tr := 0
		var tcol := 0
		if g > 0:
			cr = cur_idx % g
			cc = cur_idx / g
			tr = best_idx % g
			tcol = best_idx / g
		else:
			cr = cur_idx / -g
			cc = cur_idx % -g
			tr = best_idx / -g
			tcol = best_idx % -g
		if cr == tr and cc == tcol:
			return ["Accept"]
		seq += _repeat("down" if tr > cr else "up", abs(tr - cr))
		seq += _repeat("right" if tcol > cc else "left", abs(tcol - cc))
		return seq

	var single: bool = (lines[best_line] as Array).size() == 1
	if best_line == cur_line and (best_idx == cur_idx or single):
		return ["Accept"]
	if best_line != cur_line:
		seq += _repeat(entry.get("line_inc", "down") if best_line > cur_line else entry.get("line_dec", "up"), abs(best_line - cur_line))
	if not single and best_idx != cur_idx:
		seq += _repeat(entry.inc if best_idx > cur_idx else entry.dec, abs(best_idx - cur_idx))
	return seq


func _repeat(a: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(a)
	return out


func _press_seq(seq: Array) -> void:
	busy = true
	for a in seq:
		Input.action_press(a)
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		Input.action_release(a)
		await get_tree().physics_frame
		await get_tree().process_frame
	busy = false


# ---------------------------------------------------------------- volumen (Opciones)

func _volume_ui():
	var g = get_node_or_null("/root/globals")
	var ui = g.get("ui") if g else null
	if ui == null or not is_instance_valid(ui) or int(ui.get("state")) != 1:
		return null
	var om = ui.get("options_menu")
	if om == null or not om.visible:
		return null
	return ui


func _volume_tap(p: Vector2) -> bool:
	var ui = _volume_ui()
	if ui == null:
		return false
	var idx := int(ui.option_index)
	var item = ui.options_items.get_child(idx)
	var bar = item.get_node_or_null("BarBG")
	if bar == null:
		bar = item.get_node_or_null("Bar")
	var r = _item_rect(bar)
	var key: String = ["bgm_volume", "se_volume"][clampi(idx, 0, 1)]
	var g = get_node("/root/globals")
	if r != null and (r as Rect2).grow(24).has_point(p):
		var rr: Rect2 = r
		var target := clampf(snappedf((p.x - rr.position.x) / maxf(rr.size.x, 1.0), 0.1), 0.1, 1.0)
		var cur: float = g.options[key]
		var steps := int(round((target - cur) / 0.1))
		if steps != 0:
			_press_seq(_repeat("right" if steps > 0 else "left", abs(steps)))
	else:
		_press_seq(["Accept"])  # tocar fuera de la barra = terminar
	return true


# ---------------------------------------------------------------- pistas

var _ctx := ""
var _ctx_seen := {}
var _ctx_timer := 0.0

const HINTS := {
	"title": "Toca una opción para ver qué es · tócala otra vez para entrar",
	"menu": "Toca una opción para elegirla · tócala otra vez para confirmar · ‹ Atrás para salir",
	"options": "Toca un volumen y luego toca la barra para ajustarlo · ‹ Atrás para salir",
	"volume": "Toca la barra para cambiar el volumen · toca fuera para terminar",
	"formation": "Toca una casilla para elegirla · otra vez para tomar o colocar al Pokémon",
	"shop": "Toca una carta para elegirla · otra vez para comprar · ‹ Atrás para salir",
	"choice": "Toca una respuesta para elegirla · tócala otra vez para confirmar",
	"lc": "Toca un personaje para elegirlo · otra vez para confirmar · ‹ Atrás para volver",
}


func _process(d: float) -> void:
	_ctx_timer += d
	if _ctx_timer < 0.4:
		return
	_ctx_timer = 0.0
	var c := _context()
	if c != _ctx:
		_ctx = c
		if c != "" and not _ctx_seen.has(c):
			_ctx_seen[c] = true
			var tc = get_node_or_null("/root/TouchControls")
			if tc and tc.has_method("show_hint"):
				tc.show_hint(HINTS.get(c, HINTS["menu"]))


func _context() -> String:
	if _volume_ui() != null:
		return "volume"
	for cl in _find_named("ChoiceList"):
		if cl.is_visible_in_tree():
			return "choice"
	var g = get_node_or_null("/root/globals")
	var ui = g.get("ui") if g else null
	if ui and is_instance_valid(ui):
		var st := int(ui.get("state")) if ui.get("state") != null else 0
		match st:
			13:
				return "options"
			5:
				return "formation"
			7, 9:
				return "shop"
			2, 3, 4, 8, 10, 11:
				return "menu"
	var lc = _find_script(LC_SCRIPT)
	if lc and int(lc.get("state")) == 0:
		return "lc"
	var title = _find_script(TITLE_SCRIPT)
	if title and int(title.get("state")) == 1:
		return "title"
	return ""


# ---------------------------------------------------------------- menús

func _vis_children(n) -> Array:
	if n == null or not is_instance_valid(n):
		return []
	return n.get_children()


func _list(cur: int, items: Array, inc := "down", dec := "up") -> Dictionary:
	return {"cur": cur, "lines": [items], "inc": inc, "dec": dec}


func _active_entries() -> Array:
	var out := []
	var g = get_node_or_null("/root/globals")

	# Diálogos con opciones (NPCs, jugador, batalla)
	for cl in _find_named("ChoiceList"):
		if cl.is_visible_in_tree():
			var items: Array = cl.get_children()
			var cur := 0
			for i in items.size():
				var s = items[i].get_node_or_null("Selector")
				if s and s.visible:
					cur = i
			out.append(_list(cur, items))

	var ui = g.get("ui") if g else null
	if ui and is_instance_valid(ui) and ui.get("state") != null:
		match int(ui.get("state")):
			2:
				out.append(_list(ui.selector_index, _vis_children(ui.v_list)))
			3, 8:
				out.append(_list(ui.party_index, _vis_children(ui.party_menu.get_node("VList"))))
			4:
				out.append(_list(ui.status_move_index, _vis_children(ui.status_menu.get_node("Moves"))))
			5:
				var fm = ui.get("formation_menu")
				if fm:
					out.append({"cur": ui.formation_index - 1, "lines": [_vis_children(fm.get_node("Slots"))], "grid": 3})
				out.append(_list(ui.party_index, _vis_children(ui.party_menu.get_node("VList"))))
			7:
				var sell = ui.get("card_shop_menu").get_node_or_null("SellButton") if ui.get("card_shop_menu") else null
				out.append({"cur": ui.card_shop_index, "cur_line": ui.card_shop_line,
					"lines": [_vis_children(ui.card_list), _vis_children(ui.booster_list), [sell] if sell else []],
					"inc": "right", "dec": "left"})
			9:
				out.append({"cur": ui.starter_index, "cur_line": ui.starter_line,
					"lines": [_vis_children(ui.deck_list1), _vis_children(ui.deck_list2), _vis_children(ui.deck_list3)],
					"inc": "right", "dec": "left"})
			10:
				out.append(_list(ui.item_index, _vis_children(ui.item_list)))
			11:
				out.append(_list(ui.item_shop_index, _vis_children(ui.item_shop_list)))
			13:
				out.append(_list(ui.option_index, _vis_children(ui.options_items)))

	var battle = g.get("battle") if g else null
	if battle and is_instance_valid(battle):
		var ms := int(battle.get("menu_state"))
		if ms == 1 and ui:
			out.append(_list(battle.party_index, _vis_children(ui.party_menu.get_node("VList"))))
		elif ms == 3:
			var field = battle.get_node_or_null("UnitField")
			if field:
				var pts := []
				for v in battle.battle_positions[0]:
					pts.append({"field": field, "pos": v})
				var fp = battle.formation_position
				out.append({"cur": int(fp[0]) + int(fp[1]) * 3, "lines": [pts], "grid": 3})

	var lc = _find_script(LC_SCRIPT)
	if lc and int(lc.get("state")) == 0:
		out.append({"cur": lc.selector_index, "lines": [_vis_children(lc.grid)], "grid": -12})

	var title = _find_script(TITLE_SCRIPT)
	if title and int(title.get("state")) == 1:
		out.append(_list(title.menu_index, _vis_children(title.menu_list)))

	return out


# ---------------------------------------------------------------- utilidades

func _item_rect(n):
	if n is Dictionary:
		var t: Transform2D = n.field.get_global_transform_with_canvas()
		var c: Vector2 = t * n.pos
		return Rect2(c - Vector2(70, 110), Vector2(140, 150))
	if n == null or not is_instance_valid(n) or not (n is CanvasItem) or not n.is_visible_in_tree():
		return null
	if n is Control:
		return n.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, n.size)
	if n is Sprite2D:
		return n.get_global_transform_with_canvas() * n.get_rect()
	var r = null
	for ch in n.get_children():
		if ch is Control or ch is Sprite2D:
			var cr = _item_rect(ch)
			if cr != null:
				r = cr if r == null else (r as Rect2).merge(cr)
	if r == null and n is Node2D:
		var c2: Vector2 = n.get_global_transform_with_canvas().origin
		r = Rect2(c2 - Vector2(40, 40), Vector2(80, 80))
	return r


func _speech_visible() -> bool:
	for s in _find_named("SpeechBox"):
		if s is CanvasItem and s.is_visible_in_tree():
			return true
	return false


func _find_named(nm: String) -> Array:
	return get_tree().root.find_children(nm, "", true, false)


func _find_script(path: String):
	var c = _cache.get(path)
	if c and is_instance_valid(c) and c.is_inside_tree():
		return c
	var found = _search(get_tree().root, path)
	_cache[path] = found
	return found


func _search(n: Node, path: String):
	var s = n.get_script()
	if s and s.resource_path == path:
		return n
	for ch in n.get_children():
		var r = _search(ch, path)
		if r:
			return r
	return null
