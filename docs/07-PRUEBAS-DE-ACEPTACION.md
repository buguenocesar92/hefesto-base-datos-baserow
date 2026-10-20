# 07 — Pruebas de aceptación

**Estado del kit: `kit preparado`.**

En el entorno donde se preparó este kit **no hay Docker ni servidor**. Nada de
lo que sigue se ejecutó contra una instancia real. Este documento separa con
cuidado lo que **sí** se comprobó de lo que **no**.

---

# PARTE A — Realmente ejecutado

Estas comprobaciones **sí** se hicieron, contra las fuentes upstream. No
requieren Docker.

## A.1 Estructura y sintaxis

| Prueba | Resultado |
|---|---|
| `compose.yaml` parsea como YAML válido | **Sí** |
| Contiene 10 servicios y 5 volúmenes | **Sí** |
| `docker compose config` **no** se ejecutó | Correcto: requiere Docker |
| `bash -n scripts/backup-baserow.sh` | **Sin errores de sintaxis** |
| `bash -n scripts/restore-baserow.sh` | **Sin errores de sintaxis** |
| Los scripts tienen cabecera, comentarios en español y `set -euo pipefail` | **Sí** |

Validación de seguridad del compose (por inspección del YAML parseado):

| Prueba | Resultado |
|---|---|
| ¿Algún servicio pública el puerto de PostgreSQL? | **No.** `db` no tiene `ports:` |
| ¿Algún servicio pública el puerto de Redis? | **No.** `redis` no tiene `ports:` |
| ¿Quién pública puertos? | Solo `caddy` (80 y 443), más `email-receiver` tras perfil |
| ¿Hay alguna imagen con `:latest`? | **No** |
| ¿Los servicios de larga duración tienen `restart`? | **Sí**, `unless-stopped` |
| ¿ElCorrector de permisos tiene reinicio? | No, y no debe: es tarea única |

## A.2 Versiones y licencias (leídas de la fuente)

| Prueba | Resultado | Fuente |
|---|---|---|
| Última versión estable | **2.4.1**, publicada 2026-10-13 | Docker Hub |
| Digest del manifiesto | `sha256:2229bc0ad9c8e1c3c44cef3324ff0501639d44a7b6f64026ebaa44f61cfb038e` | Docker Hub |
| Digest `linux/amd64` | `sha256:d10301e2dc5ef3a49fc9270dbbe0465df074f980cbcffa142128d44b9543285b` | Docker Hub |
| Digest `linux/arm64` | `sha256:952cdf956346fd84c94def6734dcb4718b7aa8b02c0631d12ec26b66e8cc9bc0` | Docker Hub |
| Licencia raíz | **MIT Expat** | `LICENSE` en 2.4.1 |
| Licencia de `premium/` | Baserow Premium Edition License | `premium/LICENSE` en 2.4.1 |
| Licencia de `enterprise/` | Baserow Enterprise Edition License | `enterprise/LICENSE` en 2.4.1 |
| ¿MIT cubre `premium/` y `enterprise/`? | **No.** Confirmado en el texto de `premium/LICENSE` | upstream 2.4.1 |
| Motor de la base interna | **PostgreSQL** (`pgvector/pgvector:pg15`) | `docker-compose.yml` 2.4.1 |
| Versiones soportadas | PostgreSQL >=14, pgvector >=0.8.1, Redis >=6.2.7 | `docs/installation/supported.md` |
| ¿`pgvector` es obligatorio? | Aparece como dependencia soportada y probada | `supported.md` 2.4.1 |

## A.3 Variables de entorno (leídas del `.env.example` oficial)

| Prueba | Resultado |
|---|---|
| Las 3 obligatorias son `SECRET_KEY`, `DATABASE_PASSWORD`, `REDIS_PASSWORD` | **Confirmado** |
| El compose aborta si faltan (sintaxis `${VAR:?}`) | **Confirmado** en upstream |
| ¿Existe alguna variable con separador `__`? | **No se encontró ninguna** en `.env.example` ni en `docker-compose.yml` de 2.4.1 |

## A.4 Comportamiento de respaldo (leído del código fuente)

| Prueba | Resultado | Fuente |
|---|---|---|
| ¿El respaldo oficial exige la base quieta? | **Sí**, advertencia literal en el código | `backup_baserow.py` 2.4.1 |
| ¿La restauración solo acepta bases vacías? | **Sí**: *"Only restoring into existing blank databases is supported"* | `restore_baserow.py` 2.4.1 |

