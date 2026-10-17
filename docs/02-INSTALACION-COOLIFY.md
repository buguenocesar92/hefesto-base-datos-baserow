# 02 — Instalación en Coolify

Estado del kit: **kit preparado**. No se probó en Coolify. Ver la sección 6.

---

## 1. ¿Sirve este kit para Coolify?

**Sí**, con una salvedad importante.

Coolify despliega recursos de tipo "Docker Compose" usando el mismo motor que
`docker compose`. Este kit es un `compose.yaml` estándar, sin `build:` (todo se
descarga de imágenes oficiales), así que funciona tal cual.

**La salvedad:** este compose declara **cinco volúmenes con nombre**
(`pgdata`, `media`, `caddy_data`, `caddy_config`, `mox_data`). Si en Coolify se
marca la casilla de regenerate volumes en cada despliegue, Coolify puede borrar
los datos y crear volúmenes vacíos. Es el error más caro que se puede cometer
con este kit: **se pierden todas las tablas, usuarios y adjuntos.**

> Coolify etiqueta sus volúmenes con el prefijo del proyecto. Si los borras,
> el respaldo del kit sigue sirviendo, pero solo si existe uno reciente.

---

## 2. Preparación

En el panel de Coolify:

1. **New Resource → Docker Compose**
2. Elige el servidor destino.
3. En **Docker Compose → General**:
   - **Compose File**: sube o pega el contenido de `compose.yaml`.
   - **Base Directory / Workdir**: la carpeta donde vive el kit.

---

## 3. Variables de entorno

En **Environment Variables**, define lo mismo que en `.env`:

| Variable | Obligatoria | Cómo obtenerla |
|---|---|---|
| `SECRET_KEY` | Sí | `openssl rand -base64 32` |
| `DATABASE_PASSWORD` | Sí | `openssl rand -base64 32` |
| `REDIS_PASSWORD` | Sí | `openssl rand -base64 32` |
| `BASEROW_JWT_SIGNING_KEY` | Recomendada | `openssl rand -base64 32` |
| `BASEROW_PUBLIC_URL` | Sí | `https://tudominio.cl` |
| `BASEROW_CADDY_ADDRESSES` | Sí | `:443` |
| `BASEROW_VERSION` | No | `2.4.1` (ya viene por defecto) |

Genera las cuatro claves **por separado**. Coolify guarda estas variables en su
propia base de datos: trátalas como secretos, no las pegues en el canal del
equipo ni las guardes en el repositorio.

**No uses el `.env` tal cual.** Coolify gestiona las variables por su cuenta. El
`.env.example` está para generar los valores; las claves definitivas se escriben
en la interfaz de Coolify.

---

## 4. Dominio, proxy y HTTPS

1. **New Resource → Service → Proxy**, y apunta un dominio, por ejemplo
   `baserow.miempresa.cl`.
2. Coolify genera el proxy inverso y emite el certificado TLS.
3. Coolify enruta por dominio hacia los puertos que el compose publica.

Puntos concretos para este kit:

| Aspecto | Valor en este kit | Qué revisar en Coolify |
|---|---|---|
| Puerto del contenedor | 80 y 443 (servicio `caddy`) | Que el proxy apunte a **80** para HTTP |
| Proxy interno | Caddy, dentro del compose | Que Coolify no lo sustituya |
| HTTPS | Terminado en Coolify | Que a Baserow le llegue HTTP por 80 |
| `BASEROW_PUBLIC_URL` | Debe ser la URL pública | Si no coincide, fallan adjuntos y correos |

### 4.1 El detalle que más se olvida

`BASEROW_PUBLIC_URL` **debe ser exactamente** la URL con la que el usuario abre
el sitio, por ejemplo `https://baserow.miempresa.cl`.

Si no coincide:

- Los enlaces de archivos adjuntos salen mal.
- Los correos de invitación apuntan a otro sitio.
- Baserow puede tratar el sitio como una "aplicación publicada" ajena y pedir
  autenticación en vez de servir el contenido.

La documentación de Baserow lo dice de forma explícita: cualquier dirección
distinta de `BASEROW_PUBLIC_URL` se considera una aplicación publicada.

### 4.2 Sobre el proxy de Coolify

**Pendiente de verificar:** no se comprobó en un Coolify real si su proxy
inyecta correctamente los encabezados que Caddy espera (`X-Forwarded-*`, `Host`).

Si el login o los websockets fallan detrás del proxy de Coolify, esto es lo
primero que hay que revisar. La alternativa que sí está documentada por Baserow
es correr Caddy sin nada delante:

```bash
HOST_PUBLISH_IP=0.0.0.0
BASEROW_CADDY_ADDRESSES=:443
```

Es decir, que Caddy termine el TLS directamente y no usar el proxy de Coolify.
No se ha probado ninguna de las dos en Coolify.

---

## 5. Volúmenes

Deja los volúmenes **persistentes**. Configura el despliegue de modo que:

- No se regeneren en cada redeploy.
- Los cinco volúmenes con nombre existan y se conserven.

Los volúmenes mapped/named de este kit:

| Volumen | Contenido | ¿Respaldar? |
|---|---|---|
| `pgdata` | Base interna: tablas, usuarios, permisos | **Sí** |
| `media` | Archivos adjuntos | **Sí** |
| `caddy_data` | Certificados TLS | Opcional |
| `caddy_config` | Configuración de Caddy | Opcional |
| `mox_data` | Buzón (solo perfil inbound-email) | Opcional |

---

## 6. Lo que falta probar en Coolify

- [ ] Despliegue limpio y arranque de los diez servicios.
- [ ] Que las cinco variables obligatorias las detecte Coolify (el compose usa
      `${VAR:?}`, que aborta el arranque si faltan; Coolify debería manejarla,
      pero **no está probado**).
- [ ] Login, subida de adjuntos y colaboración en tiempo real a través del proxy.
- [ ] El respaldo y la restauración usando los scripts de este kit **dentro de
      Coolify**. Los scripts asumen que `docker compose` se ejecuta en la
      carpeta del kit; en Coolify el directorio de trabajo puede ser otro.
      **Verificar la ruta antes de depender de ellos.**
- [ ] HTTPS y renovación del certificado.

---

## 7. Alternativa recomendada para Hefesto

Para la primera instalación de un cliente, **instala con `docker compose` normal
en el VPS** (ver `docs/01`) y usa Coolify solo cuando la operación ya esté
establecida. Razones:

1. Los scripts de respaldo asumen acceso directo al servidor.
2. La depuración es mucho más simple sin una capa de por medio.
3. Coolify gestiona variables y volúmenes: útil, pero añade un sitio más donde
   puede fallar el manejo de secretos.