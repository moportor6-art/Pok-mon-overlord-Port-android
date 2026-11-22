extends Node
## Carga el parche del juego que bajó el actualizador (user://actualizacion/build-N.pck).
## Debe ser el PRIMER autoload: se ejecuta en _init(), antes de que se carguen los demás
## scripts, así los archivos del parche reemplazan a los de la APK.
## Vuelta atrás: si con el parche el juego no llega a funcionar 10 s (2 intentos), se vuelve a la APK.

const DIR := "user://actualizacion/"
const ACTIVE := DIR + "activo.json"

var loaded_build := 0
var _data := {}


func _init() -> void:
	if not FileAccess.file_exists(ACTIVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(ACTIVE))
	if typeof(d) != TYPE_DICTIONARY:
		_drop("")
		return
	var app_build := int(str(ProjectSettings.get_setting("application/config/version", "0")))
	var b := int(d.get("build", 0))
	if b <= app_build:
		_drop("")  # la APK instalada ya es igual o más nueva: el parche sobra
		return
	var pending: bool = d.get("pending", false)
	var tries := int(d.get("tries", 0))
	if pending and tries >= 2:
		_drop("La actualización build %d no arrancó bien: se volvió a la versión de la app." % b)
		return
	if pending:
		d["tries"] = tries + 1
		_save(d)
	var path: String = DIR + str(d.get("pck", ""))
	if not FileAccess.file_exists(path) or not ProjectSettings.load_resource_pack(path, true):
		_drop("No se pudo cargar la actualización build %d: se volvió a la versión de la app." % b)
		return
	loaded_build = b
	_data = d


func _ready() -> void:
	if loaded_build > 0 and _data.get("pending", false):
		get_tree().create_timer(10.0).timeout.connect(_confirm)


func _confirm() -> void:
	_data["pending"] = false
	_data["tries"] = 0
	_save(_data)


func _save(d: Dictionary) -> void:
	var f := FileAccess.open(ACTIVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _drop(msg: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTIVE))
	var da := DirAccess.open(DIR)
	if da:
		for fn in da.get_files():
			if fn.ends_with(".pck"):
				da.remove(fn)
	if msg != "":
		var f := FileAccess.open(DIR + "vuelta_atras.txt", FileAccess.WRITE)
		if f:
			f.store_string(msg)