---

# PARTE B — Pendiente

**Nada de esto se ha probado.** Cada punto necesita un servidor real.

## B.1 Puesta en marcha

- [ ] `cp .env.example .env`, generar los 4 secretos, `docker compose up -d`.
- [ ] Los 10 servicios quedan arriba y estables.
- [ ] Los 5 servicios con `healthcheck` pasan a `healthy`.
- [ ] La primera migración termina sin errores.
- [ ] La interfaz carga y se puede crear la primera cuenta.
- [ ] El consumo de RAM y CPU real, para validar la tabla de `docs/01`.
- [ ] Cuánto tarda el primer arranque completo.

## B.2 Seguridad

- [ ] Crear la primera cuenta **antes** de exponer el servidor (procedimiento de `docs/04`).
- [ ] **Confirmar si existe una forma de cerrar el registro público.** En los
      archivos oficiales revisados no se encontró ninguna variable de entorno
      para eso. Hay que mirarlo en la interfaz de una instancia real.
- [ ] Confirmar el modelo de permisos real (roles y niveles).
- [ ] Confirmar si un adjunto servido en `/media` exige autenticación.
- [ ] Comprobar si las vistas públicas quedan accesibles sin iniciar sesión.
- [ ] Comprobar qué hace `BASEROW_OSS_ONLY=true` exactamente en la interfaz.

## B.3 Respaldo y restauración — **lo más importante de esta lista**

- [ ] Ejecutar `backup-baserow.sh` de verdad.
- [ ] Confirmar que genera los 5 artefactos esperados.
- [ ] Confirmar que `sha256sum -c SHA256SUMS` da correcto.
- [ ] **Restaurar en limpio y comprobar que vuelven usuarios, tablas y
      adjuntos.** Hasta que esto se haga, no se puede afirmar que el respaldo
      funciona.
- [ ] Confirmar que el script se niega a restaurar sobre una base ocupada.
- [ ] Confirmar que un respaldo sin sello es rechazado.
- [ ] Confirmar que un archivo `tar` con rutas `../` es rechazado.
- [ ] Probar un respaldo con la base de varios megas, no vacía.

## B.4 Coolify

- [ ] Despliegue completo como recurso Docker Compose.
- [ ] Que Coolify entregue las variables `${VAR:?}` sin fallar.
- [ ] Login, adjuntos y websockets detrás del proxy de Coolify.
- [ ] Que los 5 volúmenes persistan entre despliegues.
- [ **Los scripts de respaldo dentro de Coolify:** asumen que `docker compose`
      se ejecuta en la carpeta del kit. En Coolify puede no ser así.

## B.5 Datos y verificaciones pendientes de documentación

Estos puntos **no se pudieron verificar leyendo las fuentes** y están marcados
como pendientes en sus documentos:

- [ ] **Lista de motores de base de datos externos soportados** en la versión
      vigente (PostgreSQL, MySQL, SQL Server, SQLite u otros). La tarea original
      lo daba por verificado, pero **no se pudo confirmar contra la fuente** en
      esta sesión. No se afirma en ningún documento del kit.
- [ ] **Formatos reales de importación y exportación.** Ver `docs/09`.
- [ ] **Rutas exactas para desactivar el registro de usuarios.**
- [ ] **Nombre y ubicación de los ajustes de administración** relevantes.
- [ ] **Licencia exacta de la documentación** y su ruta en el repositorio.
- [ ] **Comportamiento verificado frente a Supabase.** Ver `docs/09`, sección 4.

## B.6 Digests de Redis y pgvector

- [ ] Fijar `redis:6` y `pgvector/pgvector:pg15` por digest antes de producción.
      El procedimiento está en `VERSION.md`, sección 2.1. **No se fijaron en el
      compose entregado** porque en este entorno no se pudo resolver el registro
      para comprobar esos digests.

---

## C. Cómo convertir esto en un kit más avanzado

Cuando las pruebas de la Parte B se hayan hecho en un servidor real, el estado
del kit puede pasar a:

- `validado localmente` — si se ejecutó todo en una máquina de pruebas.
- `desplegado` — si corrió en un servidor de un cliente.
- `aceptado en servidor` — si el cliente lo confirmó en producción.

**Hasta entonces, el estado es `kit preparado` y debe decirse así.**