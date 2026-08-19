#!/usr/bin/env bash
# Lo mismo que hace el IDE (Cursor / VS Code), desde consola.
#
#   ./tool/check.sh              -> formatea lo MODIFICADO + analiza + tests
#   ./tool/check.sh --all        -> formatea TODO lib/ y test/ (ojo: churn)
#   ./tool/check.sh --fix        -> aplica los arreglos automaticos de lints
#   ./tool/check.sh --no-tests   -> salta los tests (mas rapido)
#
# Que corresponde a que:
#   dart format    = "Format Document" del IDE (Shift+Alt+F)
#   flutter analyze= el panel de Problems. Misma fuente: analysis_options.yaml
#   dart fix       = los "Quick Fix" (lightbulb) aplicados en lote
#
# El IDE usa el Dart Analysis Server, que lee el MISMO analysis_options.yaml.
# Por eso `flutter analyze` y el panel de Problems dan siempre el mismo resultado.
set -uo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"

FORMAT_ALL=0
RUN_FIX=0
RUN_TESTS=1
for arg in "$@"; do
  case "$arg" in
    --all)      FORMAT_ALL=1 ;;
    --fix)      RUN_FIX=1 ;;
    --no-tests) RUN_TESTS=0 ;;
    -h|--help)  sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "opcion desconocida: $arg" >&2; exit 2 ;;
  esac
done

FAILED=0
step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$1"; }
fail() { printf '\033[1;31mFAIL %s\033[0m\n' "$1"; FAILED=1; }
ok()   { printf '\033[1;32mOK   %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. Formato
# ---------------------------------------------------------------------------
# Por defecto SOLO los archivos modificados respecto a main. El repo no esta
# formateado con el formatter actual (Dart 3.7 cambio a "tall style"), asi que
# `dart format .` reescribe medio archivo ajeno y ensucia el diff. Con --all se
# hace a proposito, idealmente en un commit que solo sea formato.
step "Formato"
if [ "$FORMAT_ALL" -eq 1 ]; then
  dart format lib test && ok "formateado todo lib/ y test/" || fail "dart format"
else
  mapfile -t FILES < <(
    { git diff --name-only --diff-filter=ACMR -- '*.dart'
      git diff --name-only --diff-filter=ACMR --cached -- '*.dart'
      git ls-files --others --exclude-standard -- '*.dart'
    } | sort -u
  )
  if [ "${#FILES[@]}" -eq 0 ]; then
    ok "sin archivos .dart modificados"
  else
    printf '  %s\n' "${FILES[@]}"
    dart format "${FILES[@]}" >/dev/null && ok "${#FILES[@]} archivo(s) formateado(s)" || fail "dart format"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Arreglos automaticos (opcional)
# ---------------------------------------------------------------------------
if [ "$RUN_FIX" -eq 1 ]; then
  step "dart fix --apply"
  dart fix --apply && ok "arreglos aplicados" || fail "dart fix"
fi

# ---------------------------------------------------------------------------
# 3. Analizador (== panel de Problems del IDE)
# ---------------------------------------------------------------------------
step "flutter analyze"
# --no-fatal-infos: lo mismo que corre el CI (deploy-web-firebase.yml y
# codemagic.yaml). Los ~800 infos son la deuda conocida de PortalColors
# deprecado; con infos fatales esto salia SIEMPRE rojo y se aprendia a ignorar.
# Errores y warnings siguen siendo fatales. El conteo de infos se imprime para
# que una subida se note.
ANALYZE_OUT="$(mktemp)"
if flutter analyze --no-fatal-infos >"$ANALYZE_OUT" 2>&1; then
  # `^ *info` y no ' info • ': solo las lineas de info van indentadas, las de
  # error y warning arrancan en la columna 0. Un patron con espacio inicial las
  # pierde en silencio.
  INFOS="$(grep -cE '^ *info • ' "$ANALYZE_OUT" || true)"
  if [ "$INFOS" -gt 0 ]; then
    ok "sin errores ni warnings ($INFOS infos: deuda PortalColors)"
  else
    ok "sin issues"
  fi
else
  cat "$ANALYZE_OUT"
  fail "analyze encontro errores o warnings"
fi
rm -f "$ANALYZE_OUT"

# ---------------------------------------------------------------------------
# 4. Tests
# ---------------------------------------------------------------------------
if [ "$RUN_TESTS" -eq 1 ]; then
  step "flutter test"
  if flutter test; then ok "tests en verde"; else fail "tests fallando"; fi
fi

echo
if [ "$FAILED" -eq 0 ]; then
  printf '\033[1;32m═══ TODO OK ═══\033[0m\n'
else
  printf '\033[1;31m═══ HAY FALLAS (ver arriba) ═══\033[0m\n'
fi
exit "$FAILED"
