"""Huella de la parte nativa: si cambia, hace falta APK nueva; si no, basta un parche .pck.

Uso: python3 android/native_hash.py <godot_tag>   (ejecutar ANTES de apply_android.py)
"""
import hashlib
import pathlib
import sys

h = hashlib.sha256(sys.argv[1].encode())
files = sorted(pathlib.Path("android").rglob("*"))
files = [f for f in files if f.is_file() and f.suffix not in (".gd",)]   # los .gd del port viajan en el parche
files.append(pathlib.Path("game/project.godot"))
for f in files:
    h.update(str(f).encode())
    h.update(f.read_bytes())
print(h.hexdigest()[:16])
