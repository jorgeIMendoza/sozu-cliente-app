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
