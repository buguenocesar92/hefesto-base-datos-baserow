# Kit Baserow — Base de datos interna sin límite de filas

**Hefesto Studio** · Instalación autoalojada de Baserow Open Source Edition

---

## Estado del kit: `kit preparado`

> **Este kit no se ha ejecutado.** En el entorno donde se preparó no hay Docker
> ni servidor. Los archivos están escritos y su sintaxis fue validada, pero
> **nada se ha corrido contra una instancia real**.
>
> Antes de entregarlo a un cliente hay que ejecutar la lista de la
> [Parte B de `docs/07-PRUEBAS-DE-ACEPTACION.md`](docs/07-PRUEBAS-DE-ACEPTACION.md).

Lo que **sí** se verificó: versiones, digests, licencias, variables de entorno,
comandos de respaldo y estructura del compose, todo leído de las fuentes
oficiales de Baserow 2.4.1. El detalle está en
[`docs/07`](docs/07-PRUEBAS-DE-ACEPTACION.md).

---

## Qué es este kit

Despliega **Baserow Open Source Edition 2.4.1**, la base de datos visual
autoalojable de código abierto.

Es una **capa de administración**: interfaz, permisos y API por encima de datos.
El argumento comercial es que la versión autoalojada no tiene límites de filas,
almacenamiento ni peticiones de API, cosa que la nube de Baserow sí impone por
plan.

### Lo que este kit NO es

| No es | Por qué importa |
|---|---|
| **Una base de datos** | Es una capa sobre bases que el cliente ya tiene, o su propio almacén interno. **No reemplaza a PostgreSQL ni a MySQL.** |
| **Multi-tenant** | **Una instancia es para un cliente.** No hay aislamiento entre inquilinos |
| **El código de Baserow** | Solo despliega imágenes oficiales ya construidas |
| **Un producto probado** | Está preparado, no validado |

---

## Contenido del paquete

```
hefesto-base-datos-baserow/
├── README.md                    Este archivo
├── VERSION.md                   Versiones exactas, digests y diferencias con upstream
├── LICENCIAS.md                 Licencias por componente y por qué Baserow
├── compose.yaml                 10 servicios, 5 volúmenes
├── .env.example                 Plantilla sin secretos
├── .gitignore
├── config/
│   └── Caddyfile                Copia textual del upstream (MIT Expat)
├── scripts/
│   ├── backup-baserow.sh        Respaldo verificado con SHA-256
│   └── restore-baserow.sh       Restauración con validaciones de seguridad
├── ejemplos/
│   └── registro-de-clientes-postgresql/   DEMOSTRACIÓN, datos ficticios
└── docs/
    ├── 01-INSTALACION-DOCKER.md
    ├── 02-INSTALACION-COOLIFY.md
    ├── 03-VARIABLES-Y-COMO-OBTENERLAS.md
    ├── 04-PRIMERA-CUENTA-Y-USUARIOS.md
    ├── 05-RESPALDOS-Y-RESTAURACION.md
    ├── 06-ACTUALIZACIONES-Y-REVERSION.md
    ├── 07-PRUEBAS-DE-ACEPTACION.md
    ├── 08-SERVICIOS-COMERCIALES.md
    ├── 09-EXPORTACION-O-TRASPASO.md
    └── 10-LICENCIAS-Y-FUENTES.md
```

---

## Stack

| Componente | Versión |
|---|---|
| Baserow | 2.4.1 (`baserow/backend`, `baserow/web-frontend`) |
| PostgreSQL interno | 15 con pgvector (`pgvector/pgvector:pg15`) |
| Redis | 6 |
| Caddy | 2.11.4 |
| Docker Compose | >= 1.19.0 |

---

## Inicio rápido

```bash
# 1. Preparar
cp .env.example .env
chmod 600 .env

# 2. Generar los cuatro secretos, cada uno por separado
openssl rand -base64 32   # SECRET_KEY
openssl rand -base64 32   # BASEROW_JWT_SIGNING_KEY
openssl rand -base64 32   # DATABASE_PASSWORD
openssl rand -base64 32   # REDIS_PASSWORD

# 3. Completar .env y poner la URL real en BASEROW_PUBLIC_URL

# 4. Levantar
docker compose up -d
docker compose ps
```

**Al copiar el kit a un servidor Linux, marca los scripts como ejecutables:**

```bash
chmod +x scripts/backup-baserow.sh scripts/restore-baserow.sh
```

**Antes de abrir el servidor al mundo, crea la primera cuenta.** En una
instancia recién levantada, la primera persona que se registre se queda con el
control. El procedimiento está en
[`docs/04`](docs/04-PRIMERA-CUENTA-Y-USUARIOS.md).

Detalle completo en [`docs/01`](docs/01-INSTALACION-DOCKER.md).

---

## Despliegue en Coolify (MVP Hefesto)

Este kit está adaptado para correr **detrás de Coolify con su Traefik** en la
rama `coolify`. La diferencia operativa es que `caddy` ya **no publica
puertos**: el proxy externo (Traefik) termina TLS y enruta por dominio al
puerto interno `:80` del contenedor `caddy`. El detalle del contrato y de la
adaptación está en `docs/02-INSTALACION-COOLIFY.md` y se valida con:

