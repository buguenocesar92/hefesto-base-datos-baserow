# 03 — Variables de entorno y cómo obtenerlas

Estado del kit: **kit preparado**.

Los nombres de variable de este documento se tomaron textualmente del
`.env.example` y del `docker-compose.yml` oficiales de Baserow **2.4.1**:

- <https://github.com/baserow/baserow/blob/2.4.1/.env.example>
- <https://github.com/baserow/baserow/blob/2.4.1/docker-compose.yml>
- Referencia completa: <https://baserow.io/docs/installation/configuration>

---

## 1. Las tres obligatorias

El compose oficial marca estas tres con `${VAR:?}`, que hace que Docker Compose
**aborte el arranque** si no están definidas:

| Variable | Para qué | Cómo obtenerla |
|---|---|---|
| `SECRET_KEY` | Clave de cifrado interna de Django | `openssl rand -base64 32` |
| `DATABASE_PASSWORD` | Contraseña del PostgreSQL interno | `openssl rand -base64 32` |
| `REDIS_PASSWORD` | Contraseña del Redis interno | `openssl rand -base64 32` |

En el `.env.example` oficial aparecen comentadas con la etiqueta
`# Required to be set by you in the docker-compose and standalone installs.`

> Detalle que conviene conocer: la imagen `baserow/baserow` (la de todo en uno)
> **genera estos valores automáticamente** si no se los pasa y los guarda en
> `/baserow/data/.secret`. En este kit, que usa el compose por servicios, se
> exigen siempre. Es una decisión consciente: preferimos que los secretos los
> controle el operador y no queden generados dentro de un volumen.

---

## 2. Recomendadas

| Variable | Si no la defines | Si la cambias después |
|---|---|---|
| `BASEROW_JWT_SIGNING_KEY` | Baserow usa `SECRET_KEY` como clave de firma JWT | Invalida las sesiones activas |
| `BASEROW_PUBLIC_URL` | `http://localhost` | Ver sección 4: es crítico |
| `BASEROW_CADDY_ADDRESSES` | `:80` | Hay que reiniciar Caddy |

Definir `BASEROW_JWT_SIGNING_KEY` por separado permite rotar una clave sin tocar
la otra. Recomendado.

---

## 3. Tabla completa de las variables que usa este kit

| Variable | Obligatoria | Ejemplo falso | De dónde sale | Qué pasa si se cambia después |
|---|---|---|---|---|
| `SECRET_KEY` | **Sí** | `REEMPLAZAR_...` | `openssl rand -base64 32` | Invalida sesiones y datos cifrados con ella |
| `DATABASE_PASSWORD` | **Sí** | `REEMPLAZAR_...` | `openssl rand -base64 32` | Hay que cambiarla **también** dentro de PostgreSQL |
| `REDIS_PASSWORD` | **Sí** | `REEMPLAZAR_...` | `openssl rand -base64 32` | Redis deja de autenticar al backend |
| `BASEROW_JWT_SIGNING_KEY` | No | (vacío) | `openssl rand -base64 32` | Cierra las sesiones activas |
| `BASEROW_PUBLIC_URL` | Muy recomendada | `https://datos.miempresa.cl` | El dominio del cliente | Ver sección 4 |
| `BASEROW_CADDY_ADDRESSES` | No | `:443` | Decisión de despliegue | Requiere reiniciar Caddy |
| `HOST_PUBLISH_IP` | No | `0.0.0.0` | Decisión de red | Cambia desde qué se accede |
| `WEB_FRONTEND_PORT` | No | `80` | Decisión de despliegue | Cambia el puerto público |
| `WEB_FRONTEND_SSL_PORT` | No | `443` | Decisión de despliegue | Cambia el puerto público |
| `BASEROW_VERSION` | No | `2.4.1` | `VERSION.md` | **Actualiza o degrada el software** |
| `DATABASE_USER` | No | `baserow` | Decisión interna | Hay que renombrar el rol en PostgreSQL |
| `DATABASE_NAME` | No | `baserow` | Decisión interna | Hay que renombrar la base |
| `DATABASE_HOST` | No | (vacío = servicio `db`) | Solo con base externa | Ver `docs/09` |
| `DATABASE_PORT` | No | (vacío) | Solo con base externa | Ver `docs/09` |
| `DATABASE_URL` | No | (vacío) | Solo con base externa | Tiene prioridad sobre `DATABASE_*` |
| `REDIS_HOST` | No | (vacío = servicio `redis`) | Solo con Redis externo | Cambia el destino de la caché |
| `REDIS_URL` | No | (vacío) | Solo con Redis externo | Tiene prioridad sobre `REDIS_*` |
| `EMAIL_SMTP` | No | `True` | Datos del SMTP del cliente | Sin esto no hay correos |
| `EMAIL_SMTP_HOST` | No | `smtp.miempresa.cl` | SMTP del cliente | — |
| `EMAIL_SMTP_PORT` | No | `587` | SMTP del cliente | — |
| `EMAIL_SMTP_USE_TLS` | No | `True` | SMTP del cliente | — |
| `EMAIL_SMTP_USER` | No | `usuario` | SMTP del cliente | — |
| `EMAIL_SMTP_PASSWORD` | No | `CLAVE_DE_EJEMPLO` | SMTP del cliente | — |
| `FROM_EMAIL` | No | `sistema@miempresa.cl` | Debe pasar la validación de dominio | — |
| `BASEROW_OSS_ONLY` | No | `true` | Decisión comercial | Desactiva funciones premium aun con licencia |
| `BASEROW_USE_PG_FULLTEXT_SEARCH` | No | `false` | Decisión técnica | Requiere pgvector |
| `BASEROW_MAX_IMPORT_FILE_SIZE_MB` | No | `512` | Decisión técnica | Solo afecta importaciones futuras |
| `BASEROW_BACKEND_LOG_LEVEL` | No | `INFO` | Decisión técnica | Solo verbosidad del log |
| `BASEROW_INBOUND_EMAIL_DOMAIN` | No | (vacío) | Solo con perfil inbound-email | — |
| `BASEROW_INBOUND_EMAIL_WEBHOOK_SECRET` | No | (vacío) | `openssl rand -hex 32` | — |
| `BASEROW_INBOUND_EMAIL_HOST_SMTP_PORT` | No | `25` | Decisión de red | Publica SMTP en el host |

