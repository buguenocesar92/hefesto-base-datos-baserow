#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio — Kit Baserow
# restore-baserow.sh — restauración del almacén interno de Baserow
#
# QUÉ RESTAURA
#   1. La base de datos interna de Baserow (servicio `db`).
#   2. El volumen `media` con los archivos adjuntos.
#
# REGLAS INNEGOCIABLES (ver también docs/05)
#   - Verifica SHA-256 contra el manifiesto ANTES de extraer nada.
#   - Rechaza rutas peligrosas en el archivo (path traversal, rutas absolutas).
#   - NO hace DROP de ninguna base de datos. Jamás.
#   - Se niega a restaurar sobre un destino con datos, salvo --force explícito.
#   - Al terminar, deja la instancia DETENIDA para que alguien la revise.
#
# USO
#   ./scripts/restore-baserow.sh CARPETA_RESPALDO [--force]
#
#   CARPETA_RESPALDO debe contener: baserow-db.sql.gz, media.tar.gz,
#   SHA256SUMS y el sello RESPUALDO_COMPLETO.
# =============================================================================

set -euo pipefail

FUERZA=0

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

log()  { printf '[%s] %s\n' "$(date -u '+%H:%M:%S')" "$*"; }
error(){ printf '[ERROR] %s\n' "$*" >&2; }
die()  { error "$*"; exit 1; }

# --- Argumentos ----------------------------------------------------------------
ORIGEN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) FUERZA=1; shift ;;
    -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
    -*) die "Argumento desconocido: $1" ;;
    *)  [ -z "$ORIGEN" ] || die "Solo se acepta una carpeta de origen."
        ORIGEN="$1"; shift ;;
  esac
done
[ -n "$ORIGEN" ] || die "Falta la carpeta de respaldo. Ejemplo: $0 ./backups/baserow-20260101T120000Z"

# --- Verificaciones previas ----------------------------------------------------
command -v docker >/dev/null 2>&1 || die "No se encontró 'docker' en el PATH."
command -v sha256sum >/dev/null 2>&1 || die "No se encontró 'sha256sum'."
[ -d "$ORIGEN" ] || die "No existe la carpeta de respaldo: $ORIGEN"
ORIGEN="$(cd "$ORIGEN" && pwd)"
[ -f ".env" ] || die "No existe .env. Sin los secretos no se puede restaurar (ver docs/05)."

# --- Paso 1: el respaldo debe estar declarado completo -------------------------
# El sello lo escribe backup-baserow.sh SOLO cuando todo terminó bien.
if [ ! -f "$ORIGEN/RESPUALDO_COMPLETO" ]; then
  die "Falta el sello 'RESPUALDO_COMPLETO'. Este respaldo no fue marcado como íntegro.
     Un respaldo a medias no se restaura: consérvalo para investigar y saca otro nuevo."
fi
log "Respaldo marcado como completo el: $(cat "$ORIGEN/RESPUALDO_COMPLETO")"

# --- Paso 2: verificación de sumas ---------------------------------------------
[ -f "$ORIGEN/SHA256SUMS" ] || die "Falta SHA256SUMS: no se puede verificar la integridad."
log "Verificando sumas SHA-256..."
( cd "$ORIGEN" && sha256sum -c SHA256SUMS ) \
  || die "Las sumas NO coinciden. El archivo está corrupto o fue modificado.
     NO se restaura nada. Revisa el origen de ese respaldo."
log "Sumas correctas."

for requerido in baserow-db.sql.gz media.tar.gz; do
  [ -f "$ORIGEN/$requerido" ] || die "Falta el artefacto '$requerido' en el respaldo."
  gzip -t "$ORIGEN/$requerido" || die "El archivo '$requerido' está corrupto (gzip -t falló)."
done

# --- Paso 3: validación de rutas dentro del archivo ---------------------------
# Nunca extraer un archivo sobre rutas arbitrarias. Se revisa la lista completa
# ANTES de extraer y se aborta si hay algo sospechoso.
log "Revisando que el archivo no contenga rutas peligrosas..."
entradas="$(tar -tzf "$ORIGEN/media.tar.gz")" || die "No se pudo leer el índice del archivo."

