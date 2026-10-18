# 09 — Exportación, traspaso y conexión a bases existentes

Estado del kit: **kit preparado**.

---

## 1. Tres cosas distintas que se suelen confundir

Esta distinción es la más importante de este documento. Son cosas distintas, con
riesgos distintos, y no se sustituyen entre sí.

| Cosa | Qué es | Automático |
|---|---|---|
| **A. Exportar** | Sacar datos a un archivo. Copia de un momento | No |
| **B. Traspasar la instancia** | Mover toda la instalación a otro servidor | Manual, pero conserva todo |
| **C. Conectar una base externa** | Mostrar en Baserow datos que viven en la base del cliente | Sí, según la función |

**Un CSV exportado no es una sincronización.** Si exportas a CSV y otro importa
mañana, entre medio los dos quedan desincronizados, y sin que nadie se entere.
Un CSV es una foto, no un canal.

---

## 2. A. Exportar datos

### 2.1 Lo verificado

Del `docker-compose.yml` oficial de Baserow 2.4.1 se confirma que existe una
variable:

| Variable | Por defecto | Qué controla |
|---|---|---|
| `BASEROW_MAX_IMPORT_FILE_SIZE_MB` | `512` | Tamaño máximo de archivo importable |

Además, existe un servicio dedicado, `celery-export-worker`, separado del worker
normal. Eso indica que **las exportaciones de datos pesados son una operación en
segundo plano**, no inmediata.

Y existe un comando oficial en el código:
`export_workspace_applications`.

### 2.2 Lo NO verificado

> **Pendiente de verificación.** No se pudo confirmar la lista exacta de
> formatos de exportación e importación de la interfaz en la versión 2.4.1.

**Por eso este documento no afirma "Baserow exporta a CSV, Excel y JSON".**

Para responder con certeza hay que:

1. Instalar la instancia y abrir el menú de exportación de una tabla.
2. Revisar <https://baserow.io/docs> en la sección de importación y exportación.

Un formato que se mencione sin verificar y después no exista es una promesa rota.

### 2.3 La advertencia que sí aplica

La propia documentación de Baserow advierte sobre el alcance de sus comandos de
exportación: no sirven para mover una instancia completa. En sus términos, solo
exportan **las aplicaciones y sus archivos**.

Si el cliente quiere moverse de servidor, necesita la sección 3, no un CSV.

---

## 3. B. Traspasar la instancia entera

**Este es el procedimiento correcto para mudar de servidor.** Conserva usuarios,
permisos, tokens, webhooks, historial y archivos.

```bash
# 1. En el servidor viejo: respaldo completo y verificado
./scripts/backup-baserow.sh -d ./backups --etiqueta mudanza

# 2. Copiar el respaldo AL NUEVO servidor, junto con el .env
scp -r ./backups/baserow-*-mudanza usuario@servidor-nuevo:/opt/baserow/backups/
scp .env usuario@servidor-nuevo:/opt/baserow/.env

# 3. En el servidor nuevo
cd /opt/baserow
cp .env.example .env      # si no copiaste el .env
chmod 600 .env
docker compose up -d db
./scripts/restore-baserow.sh ./backups/baserow-<fecha>-mudanza
docker compose up -d
```

**El `.env` es obligatorio.** Los secretos no van dentro del respaldo. Si no
tienes el `.env` original, la instancia restaurada arranca pero sin las claves
correctas.

Details en `docs/05`.

---

## 4. C. Conectar una base de datos existente

Esta es la parte que convierte a Baserow en "la capa de administración sobre la
base que el cliente ya tiene", y por eso hay que ser especialmente cuidadoso.

### 4.1 Lo verificado

Del `docker-compose.yml` oficial de Baserow 2.4.1 se confirman estos puntos:

1. **Baserow funciona sobre PostgreSQL como almacén interno.** Usa la imagen
   `pgvector/pgvector:pg15` y exige la extensión `pgvector`
   (`docs/installation/supported.md`: PostgreSQL >= 14, pgvector >= 0.8.1).

2. **Se puede apuntar a un PostgreSQL externo** mediante `DATABASE_URL` o las
   variables `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_NAME`,
   `DATABASE_PASSWORD`. Está documentado en el compose oficial.

3. **Existen controles de seguridad para conexiones salientes**, entre ellos:

   | Variable | Qué controla |
   |---|---|
   | `BASEROW_DATA_SYNC_ALLOW_PRIVATE_ADDRESS` | Permitir conexiones a direcciones privadas |
   | `BASEROW_PREVENT_POSTGRESQL_DATA_SYNC_CONNECTION_TO_DATABASE` | Impedir que la sincronización se conecte a la propia base |
   | `BASEROW_POSTGRESQL_DATA_SYNC_BLACKLIST` | Lista de destinos bloqueados |
   | `BASEROW_SSO_ALLOW_PRIVATE_ADDRESS` | Conexiones a direcciones privadas en SSO |
   | `BASEROW_WEBHOOKS_IP_WHITELIST` / `BLACKLIST` | Filtros de IP para webhooks |

