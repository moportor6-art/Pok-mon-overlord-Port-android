"""Parchea la plantilla Android (gradle) de Godot:
  - 120 Hz: pide la tasa de refresco más alta de la pantalla y usa la zona del notch.
  - Actualizador (Updater.java + InstallReceiver.java), igual que el de DB Survivors.

Uso: python3 android/patch_android_build.py <game/android/build> <build> <huella_nativa>
"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path(sys.argv[1])
build = int(sys.argv[2])
native = sys.argv[3]
here = pathlib.Path(__file__).parent

CODE = """
        // --- Port: pedir la tasa de refresco más alta de la pantalla (90/120/144 Hz) ---
        try {
            android.view.Display d = getWindowManager().getDefaultDisplay();
            android.view.Display.Mode cur = d.getMode();
            android.view.Display.Mode best = cur;
            for (android.view.Display.Mode m : d.getSupportedModes()) {
                if (m.getPhysicalWidth() == cur.getPhysicalWidth()
                        && m.getPhysicalHeight() == cur.getPhysicalHeight()
                        && m.getRefreshRate() > best.getRefreshRate()) {
                    best = m;
                }
            }
            android.view.WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.preferredDisplayModeId = best.getModeId();
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                lp.preferredRefreshRate = best.getRefreshRate();
            }
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                lp.layoutInDisplayCutoutMode = 1; // SHORT_EDGES: usar también la zona del notch
            }
            getWindow().setAttributes(lp);
        } catch (Throwable t) { }
        // --- Port: buscar actualizaciones al abrir (sin internet, nada) ---
        final android.app.Activity self = this;
        UpdaterBridge.init(this);
        if (savedInstanceState != null && savedInstanceState.getBoolean("__port_keep__")) {   // mantiene los métodos del puente
            UpdaterBridge.check(); UpdaterBridge.history(); UpdaterBridge.build();
        }
        new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
            try { new Updater(self).check(false); } catch (Throwable t) { }
        }, 5000);
"""

files = [f for f in root.rglob("*.java") if "extends GodotActivity" in f.read_text(encoding="utf-8")]
if not files:
    sys.exit("No se encontró la actividad de Godot")
act = files[0]
src = act.read_text(encoding="utf-8")
if "Port: pedir la tasa" not in src:
    m = re.search(r"super\.onCreate\(([^)]*)\);", src)
    if m:
        arg = m.group(1).strip() or "savedInstanceState"
        src = src[:m.end()] + CODE.replace("savedInstanceState", arg) + src[m.end():]
    else:
        i = src.rindex("}")
        src = src[:i] + """
    @Override
    public void onCreate(android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);""" + CODE + """    }
""" + src[i:]
    act.write_text(src, encoding="utf-8")
print("Actividad parcheada:", act)

pkg_dir = act.parent
pkg = re.search(r"^package\s+([\w.]+);", src, re.M).group(1)
for fn in ["Updater.java", "InstallReceiver.java", "UpdaterBridge.java"]:
    t = (here / "updater" / fn).read_text(encoding="utf-8")
    t = re.sub(r"^package\s+[\w.]+;", f"package {pkg};", t, flags=re.M)
    (pkg_dir / fn).write_text(t, encoding="utf-8")
(pkg_dir / "BuildInfo.java").write_text(
    f"package {pkg};\n\nfinal class BuildInfo {{\n    static final int BUILD = {build};\n"
    f"    static final String NATIVE = \"{native}\";\n}}\n", encoding="utf-8")
print("Actualizador copiado en", pkg_dir, "· build", build, "· nativo", native)

man = root / "AndroidManifest.xml"
x = man.read_text(encoding="utf-8")
if "InstallReceiver" not in x:
    x = x.replace("</application>", f'        <receiver android:name="{pkg}.InstallReceiver" android:exported="false" />\n    </application>', 1)
    man.write_text(x, encoding="utf-8")
print("Manifiesto con InstallReceiver")
