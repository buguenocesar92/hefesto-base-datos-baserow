#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio — Kit Baserow
# backup-baserow.sh — respaldo del almacén interno de Baserow
#
# QUÉ RESPALDA ESTE SCRIPT
#   1. La base de datos interna de Baserow (PostgreSQL del servicio `db`).
#      Ahí están las definiciones de tablas y campos, usuarios, permisos,
#      espacios de trabajo, tokens de API, webhooks e historial.
#   2. El volumen `media`: archivos que los usuarios subieron a la instancia.
#
# QUÉ NO RESPALDA ESTE SCRIPT (y por qué)
#   - Las bases de datos a las que el CLIENTE conecta. No son de Baserow:
#     siguen siendo del cliente y su respaldo es responsabilidad de él.
#     Ver docs/05.
#   - Redis. Es caché y colas. Se reconstruye solo.
#   - Certificados de Caddy. Se reemiten si hace falta.
#
# USO
#   ./scripts/backup-baserow.sh [-d DIRECTORIO] [--etiqueta TEXTO] [--force]
#
# El respaldo se marca como completo SOLO al final y solo si todas las etapas
# terminaron bien. Un respaldo incompleto se elimina.
# =============================================================================

set -euo pipefail

# --- Configuración por defecto -------------------------------------------------
DESTINO="./backups"
ETIQUETA=""
FUERZA=0

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

log()  { printf '[%s] %s\n' "$(date -u '+%H:%M:%S')" "$*"; }
error(){ printf '[ERROR] %s\n' "$*" >&2; }
die()  { error "$*"; exit 1; }

# --- Verificaciones previas ----------------------------------------------------

command -v docker >/dev/null 2>&1 || die "No se encontró 'docker' en el PATH."
command -v sha256sum >/dev/null 2>&1 || die "No se encontró 'sha256sum'."
docker compose version >/dev/null 2>&1 || die "No se pudo ejecutar 'docker compose'."

[ -f ".env" ] || die "No existe .env. Copia .env.example y complétalo (ver docs/01)."
# Permisos correctos: .env guarda los secretos.
permisos_env="$(stat -c '%a' .env 2>/dev/null || echo '')"
case "$permisos_env" in
  600|400) : ;;
  "") log "AVISO: no se pudo leer el permiso de .env." ;;
  *) error "AVISO: .env tiene permisos $permisos_env. Debería ser 600 (chmod 600 .env)." ;;
esac

# --- Lectura de argumentos -----------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--destino) DESTINO="${2:?falta el valor de $1}"; shift 2 ;;
    --etiqueta)    ETIQUETA="${2:?falta el valor de $1}"; shift 2 ;;
    --force|-f)    FUERZA=1; shift ;;
    -h|--help)     sed -n '2,25p' "$0"; exit 0 ;;
    *) die "Argumento desconocido: $1" ;;
  esac
done

# --- Validación de la ruta de destino -----------------------------------------
mkdir -p "$DESTINO"
DESTINO="$(cd "$DESTINO" && pwd)" || die "No se pudo resolver el directorio de destino."

# No permite que '..' escale por sobre el directorio actual.
case "$DESTINO" in
  /) die "El destino no puede ser la raíz del sistema." ;;
esac
if [ -L "$DESTINO" ]; then
  error "AVISO: el destino es un enlace simbólico. Revisa que apunte donde corresponde."
fi

# --- Identificación del respaldo ----------------------------------------------
FECHA="$(date -u '+%Y%m%dT%H%M%SZ')"
NOMBRE="baserow-${FECHA}"
[ -n "$ETIQUETA" ] && NOMBRE="${NOMBRE}-$(echo "$ETIQUETA" | tr -cd 'A-Za-z0-9_-')"

CARPETA="$DESTINO/$NOMBRE"
if [ -e "$CARPETA" ]; then
  if [ "$FUERZA" -eq 1 ]; then
    error "AVISO: $CARPETA ya existe. Se va a sobrescribir (--force)."
    rm -rf -- "$CARPETA"
  else
    die "La carpeta $CARPETA ya existe. Usa --force para sobrescribir."
  fi
fi

# Carpeta de trabajo: si algo falla, no queda un respaldo "completo" en el destino.
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/baserow-respaldo-XXXXXX")"
# La limpieza solo borra la carpeta temporal. NUNCA borra datos del cliente.
limpieza() { rm -rf -- "$TRABAJO"; }
trap limpieza EXIT

# --- Obtención de la configuración (sin imprimir secretos) ---------------------
leer_env() {
  # Lee una clave exacta de .env. No ejecuta el archivo: evita que un .env
  # malicioso inyecte comandos.
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" .env | tail -n 1
}

DB_USER="$(leer_env DATABASE_USER)";  DB_USER="${DB_USER:-baserow}"
DB_NAME="$(leer_env DATABASE_NAME)";  DB_NAME="${DB_NAME:-baserow}"
DB_PASS="$(leer_env DATABASE_PASSWORD)"
[ -n "$DB_PASS" ] || die "DATABASE_PASSWORD no está definido en .env."

