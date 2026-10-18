# 01 — Instalación con Docker (instalación directa)

Estado del kit: **kit preparado**. Ninguno de estos comandos se ejecutó en un
servidor real al preparar el kit. Están tomados de la documentación oficial de
Baserow 2.4.1 y deben probarse en el primer servidor de destino.

---

## 1. Requisitos del servidor

Mínimo realista para una Pyme (estimación de Hefesto, **no** medida):

| Recurso | Mínimo | Cómodo |
|---|---|---|
| RAM | 2 GB | 4 GB |
| vCPU | 2 | 4 |
| Disco | 20 GB | 40 GB (los adjuntos crecen rápido) |
| Sistema | Ubuntu 22.04 / Debian 12 | Ubuntu 24.04 LTS |

Baserow corre seis procesos de aplicación (backend, interfaz, tres workers de
Celery y el planificador) más PostgreSQL y Redis. **No es un servidor de
aplicaciones web único y pequeño.** Con 2 GB va justo.

**Pendiente de verificar:** el equipo de Baserow pública requisitos oficiales de
hardware en su sitio, pero esos valores no se pudieron leer de forma fiable al
preparar este kit. La tabla de arriba es una estimación propia de Hefesto. Si el
cliente tiene muchos usuarios simultáneos, medir antes de prometer nada.

Requisitos verificados de la versión 2.4.1 (de `docs/installation/supported.md`):

- Docker >= 19.03
- Docker Compose >= 1.19.0
- PostgreSQL >= 14 (la imagen del kit trae 15)
- Redis >= 6.2.7
- pgvector >= 0.8.1

---

## 2. Preparación del sistema

```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker desde el repositorio oficial de Docker (no el de Ubuntu,
# que suele estar desactualizado).
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verificar
docker --version
docker compose version
```

---

## 3. Desplegar el kit

```bash
# Copiar el kit al servidor, por ejemplo en /opt/baserow
sudo mkdir -p /opt/baserow
cd /opt/baserow
# (copiar aquí los archivos del kit)

cp .env.example .env
chmod 600 .env
```

Generar los secretos. **Cada uno por separado**, nunca copiar el mismo valor en
varios campos:

```bash
openssl rand -base64 32   # SECRET_KEY
openssl rand -base64 32   # BASEROW_JWT_SIGNING_KEY
openssl rand -base64 32   # DATABASE_PASSWORD
openssl rand -base64 32   # REDIS_PASSWORD
```

Editar `.env` y, como mínimo, poner:

```bash
SECRET_KEY=<salida 1>
BASEROW_JWT_SIGNING_KEY=<salida 2>
DATABASE_PASSWORD=<salida 3>
REDIS_PASSWORD=<salida 4>
BASEROW_PUBLIC_URL=http://localhost
```

### 3.1 Levantar

```bash
docker compose up -d
docker compose ps          # todos deben quedar "healthy" o "running"
docker compose logs -f caddy
```

El primer arranque tarda: Baserow aplica las migraciones de la base. Espera a
ver en los registros que el servicio está disponible.

---

## 4. HTTPS

Sin HTTPS, las contraseñas y los tokens de API viajan en claro. **No publiques
la instancia por HTTP fuera de una red interna.**

La vía más simple es dejar que Caddy emita el certificado:

```bash
# 1. Apuntar el dominio DNS a la IP del servidor
# 2. En .env:
BASEROW_PUBLIC_URL=https://baserow.miempresa.cl
BASEROW_CADDY_ADDRESSES=:443

# 3. Reiniciar
docker compose up -d
```

Para que funcione, el puerto 443 debe estar abierto en el grupo de seguridad del
proveedor del VPS y en el cortafuegos.

### 4.1 Advertencia seria sobre ufw

Baserow advierte en su documentación oficial que **Docker puede saltarse las
reglas de ufw** al publicar puertos en `0.0.0.0`, dejando el contenedor
expuesto aunque ufw parezca cerrado.

Dos formas de evitarlo:

**a) Publicar solo en localhost y poner otro proxy delante** (recomendado si ya
hay un proxy en el servidor):

```bash
HOST_PUBLISH_IP=127.0.0.1
```

**b) Publicar en `0.0.0.0` y confiar en el grupo de seguridad del VPS.** Es lo
que hace la mayoría, pero entonces el grupo de seguridad es tu única barrera.

Fuente: <https://baserow.io/docs/installation/install-with-docker#quick-start>

---

## 5. Verificación posterior

```bash
# Estado de los servicios
docker compose ps

# Comprobación de salud documentada por Baserow
docker compose exec backend ./baserow.sh backend-cmd backend-healthcheck

# Ver tablas creadas por las migraciones
docker compose exec db psql -U baserow -d baserow -c '\dt'
```

---

## 6. Diferencias con el compose oficial

Este kit **simplifica** `docker-compose.yml` de Baserow 2.4.1. El detalle
completo está en `VERSION.md`, sección 3. Resumen:

1. **Se eliminaron unas 290 variables de entorno con valor vacío** del backend.
   En upstream están vacías a propósito: son la lista de puntos de ajuste
   disponibles, no configuración. Se conservaron solo las que el operador va a
   usar.
2. **`depends_on` con `condition: service_healthy`.** Upstream solo ordena el
   arranque; así es posible que el backend intente conectarse a PostgreSQL antes
   de que esté listo. Es una mejora de Hefesto.
3. **Rotación de logs** (`json-file`, 10 MB x 5 archivos). Decisión de Hefesto:
   sin esto los logs crecen sin límite en un servidor que nadie limpia.
4. **`email-receiver` tras el perfil `inbound-email`.** Igual que upstream, para
   no publicar el puerto 25 SMTP en servidores que no usan esa función.
5. **`BASEROW_OSS_ONLY=true` por defecto**, para que quede explícito que la
   instalación es edición abierta.
6. **El Caddyfile se toma de `config/Caddyfile`** en vez de la raíz del
   proyecto. Contenido idéntico al de upstream.

**Lo que NO se tocó:** nombres de servicios, comandos de Celery, `healthcheck`,
`stop_signal: SIGQUIT`, el `chown 9999:9999`, el contenido del Caddyfile.

---

## 7. Receptor de correo entrante (opcional)

Solo si se usa el disparador de automatizaciones "Start workflow by email".
**Pública el puerto 25 en el host**, así que solo actívalo si es necesario:

```bash
# En .env
BASEROW_INBOUND_EMAIL_DOMAIN=entrada.miempresa.cl
BASEROW_INBOUND_EMAIL_WEBHOOK_SECRET=<openssl rand -hex 32>

# En el comando de arranque
COMPOSE_PROFILES=inbound-email docker compose up -d
```

Además requiere un registro MX apuntando al servidor y el puerto 25 abierto.
Ver `docs/01`, sección 7 del compose, y la documentación oficial de Baserow.