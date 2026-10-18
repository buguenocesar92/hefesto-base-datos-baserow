# 05 — Respaldos y restauración

Estado del kit: **kit preparado**. Los scripts se escribieron y se validó su
sintaxis (`bash -n`), pero **no se ejecutaron contra una instancia real**,
porque en el entorno donde se preparó el kit no hay Docker.

---

## 1. Qué es persistente

Estos son los volúmenes del kit. Los nombres llevan prefijo del proyecto
(`baserow_` por defecto) cuando los crea Docker.

| Volumen | Ruta en el contenedor | Contenido | ¿Respaldar? |
|---|---|---|---|
| `pgdata` | `/var/lib/postgresql/data` | **Base de datos interna de Baserow** | **Sí** |
| `media` | `/baserow/media` | **Archivos adjuntos subidos** | **Sí** |
| `caddy_data` | `/data` | Certificados TLS emitidos | Opcional |
| `caddy_config` | `/config` | Configuración de Caddy | Opcional |
| `mox_data` | `/baserow/data/mox` | Buzón del receptor de correo | Solo con perfil `inbound-email` |

**Qué hay dentro de `pgdata`:** las definiciones de tablas y campos, las filas de
los datos que viven en Baserow, los usuarios, los permisos, los espacios de
trabajo, los tokens de API, los webhooks, los comentarios y el historial de
filas. Es el corazón de la instalación.

---

## 2. Qué NO se respalda, y por qué

| Elemento | Por qué no |
|---|---|
| **Redis** | Es caché y cola de tareas. Se reconstruye solo al arrancar |
| **Bases de datos externas** | No son de Baserow. Son del cliente. Ver sección 3 |
| **Certificados TLS** | Se reemiten. Guardarlos evita el trámite, pero no son datos |
| **`.env` y los secretos** | **Nunca** van dentro del respaldo. Ver sección 8 |
| **Las imágenes Docker** | Se vuelven a descargar |

---

## 3. El alcance, que es donde más se falla

> **Este kit respalda el almacén interno de Baserow. No respalda las bases de
> datos a las que el cliente conecta.**

Si el cliente conecta su PostgreSQL de producción a Baserow para darle una
interfaz, esos datos **no están en este respaldo**. Son del cliente y su
respaldo es responsabilidad de él, o de otro kit de Hefesto.

Decirle al cliente que «tiene respaldos» sin aclarar esto es un error grave:
va a descubrir que su base real no estaba cubierta cuando la necesite.

---

## 4. Cómo obtener una copia coherente

El propio comando de respaldo de Baserow advierte, en su documentación:

> "WARNING: This command is only safe to run on a database which is not actively
> being updated and not connected to a running versión of Baserow for the
> duration of the back-up."

> "Additionally when tables are being backed up this command will hold an
> ACCESS SHARE lock over them, meaning users will see errors if they attempt to
> delete tables or edit fields."

