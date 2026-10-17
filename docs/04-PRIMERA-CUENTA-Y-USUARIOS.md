# 04 — Primera cuenta, usuarios y control de acceso

Estado del kit: **kit preparado**. Ninguna de estas comprobaciones se ejecutó
contra una instancia real al preparar el kit.

**Este es el punto de seguridad más delicado de toda la instalación.** Léelo
antes de abrir el servidor al mundo.

---

## 1. El riesgo principal: la primera cuenta

Baserow crea las cuentas desde un formulario de registro en la propia
interfaz web. Eso significa que **en una instancia recién levantada y expuesta al
público, la primera persona que se registre se queda con el control de la
instancia.**

No hay «instalador» que pida crear un administrador. No hay cuenta de
administrador creada de antemano.

### 1.1 Procedimiento seguro, paso a paso

**Nunca abras la instancia a internet antes de crear la primera cuenta.**

```bash
# 1. Publicar SOLO en localhost
#    En .env:
#      HOST_PUBLISH_IP=127.0.0.1
#      BASEROW_PUBLIC_URL=http://localhost

# 2. Levantar
docker compose up -d

# 3. Crear la cuenta desde el navegador, por túnel SSH
#    (desde tu propio equipo)
ssh -L 8080:127.0.0.1:80 usuario@servidor
#    Luego abrir http://localhost:8080 en el navegador

# 4. Solo cuando la cuenta exista y tenga los permisos correctos:
#      HOST_PUBLISH_IP=0.0.0.0
#      BASEROW_PUBLIC_URL=https://datos.miempresa.cl
docker compose up -d
```

La alternativa más simple, si estás en el mismo servidor y no necesitas abrir
nada todavía: entra por `http://IP_DEL_SERVIDOR` **con el cortafuegos cerrado** a
todo menos a tu IP.

### 1.2 Por qué esto importa

Quien se registre primero puede, según los permisos que le toque:

- Crear y borrar bases de datos y tablas.
- Ver todos los datos de todos los usuarios.
- Crear tokens de API con permisos amplios.
- Invitar usuarios y cambiar permisos.

En una instancia recién creada no hay otros usuarios, así que esa persona es
la dueña de hecho.

---

## 2. Cerrar el registro de cuentas nuevas

**Pendiente de verificación importante.** Al revisar el `docker-compose.yml` y
el `.env.example` oficiales de Baserow 2.4.1 **no se encontró ninguna variable
de entorno para desactivar el registro público de usuarios**.

No se escribe aquí ningún nombre de variable para este fin porque no se pudo
verificar que exista, y una variable inventada no da error: Baserow la ignora en
silencio y la instancia sigue abierta al público.

### Qué hacer en su lugar

En orden de preferencia, todas con el mismo objetivo de que nadie más pueda
registrarse:

1. **No abrir la instancia al mundo exterior.** Mantenerla en red interna o
   detrás de VPN. Es la medida más efectiva.
2. **No dar la URL de registro a nadie.** Crear las cuentas una a una e
   invitar por correo.
3. **Revisar el panel de administración de la instancia** y ver si hay un ajuste
   de registro disponible en la interfaz. **Pendiente de confirmar:** el nombre
   exacto de esa opción y su ubicación.
4. Si hay un proxy delante (Nginx, Traefik, Coolify), bloquear la ruta de
   registro en el proxy.

### 2.1 Lo que sí se sabe del comportamiento

Del `docker-compose.yml` oficial se observa que Baserow sí expone controles
relacionados con el acceso público, entre ellos:

| Variable | Qué controla |
|---|---|
| `DISABLE_ANONYMOUS_PUBLIC_VIEW_WS_CONNECTIONS` | Conexiones websocket a vistas públicas |
| `BASEROW_EXTRA_PUBLIC_URLS` | Dominios extra que se consideran parte de la instancia |

Que exista un interruptor para las conexiones anónimas a vistas públicas sugiere
que **las vistas públicas sí pueden exponerse sin autenticación**. Verificar en
la instancia antes de publicar un enlace de vista.

---

## 3. El modelo de permisos

