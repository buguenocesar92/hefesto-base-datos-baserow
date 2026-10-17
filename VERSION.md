# Versiones — Hefesto Studio, kit Baserow

Este documento fija **exactamente** qué versiones se instalaron y de dónde sale
cada una. Cualquier cambio de versión debe pasar por aquí.

---

## 1. Aplicación: Baserow Open Source Edition

| Dato | Valor |
|---|---|
| Versión | **2.4.1** |
| Fecha de publicación de la etiqueta | 2026-10-13 |
| Imagen oficial (todo en uno) | `baserow/baserow:2.4.1` |
| Imagen del backend | `baserow/backend:2.4.1` |
| Imagen de la interfaz | `baserow/web-frontend:2.4.1` |

**Digest de `baserow/baserow:2.4.1`** (índice de manifiesto, cubre amd64 y arm64):

```
sha256:2229bc0ad9c8e1c3c44cef3324ff0501639d44a7b6f64026ebaa44f61cfb038e
```

Por arquitectura:

| Arquitectura | Digest |
|---|---|
| `linux/amd64` | `sha256:d10301e2dc5ef3a49fc9270dbbe0465df074f980cbcffa142128d44b9543285b` |
| `linux/arm64` | `sha256:952cdf956346fd84c94def6734dcb4718b7aa8b02c0631d12ec26b66e8cc9bc0` |

Fuente: registro de Docker Hub, consulta del 2026-10-17.
<https://registry.hub.docker.com/v2/repositories/baserow/baserow/tags/2.4.1>

> **Por qué esta versión y no otra.** 2.4.1 era la etiqueta estable más reciente
> al momento de preparar este kit. Verificado contra Docker Hub, no supuesto.

---

## 2. Servicios de infraestructura

Estas versiones están **tomadas textualmente del `docker-compose.yml` oficial de
Baserow 2.4.1**, no elegidas por nosotros:

| Servicio | Imagen | Origen de la versión |
|---|---|---|
| Base de datos interna | `pgvector/pgvector:pg15` | upstream 2.4.1 |
| Caché y colas | `redis:6` | upstream 2.4.1 |
| Proxy inverso | `caddy:2.11.4` | upstream 2.4.1 |
| Ajuste de permisos (tarea única) | `bash:4.4` | upstream 2.4.1 |

### 2.1 Advertencia honesta sobre `redis:6`

`redis:6` es una etiqueta **móvil**, no un número exacto de versión. Es la que
usa el compose oficial de Baserow 2.4.1, por eso la conservamos, pero el
contrato de Hefesto exige versiones fijadas.

**Antes de poner esto en producción, fija el digest.** Pasos exactos:

```bash
docker pull redis:6
docker image inspect redis:6 --format '{{index .RepoDigests 0}}'
# Reemplazar en compose.yaml:
#   image: redis@sha256:<DIGEST_OBTENIDO>
```

**Pendiente de verificar:** no fijamos el digest de `redis:6` ni de
`pgvector/pgvector:pg15` en el compose entregado, porque en el entorno donde se
preparó este kit no había acceso al registro para resolver y comprobar esos
digests. Es una decisión consciente, no un descuido: preferimos entregar la
etiqueta que usa upstream y dejar el paso de fijación explícito, antes que
escribir un digest inventado o aproximado.

### 2.2 Requisitos de versión que declara el propio Baserow 2.4.1

Extraído de `docs/installation/supported.md` en la etiqueta 2.4.1:

| Dependencia | Soportadas | Probadas | Recomendadas |
|---|---|---|---|
| PostgreSQL | >= 14 | 14 | 15+ |
| pgvector | >= 0.8.1 | 0.8.1 | Última |
| Redis | >= 6.2.7 | 6.2.7 | Última |
| Docker | >= 19.03 | Última | Última |
| Python | >= 3.14.0 | 3.14.7 | 3.14.x más reciente |
| Node.js | >= 24.0.0 | 24.21.0 | >= 24.0.0 |

Fuente: <https://github.com/baserow/baserow/blob/2.4.1/docs/installation/supported.md>

**Consecuencia concreta:** la imagen `pgvector/pgvector:pg15` trae PostgreSQL 15
y pgvector, que cumple lo recomendado. No es negociable usar una imagen de
PostgreSQL sin pgvector: Baserow la requiere.

---

## 3. Cambios que este kit introduce sobre el compose oficial

El compose oficial de Baserow 2.4.1 declara unos **290 nombres de variable de
entorno con valor vacío** en el backend. Casi todos existen como lista de
"puntos de ajuste disponibles", no como configuración real: si están vacíos,
Baserow usa su valor por defecto.

Nuestro `compose.yaml` conserva solo las variables que tienen un valor por
defecto útil o que el operador realmente va a tocar. Diferencias completas:

| # | Cambio | Motivo |
|---|---|---|
| 1 | Se eliminan las ~290 variables vacías del backend | Eran documentación, no configuración. Mantenerlas confunde y llena el archivo de ruido |
| 2 | Se agrupan en el ancla `x-backend-variables` | Evita repetir el bloque en cuatro servicios. Es lo mismo que hace upstream |
| 3 | Se eliminan el servicio `email-receiver` y su volumen salvo en perfil `inbound-email` | Publica el puerto 25 en el host. upstream ya lo hace así para no abrirlo por defecto |
| 4 | `depends_on` usa `condition: service_healthy` en vez de solo ordenar el arranque | Evita que backend y Celery se conecten a PostgreSQL antes de que esté listo. Decisión de Hefesto |
| 5 | Se añade rotación de logs (`json-file`, 10 MB x 5) | Sin esto, los logs de un servidor que nunca se limpia crecen sin límite. Decisión de Hefesto |
| 6 | Se fija `BASEROW_OSS_ONLY=true` por defecto | Deja explícito que la instalación es edición abierta, aunque alguien registre una licencia |
| 7 | El Caddyfile se monta desde `./config/Caddyfile` en vez de `$PWD/Caddyfile` | Ordena el kit según el contrato de Hefesto. El contenido es idéntico al de upstream |
| 8 | Se eliminan las variables `DATABASE_READ_1_*` y `DATABASE_READ_2_*` | Son para réplicas de lectura separadas. No aplican a una Pyme con un servidor modesto |

**Lo que NO se cambió:** los nombres de los servicios, los comandos de Celery,
los `healthcheck`, el `stop_signal: SIGQUIT` de beat, el `chown 9999:9999` del
corrector de permisos, la variable de contraseña de Redis y el contenido del
Caddyfile. Todo eso viene textual de upstream y se mantiene a propósito.

---

## 4. Procedimiento de actualización

Ver `docs/06-ACTUALIZACIONES-Y-REVERSION.md`. En resumen:

1. Respaldo (obligatorio).
2. Cambiar `BASEROW_VERSION` en `.env`.
3. `docker compose pull && docker compose up -d`.
4. Baserow aplica solo las migraciones pendientes al arrancar.

**No hay atajos entre versiones:** se puede saltar de cualquier versión a la
más reciente y Baserow aplica todas las migraciones intermedias.