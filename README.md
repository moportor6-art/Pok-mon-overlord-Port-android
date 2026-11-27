# Pokémon Overlord — Port Android

Port offline para Android de **Pokémon Overlord** (fangame de jab_lao, Godot 4.5).

## Cómo funciona

1. `original/index.pck` es el juego de la versión web.
2. La primera vez, GitHub Actions recupera el proyecto Godot completo con GDRE Tools y lo guarda en `game/`.
3. En cada push se aplican los ajustes de Android (`android/`), se exporta el APK con Godot 4.5 y se publica en **Releases**.

## Añadidos de Android

- Juego en **español** (diálogos, movimientos, objetos y menús). El diccionario está en `android/es.json`
  y se aplica al compilar; el código original en inglés no se toca.
- Toques directos en los menús: toca una opción para elegirla y otra vez para confirmar.
- Botón **‹ Atrás** siempre visible (y el botón atrás de Android): nunca te quedas atrapado en un menú.
- Volumen: toca la barra para ajustarlo.
- Pistas cortas en pantalla la primera vez que entras a cada menú.
- Botón **⟳ Actualizaciones** en el título: buscar actualización e historial de versiones.
- Cruceta, A = Aceptar, B = Atrás, i = Info. El botón `≡` oculta o muestra la cruceta.
- Pantalla completa en horizontal (gira con el sensor).
- **🌱 Expedición** (0.8, mundo de prueba de [worldgen](https://github.com/moportor6-art/worldgen)): botón arriba a la
  derecha cuando caminas libre. Te lleva a una cueva generada (6 mapas de `android/expediciones.json`, pintados con las
  casillas de cueva del juego, con rocas y hoyos que bloquean); «↩ Volver» te deja donde estabas (`android/expedicion.gd`).
- Firma de depuración fija (`android/debug.keystore`) para que cada versión se instale encima de la anterior sin perder la partida.

La versión del APK está en `VERSION`.

## Actualizador (igual que DB Survivors)

Cada compilación se publica en Releases como `build-N` con la APK, `contenido.json` y un paquete del juego.
Al abrir la app, a los 5 segundos busca la última versión y muestra las novedades y el tamaño
(Actualizar / Más tarde / Omitir esta versión).

- **Solo cambió el juego** (scripts, escenas, imágenes, sonidos): baja un parche pequeño `patch.pck`,
  se reinicia y lo carga `PatchLoader` al arrancar. No se reinstala nada.
- **Cambió la parte nativa** (versión de Godot, ajustes del proyecto, ajustes de exportación, Java, íconos):
  baja la APK completa y Android la instala encima, sin desinstalar. Esto debería pasar muy rara vez:
  `android/native_hash.py` solo cuenta lo que de verdad va dentro del APK. Los scripts de compilación,
  la traducción, los `.gd`, escenas, imágenes y sonidos siempre viajan en el parche.
- Para añadir funciones nuevas sin APK: ponerlas en los autoloads que ya existen (`port_ui.gd`,
  `touch_controls.gd`, `touch_nav.gd`) o en los scripts del juego, no crear autoloads nuevos.
- **Vuelta atrás**: si el juego no arranca con el parche (2 intentos), vuelve solo a lo que trae la APK.
- Las partidas guardadas nunca se tocan.
