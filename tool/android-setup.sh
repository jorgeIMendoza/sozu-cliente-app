#!/usr/bin/env bash
# Termina de configurar el SDK de Android en WSL. Idempotente: se puede repetir.
#
#   ./tool/android-setup.sh
#
# Requiere Java 17+ ya instalado. Si falta:
#   sudo pacman -S --noconfirm jdk21-openjdk
#
# Instala platform-tools (adb), platforms;android-36 y build-tools;36.0.0, acepta
# licencias y apunta Flutter al SDK. compileSdk 36 sale de
# ~/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt
set -uo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"

SDK="$HOME/android-sdk"
COMPILE_SDK=36
BUILD_TOOLS="36.0.0"

log() { printf '\033[1;36m▶ %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# --- Java --------------------------------------------------------------------
# El JDK del sistema gana sobre el portable: es el que Gradle encuentra solo.
if command -v java >/dev/null 2>&1; then
  export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
elif [ -x "$HOME/jdk21/bin/java" ]; then
  export JAVA_HOME="$HOME/jdk21"
  export PATH="$JAVA_HOME/bin:$PATH"
else
  die "No hay Java. Corre:  sudo pacman -S --noconfirm jdk21-openjdk"
fi
ok "Java: $(java -version 2>&1 | head -1)"

SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
[ -x "$SDKM" ] || die "Falta $SDKM (descarga cmdline-tools primero)"

export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"

# --- Licencias y paquetes ----------------------------------------------------
# Se aceptan ANTES y DESPUES: los paquetes nuevos traen licencias propias que no
# existian en la primera pasada.
log "Aceptando licencias"
yes 2>/dev/null | "$SDKM" --licenses >/dev/null 2>&1
ok "licencias"

log "Instalando platform-tools, platforms;android-$COMPILE_SDK, build-tools;$BUILD_TOOLS"
"$SDKM" --install \
  "platform-tools" \
  "platforms;android-$COMPILE_SDK" \
  "build-tools;$BUILD_TOOLS" 2>&1 | grep -vE "^\[|^$" | tail -5
yes 2>/dev/null | "$SDKM" --licenses >/dev/null 2>&1

[ -x "$SDK/platform-tools/adb" ] || die "adb no quedo instalado"
ok "adb: $("$SDK/platform-tools/adb" version | head -1)"

# --- Enlazar con Flutter -----------------------------------------------------
log "Apuntando Flutter al SDK"
flutter config --android-sdk "$SDK" >/dev/null
flutter config --jdk-dir "$JAVA_HOME" >/dev/null 2>&1 || true
ok "flutter config"

log "flutter doctor"
flutter doctor 2>&1 | grep -E "^\[|Android|Java" | head -8

cat <<'FIN'

Agrega esto a tu ~/.bashrc para que persista entre sesiones:

  export ANDROID_HOME="$HOME/android-sdk"
  export ANDROID_SDK_ROOT="$HOME/android-sdk"
  export PATH="$HOME/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"

Siguientes pasos:
  ./tool/apk.sh              compila el APK y lo copia a Windows
  tool/android-usb.md        conectar el telefono por cable (hot reload)
FIN