Fuente: `backend/src/baserow/core/management/commands/backup_baserow.py`,
etiqueta 2.4.1
(<https://github.com/baserow/baserow/blob/2.4.1/backend/src/baserow/core/management/commands/backup_baserow.py>)

**Traducción práctica:** un respaldo con Baserow corriendo puede quedar
inconsistente. Por eso `backup-baserow.sh`:

1. Detiene `backend`, `web-frontend`, `celery`, `celery-export-worker` y
   `celery-beat-worker`.
2. Deja el servicio `db` arriba, porque es a quien hay que conectarse para volcar.
3. Vuelca.
4. Vuelve a levantar.

**Hay una ventana de inactividad.** Es el precio de un respaldo coherente, y es
correcto: un respaldo que a veces está mal es peor que no tener respaldo.

---

## 5. Los scripts

### 5.1 Respaldo

```bash
chmod +x scripts/backup-baserow.sh
./scripts/backup-baserow.sh -d ./backups
./scripts/backup-baserow.sh -d ./backups --etiquenda antes-migracion
```

Produce una carpeta con:

```
backups/baserow-20260117T143000Z/
├── baserow-db.sql.gz     # volcado de la base interna
├── media.tar.gz          # archivos adjuntos
├── MANIFIESTO.txt        # versión, fecha, alcance
├── SHA256SUMS            # sumas de verificación
└── RESPUALDO_COMPLETO    # sello: solo existe si todo terminó bien
```

### 5.2 Garantías que da el script

- `set -euo pipefail`: se detiene al primer error.
- Trabaja en una carpeta temporal. El destino final solo se escribe al final.
- Verifica `gzip -t` de cada artefacto.
- Calcula **SHA-256** de cada archivo.
- **Vuelve a verificar las sumas después de copiar** al destino.
- El sello `RESPUALDO_COMPLETO` se escribe **solo al terminar bien**. Un respaldo
  incompleto nunca queda marcado como bueno.
- Si algo falla, no se borra nada del cliente: solo se limpia la carpeta
  temporal.
- Si se interrumpe, avisa de que los servicios quedaron detenidos.

### 5.3 Restauración

```bash
chmod +x scripts/restore-baserow.sh
./scripts/restore-baserow.sh ./backups/baserow-20260117T143000Z
```

El script, en orden:

1. Verifica que exista el sello `RESPUALDO_COMPLETO`. Si falta, **no restaura**.
2. Verifica los **SHA-256**. Si no cuadran, **no restaura**.
3. Valida `gzip` de cada artefacto.
4. **Revisa la lista de rutas dentro del archivo antes de extraer**, y aborta si
   encuentra rutas absolutas (`/etc/...`) o saltos hacia arriba (`../`). Esto es
   la defensa contra *path traversal*.
5. Detiene toda la instancia.
6. Comprueba si la base destino ya tiene tablas.
7. Restaura la base.
8. Restaura los adjuntos y corrige permisos a `9999:9999`.
9. **Deja la instancia detenida.**

### 5.4 Qué NO hace nunca

| Garantía | Detalle |
|---|---|
| **Nunca hace `DROP`** | El volcado se genera sin `--clean`, así que el archivo no lleva sentencias de borrado |
| **Nunca sobrescribe a la fuerza** | Si la base destino tiene tablas, se niega salvo `--force` explícito |
| **Nunca borra datos del cliente** | Los únicos `rm` del script son sobre la carpeta temporal y, con `--force`, sobre una carpeta de respaldo del mismo nombre |
| **Nunca restaura un respaldo a medias** | El sello es obligatorio |

Sobre `--force`: **no borra la base**. Inserta sobre lo que haya y
probablemente falle de forma limpia. La forma correcta de reemplazar es
apuntar `.env` a una base nueva y vacía.

### 5.5 Ante un fallo parcial

Si la restauración se interrumpe, la base puede quedar con tablas a medias.

- **No borres nada a mano todavía.** Guarda el respaldo original: es lo único
  que te queda.
- Levanta solo la base para inspeccionar: `docker compose up -d db`
- Vuelve a ejecutar el script de restauración desde el mismo respaldo. Como el
  destino ya tiene contenido, te va a pedir `--force`; o mejor, apunta `.env`
  a una base vacía nueva y restaura ahí.

---

## 6. Verificar un respaldo que no hiciste tú

```bash
cd backups/carpeta-del-respaldo

# 1. ¿Tiene el sello de completitud?
cat RESPUALDO_COMPLETO

# 2. ¿Las sumas cuadran?
sha256sum -c SHA256SUMS

# 3. ¿Qué versión es?
cat MANIFIESTO.txt
```

Si el sello no está, **no confíes en ese respaldo**, aunque los archivos parezcan
bien.

---

## 7. Automatizar

```bash
# Respaldo diario a las 03:15, conservando 14 copias
15 3 * * * cd /opt/baserow && ./scripts/backup-baserow.sh -d /var/backups/baserow >> /var/log/baserow-backup.log 2>&1
```

Recomendaciones:

- **Copia el respaldo fuera del servidor.** Un respaldo en el mismo disco que
  se quemó, no es un respaldo.
- Prueba la restauración **una vez** en un entorno descartable. Un respaldo que
  nunca se restauró es una hipótesis.
- Registra los fallos. Si el script escribe en el log y termina sin el sello, hay
  que enterarse.

---

## 8. Los secretos que hay que conservar aparte

El respaldo **no** incluye `.env`. Si restauras en otra máquina necesitas:

| Secreto | Para qué |
|---|---|
| `SECRET_KEY` | Sin ella, quedan invalidados los tokens y sesiones existentes |
| `BASEROW_JWT_SIGNING_KEY` | Igual, para la firma JWT |
| `DATABASE_PASSWORD` | Necesaria para que el backend entre a PostgreSQL |
| `REDIS_PASSWORD` | Necesaria para que el backend entre a Redis |
| Contraseña del SMTP | Para enviar correos |

**Guárdalos en el gestor de secretos que use el cliente**, no en un archivo junto
al respaldo. Si el respaldo se filtra, el `.env` no debe filtrarse con él.

---

## 9. Comandos oficiales de Baserow (referencia)

El proyecto pública comandos propios de respaldo y restauración. Se dejan
documentados por completitud; **el kit usa `pg_dump`, que es más simple de
auditar y no depende de la invocación interna de la imagen**.

Documentados por Baserow:
- `backup_baserow -f ARCHIVO.tar.gz` — respaldo por lotes con `pg_dump`
- `restore_baserow -f ARCHIVO.tar.gz` — restauración. Su propia documentación
  dice: *"Only restoring into existing blank databases is supported, to restore
  over an existing database you must DROP and CREATE it yourself first."*
- `export_workspace_applications` / `import_workspace_applications` — solo
  transportan las aplicaciones y sus archivos; **no** sirven para mover una
  instancia completa.

Fuente: <https://baserow.io/docs/installation/install-with-docker#backing-up-and-restoring-baserow>