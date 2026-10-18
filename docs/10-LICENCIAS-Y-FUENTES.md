# 10 — Licencias y fuentes

Todo lo de este documento se verificó leyendo los archivos de licencia del
repositorio oficial de Baserow en la etiqueta **2.4.1**, el 17 de octubre de
2026. No se recuerda de memoria ni de notas anteriores.

Resumen ejecutivo: `LICENCIAS.md` tiene el detalle y el razonamiento comercial.
Este documento es el registro de fuentes.

---

## 1. Licencias de la aplicación

| Componente | Licencia | Archivo fuente |
|---|---|---|
| Baserow Open Source Edition | **MIT Expat** | [`LICENSE`](https://github.com/baserow/baserow/blob/2.4.1/LICENSE) |
| Directorio `premium/` | Baserow Premium Edition License | [`premium/LICENSE`](https://github.com/baserow/baserow/blob/2.4.1/premium/LICENSE) |
| Directorio `enterprise/` | Baserow Enterprise Edition License | [`enterprise/LICENSE`](https://github.com/baserow/baserow/blob/2.4.1/enterprise/LICENSE) |

### 1.1 La exclusión crítica

**`premium/` y `enterprise/` NO están cubiertos por la licencia MIT.** Cada
directorio lleva su propia licencia, que exige suscripción.

El propio texto de `premium/LICENSE` lo confirma: cualquier parte del software
distribuida como parte de la Open Source Edition permanece bajo MIT Expat. La
frontera entre lo libre y lo de pago está dibujada de forma explícita en el
propio repositorio.

**Consecuencia práctica:** el código de esas carpetas **no** se puede copiar a
un proyecto del cliente sin sacar ese código del MIT. Este kit no lo hace.

### 1.2 Obligaciones reales de la MIT Expat

La MIT Expat es una licencia **permisiva**. Las obligaciones son pocas y todas
se cumplen con lo que este kit ya hace:

| Obligación | Cómo se cumple |
|---|---|
| Conservar el aviso de copyright | Se enlaza al repositorio y a los archivos de licencia originales |
| Incluir el texto de la licencia al redistribuir | Si se redistribuye código o imagen, incluir el `LICENSE` de Baserow |
| Declarar el uso | Este documento y `LICENCIAS.md` |

**Lo que MIT NO exige**, y conviene tener claro:

- **No** obliga a mostrar el logotipo de Baserow en la interfaz.
- **No** obliga a publicar el código fuente del proyecto del cliente.
- **No** tiene copyleft: no obliga a abrir nada.

Aun así, **quitar la atribución de Baserow es mala práctica** y este kit no lo
recomienda, aunque la licencia no lo prohíba.

### 1.3 Documentación

La documentación se pública bajo **CC BY-SA 4.0**, según lo indicado en
<https://baserow.io/docs>.

**Pendiente de verificación:** no se pudo confirmar la ruta exacta del archivo de
licencia de la documentación dentro del repositorio en 2.4.1.

CC BY-SA tiene una obligación que **sí** importa si se reutiliza material:
**copyleft de compartición.** Si se copia texto o diagramas de la documentación,
hay que dar crédito y compartir bajo la misma licencia. **Revisarlo antes de
reutilizar material de la documentación en material comercial.**

---

## 2. Licencias de la infraestructura

| Componente | Licencia | Fuente |
|---|---|---|
| PostgreSQL | PostgreSQL License | <https://www.postgresql.org/about/licence/> |
| pgvector | PostgreSQL License | <https://github.com/pgvector/pgvector/blob/master/LICENSE> |
| Redis | BSD de 3 cláusulas | <https://github.com/redis/redis/blob/unstable/COPYING> |
| Caddy | Apache-2.0 | <https://github.com/caddyserver/caddy/blob/master/LICENSE> |
| GNU Bash | GPL-3.0 | <https://www.gnu.org/licenses/gpl-3.0.html> |
| Docker Engine | Apache-2.0 | <https://github.com/moby/moby/blob/master/LICENSE> |

### 2.1 La nota sobre Bash

GNU Bash es GPL-3.0, la única licencia copyleft del conjunto. Se usa en el
servicio `volume-permissions-fixer`, que ejecuta un único `chown` en un
contenedor desechable de la imagen oficial `bash:4.4`.

**No se distribuye, no se modifica y no se incluye en lo que recibe el
cliente.** Se ejecuta igual que se ejecuta `curl`. La GPL no obliga a nada en
este uso.

Si algún día ese script se copiara dentro del proyecto del cliente, ahí sí
habría que mirar la GPL. **No se hace.**

### 2.2 Apache-2.0

Caddy y Docker usan Apache-2.0. Obliga a conservar el aviso de licencia. No es
copyleft: no obliga a abrir el código de quien lo usa.

---

## 3. Registro de fuentes consultadas

Todo lo afirmado en este kit sale de estas fuentes, consultadas el
**2026-10-17**:

### 3.1 Repositorio de Baserow, etiqueta 2.4.1

| Archivo | Para qué se usó |
|---|---|
| `LICENSE` | Licencia de la edición abierta |
| `premium/LICENSE` | Confirmar la exclusión del MIT |
| `enterprise/LICENSE` | Licencia enterprise |
| `docker-compose.yml` | Servicios, versiones, healthcheck, puertos, variables |
| `Caddyfile` | Enrutado, `/media`, encabezados de seguridad |
| `.env.example` | Las tres variables obligatorias |
| `docs/installation/install-with-docker.md` | Respaldo, salud, HTTPS, advertencia de ufw |
| `docs/installation/supported.md` | Versiones de PostgreSQL, pgvector, Redis, Docker |
| `docs/technical/database-plugin.md` | Confirmar PostgreSQL como almacén interno |
| `docs/index.md` | Ubicación de la documentación técnica |
| `backend/src/baserow/core/management/commands/backup_baserow.py` | Advertencia de base quieta |
| `backend/src/baserow/core/management/commands/restore_baserow.py` | «Solo bases vacías» |
| `backend/src/baserow/core/management/commands/manage_trusted_sources.py` | Claves de confianza para importación/exportación |

### 3.2 Docker Hub

- Registro de `baserow/baserow`: versión, fecha y digests.
  <https://registry.hub.docker.com/v2/repositories/baserow/baserow/tags/2.4.1>

### 3.3 Sitio de Baserow

- Preguntas frecuentes y límites de filas: <https://baserow.io/pricing>
- Instalación con Docker: <https://baserow.io/docs/installation/install-with-docker>
- Configuración: <https://baserow.io/docs/installation/configuration>

### 3.4 Alternativas descartadas

- NocoDB: <https://github.com/nocodb/nocodb/blob/master/LICENSE.md>
- Directus: <https://github.com/directus/directus/blob/main/license>

---

## 4. Lo que este kit no incluye

- **No** incluye el código fuente de Baserow. Solo despliega imágenes oficiales.
- **No** incluye código de `premium/` ni de `enterprise/`.
- **No** incluye código propio de Hefesto más allá de los scripts de respaldo y
  el compose.

---

## 5. Lo que queda pendiente de verificar en materia de licencias

- [ ] La ruta exacta del archivo de licencia de la documentación en 2.4.1.
- [ ] Los términos de CC BY-SA aplicados a un caso concreto de reutilización.
- [ ] Si existen cambios de licencia entre la versión instalada y la que se
      ofrece al cliente. **Un proyecto puede cambiar de licencia:**
      la de hoy es MIT, la de mañana no se puede prometer.