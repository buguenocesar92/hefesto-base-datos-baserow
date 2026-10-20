# 08 — Servicios comerciales

Estado del kit: **kit preparado**.

---

## 1. Qué vendemos, en una frase

> Instalación y operación de una base de datos interna para la Pyme, sin límite
> de filas, sobre software con licencia abierta que el cliente puede auditar.

**No vendemos** "la base de datos del cliente". Vendemos la **capa de
administración**: interfaz, permisos y API por encima de datos que el cliente
ya tiene o que se guardan en su propio servidor.

---

## 2. A quién le sirve

Buen ajuste:

- Pymes que hoy usan Airtable o Microsoft Lists y están pagando por filas.
- Equipos que quieren una base interna y no quieren que sus datos estén en un
  SaaS ajeno.
- Empresas que ya tienen PostgreSQL y quieren una interfaz para que los use
  personal que no programa.
- Organizaciones con requisitos de datos en territorio nacional.

**Mal ajuste:**

- Quien busca reemplazar su base de datos de producción. Esto no lo hace.
- Quien necesita una aplicación pública de alto tráfico.
- Quien necesita multi-tenant. Ver sección 5.

---

## 3. El argumento de los límites de filas

Este es el argumento de venta central, y está **verificado con cita textual**.

### 3.1 Lo que Baserow promete para el autoalojamiento

Del sitio oficial de Baserow, sección de preguntas frecuentes:

> "The self-hosted versión will never have row, storage, or API request
> limitations. It will always be unlimited and free."

> "Baserow Self-Hosted will never place limits on rows, records, webhooks, or
> API requests—they will always be unlimited."

> "Does Baserow have a rate limit? — The self-hosted versión of Baserow does not
> have a rate limit. The hosted versión has a rate limit of maximum 10 concurrent
> requests."

Fuente: <https://baserow.io/pricing> (sección de preguntas frecuentes), y
<https://baserow.io/faq>

### 3.2 Lo que la nube sí limita

Del mismo sitio:

> "Each Baserow Cloud plan has specific row limits. If a workspace exceeds its row
> limit for 7 days, you won't be able to create new rows. You'll receive an error
> message explaining that you must either upgrade your plan or reduce your row
> count to continue adding data."

> "In Baserow Cloud, there's a limit of 10 concurrent API requests. This limit is
> subject to a fair use policy... For webhooks in Baserow Cloud, there is a
> maximum capacity of 5,000 pending calls per webhook."

**Pendiente de verificar:** las cifras exactas de filas por plan (los valores
que la tarea original entregaba: 3.000 en Free, 50.000 en Premium, 250.000 en
Advanced y 1.000.000 en Enterprise) **no se pudieron confirmar** contra la
página de precios, que se carga de forma dinámica y no entregó los números al
ser consultada.

**Por eso no aparecen como cifra en ningún documento de este kit.** Cuando se
confirmen, la comparación queda así:

| Plan en la nube | Límite de filas | En autoalojamiento |
|---|---|---|
| Free | (verificar) | Sin límite |
| Premium | (verificar) | Sin límite |
| Advanced | (verificar) | Sin límite |
| Enterprise | (verificar) | Sin límite |

Lo que **sí** está verificado y sostiene el argumento: la nube impone límites
por plan, y el autoalojamiento no los tiene.

### 3.3 Cómo usarlo en la venta, con honestidad

Correcto: "Esta instalación no tiene el techo de filas que tiene el plan
gratuito de la nube. Baserow lo dice por escrito en su sitio: el autoalojamiento
no tiene límites de filas, almacenamiento ni peticiones de API."

Incorrecto: "Puede tener un millón de filas sin problema." Eso depende del disco
del servidor y del trabajo que haga, no de una promesa del proveedor.

---

## 4. Por qué Baserow y no NocoDB ni Directus

La decisión se tomó **por licencia**, y es el mejor argumento del producto: el
cliente lo audita en noventa segundos.

| Herramienta | Licencia | ¿Se puede revender? |
|---|---|---|
| **Baserow (edición abierta)** | **MIT Expat** | **Sí** |
| NocoDB | Sustainable Use License, desde 2026-01-09 | **No** sin licencia comercial |
| Directus | Monospace Sustainable Core License, source-available | **No** |

