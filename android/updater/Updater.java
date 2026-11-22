package com.godot.game;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Locale;

/**
 * Actualizador del port (mismo sistema que DB Survivors).
 * <p>
 * Cada compilación de GitHub se publica como versión build-N con: la APK, un manifiesto (contenido.json) y
 * un paquete del juego (.pck).
 * <ul>
 * <li>Si solo cambió el juego, se baja un <b>parche pequeño</b> (patch.pck) con los archivos que cambiaron.
 * El juego lo carga al arrancar (PatchLoader.gd). No se reinstala nada.</li>
 * <li>Si cambió la parte nativa (Godot, ajustes, Java, íconos), se baja la APK completa y Android la instala
 * encima (misma firma: no hace falta desinstalar).</li>
 * <li>Antes se ven las novedades y el tamaño: Actualizar, Más tarde u Omitir esta versión.</li>
 * <li>Vuelta atrás: si el juego no arranca con el parche, PatchLoader vuelve solo a lo que trae la APK.</li>
 * </ul>
 * Las partidas guardadas (user://) no se tocan nunca.
 */
final class Updater {
    private static final String REPO = "moportor6-art/Pok-mon-overlord-Port-android";
    private static final String LATEST = "https://api.github.com/repos/" + REPO + "/releases/latest";

    private final Activity act;
    private final SharedPreferences prefs;
    private final File dir;
    private volatile boolean busy;

    Updater(Activity a) {
        act = a;
        prefs = a.getSharedPreferences("actualizador", Activity.MODE_PRIVATE);
        dir = new File(a.getFilesDir(), "actualizacion");   // = user://actualizacion/ en Godot
    }

