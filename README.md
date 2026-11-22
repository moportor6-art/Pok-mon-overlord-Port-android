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