# --- Paso 1: detener a quien escribe ------------------------------------------
# El comando backup_baserow de Baserow advierte explícitamente que solo es
# seguro sobre una base que no se está modificando. Por eso se detienen el
# backend, la interfaz y los workers ANTES de volcar. La base de datos (db) queda
# arriba porque es a la que hay que conectarse para volcar.
SERVICIOS="backend web-frontend celery celery-export-worker celery-beat-worker"

log "Deteniendo los servicios que escriben en la base: $SERVICIOS"
for s in $SERVICIOS; do
  if docker compose ps --status running --services 2>/dev/null | grep -qx "$s"; then
    docker compose stop "$s" >/dev/null 2>&1 || die "No se pudo detener el servicio '$s'."
  else
    log "El servicio '$s' ya estaba detenido."
  fi
done

# Si el script se interrumpe aquí, hay que levantar los servicios a mano.
trap 'error "Interrumpido. Los servicios siguen DETENIDOS; levántalos con: docker compose up -d"; limpieza; exit 130' INT TERM

# --- Paso 2: volcar la base de datos interna ----------------------------------
log "Volcando la base interna '$DB_NAME' (usuario '$DB_USER')..."
# PGPASSWORD va por el entorno de `exec`, no en la línea de comandos, para que
# no aparezca en la lista de procesos del contenedor.
# Sin --clean: el volcado NO lleva sentencias DROP dentro. La restauración solo
# acepta una base vacía, así que nunca hace falta borrar nada (ver
# restore-baserow.sh y el punto 8 del contrato del kit).
docker compose exec -T \
  -e PGPASSWORD="$DB_PASS" \
  db pg_dump --no-owner --no-privileges \
  -U "$DB_USER" -d "$DB_NAME" \
  | gzip -9 > "$TRABAJO/baserow-db.sql.gz" \
  || die "Falló el volcado de la base de datos interna."

gzip -t "$TRABAJO/baserow-db.sql.gz" || die "El archivo de base de datos está corrupto."
[ -s "$TRABAJO/baserow-db.sql.gz" ] || die "El volcado salió vacío."

# --- Paso 3: volcar los archivos adjuntos (volumen media) ---------------------
log "Empaquetando los archivos adjuntos (volumen 'media')..."
# Se usa la propia imagen del backend para no descargar nada nuevo.
docker compose run --rm --no-deps --user 0 --entrypoint tar backend \
  -czf - -C /baserow media > "$TRABAJO/media.tar.gz" \
  || die "Falló el empaquetado del volumen 'media'."

gzip -t "$TRABAJO/media.tar.gz" || die "El archivo de adjuntos está corrupto."
# Un volumen media vacío es válido; se registra su tamaño igual.
tam_media="$(stat -c '%s' "$TRABAJO/media.tar.gz")"
log "Volumen 'media': $tam_media bytes comprimidos."

# --- Paso 4: información del respaldo ------------------------------------------
VERSIÓN_BASEROW="$(leer_env BASEROW_VERSION)"; VERSIÓN_BASEROW="${VERSIÓN_BASEROW:-2.4.1}"
cat > "$TRABAJO/MANIFIESTO.txt" <<EOF
# Manifiesto del respaldo — Hefesto Studio, kit Baserow
# Generado: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
nombre=$NOMBRE
etiqueta=${ETIQUETA:-}
baserow_version=$VERSIÓN_BASEROW
base_datos=$DB_NAME
usuario_base=$DB_USER
maquina=$(hostname)
# Este respaldo cubre SOLO el almacén interno de Baserow y sus archivos
# adjuntos. Las bases de datos conectadas por el cliente NO se incluyen.
alcance=almacen_interno_baserow+media
EOF

# --- Paso 5: sumas SHA-256 ----------------------------------------------------
# Se calculan sobre los artefactos y se escriben aparte. Todavía NO es
# un respaldo completo: falta la verificación.
( cd "$TRABAJO" && sha256sum baserow-db.sql.gz media.tar.gz > SHA256SUMS )

# --- Paso 6: promover a completo ----------------------------------------------
# Recién aquí, con todo verificado, el respaldo pasa a existir en el destino.
mkdir -p "$CARPETA"
cp -a "$TRABAJO/." "$CARPETA/"

# Verificación final: los archivos existen y el checksum sigue cuadrando.
( cd "$CARPETA" && sha256sum -c SHA256SUMS >/dev/null ) \
  || die "Falló la verificación de sumas tras copiar. No confíes en $CARPETA."

# Sello de finalización. Su presencia significa "respaldo íntegro y verificado".
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$CARPETA/RESPUALDO_COMPLETO"

# --- Paso 7: volver a levantar los servicios ----------------------------------
log "Levantando los servicios..."
docker compose up -d >/dev/null || die "No se pudieron levantar los servicios."
trap limpieza EXIT

log "Respaldo completo y verificado en: $CARPETA"
log "Contiene: baserow-db.sql.gz, media.tar.gz, MANIFIESTO.txt, SHA256SUMS"
log "Recuerda copiar .env y los secretos aparte: NO están en este respaldo."