**Pendiente de verificación en detalle.** La documentación técnica de Baserow
confirma que existe un sistema de permisos propio
(<https://github.com/baserow/baserow/blob/2.4.1/docs/technical/permissions-guide.md>),
pero **no se pudo leer el detalle de roles y niveles** al preparar este kit.

Lo que sí está confirmado por el código y la documentación:

- Cada tabla tiene su **esquema propio** dentro de PostgreSQL.
- Cada campo es una columna; internamente se llama `field_{id}`.
- Existen vistas con configuración propia (por ejemplo, dos vistas de la misma
  tabla pueden tener distinto orden y distinto ancho de columna).
- Existe historial de filas.

Fuente: <https://github.com/baserow/baserow/blob/2.4.1/docs/technical/database-plugin.md>

**Antes de prometerle a un cliente un modelo de permisos concreto, hay que
probarlos en la instancia.** La guía técnica de permisos enlazada arriba es la
fuente a revisar.

---

## 4. Crear usuarios después

Procedimiento recomendado una vez que la instancia esté segura:

1. Entrar con la cuenta propietaria.
2. Crear una cuenta por persona, **con correo corporativo real**.
3. Asignar permisos por base de datos o por tabla, no global.
4. Verificar qué puede ver cada persona con una cuenta de prueba.

### 4.1 Correo saliente

Sin `EMAIL_SMTP` configurado, **Baserow no envía correos**. Eso significa que:

- Las invitaciones por correo no llegan.
- No hay recuperación de contraseña.
- No hay avisos automáticos.

En una instalación interna esto es aceptable: se crean las cuentas a mano desde
la interfaz y se entregan las credenciales por un canal seguro. Si el cliente
quiere invitaciones automáticas, hay que configurar el SMTP (ver
`docs/03`, sección 3).

**Nunca enviar la contraseña inicial por correo.** Si se usa invitación, Baserow
manda un enlace; la contraseña la elige la persona.

---

## 5. Archivos adjuntos y su exposición

Dato verificado leyendo el `Caddyfile` oficial de Baserow 2.4.1:

- Los adjuntos se sirven desde la ruta `/media/*`.
- El servidor responde con `X-Content-Type-Options: nosniff` y una
  `Content-Security-Policy` restrictiva. Eso es correcto: impide que un archivo
  subido se ejecute como código en el navegador del usuario.
- El acceso a los archivos lo controla Baserow según los permisos del usuario
  que los solicitó.

**Pendiente de verificar:** si un archivo servido por `/media` puede accederse sin
autenticación cuando quien lo pidió tenía permiso, por ejemplo tras compartir
un enlace. Probar en la instancia antes de afirmar que los adjuntos están
siempre protegidos.

Fuente: `config/Caddyfile` (copia textual del upstream), y
<https://github.com/baserow/baserow/blob/2.4.1/Caddyfile>

---

## 6. Tokens de API

Baserow permite crear tokens para la API REST y GraphQL.

**Reglas que hay que aplicar:**

1. Un token por integración, nunca uno compartido por todos.
2. Darle solo el acceso que necesita esa integración.
3. Guardarlos en el gestor de secretos del cliente, no en un archivo de texto
   en el repositorio.
4. Rotarlos cuando alguien leave la empresa o deja de usarse la integración.

Un token de API con permisos amplios equivale a acceso total a los datos. **No
lo pegues en un canal de chat ni en un ticket.**

---

## 7. Lista de verificación de seguridad antes de entregar

- [ ] La primera cuenta se creó **antes** de exponer el servidor.
- [ ] El registro de nuevos usuarios está efectivamente cerrado o restringido.
- [ ] `BASEROW_PUBLIC_URL` coincide exactamente con la URL real.
- [ ] HTTPS habilitado y funcionando.
- [ ] `SECRET_KEY`, `DATABASE_PASSWORD`, `REDIS_PASSWORD` y
      `BASEROW_JWT_SIGNING_KEY` son distintos entre sí y generados localmente.
- [ ] `.env` con permisos `600` y fuera del repositorio.
- [ ] PostgreSQL y Redis **no** tienen puertos publicados (verificado: el
      compose no publica ninguno de los dos).
- [ ] Cada usuario con el mínimo permiso que necesita.
- [ ] Ninguna vista pública compartida sin revisarla.
- [ ] Respaldo probado: se hizo uno y se comprobó que existe. Ver `docs/05`.