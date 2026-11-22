"""Traduce el juego al español en la copia de compilación (el código original en inglés no se toca en el repo).

Uso: python3 android/translate_es.py <carpeta_del_proyecto>
Diccionario: android/es.json  →  {"texto en inglés": {"es": "texto en español", "files": [...]}}
Solo reemplaza textos completos entre comillas (o líneas `text = "..."` de las escenas),
nunca claves ni comparaciones, para no romper la lógica del juego.
"""
import json
import os
import sys

proj = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(here, "es.json"), encoding="utf-8"))
by_file = {}
for en, v in d.items():
    for f in v["files"]:
        by_file.setdefault(f, []).append((en, v["es"]))
total = 0
for f, pairs in by_file.items():
    path = os.path.join(proj, f)
    if not os.path.isfile(path):
        continue
    s = open(path, encoding="utf-8").read()
    n0 = s
    for en, es in sorted(pairs, key=lambda p: -len(p[0])):
        if f.endswith(".tscn"):
            a, b = f'text = "{en}"', f'text = "{es}"'
        else:
            a, b = f'"{en}"', f'"{es}"'
        c = s.count(a)
        if c:
            s = s.replace(a, b)
            total += c
    if s != n0:
        open(path, "w", encoding="utf-8").write(s)
print("Textos traducidos al español:", total)