```bash
bash scripts/coolify-check.sh
```

Variables que aplican en Coolify (las obligatorias siguen abortando si faltan
gracias a `${VAR:?}`; las que el contrato del kit no exige son opcionales):

| Variable | Obligatoria | Cómo obtenerla / valor por defecto |
|---|---|---|
| `SECRET_KEY` | Sí | `openssl rand -base64 32` |
| `DATABASE_PASSWORD` | Sí | `openssl rand -base64 32` |
| `REDIS_PASSWORD` | Sí | `openssl rand -base64 32` |
| `BASEROW_PUBLIC_URL` | Sí | URL pública con TLS, p. ej. `https://basedatos.miempresa.cl` |
| `BASEROW_JWT_SIGNING_KEY` | Recomendada | `openssl rand -base64 32` (si no, usa `SECRET_KEY`) |
| `BASEROW_CADDY_ADDRESSES` | No | `:80` (Caddy queda como gateway HTTP interno; Traefik hace TLS) |
| `BASEROW_VERSION` | No | `2.4.1` (default) |

`HOST_PUBLISH_IP`, `WEB_FRONTEND_PORT` y `WEB_FRONTEND_SSL_PORT` se eliminaron
junto con el bloque `ports:` de `caddy`: Coolify ya no las necesita.

Antes del primer despliegue público, **crear la cuenta administradora** desde
el navegador: la primera persona que se registre toma la instancia. El
procedimiento está en [`docs/04`](docs/04-PRIMERA-CUENTA-Y-USUARIOS.md).

---

## Seguridad en resumen

- **PostgreSQL y Redis no tienen puertos publicados.** Solo el proxy `caddy`
  expone 80 y 443. Verificado sobre el YAML.
- **Las tres variables obligatorias** (`SECRET_KEY`, `DATABASE_PASSWORD`,
  `REDIS_PASSWORD`) abortan el arranque si faltan.
- **Ningún secreto real en este kit.** `.env` está en `.gitignore`.
- **Los scripts de respaldo no borran datos.** La restauración exige `--force`
  explícito y jamás ejecuta un `DROP`.
- **Se verifica** que el archivo comprimido no contenga rutas peligrosas antes
  de extraerlo.

---

## Qué hay que respaldar

| Elemento | ¿Respaldado por este kit? |
|---|---|
| Almacén interno de Baserow (tablas, usuarios, permisos) | **Sí** |
| Archivos adjuntos | **Sí** |
| **Bases de datos del cliente** | **No.** Son responsabilidad del cliente |

Esta distinción está detallada en
[`docs/05`](docs/05-RESPALDOS-Y-RESTAURACION.md).

---

## Por qué Baserow

Dos de las alternativas habituales ya **no se pueden revender**:

| Herramienta | Licencia | ¿Revendible? |
|---|---|---|
| **Baserow (edición abierta)** | **MIT Expat** | **Sí** |
| NocoDB | Sustainable Use License, desde 2026-01-09 | No sin licencia comercial |
| Directus | Monospace Sustainable Core License | No |

El cliente puede auditar la licencia en noventa segundos: está en el
`LICENSE` del repositorio oficial. Detalle en
[`LICENCIAS.md`](LICENCIAS.md) y
[`docs/08`](docs/08-SERVICIOS-COMERCIALES.md).

**Ojo con la exclusión:** las carpetas `premium/` y `enterprise/` de Baserow
**no** están bajo la licencia MIT. La edición abierta no incluye esas funciones.

---

## Qué queda pendiente

Todo esto está detallado en
[`docs/07`](docs/07-PRUEBAS-DE-ACEPTACION.md), pero lo esencial:

1. **Probar el respaldo y la restauración de verdad.** Hasta que no se restaure
   un respaldo en limpio, no se puede afirmar que funcione.
2. **Confirmar cómo se cierra el registro de usuarios nuevos.** En los archivos
   oficiales revisados no se encontró ninguna variable de entorno para eso, y
   no se inventó ninguna.
3. **Verificar la lista de bases de datos externas soportadas** en la versión
   vigente. No se pudo confirmar, así que no se afirma en ningún documento.
4. **Confirmar los formatos de importación y exportación** reales.
5. **Fijar por digest `redis:6` y `pgvector/pgvector:pg15`** antes de producción.
6. **Medir recursos reales** de RAM y CPU.
7. **Sobre Supabase:** se verificó que el almacén interno es PostgreSQL y que se
   puede apuntar a uno externo, pero **no** se verificó la configuración concreta
   de Supabase. **Este kit no lo promete.** Ver
   [`docs/09`](docs/09-EXPORTACION-O-TRASPASO.md).

---

## Origen de cada parte

| Parte | Origen | Licencia |
|---|---|---|
| `compose.yaml` | Hefesto, simplificado del oficial | MIT Expat + comentarios Hefesto |
| `config/Caddyfile` | Upstream, copia textual | MIT Expat |
| Scripts, `.env.example`, docs | Hefesto | Hefesto |
| Aplicación Baserow | Upstream (Baserow Inc.) | MIT Expat |

Detalle en [`LICENCIAS.md`](LICENCIAS.md).