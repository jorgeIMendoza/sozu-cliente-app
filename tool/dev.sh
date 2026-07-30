#!/usr/bin/env bash
# Levanta el portal del cliente en modo desarrollo (web).
#
#   ./tool/dev.sh              -> web en http://localhost:5000
#   PORT=5100 ./tool/dev.sh    -> otro puerto
#   ./tool/dev.sh <device-id>  -> otra plataforma (ver: flutter devices)
#
# En la terminal, mientras corre:  r = hot reload | R = hot restart | q = salir
set -euo pipefail

cd "$(dirname "$0")/.."

# El SDK vive fuera del PATH por defecto en WSL.
export PATH="$HOME/flutter/bin:$PATH"

if ! command -v flutter >/dev/null; then
  echo "flutter no esta en el PATH. Instalalo en ~/flutter (ver README)." >&2
  exit 1
fi

if [ ! -f assets/env ]; then
  echo "Falta assets/env. Copia .env.example y llena SUPABASE_URL / SUPABASE_ANON_KEY." >&2
  exit 1
fi

DEVICE="${1:-web-server}"
PORT="${PORT:-5000}"

# --- Puente de adb para dispositivos fisicos ---------------------------------
# WSL2 no pasa el USB: el servidor de adb corre en Windows y aqui solo va el
# cliente, apuntado por TCP. La IP del host se resuelve cada vez porque cambia
# en cada reinicio de WSL. Ver tool/android-usb.md.
if [ "$DEVICE" != "web-server" ] && [ "$DEVICE" != "chrome" ]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
  [ -x "$HOME/jdk21/bin/java" ] && [ -z "${JAVA_HOME:-}" ] && export JAVA_HOME="$HOME/jdk21"

  if [ -z "${ADB_SERVER_SOCKET:-}" ]; then
    WIN_HOST="$(ip route show default 2>/dev/null | awk '{print $3}')"
    if [ -n "$WIN_HOST" ] && timeout 3 bash -c "cat < /dev/null > /dev/tcp/$WIN_HOST/5037" 2>/dev/null; then
      export ADB_SERVER_SOCKET="tcp:$WIN_HOST:5037"
      echo "==> puente de adb: $ADB_SERVER_SOCKET"
    else
      echo "!!  El servidor de adb de Windows no responde en $WIN_HOST:5037" >&2
      echo "    En PowerShell, desde donde tengas platform-tools:" >&2
      echo "      .\\adb.exe -a -P 5037 nodaemon server" >&2
      echo "    Deja esa ventana abierta. Detalle en tool/android-usb.md" >&2
      exit 1
    fi
  fi
fi
BUILD_TIMESTAMP="$(TZ=America/Mexico_City date +%y%m%d.%H%M)"

flutter pub get

COMMON_ARGS=(
  --dart-define=BUILD_TIMESTAMP="$BUILD_TIMESTAMP"
  --dart-define=APP_ENV=dev
)

if [ "$DEVICE" = "web-server" ] || [ "$DEVICE" = "chrome" ]; then
  # 0.0.0.0 para poder abrirlo desde el navegador de Windows y desde el
  # celular en la misma red (util para probar responsive en fisico).
  echo "==> http://localhost:$PORT"

  # WSL2 esta detras de NAT: escuchar en 0.0.0.0 NO alcanza para que el celular
  # llegue, hace falta un portproxy en Windows. Se imprime el comando exacto en
  # vez de explicarlo, porque la IP de WSL cambia en cada reinicio.
  if grep -qi microsoft /proc/version 2>/dev/null; then
    WSL_IP="$(ip -4 -o addr show eth0 2>/dev/null | sed -n 's|.*inet \([0-9.]*\)/.*|\1|p' | head -1)"
    PS1_WIN="$(command -v wslpath >/dev/null && wslpath -w "$(pwd)/tool/wsl-expose.ps1" || echo 'tool\wsl-expose.ps1')"
    echo "==> WSL IP: ${WSL_IP:-desconocida}"
    echo "    Para abrir desde el celular, en PowerShell de Windows COMO ADMIN:"
    echo "      powershell -ExecutionPolicy Bypass -File \"$PS1_WIN\" -Port $PORT"
    echo "    (una vez por reinicio de WSL; imprime la URL para el celular)"
  fi

  exec flutter run -d "$DEVICE" \
    --web-hostname 0.0.0.0 \
    --web-port "$PORT" \
    "${COMMON_ARGS[@]}"
fi

exec flutter run -d "$DEVICE" "${COMMON_ARGS[@]}"
