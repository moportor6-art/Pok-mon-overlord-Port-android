# Pokémon Overlord — Port Android

Port offline para Android de **Pokémon Overlord** (fangame de jab_lao, Godot 4.5).

## Cómo funciona

1. `original/index.pck` es el juego de la versión web.
2. La primera vez, GitHub Actions recupera el proyecto Godot completo con GDRE Tools y lo guarda en `game/`.
3. En cada push se aplican los ajustes de Android (`android/`), se exporta el APK con Godot 4.5 y se publica en **Releases**.

## Añadidos de Android

- Controles táctiles (cruceta, A = Aceptar, B = Cancelar, i = Info). El botón `≡` los oculta o muestra.
- Pantalla completa en horizontal (gira con el sensor).
- Firma de depuración fija (`android/debug.keystore`) para que cada versión se instale encima de la anterior sin perder la partida.

La versión del APK está en `VERSION`.

## Actualizador (igual que DB Survivors)

Cada compilación se publica en Releases como `build-N` con la APK, `contenido.json` y un paquete del juego.
Al abrir la app, a los 5 segundos busca la última versión y muestra las novedades y el tamaño
(Actualizar / Más tarde / Omitir esta versión).

- **Solo cambió el juego** (scripts, escenas, imágenes, sonidos): baja un parche pequeño `patch.pck`,
  se reinicia y lo carga `PatchLoader` al arrancar. No se reinstala nada.
- **Cambió la parte nativa** (versión de Godot, `project.godot`, ajustes de exportación, Java, íconos):
  baja la APK completa y Android la instala encima, sin desinstalar.
- **Vuelta atrás**: si el juego no arranca con el parche (2 intentos), vuelve solo a lo que trae la APK.
- Las partidas guardadas nunca se tocan.
