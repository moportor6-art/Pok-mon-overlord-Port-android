"""Parchea la actividad Android de Godot para pedir la tasa de refresco más alta (120 Hz)."""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
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
"""
files = [f for f in root.rglob("*.java") if "extends GodotActivity" in f.read_text(encoding="utf-8")]
if not files:
    sys.exit("No se encontró la actividad de Godot")
f = files[0]
src = f.read_text(encoding="utf-8")
if "Port: pedir la tasa" in src:
    print("ya parcheado"); sys.exit(0)
m = re.search(r"super\.onCreate\([^)]*\);", src)
if m:
    src = src[:m.end()] + CODE + src[m.end():]
else:
    i = src.rindex("}")
    src = src[:i] + """
    @Override
    public void onCreate(android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);""" + CODE + """    }
""" + src[i:]
f.write_text(src, encoding="utf-8")
print("Parcheado:", f)
print(src)
