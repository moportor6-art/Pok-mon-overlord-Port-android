"""Escribe contenido.json (lo lee el actualizador de la app).

Uso: python3 android/manifest.py <build> <huella> <apk> <salida> [--patch patch.pck <base>] [--base base.pck]
"""
import hashlib
import json
import os
import sys


def info(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return {"size": os.path.getsize(p), "sha": h.hexdigest()}


a = sys.argv[1:]
m = {"build": int(a[0]), "native": a[1], "apk": info(a[2])}
out = a[3]
rest = a[4:]
if rest[:1] == ["--patch"]:
    m["patch"] = dict(info(rest[1]), base=int(rest[2]))
elif rest[:1] == ["--base"]:
    m["base"] = info(rest[1])
with open(out, "w") as f:
    json.dump(m, f, indent=1)
print(json.dumps(m, indent=1))
