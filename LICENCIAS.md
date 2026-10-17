# Licencias — Hefesto Studio, kit Baserow

Este documento existe porque la decisión de qué herramienta se puede revender se
tomó **por licencia, no por sus características técnicas**. Se verificó leyendo los archivos
de licencia en el repositorio oficial de Baserow, etiqueta **2.4.1**.

---

## 1. Por qué Baserow y no NocoDB ni Directus

Esta decisión ya está tomada y verificada. No es una preferencia de gusto.

### 1.1 NocoDB — descartado

NocoDB cambió su licencia de **AGPL-3.0** a la **Sustainable Use License** el
**9 de enero de 2026**.

Consecuencia real: el autoalojamiento interno sigue siendo gratuito, pero
**ofrecer NocoDB como servicio gestionado, dar acceso directo a clientes
externos o revenderlo dentro de un producto de pago exige licencia comercial**.
Como este kit se vende, queda descartado.

Fuente: <https://github.com/nocodb/nocodb/blob/master/LICENSE.md> y comunicados
de la Maintainers License Initiative sobre la Sustainable Use License.

### 1.2 Directus — descartado

Directus usa desde la versión 12 la **Monospace Sustainable Core License**: es
*source-available*, no open source. No está aprobada por la OSI e incluye
restricciones de uso competidor y claves de registro.

Fuente: <https://github.com/directus/directus/blob/main/license>

### 1.3 Baserow — elegido

La **Open Source Edition de Baserow está bajo MIT Expat**, que es una licencia
permisiva: permite usar, modificar, redistribuir, vender y hospedar el software,
incluido comercialmente, conservando el aviso de copyright.

**El cliente puede auditarlo en noventa segundos.** No hace falta creerle a
Hefesto: basta abrir el archivo `LICENSE` en el repositorio.

---

## 2. Licencia por componente — Verificado en la etiqueta 2.4.1

| Componente | Ruta en el repositorio | Licencia | Confirmado |
|---|---|---|---|
| Open Source Edition (backend, interfaz, plugin de base de datos) | `LICENSE` (raíz) | **MIT Expat** | Sí |
| Funciones premium | `premium/LICENSE` | **Baserow Premium Edition License** | Sí |
| Funciones enterprise | `enterprise/LICENSE` | **Baserow Enterprise Edition License** | Sí |

### 2.1 El límite que hay que decir en voz alta

**Las carpetas `premium/` y `enterprise/` NO están cubiertas por la licencia
MIT.** Cada una lleva su propia licencia.

Esto no es una sutileza legal menor. Significa que:

- La edición abierta que instala este kit **no incluye** las funciones premium
  ni enterprise.
- Copiar código de `premium/` o `enterprise/` al proyecto del cliente **saca el
  código del MIT**. No lo hagas.
- Activar esas funciones requiere comprar una licencia a Baserow, por usuario y
  por mes, y registrarla en la instancia.

El propio archivo `premium/LICENSE` lo dice de forma explícita: cualquier parte
del software distribuida como parte de la Open Source Edition sigue bajo MIT
Expat. Es decir, la frontera está dibujada de forma consciente.

Fuente directa del texto de `premium/LICENSE` en 2.4.1:
<https://github.com/baserow/baserow/blob/2.4.1/premium/LICENSE>

### 2.2 Documentación

La documentación del proyecto se publica bajo **CC BY-SA 4.0**.

**Pendiente de verificar:** no se pudo confirmar la ruta exacta del archivo de
licencia de la documentación dentro del repositorio en 2.4.1. Antes de
reutilizar texto o capturas de la documentación en material comercial, hay que
confirmar el archivo y cumplir la atribución y el copyleft de compartición (CC BY-SA).

Fuente: <https://baserow.io/docs/index>

---

## 3. Licencias de los componentes de infraestructura

| Componente | Licencia | Enlace |
|---|---|---|
| PostgreSQL | PostgreSQL License (BSD, tipo BSD) | <https://www.postgresql.org/about/licence/> |
| pgvector | PostgreSQL License | <https://github.com/pgvector/pgvector/blob/master/LICENSE> |
| Redis | BSD de 3 cláusulas | <https://github.com/redis/redis/blob/unstable/COPYING> |
| Caddy | Apache-2.0 | <https://github.com/caddyserver/caddy/blob/master/LICENSE> |
| GNU Bash | GPL-3.0 | Solo se usa en un contenedor efímero para un `chown`; no se distribuye ni se modifica |
| Docker Engine | Apache-2.0 | <https://github.com/moby/moby/blob/master/LICENSE> |

Todas son permisivas salvo GPL-3.0 de Bash, que se usa únicamente para ejecutar
`chown` en un contenedor desechable: no se distribuye, no se modifica y no entra
en la imagen que se entrega al cliente.

---

## 4. Qué es código de Hefesto y qué es de upstream

| Parte | Origen | Licencia |
|---|---|---|
| `compose.yaml` | Hefesto, **simplificado** del compose oficial | MIT Expat (upstream) + comentarios Hefesto |
| `config/Caddyfile` | Upstream, **copiado textual** | MIT Expat (upstream) |
| `.env.example`, `.gitignore` | Hefesto | Hefesto |
| `scripts/backup-baserow.sh`, `scripts/restore-baserow.sh` | Hefesto | Hefesto |
| `docs/` | Hefesto | Hefesto |
| `VERSION.md`, `LICENCIAS.md`, `README.md` | Hefesto | Hefesto |
| Toda la aplicación Baserow | Upstream (Brandon Setmire, Baserow Inc.) | MIT Expat + licencias premium/enterprise |

**Obligación de atribución.** La licencia MIT Expat exige conservar el aviso de
copyright y el texto de la licencia en las redistribuciones. Este kit enlaza al
repositorio original y a los archivos de licencia originales, que es la forma
de cumplirlo. Si se redistribuye una copia de la imagen o del código, hay que
incluir el `LICENSE` de Baserow.

**Aviso:** este kit **no** incluye el código de Baserow. Solo despliega imágenes
oficiales ya construidas. El cliente no recibe código fuente con este paquete.

---

## 5. Resumen para la venta

| Pregunta que hace el cliente | Respuesta honesta |
|---|---|
| ¿Puedo venderlo hospedado? | Sí, la edición abierta es MIT Expat |
| ¿Puedo venderlo dentro de un producto de pago? | Sí, por la misma razón |
| ¿Puedo quitarle el logo de Baserow? | **No.** La atribución es obligatoria bajo MIT |
| ¿Incluye funciones premium? | No. Hay que comprarlas aparte |
| ¿Puedo auditarlo yo mismo? | Sí. `LICENSE` en la raíz del repositorio, 90 segundos |
| ¿Es la base de datos del cliente? | No. Ver el punto siguiente |

### Sobre el punto que más se malinterpreta en la venta

Baserow **no es la base de datos del cliente**. Es una capa de administración
sobre bases que el cliente ya tiene, o su propio almacén interno. No reemplaza
a PostgreSQL ni a MySQL, y no es un "Airtable alternativa" en el sentido de
guardar los datos del cliente en un SaaS ajeno.

Ver el alcance completo en `README.md` y `docs/08-SERVICIOS-COMERCIALES.md`.