while IFS= read -r entrada; do
  [ -n "$entrada" ] || continue
  case "$entrada" in
    /*)    die "Ruta absoluta detectada en media.tar.gz: '$entrada'. Se aborta." ;;
    ../*)  die "Salto hacia arriba detectado en media.tar.gz: '$entrada'. Se aborta." ;;
    */../*) die "Salto hacia arriba en medio de la ruta: '$entrada'. Se aborta." ;;
  esac
done <<< "$entradas"
log "Rutas verificadas: sin absolutas ni saltos hacia arriba."

# --- Configuración -------------------------------------------------------------
leer_env() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" .env | tail -n 1
}
DB_USER="$(leer_env DATABASE_USER)"; DB_USER="${DB_USER:-baserow}"
DB_NAME="$(leer_env DATABASE_NAME)"; DB_NAME="${DB_NAME:-baserow}"
DB_PASS="$(leer_env DATABASE_PASSWORD)"
[ -n "$DB_PASS" ] || die "DATABASE_PASSWORD no está definido en .env."

# --- Paso 4: detener la instancia ---------------------------------------------
# Nunca se restaura sobre una base que esté en uso. Además, el propio comando
# de restauración de Baserow advierte que solo es seguro sobre una base que no
# se está modificando.
log "Deteniendo toda la instancia..."
docker compose down --remove-orphans >/dev/null 2>&1 || die "No se pudo detener la instancia."

# --- Paso 5: ¿el destino está ocupado? ----------------------------------------
# Este script NUNCA borra la base a propósito. Si ya existe y tiene tablas, se
# detiene y lo explica. La decisión de descartar la base vieja la toma una
# persona, a mano, con un DROP DATABASE explícito.
log "Levantando solo el servicio 'db' para inspeccionar el destino..."
docker compose up -d db >/dev/null || die "No se pudo levantar el servicio 'db'."

log "Comprobando si la base '$DB_NAME' ya tiene contenido..."
# La contraseña viaja por el entorno de `exec`, nunca incrustada en una cadena
# de shell que se evalúe dentro del contenedor.
ocupada="$(docker compose exec -T -e PGPASSWORD="$DB_PASS" db \
  psql -U "$DB_USER" -d "$DB_NAME" -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" \
  2>/dev/null | tr -d '[:space:]' || echo 0)"

case "${ocupada:-0}" in
  ''|*[!0-9]*) ocupada=0 ;;
esac

if [ "$ocupada" -gt 0 ]; then
  if [ "$FUERZA" -eq 1 ]; then
    error "AVISO: la base '$DB_NAME' ya tiene $ocupada tablas y se continúa con --force."
    error "AVISO: esto intentará insertar sobre datos existentes y probablemente falle"
    error "AVISO: de forma limpia. Lo correcto es crear una base vacía y apuntar a ella."
  else
    docker compose down --remove-orphans >/dev/null 2>&1 || true
    die "La base '$DB_NAME' ya tiene $ocupada tablas. No se restaura sobre datos existentes.

     Esto es deliberado: este script nunca borra nada por su cuenta.
     Elige una de estas dos opciones y hazla tú a conciencia:
       a) Apuntar .env a una base NUEVA y vacía (recomendado).
       b) Si de verdad quieres reemplazar la actual, borra tú la base a mano
          desde el contenedor 'db' y vuelve a ejecutar este script."
  fi
fi

# --- Paso 6: restaurar la base de datos ----------------------------------------
log "Restaurando la base interna '$DB_NAME'..."
# psql con ON_ERROR_STOP: si una sentencia falla, el script se detiene.
docker compose exec -T -e PGPASSWORD="$DB_PASS" db \
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 --quiet \
  < <(gzip -dc "$ORIGEN/baserow-db.sql.gz") \
  || die "Falló la restauración de la base de datos. La base puede quedar a medias."

# --- Paso 7: restaurar los archivos adjuntos -----------------------------------
log "Restaurando el volumen 'media'..."
# Se extrae dentro del volumen montado en el contenedor, nunca sobre rutas
# del sistema. El contenido ya fue validado en el paso 3.
docker compose run --rm --no-deps --user 0 --entrypoint sh backend -c \
  "tar -xzf - -C /baserow" < "$ORIGEN/media.tar.gz" \
  || die "Falló la extracción de los archivos adjuntos."

# El volumen queda con raíz; el servicio volume-permissions-fixer lo corrige al
# arrancar. Se vuelve a ejecutar de forma explícita para no depender de eso.
docker compose run --rm --user 0 --entrypoint chown backend 9999:9999 -R /baserow/media \
  || die "No se pudieron corregir los permisos del volumen 'media'."

# --- Paso 8: estado final ------------------------------------------------------
# La instancia queda DETENIDA a propósito. Alguien debe revisar que todo esté
# bien antes de exponerla de nuevo.
docker compose down --remove-orphans >/dev/null 2>&1 || true

cat <<EOF

============================================================================
 RESTAURACIÓN TERMINADA
 Carpeta de origen : $ORIGEN
 Base restaurada   : $DB_NAME
============================================================================

 La instancia quedó DETENIDA a propósito. Revisa antes de publicarla otra vez.

   1. Levanta SOLO la base para inspeccionar:
        docker compose up -d db
        docker compose exec db psql -U $DB_USER -d $DB_NAME -c '\\dt'

   2. Si todo se ve bien, levanta todo:
        docker compose up -d

   3. Entra y revisa usuarios, permisos y archivos adjuntos.

 Si algo salió mal: vuelve a levantar el servicio 'db' y restaura de nuevo
 desde el mismo respaldo. No se perdió nada, porque nunca se borró nada.

Recuerda: los secretos de .env NO estaban en el respaldo. Si restauraste en
otra máquina, necesitas el .env ORIGINAL de esta instancia.
EOF