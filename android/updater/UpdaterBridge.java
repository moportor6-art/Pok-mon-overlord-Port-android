package com.godot.game;

import android.app.Activity;

/** Puente para el juego (GDScript → JavaClassWrapper): botón "Actualizaciones" del título. */
public final class UpdaterBridge {
    private static Activity act;

    static void init(Activity a) { act = a; }

    /** Busca una versión nueva y avisa también si no hay ninguna. */
    public static void check() {
        final Activity a = act;
        if (a != null) a.runOnUiThread(() -> new Updater(a).check(true));
    }

    /** Muestra el historial de versiones (novedades de cada build). */
    public static void history() {
        final Activity a = act;
        if (a != null) a.runOnUiThread(() -> new Updater(a).history());
    }

    /** Build de la app instalada. */
    public static int build() { return BuildInfo.BUILD; }
}
