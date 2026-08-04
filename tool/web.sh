#!/usr/bin/env bash
# Compila la web en RELEASE y la sirve, para juzgar rendimiento de verdad.
#
#   ./tool/web.sh              compila release y sirve en http://localhost:5001
#   ./tool/web.sh --serve      solo sirve lo que ya hay en build/web
#   PORT=5002 ./tool/web.sh    otro puerto
#
# POR QUE EXISTE: `./tool/dev.sh` corre en modo DEBUG, y en Flutter web debug
# compila con DDC sin optimizar. Es varias veces mas lento que release y el coste
# escala con el numero de widgets, asi que una pantalla densa se siente pesada
# aunque en produccion vaya bien. Para juzgar fluidez hay que medir aqui.
#
# Diferencias con dev.sh, las dos a proposito:
#   - `APP_ENV=prod`, asi que NO sale la franja de PREVIEW (igual que apk.sh).
#   - Sin hot reload: cada cambio exige recompilar (~110-190 s).
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"

PORT="${PORT:-5001}"
SERVE_ONLY=0
for a in "$@"; do
  case "$a" in
    --serve) SERVE_ONLY=1 ;;
    *) echo "Opcion desconocida: $a" >&2; exit 1 ;;
  esac
done

if [ "$SERVE_ONLY" -eq 0 ]; then
  if [ ! -f assets/env ]; then
    echo "Falta assets/env. Copia .env.example y llena SUPABASE_URL / SUPABASE_ANON_KEY." >&2
    exit 1
  fi
  BUILD_TIMESTAMP="$(TZ=America/Mexico_City date +%y%m%d.%H%M)"
  echo "==> compilando release (tarda ~110-190 s, es normal: dart2js optimiza el programa completo)"
  flutter build web --release \
    --dart-define=BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
    --dart-define=APP_ENV=prod
fi

[ -f build/web/index.html ] || { echo "No hay build/web. Corre sin --serve." >&2; exit 1; }

echo "==> http://localhost:$PORT   (Ctrl+C para parar)"
if grep -qi microsoft /proc/version 2>/dev/null; then
  WSL_IP="$(ip -4 -o addr show eth0 2>/dev/null | sed -n 's|.*inet \([0-9.]*\)/.*|\1|p' | head -1)"
  echo "==> WSL IP: ${WSL_IP:-desconocida} (para abrirlo desde el celular hace falta"
  echo "    el portproxy de tool/wsl-expose.ps1, igual que con dev.sh)"
fi

# El fallback a index.html es OBLIGATORIO: la app usa `usePathUrlStrategy()`, o sea
# URLs sin `#`. Sin el, recargar en /inicio da 404 y parece un bug de la app.
# `python3 -m http.server` NO lo hace, de ahi el handler.
exec python3 - "$PORT" <<'PY'
import functools, http.server, os, socketserver, sys

PUERTO = int(sys.argv[1])
RAIZ = os.path.join(os.getcwd(), 'build', 'web')


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        ruta = self.translate_path(self.path)
        # Solo las rutas de navegacion caen a index.html. Un asset que falta debe
        # seguir dando 404: si tambien devolviera index.html, un nombre mal
        # escrito se veria como una pantalla en blanco sin error.
        if not os.path.exists(ruta) and '.' not in os.path.basename(ruta):
            self.path = '/index.html'
        return super().send_head()

    def end_headers(self):
        # Sin cache: si no, se prueba el build anterior sin darse cuenta.
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass  # el log por peticion tapa la salida util


class Servidor(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


handler = functools.partial(SpaHandler, directory=RAIZ)
with Servidor(('0.0.0.0', PUERTO), handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print()
PY
