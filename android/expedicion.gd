extends RefCounted
# Expedición (mundo de prueba de worldgen, repo moportor6-art/worldgen).
# Los mapas los genera worldgen (adapters/overlord.js, tipo «cueva») y vienen en expediciones.json; aquí solo se
# pintan con las casillas de cueva que ya trae el juego (Caves.png, fuente 6 del TileSet) en una zona libre del mapa
# grande del nivel, lejos de las áreas de la historia, y se ponen choques para las rocas y paredes.
# Leyenda: "." suelo · "=" camino · "h" suelo oscuro · "f" suelo · "R"/"T" roca (bloquea) · "~" hoyo (bloquea).

const FUENTE := 6                       # Caves.png en TileSet_jasff
const ORIGEN := Vector2i(300, 0)        # celda de la esquina del mapa (fuera de todas las áreas)
const SUELO := {".": Vector2i(4, 13), "=": Vector2i(1, 13), "h": Vector2i(4, 14), "f": Vector2i(2, 13)}
const ROCAS := [Vector2i(5, 6), Vector2i(6, 6), Vector2i(5, 7)]
const HOYO := Vector2i(4, 3)
const BLOQUEA := ["R", "T", "~"]
const ARCHIVO := "res://port/expediciones.json"

static var _hecho := {}


static func mapas() -> Array:
	var f := FileAccess.open(ARCHIVO, FileAccess.READ)
	if f == null:
		return []
	var d = JSON.parse_string(f.get_as_text())
	return d["mapas"] if d is Dictionary and d.has("mapas") else []


# Pinta el mapa n en el nivel y lleva al jugador a la entrada. Devuelve la posición de la entrada o null.
static func entrar(level: Node, n: int = -1):
	var lista := mapas()
	if lista.is_empty() or level == null:
		return null
	if n < 0:
		n = randi() % lista.size()
	var m: Dictionary = lista[n % lista.size()]
	var floor_l: TileMapLayer = level.get_node_or_null("Tiles/Floor")
	var obj_l: TileMapLayer = level.get_node_or_null("Tiles/Objects")
	if floor_l == null or obj_l == null:
		return null
	var filas: Array = m["filas"]
	var alto := filas.size()
	var ancho := String(filas[0]).length()
	# Limpia lo de una expedición anterior
	for y in range(-1, 60):
		for x in range(-1, 40):
			var c := ORIGEN + Vector2i(x, y)
			floor_l.erase_cell(c)
			obj_l.erase_cell(c)
	var viejo = level.get_node_or_null("ExpedicionChoques")
	if viejo:
		viejo.free()
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "ExpedicionChoques"
	level.add_child(cuerpo)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.get("semilla", 1))
	for y in alto:
		var fila := String(filas[y])
		for x in ancho:
			var ch := fila[x]
			var c := ORIGEN + Vector2i(x, y)
			floor_l.set_cell(c, FUENTE, SUELO.get(ch, SUELO["."]))
			if ch == "~":
				floor_l.set_cell(c, FUENTE, HOYO)
			elif ch == "R" or ch == "T":
				obj_l.set_cell(c, FUENTE, ROCAS[rng.randi() % ROCAS.size()])
			if ch in BLOQUEA:
				var forma := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2(46, 46)
				forma.shape = r
				forma.global_position = floor_l.to_global(floor_l.map_to_local(c))
				cuerpo.add_child(forma)
	# Borde exterior cerrado (por si el mapa toca el límite)
	for x in range(-1, ancho + 1):
		for y in [-1, alto]:
			_choque(cuerpo, floor_l, ORIGEN + Vector2i(x, y))
	for y in alto:
		for x in [-1, ancho]:
			_choque(cuerpo, floor_l, ORIGEN + Vector2i(x, y))
	var e: Dictionary = m["entrada"]
	var pos := floor_l.to_global(floor_l.map_to_local(ORIGEN + Vector2i(int(e["x"]), int(e["y"]))))
	var player = level.get_node_or_null("Actors/Player")
	if player:
		player.global_position = pos
		var cam = player.get_node_or_null("Camera")
		if cam:
			var a := floor_l.to_global(floor_l.map_to_local(ORIGEN)) - Vector2(24, 24)
			cam.limit_left = int(a.x) - 48 * 4
			cam.limit_top = int(a.y) - 48 * 4
			cam.limit_right = int(a.x) + 48 * (ancho + 4)
			cam.limit_bottom = int(a.y) + 48 * (alto + 4)
			cam.reset_smoothing()
	return pos


static func _choque(cuerpo: StaticBody2D, capa: TileMapLayer, c: Vector2i) -> void:
	var forma := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46, 46)
	forma.shape = r
	forma.global_position = capa.to_global(capa.map_to_local(c))
	cuerpo.add_child(forma)
