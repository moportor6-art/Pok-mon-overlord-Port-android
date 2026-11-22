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

port = os.path.join(proj, "port")
os.makedirs(port, exist_ok=True)
for fn in ["patch_loader.gd", "port_ui.gd", "touch_controls.gd", "touch_nav.gd", "splash.png", "icon_192.png", "icon_512.png",
           "icon_fg_432.png", "icon_bg_432.png"]:
    shutil.copy(os.path.join(here, fn), os.path.join(port, fn))

with open(os.path.join(here, "export_presets.cfg"), encoding="utf-8") as f:
    presets = f.read()
presets = presets.replace('version/name="0.1"', f'version/name="{version}"')
presets = re.sub(r"version/code=\d+", f"version/code={run}", presets)
with open(os.path.join(proj, "export_presets.cfg"), "w", encoding="utf-8") as f:
    f.write(presets)

# Español
import subprocess
subprocess.check_call([sys.executable, os.path.join(here, "translate_es.py"), proj])

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


set_key("autoload", "TouchControls", '"*res://port/touch_controls.gd"')
set_key("autoload", "TouchNav", '"*res://port/touch_nav.gd"')
set_key("autoload", "PortUI", '"*res://port/port_ui.gd"')
set_key("application", "config/port_version", f'"{version}"')
# Logo del juego en vez de Godot
set_key("application", "config/icon", '"res://port/icon_512.png"')
set_key("application", "boot_splash/show_image", "true")
set_key("application", "boot_splash/image", '"res://port/splash.png"')
set_key("application", "boot_splash/bg_color", "Color(0.055, 0.07, 0.157, 1)")
set_key("application", "boot_splash/fullsize", "true")
set_key("application", "boot_splash/stretch_mode", "1")
set_key("application", "boot_splash/use_filter", "true")
# Botón atrás = Cancelar (no cerrar el juego)
set_key("application", "config/quit_on_go_back", "false")
# Pantalla completa y 120 Hz
set_key("display", "window/size/mode", "3")
set_key("display", "window/vsync/vsync_mode", "1")
set_key("application", "run/max_fps", "0")
# Build de esta APK (lo usa PatchLoader para saber si un parche sobra)
set_key("application", "config/version", f'"{run}"')
# El cargador de parches tiene que ser el PRIMER autoload (set_key inserta al principio)
set_key("autoload", "PatchLoader", '"*res://port/patch_loader.gd"')
set_key("display", "window/handheld/orientation", "4")
set_key("input_devices", "pointing/emulate_mouse_from_touch", "true")
set_key("rendering", "textures/vram_compression/import_etc2_astc", "true")

with open(pg, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("project.godot ajustado para Android")
