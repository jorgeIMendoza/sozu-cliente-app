#!/usr/bin/env bash
# Sube la version de la app UNA sola vez, en el repo, y sincroniza el footer web.
#
# Fuente unica de verdad = `pubspec.yaml` -> `version: X.Y.Z+build`. De ahi
# Flutter saca el versionName visible en Play Store, App Store y (via
# appVersionBase) el footer del login web, asi los tres SIEMPRE coinciden.
# El numero de build interno (versionCode / CFBundleVersion) lo pone el CI por
# separado desde cada tienda; no se toca aqui.
#
# Reglas del versionName (pedidas por Jorge) - "vigesimal":
#   patch y minor van de 0 a 20 y luego acarrean; major arranca en 1.
#   1.0.0 -> 1.0.1 -> ... -> 1.0.20 -> 1.1.0 -> ... -> 1.1.20 -> 1.2.0 -> ...
#   (1.20.20 -> 2.0.0, desborde lejano)
#
# Uso:
#   tool/bump_version.sh            # sube al siguiente vigesimal (+1 build)
#   tool/bump_version.sh --set 1.3.0   # fija una version explicita (+1 build)
set -euo pipefail

cd "$(dirname "$0")/.."
PUBSPEC="pubspec.yaml"
VERSIONDART="lib/core/version.dart"

cur="$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//')"
name="${cur%%+*}"
build="${cur#*+}"
[ "$build" = "$cur" ] && build=0

MAJOR="${name%%.*}"
rest="${name#*.}"
MINOR="${rest%%.*}"
PATCH="${rest#*.}"

if [ "${1:-}" = "--set" ]; then
  new_name="${2:?uso: tool/bump_version.sh --set X.Y.Z}"
  case "$new_name" in
    *.*.*) : ;;
    *) echo "formato invalido: usa X.Y.Z" >&2; exit 1 ;;
  esac
else
  PATCH=$(( PATCH + 1 ))
  if [ "$PATCH" -gt 20 ]; then PATCH=0; MINOR=$(( MINOR + 1 )); fi
  if [ "$MINOR" -gt 20 ]; then MINOR=0; MAJOR=$(( MAJOR + 1 )); fi
  new_name="${MAJOR}.${MINOR}.${PATCH}"
fi
new_build=$(( build + 1 ))

# pubspec: fuente de verdad del versionName y del build de fallback.
sed -i -E "s/^version:.*/version: ${new_name}+${new_build}/" "$PUBSPEC"
# footer web: mismo X.Y.Z (el timestamp se conserva aparte).
sed -i -E "s/const String appVersionBase = '[^']*';/const String appVersionBase = '${new_name}';/" "$VERSIONDART"

echo "version: ${cur} -> ${new_name}+${new_build}"
echo "  pubspec.yaml y lib/core/version.dart (appVersionBase) sincronizados."
