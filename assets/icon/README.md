# Ícono de la app (launcher)

`brand_source.png` es la FUENTE: el ícono de marca a 512x512, con esquinas
redondeadas y fondo con gradiente. Los otros tres PNG se derivan de él y son los
que consume `flutter_launcher_icons` (config en `pubspec.yaml`).

| Archivo | Para qué | Por qué así |
|---|---|---|
| `ic_launcher_store.png` | Ícono legacy de Android + el de iOS | Full-bleed, **sin** las esquinas redondeadas de la fuente. Los dos sistemas aplican su propia máscara; con las esquinas transparentes, iOS (`remove_alpha_ios`) las rellena de blanco y quedan picos claros asomando fuera del redondeo. |
| `ic_launcher_background.png` | Capa de fondo del adaptive icon (Android 8+) | Va como imagen y no como `#RRGGBB` porque el fondo de marca es un gradiente; un color plano no empata con el resto del ícono. |
| `ic_launcher_foreground.png` | Capa de contenido del adaptive icon | Solo el wordmark sobre transparente, escalado por su **diagonal**: el launcher recorta en círculo y el wordmark es apaisado, asi que ajustarlo por el lado mayor deja las puntas fuera. |

El ícono de **notificación** (`ic_stat_sozu`, status bar) NO sale de aquí: lo
genera `tool/gen_icons.dart` desde `web/icons/Icon-512.png` y sigue siendo el
pin, no el wordmark. A 24 px "sozu CLIENTES" es una mancha ilegible, y Android
exige una silueta de un solo color.

## Regenerar

Al cambiar `brand_source.png`:

1. Volver a derivar los tres PNG (recortar esquinas, aislar el wordmark del
   fondo por luminancia, reconstruir el gradiente muestreando las esquinas).
2. `dart run flutter_launcher_icons`
3. Revisar `android/app/src/main/res/mipmap-*/` y
   `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

Verificación que importa: componer background + foreground y recortar en
círculo. Las esquinas del wordmark deben quedar dentro de un radio del 33% del
lienzo. Si se salen, el launcher corta letras.

⚠️ Los assets de esta carpeta son lo ÚNICO que distingue esta app de la de
agentes en el cajón de aplicaciones. Hasta el 2026-08-14 los dos repos traían
archivos idénticos (bytes iguales) y las dos apps se veían exactamente igual.
