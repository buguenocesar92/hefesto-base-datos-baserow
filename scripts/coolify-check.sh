#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio — Kit Baserow
# coolify-check.sh — test de aceptación para despliegue en Coolify (rama coolify)
#
# QUÉ VERIFICA
#   El contrato común de apps desplegables en Coolify (rama coolify), puntos 1
# y 2, aplicado sobre compose.yaml:
#
#   1. Los servicios SIN `profiles` no pueden tener nada que salte Traefik ni
#      dé poder sobre el host: `ports:`, `container_name`, `privileged`,
#      `cap_add`, `devices`, `network_mode: host`, `pid`/`ipc: host`,
#      `security_opt: unconfined`, binds fuera del repo, ni `docker.sock`.
#
#   2. No se fuerzan nombres fijos a nivel raíz ni en volúmenes ni en redes:
#      Coolify asigna el nombre del proyecto; el compose no debe pisarlo.
#
# CÓMO LO VERIFICA
#   - Punto 2: grep directo sobre la fuente compose.yaml (docker compose añade
#     `name:` al render desde el nombre del proyecto, así que el render no sirve
#     para distinguir un `name:` escrito por el autor del inferido).
#   - Punto 1: genera un `.env` temporal con valores ficticios no secretos
#     (`x123…`) por cada `${VAR}` del compose (URL/host → `https://ejemplo.invalid`,
#     direcciones Caddy → `:80`, puertos → 80, IP → 127.0.0.1, resto → x123_dummy),
#     renderiza con `docker compose config --format json` y valida con `jq`.
#
# USO
#   bash scripts/coolify-check.sh
#
# SALIDA
#   exit 0 si todo OK; exit != 0 con "servicio: motivo" si hay incumplimientos.
# =============================================================================

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Compose del contrato de este repo. Hoy hay uno solo.
COMPOSE="$RAIZ/compose.yaml"
BASE_DIR="$RAIZ"

log()  { printf '[%s] %s\n' "$(date -u '+%H:%M:%S')" "$*"; }
error(){ printf '[ERROR] %s\n' "$*" >&2; }
die()  { error "$*"; exit 1; }

command -v docker >/dev/null 2>&1 || die "No se encontró 'docker' en el PATH."
command -v jq     >/dev/null 2>&1 || die "No se encontró 'jq' en el PATH."
docker compose version >/dev/null 2>&1 || die "No se pudo ejecutar 'docker compose'."

[ -f "$COMPOSE" ] || die "No existe $COMPOSE."

FALLOS=0

# --- Punto 2: nada de `name:` fijo en la fuente ------------------------------
# Busca líneas que empiecen (con indentación opcional) por `name:` — la forma
# en que aparece un nombre fijo a nivel raíz, dentro de un volumen o dentro de
# una red. Docker compose luego le añade su propio `name:` al render, pero ese
# es derivado del proyecto, no del compose, y por eso no lo chequeamos aquí.
NOMBRES_FIJOS="$(grep -nE '^[[:space:]]*name:[[:space:]]' "$COMPOSE" || true)"
if [ -n "$NOMBRES_FIJOS" ]; then
  error "Nombre fijo detectado (Coolify asigna el nombre del proyecto):"
  while IFS= read -r linea; do
    error "  $linea"
  done <<< "$NOMBRES_FIJOS"
  FALLOS=$((FALLOS+1))
fi

# --- 1. Generar .env temporal con valores ficticios --------------------------
TMP_ENV="$(mktemp "${TMPDIR:-/tmp}/coolify-check-XXXXXX.env")"
trap 'rm -f "$TMP_ENV"' EXIT

# Extraer todos los nombres de variable ${VAR} y ${VAR:-default} del compose.
mapfile -t VARS < <(
  grep -oE '\$\{[A-Z_][A-Z0-9_]*(:[-?]?[^}]*)?\}' "$COMPOSE" \
    | sed -E 's/^\$\{([A-Z_][A-Z0-9_]*).*/\1/' \
    | sort -u
)

