# 06 — Actualizaciones y reversión

Estado del kit: **kit preparado**.

---

## 1. Antes de actualizar, siempre

```bash
# 1. Respaldo verificado (obligatorio)
./scripts/backup-baserow.sh -d ./backups --etiqueta antes-de-actualizar

# 2. Confirmar que el respaldo quedó completo
cat ./backups/baserow-*-antes-de-actualizar/RESPUALDO_COMPLETO

# 3. Copiar el respaldo FUERA del servidor
scp -r ./backups/baserow-*-antes-de-actualizar usuario@otro-servidor:/respaldos/
```

No hay excepción. Una migración de base de datos sin respaldo es una apuesta.

---

## 2. Actualizar

```bash
cd /opt/baserow

# Editar .env y cambiar la versión
#   BASEROW_VERSION=2.4.1   ->   BASEROW_VERSION=<NUEVA>

docker compose pull
docker compose up -d

# Mirar las migraciones mientras ocurren
docker compose logs -f backend
```

Baserow aplica solo las migraciones pendientes al arrancar. **No hay comando de
migración aparte en este kit**: el propio arranque lo hace, controlado por
`MIGRATE_ON_STARTUP` (por defecto `true`).

Espera a ver en el registro que el servicio está disponible antes de seguir.

---

## 3. Saltar de versión

Baserow permite ir **de cualquier versión a la más reciente** en un solo paso.
Las migraciones intermedias se aplican todas solas.

La propia documentación es explícita: *"No intermediate Baserow versions are
needed. You can jump straight to the latest versión."*

Fuente: <https://baserow.io/docs/installation/install-with-docker#upgrading-from-a-previous-version>

**Aviso:** mientras el backend aplica migraciones, los workers en segundo plano
pueden registrar errores del tipo `column ... does not exist`. **Son
esperados**, cesan cuando terminan las migraciones. No entrar en pánico a la
primera.

---

## 4. La excepción: PostgreSQL 11 a 15

Este es el único caso documentado que **no** se puede resolver con un simple
cambio de etiqueta.

| Origen | Destino | Problema |
|---|---|---|
| Imagen anterior a **1.24** | Cualquiera | PostgreSQL 11 |
| Imagen **1.24 o posterior** | Cualquiera | PostgreSQL 15 |

Baserow ya no admite PostgreSQL 11: dejó de recibir actualizaciones de seguridad
en noviembre de 2023.

Si el volumen de datos se creó con una imagen anterior a 1.24, la imagen nueva
**se niega a arrancar** y lo dice. Hay que subir el directorio de datos primero,
con una imagen aparte:

```bash
docker run --name baserow-pgautoupgrade \
  # los mismos argumentos que usabas normalmente
  --restart no \
  baserow/baserow-pgautoupgrade:1.30.1
```

Esa imagen sube el directorio de datos y **termina con código de salida distinto
de cero incluso si todo salió bien**. Es normal.

**Este kit parte de una instalación nueva**, así que no debería aparecer. Pero si
alguien migra desde una instancia vieja que venía de una imagen anterior a 1.24,
este es el paso que falta. Ver `docs/01` y la documentación oficial enlazada
arriba.

---

## 5. Reversión

### 5.1 La regla principal

> **Bajar de versión no es una operación soportada.**

Las migraciones de base de datos de Django son, en su mayoría, **irreversibles**.
Bajar la versión del software sin revertir la base de datos deja el sistema en
un estado inconsistente.

**Por eso el camino seguro de vuelta atrás no es "bajar la versión": es
restaurar el respaldo.**

### 5.2 Procedimiento correcto

```bash
# 1. Instancia actual con la versión nueva pero con problemas:
docker compose down

# 2. Restaurar el respaldo tomado ANTES de actualizar
./scripts/restore-baserow.sh ./backups/baserow-<fecha>-antes-de-actualizar
```

El script deja la instancia detenida para que revises antes de publicarla otra
vez. Ver `docs/05`.

### 5.3 Lo que sí es reversible

| Cambio | ¿Reversible? |
|---|---|
| Versión del software sin migraciones | Sí, cambiando `BASEROW_VERSION` |
| Migraciones de base de datos | **No** |
| Datos de la aplicación | Sí, desde respaldo |
| `BASEROW_OSS_ONLY`, niveles de log, límites | Sí, son ajustes |
| Secretos rotados | Depende: rotar `SECRET_KEY` invalida sesiones |

---

## 6. Calendario recomendado

| Frecuencia | Acción |
|---|---|
| Mensual | Revisar si hay versión nueva |
| Mensual | Aplicar actualizaciones de **seguridad** del sistema operativo |
| Trimestral | Actualizar Baserow, tras verificar las notas de la versión |
| Trimestral | **Probar una restauración** de verdad, en entorno descartable |

No apliques la última versión el mismo día que se pública. Espera unos días: si
hay un problema, se habrá publicado y ya estará corregido.

**Pendiente de verificar:** no se pudo revisar el contenido de las notas de
lanzamiento de 2.4.1 para documentar cambios concretos de esa versión. Antes de
actualizar desde una versión anterior, leer las notas oficiales:
<https://baserow.io/blog/>