    /** Build del parche activo (0 si no hay). */
    private int overlayBuild() {
        try (InputStream in = new FileInputStream(new File(dir, "activo.json"))) {
            JSONObject o = new JSONObject(readAll(in));
            int b = o.optInt("build", 0);
            return b > BuildInfo.BUILD ? b : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    /** Busca una versión nueva. manual: avisa también si no hay nada o si falla. */
    void check(final boolean manual) {
        if (BuildInfo.BUILD <= 0) return;
        if (busy) return;
        busy = true;
        showRollbackNotice();
        new Thread(() -> {
            try {
                JSONObject rel = new JSONObject(get(LATEST));
                int remote = buildOf(rel.optString("tag_name"));
                int current = Math.max(BuildInfo.BUILD, overlayBuild());
                if (remote <= current) {
                    if (manual) toast("Ya tienes la última versión (build " + current + ").");
                    return;
                }
                if (!manual && prefs.getInt("skip", 0) == remote) return;
                String manUrl = null, apkUrl = null, patchUrl = null;
                org.json.JSONArray assets = rel.getJSONArray("assets");
                for (int i = 0; i < assets.length(); i++) {
                    JSONObject a = assets.getJSONObject(i);
                    String n = a.optString("name");
                    if (n.equals("contenido.json")) manUrl = a.optString("browser_download_url");
                    else if (n.equals("patch.pck")) patchUrl = a.optString("browser_download_url");
                    else if (n.endsWith(".apk")) apkUrl = a.optString("browser_download_url");
                }
                if (manUrl == null) throw new Exception("la versión no trae su manifiesto");
                JSONObject man = new JSONObject(get(manUrl));
                String notes = rel.optString("body").trim();
                JSONObject patch = man.optJSONObject("patch");
                boolean sameNative = man.optString("native").equals(BuildInfo.NATIVE);
                if (sameNative && patch != null && patchUrl != null && patch.optInt("base") <= BuildInfo.BUILD) {
                    final long size = patch.optLong("size");
                    final String url = patchUrl, sha = patch.optString("sha", null);
                    ui(() -> offer(remote, notes, "Solo cambió el juego: se descarga un parche de " + mb(size)
                            + ". No hace falta reinstalar.", () -> applyPatch(remote, url, sha, size)));
                } else {
                    if (apkUrl == null) throw new Exception("la versión no trae la APK");
                    JSONObject apk = man.optJSONObject("apk");
                    final long size = apk == null ? 0 : apk.optLong("size");
                    final String url = apkUrl, sha = apk == null ? null : apk.optString("sha", null);
                    ui(() -> offer(remote, notes, "Esta versión cambia la app: se descarga completa (" + mb(size)
                            + ") y Android te pide confirmar la instalación. Tus partidas se conservan.", () -> installApk(url, sha, size)));
                }
            } catch (Exception e) {
                if (manual) toast("No se pudo buscar actualizaciones (¿sin internet?).");
            } finally {
                busy = false;
            }
        }).start();
    }

    private void showRollbackNotice() {
        File f = new File(dir, "vuelta_atras.txt");
        if (!f.isFile()) return;
        try (InputStream in = new FileInputStream(f)) {
            final String msg = readAll(in).trim();
            toast(msg.isEmpty() ? "La actualización no arrancó bien: se volvió a la versión anterior." : msg);
        } catch (Exception ignored) {
        }
        //noinspection ResultOfMethodCallIgnored
        f.delete();
    }

    private void offer(int build, String notes, String what, Runnable go) {
        if (act.isFinishing()) return;
        StringBuilder msg = new StringBuilder();
        if (!notes.isEmpty()) msg.append("Novedades:\n").append(notes.length() > 1500 ? notes.substring(0, 1500) + "…" : notes).append("\n\n");
        msg.append(what);
        new AlertDialog.Builder(act)
                .setTitle("Nueva versión: build " + build)
                .setMessage(msg.toString())
                .setPositiveButton("Actualizar", (d, i) -> go.run())
                .setNeutralButton("Omitir esta versión", (d, i) -> prefs.edit().putInt("skip", build).apply())
                .setNegativeButton("Más tarde", null)
                .show();
    }

    // ─── Parche del juego (.pck) ───

    private void applyPatch(final int build, final String url, final String sha, final long size) {
        final Progress pr = new Progress("Actualizando a build " + build, 100);
        new Thread(() -> {
            String name = "build-" + build + ".pck";
            File tmp = new File(dir, name + ".tmp"), pck = new File(dir, name);
            try {
                download(url, tmp, (got) -> pr.set(size > 0 ? (int) (got * 100 / size) : 0, mb(got) + " de " + mb(size)));
                if (sha != null && !sha.isEmpty() && !sha.equals(sha256(tmp))) throw new Exception("la descarga llegó dañada");
                if (pck.exists() && !pck.delete()) throw new Exception("no se pudo guardar");
                if (!tmp.renameTo(pck)) throw new Exception("no se pudo guardar");
                // Quitar parches viejos (el nuevo ya los incluye)
                File[] all = dir.listFiles();
                if (all != null) for (File f : all) if (f.getName().endsWith(".pck") && !f.getName().equals(name)) //noinspection ResultOfMethodCallIgnored
                    f.delete();
                JSONObject a = new JSONObject();
                a.put("build", build);
                a.put("pck", name);
                a.put("pending", true);
                a.put("tries", 0);
                try (OutputStream o = new FileOutputStream(new File(dir, "activo.json"))) { o.write(a.toString().getBytes("UTF-8")); }
                ui(() -> {
                    pr.close();
                    if (act.isFinishing()) return;
                    new AlertDialog.Builder(act)
                            .setTitle("Actualizado a build " + build)
                            .setMessage("El juego se reinicia para cargar la versión nueva. Tu partida se conserva.")
                            .setCancelable(false)
                            .setPositiveButton("Reiniciar", (d, i) -> restart())
                            .show();
                });
            } catch (Exception e) {
                //noinspection ResultOfMethodCallIgnored
                tmp.delete();
                final String m = e.getMessage();
                ui(() -> { pr.close(); dialog("No se pudo actualizar", "No se cambió nada. " + (m == null ? "" : "(" + m + ")")); });
            }
        }).start();
    }

    private void restart() {
        Intent i = act.getPackageManager().getLaunchIntentForPackage(act.getPackageName());
        if (i != null) {
            Intent r = Intent.makeRestartActivityTask(i.getComponent());
            act.startActivity(r);
        }
        Runtime.getRuntime().exit(0);
    }

    // ─── Actualización completa (APK) ───

    private void installApk(final String url, final String sha, final long size) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !act.getPackageManager().canRequestPackageInstalls()) {
            new AlertDialog.Builder(act)
                    .setTitle("Permiso para actualizar")
                    .setMessage("Para instalar la actualización, Android pide permitir que Pokémon Overlord instale apps. "
                            + "Actívalo en la pantalla que se abre, vuelve y pulsa Actualizar otra vez.")
                    .setPositiveButton("Abrir ajustes", (d, i) -> act.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:" + act.getPackageName()))))
                    .setNegativeButton("Cancelar", null)
                    .show();
            return;
        }
        final Progress pr = new Progress("Descargando la app", 100);
        new Thread(() -> {
            File f = new File(act.getCacheDir(), "actualizacion.apk");
            try {
                download(url, f, (got) -> pr.set(size > 0 ? (int) (got * 100 / size) : 0, mb(got) + " de " + mb(size)));
                if (sha != null && !sha.isEmpty() && !sha.equals(sha256(f))) throw new Exception("la descarga llegó dañada");
                PackageInstaller pi = act.getPackageManager().getPackageInstaller();
                PackageInstaller.SessionParams sp = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                sp.setAppPackageName(act.getPackageName());
                int id = pi.createSession(sp);
                try (PackageInstaller.Session s = pi.openSession(id)) {
                    try (InputStream in = new FileInputStream(f); OutputStream out = s.openWrite("app.apk", 0, f.length())) {
                        byte[] b = new byte[1 << 16];
                        for (int n; (n = in.read(b)) > 0; ) out.write(b, 0, n);
                        s.fsync(out);
                    }
                    Intent cb = new Intent(act, InstallReceiver.class);
                    int fl = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 31 ? PendingIntent.FLAG_MUTABLE : 0);
                    s.commit(PendingIntent.getBroadcast(act, id, cb, fl).getIntentSender());
                }
                ui(pr::close);
            } catch (Exception e) {
                final String m = e.getMessage();
                ui(() -> { pr.close(); dialog("No se pudo actualizar", "No se cambió nada. " + (m == null ? "" : "(" + m + ")")); });
            }
        }).start();
    }

