"""Copia los añadidos de Android al proyecto recuperado y ajusta project.godot.

Uso: python3 android/apply_android.py <carpeta_del_proyecto> <version>
Es idempotente: se puede ejecutar en cada build.
"""
import os
import re
import shutil
import sys

proj = sys.argv[1]
version = sys.argv[2] if len(sys.argv) > 2 else "0.1"
run = os.environ.get("GITHUB_RUN_NUMBER", "1")
here = os.path.dirname(os.path.abspath(__file__))

os.makedirs(os.path.join(proj, "android"), exist_ok=True)
shutil.copy(os.path.join(here, "touch_controls.gd"), os.path.join(proj, "android", "touch_controls.gd"))

with open(os.path.join(here, "export_presets.cfg"), encoding="utf-8") as f:
    presets = f.read()
presets = presets.replace('version/name="0.1"', f'version/name="{version}"')
presets = re.sub(r"version/code=\d+", f"version/code={run}", presets)
with open(os.path.join(proj, "export_presets.cfg"), "w", encoding="utf-8") as f:
    f.write(presets)

pg = os.path.join(proj, "project.godot")
with open(pg, encoding="utf-8") as f:
    lines = f.read().split("\n")


def set_key(section, key, value):
    header = f"[{section}]"
    if header not in lines:
        lines.extend(["", header, ""])
    start = lines.index(header) + 1
    end = start
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    for i in range(start, end):
        if lines[i].split("=", 1)[0].strip() == key:
            lines[i] = f"{key}={value}"
            return
    lines.insert(start, f"{key}={value}")


set_key("autoload", "TouchControls", '"*res://android/touch_controls.gd"')
set_key("display", "window/handheld/orientation", "4")
set_key("input_devices", "pointing/emulate_mouse_from_touch", "true")
set_key("rendering", "textures/vram_compression/import_etc2_astc", "true")

with open(pg, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("project.godot ajustado para Android")