# Valores ficticios: URL/host → ejemplo.invalid; ADDRESSES (Caddy) → :80;
# puertos → 80; IP → 127.0.0.1; el resto → x123_dummy_<NOMBRE> (no es secreto).
for v in "${VARS[@]}"; do
  case "$v" in
    *URL*)
      printf '%s=https://ejemplo.invalid\n' "$v" >> "$TMP_ENV"
      ;;
    *ADDRESSES*)
      printf '%s=:80\n' "$v" >> "$TMP_ENV"
      ;;
    *PORT*)
      printf '%s=80\n' "$v" >> "$TMP_ENV"
      ;;
    *IP*)
      printf '%s=127.0.0.1\n' "$v" >> "$TMP_ENV"
      ;;
    *)
      printf '%s=x123_dummy_%s\n' "$v" "$v" >> "$TMP_ENV"
      ;;
  esac
done

log "Generado $TMP_ENV con ${#VARS[@]} variables."

# --- 2. Renderizar el compose ------------------------------------------------
log "Renderizando $COMPOSE con docker compose config..."
RENDER="$(docker compose \
  --project-directory "$BASE_DIR" \
  -f "$COMPOSE" \
  --env-file "$TMP_ENV" \
  config --format json)" \
  || die "docker compose config falló."

log "Render correcto. Validando contrato..."

# --- 3. Validar punto 1 sobre servicios SIN profiles -------------------------
mapfile -t SERVICIOS < <(echo "$RENDER" \
  | jq -r '.services | to_entries[]
      | select((.value.profiles == null) or ((.value.profiles // []) | length == 0))
      | .key')

for svc in "${SERVICIOS[@]}"; do
  D="$(echo "$RENDER" | jq -c --arg s "$svc" '.services[$s]')"

  # ports: presencia de cualquier elemento.
  if [ "$(echo "$D" | jq -r '.ports // [] | length')" -gt 0 ]; then
    error "$svc: publica puertos ($(echo "$D" | jq -c '.ports'))"
    FALLOS=$((FALLOS+1))
  fi

  # container_name: si está definido.
  if [ "$(echo "$D" | jq -r '.container_name // "null"')" != "null" ]; then
    error "$svc: tiene container_name fijo ($(echo "$D" | jq -r '.container_name'))"
    FALLOS=$((FALLOS+1))
  fi

  # privileged.
  if [ "$(echo "$D" | jq -r '.privileged // false')" = "true" ]; then
    error "$svc: tiene privileged=true"
    FALLOS=$((FALLOS+1))
  fi

  # cap_add / devices.
  if [ "$(echo "$D" | jq -r '.cap_add // [] | length')" -gt 0 ]; then
    error "$svc: tiene cap_add ($(echo "$D" | jq -c '.cap_add'))"
    FALLOS=$((FALLOS+1))
  fi
  if [ "$(echo "$D" | jq -r '.devices // [] | length')" -gt 0 ]; then
    error "$svc: tiene devices ($(echo "$D" | jq -c '.devices'))"
    FALLOS=$((FALLOS+1))
  fi

  # network_mode / pid / ipc.
  for k in network_mode pid ipc; do
    val="$(echo "$D" | jq -r --arg k "$k" '.[$k] // "null"')"
    if [ "$val" = "host" ]; then
      error "$svc: tiene $k=host"
      FALLOS=$((FALLOS+1))
    fi
  done

  # security_opt con unconfined.
  if echo "$D" | jq -e '.security_opt // [] | any(. == "unconfined")' >/dev/null; then
    error "$svc: tiene security_opt con unconfined"
    FALLOS=$((FALLOS+1))
  fi

  # docker.sock en el source de cualquier volumen (bind o named).
  if echo "$D" | jq -e '
      [.volumes // [] | .[] | .source // empty | strings]
      | any(. | test("/var/run/docker\\.sock"))
    ' >/dev/null; then
    error "$svc: monta docker.sock"
    FALLOS=$((FALLOS+1))
  fi

  # Bind mounts fuera del repo: solo se acepta source dentro de BASE_DIR.
  if echo "$D" | jq -e --arg base "$BASE_DIR" '
      [.volumes // [] | .[] | select((.type // "volume") == "bind") | .source // empty | strings]
      | any(. | (startswith($base + "/") | not) and (. != $base))
    ' >/dev/null; then
    error "$svc: bind mount fuera del repo ($(echo "$D" | jq -c '[.volumes[]|select((.type//"volume")=="bind")|.source]'))"
    FALLOS=$((FALLOS+1))
  fi
done

if [ "$FALLOS" -gt 0 ]; then
  die "Contrato Coolify: $FALLOS incumplimiento(s)."
fi

log "Contrato Coolify: OK (${#SERVICIOS[@]} servicios sin profiles validados)."