    // ─── Ayudantes ───

    private interface OnBytes { void got(long n); }

    private final class Progress {
        private final AlertDialog dlg;
        private final ProgressBar bar;
        private final TextView label;

        Progress(String title, int max) {
            LinearLayout box = new LinearLayout(act);
            box.setOrientation(LinearLayout.VERTICAL);
            int pad = (int) (20 * act.getResources().getDisplayMetrics().density);
            box.setPadding(pad, pad / 2, pad, 0);
            bar = new ProgressBar(act, null, android.R.attr.progressBarStyleHorizontal);
            bar.setMax(Math.max(1, max));
            label = new TextView(act);
            box.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            box.addView(label);
            dlg = new AlertDialog.Builder(act).setTitle(title).setView(box).setCancelable(false).create();
            dlg.show();
        }

        void set(int v, String text) { ui(() -> { bar.setProgress(v); label.setText(text); }); }

        void close() { if (dlg.isShowing()) dlg.dismiss(); }
    }

    private void ui(Runnable r) { act.runOnUiThread(r); }

    private void toast(String m) { ui(() -> Toast.makeText(act, m, Toast.LENGTH_LONG).show()); }

    private void dialog(String title, String msg) {
        if (!act.isFinishing()) new AlertDialog.Builder(act).setTitle(title).setMessage(msg).setPositiveButton("Aceptar", null).show();
    }

    private static int buildOf(String tag) {
        if (tag == null || !tag.startsWith("build-")) return 0;
        try { return Integer.parseInt(tag.replaceAll("[^0-9]", "")); } catch (Exception e) { return 0; }
    }

    private static String mb(long b) {
        return b < 1024 * 1024 ? String.format(Locale.ROOT, "%d KB", Math.max(1, b / 1024)) : String.format(Locale.ROOT, "%.1f MB", b / 1048576.0);
    }

    private static HttpURLConnection open(String url) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(15000);
        c.setReadTimeout(30000);
        c.setRequestProperty("User-Agent", "PokemonOverlord-Updater");
        c.setRequestProperty("Accept", url.contains("api.github.com") ? "application/vnd.github+json" : "*/*");
        c.setInstanceFollowRedirects(true);
        int code = c.getResponseCode();
        if (code >= 300 && code < 400) {   // redirección a otro dominio (las descargas de GitHub)
            String loc = c.getHeaderField("Location");
            c.disconnect();
            return open(loc);
        }
        if (code != 200) throw new Exception("HTTP " + code);
        return c;
    }

    private static String get(String url) throws Exception {
        HttpURLConnection c = open(url);
        try (InputStream in = c.getInputStream()) { return readAll(in); } finally { c.disconnect(); }
    }

    private static void download(String url, File to, OnBytes progress) throws Exception {
        File parent = to.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) throw new Exception("sin espacio");
        HttpURLConnection c = open(url);
        try (InputStream in = c.getInputStream(); OutputStream out = new FileOutputStream(to)) {
            byte[] b = new byte[1 << 16];
            long got = 0, last = 0;
            for (int n; (n = in.read(b)) > 0; ) {
                out.write(b, 0, n);
                got += n;
                if (progress != null && got - last > 256 * 1024) { last = got; progress.got(got); }
            }
            if (progress != null) progress.got(got);
        } finally {
            c.disconnect();
        }
    }

    private static String readAll(InputStream in) throws Exception {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] b = new byte[1 << 14];
        for (int n; (n = in.read(b)) > 0; ) o.write(b, 0, n);
        return o.toString("UTF-8");
    }

    private static String sha256(File f) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new FileInputStream(f)) {
            byte[] b = new byte[1 << 16];
            for (int n; (n = in.read(b)) > 0; ) md.update(b, 0, n);
        }
        StringBuilder sb = new StringBuilder();
        for (byte x : md.digest()) sb.append(String.format(Locale.ROOT, "%02x", x));
        return sb.toString();
    }
}