**NocoDB** cambió de AGPL-3.0 a Sustainable Use License el 9 de enero de 2026.
El autoalojamiento interno sigue libre, pero ofrecerlo como servicio gestionado,
dar acceso directo a clientes externos o revenderlo dentro de un producto de pago
exige licencia comercial.

**Directus** usa desde la versión 12 la Monospace Sustainable Core License:
*source-available*, no aprobada por la OSI, con restricción de uso competidor y
claves de registro.

**Baserow** mantiene la edición abierta bajo MIT Expat, que es permisiva.

Detalles y fuentes en `LICENCIAS.md` y `docs/10`.

### 4.1 La licencia que hay que mostrar

El cliente puede abrir `LICENSE` en la raíz del repositorio de Baserow y ver que
es MIT Expat. **Invítalo a hacerlo.** Una venta que se sostiene en que el
cliente pueda verificar la licencia es una venta mucho más sólida que una que
depende de nuestra palabra.

---

## 5. Lo que NO es este producto

### 5.1 No es una base de datos

Baserow es una **capa de administración**. La base de datos del cliente sigue
siendo del cliente: PostgreSQL, MySQL u otro. Este kit tampoco reemplaza a
ninguna: su base interna guarda definiciones y datos propios de Baserow.

**Prometer que esto reemplaza a la base de datos del cliente es la forma más
rápida de perder al cliente y perder la confianza.**

### 5.2 No es multi-tenant

**Una instancia es para un cliente.** No hay aislamiento entre inquilinos.

Si el cliente tiene varias sucursales y quiere una sola instancia para todas,
eso se puede hacer **con permisos**, no con aislamiento: quien tenga permiso ve
lo que tenga permiso. **No es multi-tenancy y no debe venderse como tal.**

Para varios clientes hay que levantar una instancia por cliente.

### 5.3 Lo que la edición abierta no incluye

**Las carpetas `premium/` y `enterprise/` NO están bajo la licencia MIT.** Cada
una tiene su propia licencia.

Consecuencia para el cliente: **la edición abierta no incluye las funciones
premium ni enterprise.** Si las necesita, hay que comprar una licencia a
Baserow, por usuario y por mes, y registrarla en la instancia.

**Pendiente de verificar:** la lista exacta de funciones que quedan fuera de la
edición abierta **no se pudo leer en detalle** en esta sesión. Antes de
responder a un cliente "¿tiene la función X?", hay que revisarlo en la
documentación oficial de comparación de planes. No conviene improvisar esa
respuesta.

### 5.4 Lo que este kit no incluye

- No incluye el código de Baserow: solo despliega imágenes oficiales.
- No incluye migración de datos desde Airtable o Microsoft Lists.
- No incluye un panel de métricas ni monitoreo.
- No incluye soporte 24/7.
- Los scripts de respaldo y restauración **no se ejecutaron nunca** contra una
  instancia real. Ver `docs/07`.

---

## 6. Qué se puede cobrar

| Servicio | Nota |
|---|---|
| Instalación inicial | Producto principal de este kit |
| Migración de datos | Servicio aparte. No incluido aquí |
| Actualizaciones y mantenimiento | Recurrente |
| Revisión de permisos y usuarios | Punto de entrada fácil |
| Integración con sistemas del cliente | Servicio aparte |
| Respuesta a incidentes | Solo si hay contrato |

**Al cotizar, dejar claro el alcance del respaldo:** cubre el almacén interno de
Baserow y los adjuntos. Las bases de datos del cliente son responsabilidad
suya. Ver `docs/05`, sección 3.

---

## 7. Argumentos que no hay que usar

| No decir | Por qué |
|---|---|
| "Es un reemplazo de Airtable" | Es una capa sobre bases del cliente, no un SaaS equivalente |
| "Tiene límites ilimitados garantizados" | El límite pasa a ser el servidor: disco y memoria |
| "Es multi-empresa" | No lo es. Una instancia, un cliente |
| "Es open source" sin más | La edición abierta lo es; premium y enterprise no |
| "Incluye todas las funciones" | La edición abierta no incluye premium ni enterprise |
| "Sus datos están respaldados" | Sin decir que los del cliente no están en ese respaldo |
| "Baserow nunca cambia la licencia" | Una empresa puede cambiar de licencia. La de hoy es MIT, la de mañana no se sabe |