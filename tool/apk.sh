#!/usr/bin/env bash
# Compila el APK y lo deja donde Windows lo pueda abrir.
#
#   ./tool/apk.sh                  release, arquitecturas separadas (mas chico)
#   ./tool/apk.sh --debug          debug, instalable sin firmar
#   ./tool/apk.sh --fat            un solo APK universal (mas grande, mas simple)
#   ./tool/apk.sh --install        compila e instala en el telefono conectado
#
# Sin --fat genera un APK por ABI. El del telefono es casi siempre
# arm64-v8a; universal solo si vas a repartirlo sin saber el dispositivo.
set -uo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
[ -x "$HOME/jdk21/bin/java" ] && [ -z "${JAVA_HOME:-}" ] && export JAVA_HOME="$HOME/jdk21"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

MODE=release
SPLIT=1
INSTALL=0
for a in "$@"; do
  case "$a" in
    --debug)   MODE=debug ;;
    --fat)     SPLIT=0 ;;
    --install) INSTALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "opcion desconocida: $a" >&2; exit 2 ;;
  esac
done

log() { printf '\033[1;36m▶ %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32mOK   %s\033[0m\n' "$1"; }
die() { printf '\033[1;31mFAIL %s\033[0m\n' "$1" >&2; exit 1; }

[ -f assets/env ] || die "Falta assets/env. Copia .env.example."
command -v flutter >/dev/null || die "flutter no esta en el PATH"

# La misma metodologia que el resto del proyecto: version con hora de Mexico.
BUILD_TIMESTAMP="$(TZ=America/Mexico_City date +%y%m%d.%H%M)"

ARGS=(--dart-define=BUILD_TIMESTAMP="$BUILD_TIMESTAMP")
if [ "$MODE" = release ]; then
  ARGS+=(--release --dart-define=APP_ENV=prod)
else
  ARGS+=(--debug --dart-define=APP_ENV=dev)
fi
[ "$SPLIT" = 1 ] && ARGS+=(--split-per-abi)

log "flutter build apk ($MODE, timestamp $BUILD_TIMESTAMP)"
flutter build apk "${ARGS[@]}" || die "el build fallo"

OUT=build/app/outputs/flutter-apk
mapfile -t APKS < <(find "$OUT" -name "*.apk" -newermt '-10 minutes' | sort)
[ "${#APKS[@]}" -gt 0 ] || die "no encontre APKs recien generados en $OUT"

log "Generados"
for f in "${APKS[@]}"; do printf '  %-55s %s\n' "$f" "$(du -h "$f" | cut -f1)"; done

# --- Copia al lado Windows ---------------------------------------------------
# El .apk tiene que salir del sistema de archivos de WSL para que el Explorador
# y adb.exe de Windows lo vean sin rodeos.
# Se descartan los perfiles plantilla de Windows (Default, Public...): existen
# siempre y no son del usuario, asi que un `head -1` a secas elige el equivocado.
WINDOWS_HOME=""
for d in /mnt/c/Users/*/Downloads; do
  case "$(basename "$(dirname "$d")")" in
    Default|"Default User"|Public|"All Users") continue ;;
  esac
  if [ -w "$d" ]; then WINDOWS_HOME="$d"; break; fi
done
if [ -n "$WINDOWS_HOME" ]; then
  DEST="$WINDOWS_HOME/sozu-apk"
  mkdir -p "$DEST"
  cp "${APKS[@]}" "$DEST/" && ok "copiado a $DEST"
  echo "  En Windows: $(printf '%s' "$DEST" | sed 's#/mnt/c#C:#')"
else
  echo "  (no encontre Downloads en Windows; los APKs quedan en $OUT)"
fi

# --- Instalacion opcional ----------------------------------------------------
if [ "$INSTALL" = 1 ]; then
  log "Instalando en el telefono"
  command -v adb >/dev/null || die "adb no esta en el PATH; corre ./tool/android-setup.sh"
  adb devices | tail -n +2 | grep -q "device$" \
    || die "ningun telefono conectado. Ver tool/android-usb.md"
  # El de arm64 es el correcto para cualquier telefono de los ultimos anos.
  TARGET="$(printf '%s\n' "${APKS[@]}" | grep -m1 arm64 || printf '%s\n' "${APKS[0]}")"
  adb install -r "$TARGET" && ok "instalado: $(basename "$TARGET")"
fi