---

## 4. `BASEROW_PUBLIC_URL`: la variable que más problemas causa

Es la URL con la que **el usuario abre el sitio**. No la URL interna del
contenedor.

Debe coincidir **exactamente**, incluido el esquema (`https://`), el dominio y
el puerto si no es el estándar.

Si no coincide, pasan estas cosas:

1. Los enlaces de los archivos adjuntos se construyen mal y no abren.
2. Los correos de invitación y recuperación apuntan a otro sitio.
3. Baserow considera cualquier otra dirección una **"aplicación publicada"**
   ajena, y en vez de servir el contenido pide que el usuario se autentique.

La última es la más importante desde el punto de vista de la seguridad: es lo
que impide que la interfaz se vea en un dominio que no es el tuyo.

Fuente: <https://baserow.io/docs/installation/install-with-docker#quick-start>

---

## 5. Sobre el separador `__` (doble subrayado)

**Resultado de la verificación: en los archivos oficiales de Baserow 2.4.1 que
revisamos, el separador es un solo guion bajo. No hay variables con doble
subrayado.**

Se revisaron el `.env.example` y el `docker-compose.yml` completos de la
etiqueta 2.4.1. Todas las variables usan un único `_` como separador, por
ejemplo `BASEROW_PUBLIC_URL`, `DATABASE_HOST`, `EMAIL_SMTP_HOST`.

Esto importa porque es fácil inventar un nombre del estilo
`BASEROW_APLICACION__ALGO` y que Docker lo descarte en silencio. Si alguna vez
necesitas una variable que no esté en las tablas de arriba:

1. Búscala primero en `docs/installation/configuration.md` de la etiqueta
   exacta que estés instalando.
2. Si no aparece, **no la escribas**. Una variable mal nombrada no da error:
   Baserow simplemente la ignora y usa el valor por defecto, en silencio. Ese
   es el modo de fallo peligroso.

Fuente: <https://github.com/baserow/baserow/blob/2.4.1/.env.example>

---

## 6. Rotar secretos

| Secreto | Cómo rotarlo |
|---|---|
| `REDIS_PASSWORD` | Cambiar `.env`, reiniciar. No afecta datos: Redis es caché |
| `SECRET_KEY` | **Cuidado.** Invalida sesiones. No hay rotación sin más en la edición abierta |
| `BASEROW_JWT_SIGNING_KEY` | Se puede rotar de forma independiente. Cierra sesiones |
| `DATABASE_PASSWORD` | Hay que cambiarla **dentro de PostgreSQL y** en `.env` a la vez |

Para `DATABASE_PASSWORD`:

```bash
docker compose exec db psql -U baserow -d baserow -c "\password baserow"
# Luego actualizar .env y: docker compose up -d
```

**Los secretos no están en los respaldos.** Si restauras en otra máquina,
necesitas el `.env` original. Ver `docs/05`.