### 4.2 Lo NO verificado — importante

> **Pendiente de verificación: la lista de motores de base de datos externos que
> admite la versión vigente.**

La tarea original indicaba PostgreSQL, MySQL, SQL Server y SQLite. **No se pudo
confirmar contra la fuente** en esta sesión. **Este kit no lo afirma en ninguna
parte.** Hay que verificarlo antes de prometerle a un cliente que puede conectar
su base.

Para verificarlo: la documentación oficial bajo
<https://baserow.io/docs>, sección de bases de datos, en la versión que se esté
instalando.

### 4.3 Reglas para conectar una base del cliente

**Sean cuales sean los motores soportados, estas reglas aplican siempre:**

1. **Un rol de solo lectura.** Baserow muestra y administra: no necesita escribir
   en la base del cliente. Crear un rol con `SELECT` únicamente.
2. **Base de datos dedicada para la instancia interna de Baserow.** Nunca
   mezclar el almacén interno de Baserow con los datos del cliente en la misma
   base.
3. **TLS activado.** Nunca `sslmode=disable` contra una base que no esté en la
   misma red privada.
4. **Credenciales en el gestor de secretos del cliente**, no en el compose ni en
   el repositorio.

---

## 5. Sobre Supabase

**Supabase sí es una opción real en este caso**, a diferencia de otros kits: el
almacén interno de Baserow es PostgreSQL, y por tanto se puede apuntar a un
PostgreSQL de Supabase.

### 5.1 Lo verificado

- Baserow necesita PostgreSQL >= 14 con `pgvector` >= 0.8.1
  (`supported.md`, 2.4.1).
- Se puede configurar un PostgreSQL externo con `DATABASE_URL` o las variables
  `DATABASE_*` (compose oficial 2.4.1).

### 5.2 Lo NO verificado — y por eso no se promete

Al preparar este kit **no se pudo verificar la configuración concreta de
Supabase**: versión de PostgreSQL que ofrece, si la extensión `pgvector` está
habilitada en el plan del cliente, cómo se exige TLS, ni qué tipo de conexión
se necesita.

**Mientras eso no se compruebe con la cuenta real del cliente, este kit no
promete compatibilidad con Supabase.** Afirmarla sin verificar sería exactamente
el tipo de promesa que este kit evita.

### 5.3 Cómo verificarla en la cuenta del cliente

Paso a paso, cuando llegue el momento:

1. Confirmar la **versión de PostgreSQL** del proyecto Supabase. Debe cumplir
   >= 14.
2. Confirmar que **`pgvector` está disponible** en ese proyecto. Es requisito de
   Baserow. Es el punto que más suele fallar.
3. Confirmar la **cadena de conexión** y que la conexión va por **TLS**.
4. Crear el **rol de solo lectura** y una **base dedicada**.
5. Probar la conexión desde la instancia de Baserow.

Si `pgvector` no está disponible en el plan del cliente, Supabase queda
descartado como almacén interno de Baserow en esa cuenta. Eso no significa que
no se pueda usar Supabase para **otra cosa**: ver la sección siguiente.

---

## 6. Traspasar a Odoo u otra plataforma

### 6.1 Conector implementado frente a guía de integración

**En este kit no hay ningún conector implementado hacia Odoo ni hacia ninguna
otra plataforma.** No hay código de integración, ni webhooks configurados, ni
importadores. Lo que hay es una guía.

No hay que venderlo como integración lista.

### 6.2 Si el cliente pide Odoo

Lo razonable es el patrón **API de Odoo hacia la API de Baserow**, que es lo
más simple y lo que menos problemas da:

1. Crear un token de API en Baserow con permiso de escritura limitado.
2. Configurar un disparador en Baserow (webhook) hacia una ruta intermedia.
3. Esa ruta traduce el formato y llama a la API de Odoo.

**El punto 2 es la parte delicada.** Si el destino es una dirección privada, hay
que revisar `BASEROW_WEBHOOKS_ALLOW_PRIVATE_ADDRESS` y las listas de IP del
compose oficial.

Como esto es trabajo a medida, **se cotiza por separado**, y es un servicio, no
una característica del kit.

---

## 7. Resumen honesto

| Afirmación | Estado |
|---|---|
| Baserow usa PostgreSQL como almacén interno | **Verificado** |
| Se puede apuntar a un PostgreSQL externo | **Verificado** |
| `pgvector` es un requisito | **Verificado** |
| Un CSV exportado no es sincronización | **Cierto por definición** |
| Motores externos soportados (MySQL, SQL Server, SQLite) | **Pendiente de verificar** |
| Formatos exactos de importación y exportación | **Pendiente de verificar** |
| Compatibilidad con Supabase | **No verificada. No se promete** |
| Conector a Odoo | **No existe en este kit** |