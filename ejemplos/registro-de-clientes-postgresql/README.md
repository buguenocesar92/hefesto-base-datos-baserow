# DEMOSTRACIÓN — Registro de clientes sobre PostgreSQL existente

> ⚠️ **ESTO ES UNA DEMOSTRACIÓN, NO DATOS REALES.**
>
> Todos los nombres, correos, teléfonos y rut de este ejemplo son **ficticios**,
> inventados para mostrar el kit. No corresponden a personas ni a empresas
> reales. No los uses como datos de prueba en un entorno de producción sin
> reemplazarlos.
>
> Este ejemplo **no se ejecutó**. Fue escrito a partir de la documentación
> oficial de Baserow 2.4.1, pero no se probó contra una instancia real.

---

## Qué demuestra este caso

El uso más valioso de este kit: **darle interfaz y permisos a una base de datos
que el cliente ya tiene.**

Una Pyme tiene su PostgreSQL de producción con las tablas de sus clientes.
Baserow se pone por encima: el equipo de ventas deja de escribir SQL y usa una
interfaz con permisos, mientras la base sigue siendo del cliente y sigue siendo
suya.

---

## Situación

| Elemento | Detalle |
|---|---|
| Empresa | Pyme de servicios, con unas 25 personas |
| Base de datos | PostgreSQL del cliente, en su propio servidor |
| Tabla existente | `clientes` |
| Problema | Cada persona hacía consultas a mano y guardaba Excel sueltos |
| Solución | Interfaz y permisos sobre la base que ya tienen |

---

## Paso 0 — Requisitos, y una advertencia que va primero

**Antes de conectar la base del cliente, hay que responder esta pregunta: ¿qué
motores de base de datos externos admite esta versión de Baserow?**

> **Pendiente de verificación.** Al preparar este kit **no se pudo confirmar la
> lista de motores externos soportados en la versión 2.4.1**. La tarea original
> mencionaba PostgreSQL, MySQL, SQL Server y SQLite, pero **no se pudo verificar
> contra la fuente**, así que este ejemplo **no lo afirma**.

**Confírmalo en la documentación oficial antes de prometer nada al cliente:**
<https://baserow.io/docs>

Lo que **sí** está verificado es que el almacén interno de Baserow es
PostgreSQL, y que se puede apuntar a un PostgreSQL externo con `DATABASE_URL`.

---

## Paso 1 — Crear un rol de solo lectura

La base del cliente se abre **en solo lectura**. Baserow administra y muestra;
no necesita escribir en los datos del cliente.

```sql
-- Ejecutar como administrador de la base del cliente.
-- Ojo: este usuario es para la INSTALANCIA INTERNA de Baserow.

CREATE USER baserow_app WITH PASSWORD 'CAMBIAR_POR_UNA_CLAVE_FUERTE';
GRANT CONNECT ON DATABASE nombre_base TO baserow_app;
GRANT USAGE ON SCHEMA public TO baserow_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO baserow_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO baserow_app;
```

**Nunca** usar aquí el usuario `postgres` ni un rol con permisos de escritura.

**Pendiente de verificar:** la sintaxis exacta de conexión a bases externas desde
la interfaz de Baserow (qué campos pide, dónde se configura). Verificar en una
instancia real.

---

## Paso 2 — Revisar la red

Baserow trae variables para restricting conexiones salientes:

| Variable | Para qué |
|---|---|
| `BASEROW_DATA_SYNC_ALLOW_PRIVATE_ADDRESS` | Permite conexiones a direcciones privadas |
| `BASEROW_POSTGRESQL_DATA_SYNC_BLACKLIST` | Bloquea destinos concretos |

Si la base del cliente está en una red privada, hay que revisar la primera
variable. **No desactivar los controles por comodidad sin saber qué se abre.**

---

## Paso 3 — Levantar la instancia

```bash
cp .env.example .env
chmod 600 .env
# Generar los 4 secretos con openssl rand -base64 32
docker compose up -d
```

Recordar: **crear la primera cuenta antes de exponer el servidor**
(ver `docs/04`).

---

## Paso 4 — La tabla de clientes

La base del cliente ya tiene una tabla así (esquema inventado para el ejemplo):

```sql
CREATE TABLE clientes (
    id           SERIAL PRIMARY KEY,
    rut          VARCHAR(13) NOT NULL,
    nombre       VARCHAR(120) NOT NULL,
    email        VARCHAR(160),
    telefono     VARCHAR(30),
    region       VARCHAR(60),
    activo       BOOLEAN DEFAULT TRUE,
    creado_en    TIMESTAMP NOT NULL DEFAULT NOW()
);
```

**Ese esquema es inventado para la demostración.** El cliente tiene el suyo.

---

## Paso 5 — Dar de alta a las personas

Esto es lo que cambia en el día a día:

| Persona | Permiso | Consecuencia |
|---|---|---|
| Jefa de ventas | Lectura y escritura | Ve y edita clientes |
| Comercial | Lectura y escritura de los suyos | Sin ver los de otros |
| Bodega | Lectura | Solo para consultar stock |
| Administración del sistema | Acceso completo | Con cuidado, y con el mínimo de personas |

**Pendiente de verificar:** los nombres exactos de los roles y cómo se
configuran permisos por fila en Baserow 2.4.1. Confirmar en la instancia antes de
prometer este cuadro a un cliente. Ver `docs/04`.

---

## Paso 6 — Archivo de ejemplo

`clientes-ejemplo.csv` contiene datos **inventados**. Sirve para probar la
importación.

> **Pendiente de verificar:** no se pudo confirmar la lista exacta de formatos
> que la interfaz de importación acepta en 2.4.1. CSV es el punto de partida
> habitual, pero hay que confirmarlo. Ver `docs/09`.

```csv
rut,nombre,email,telefono,region,activo
11111111-1,Empresa Demo Ltda.,contacto@empresa-demo.cl,+56 2 2345 6789,Metropolitana,TRUE
22222222-2,Distribuidora Prueba SpA,admin@distribuidora-prueba.cl,+56 3 2345 1100,Valparaíso,TRUE
33333333-3,Servicios Ejemplo Ltda,info@servicios-ejemplo.cl,+56 41 2345 2200,Biobío,FALSE
```

---

## Lo que este ejemplo NO demuestra

- **No se ejecutó.** No hay evidencia de que estos pasos funcionen tal cual.
- **No es una integración automática.** Una importación de CSV es una foto, no
  una sincronización. Ver `docs/09`.
- **No hay respaldo de la base del cliente en este kit.** Su respaldo es
  responsabilidad de él. Ver `docs/05`.
- **No se verificó la lista de motores externos soportados.**

---

## Qué haría que este ejemplo fuera sólido

1. Verificar la lista de motores externos soportados en 2.4.1.
2. Instalar la instancia y conectar de verdad una base PostgreSQL de prueba.
3. Confirmar el flujo exacto de importación.
4. Documentar los nombres reales de roles y permisos.
5. Añadirlo a `ejemplos/` como caso verificado, con fecha y versión.