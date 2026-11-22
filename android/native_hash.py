"""Huella de la parte NATIVA de la app: si cambia, hace falta APK nueva; si no, basta un parche .pck pequeño.

Solo cuenta lo que de verdad termina dentro del APK y no se puede cambiar con un parche:
  - la versión de Godot,
  - los ajustes de exportación (export_presets.cfg),
  - el código Java (actualizador, 120 Hz) y su generador,
  - íconos, pantalla de carga y firma,
  - los ajustes del proyecto YA APLICADOS (project.godot: autoloads, pantalla, entrada...),
    sin las líneas de versión/build, que cambian en cada compilación.
Todo lo demás (scripts .gd, escenas, imágenes, sonidos, traducción, scripts de compilación) viaja en el parche.

Uso (DESPUÉS de apply_android.py): python3 android/native_hash.py <godot_tag> <carpeta_del_proyecto>
Si la huella aparece en android/native_alias.json, se usa el valor equivalente anterior
(para no obligar a reinstalar cuando solo cambió la forma de calcularla).
"""
import hashlib
import json
import pathlib
import re
import sys

tag, proj = sys.argv[1], pathlib.Path(sys.argv[2])
a = pathlib.Path("android")
h = hashlib.sha256(tag.encode())

files = [a / "export_presets.cfg", a / "patch_android_build.py", a / "debug.keystore"]
files += sorted((a / "updater").glob("*.java"))
files += sorted(a.glob("*.png"))
for f in files:
    h.update(str(f).encode())
    h.update(f.read_bytes())

pg = (proj / "project.godot").read_text(encoding="utf-8")
pg = "\n".join(l for l in pg.splitlines()
               if not re.match(r"^config/(version|port_version)=", l) and not l.startswith(";"))
h.update(pg.encode())

native = h.hexdigest()[:16]
alias_file = a / "native_alias.json"
if alias_file.exists():
    native = json.loads(alias_file.read_text()).get(native, native)
print(native)
