# Corrección de flujos principales (carga, estados vacíos, fotos, cierres, inventario) — Plan de implementación

**Rama de trabajo:** `claude/barbershop-app-bugs-gpqbr2`
**Origen:** pruebas manuales del usuario en teléfono real, roles Cliente, Dueño y Administrador.
**Estado de este documento:** solo plan. No se ha tocado código de la app.

## 1. Qué reportó el usuario, agrupado

| # | Síntoma | Pantallas | Tipo |
|---|---|---|---|
| A | Cliente: no aparecen barberías; "Reservar cita" se queda cargando; no se pueden elegir horarios, servicios ni productos | `client_dashboard_tab`, `barbershop_catalog_view`, `book_appointment_view` | Carga rota |
| B | Admin: "Datos de cobro" (Nequi) no carga y no se pueden guardar | `platform_settings_view` | Carga rota |
| C | Cuenta nueva: "Mis citas", "Mis compras", "Mis barberías" muestran error de conexión en vez de un estado vacío | `client_appointments_view`, `my_purchases_view`, `my_barbershops_view` | Error mal clasificado |
| D | Crear producto con foto de galería: "el objeto no existe en la referencia" | `product_form_sheet`, `firebase_storage_service` | Bug de subida |
| E | Cerrar la barbería sin fecha de regreso debe pedir confirmación y avisar a los clientes con reserva | `close_shop_view`, `cloud_shop_closure_service` | Funcionalidad nueva |
| F | Rol Dueño: gestiona sus barberos, productos, servicios y horarios (solo los suyos). Barberos: manejo básico de productos (qué entró, qué salió) | `manage_*`, reglas | Funcionalidad nueva |
| G | Servicios y productos con precio desde la creación; mejorar su apariencia | `service_form_sheet`, `product_form_sheet`, `catalog_tile` | Mejora |
| H | Sin emojis; falta diferencia de color entre fondo y tarjetas | toda la app, `app_colors`, `app_card` | Visual |
| I | Login que a veces exige varios intentos | `auth_controller`, `auth_gate` | Por investigar |

## 2. Lo que verifiqué en el código (hechos) y lo que NO puedo afirmar todavía

**Hechos**
1. Las pantallas ya distinguen vacío de error: `EmptyState` si la lista llega vacía, `ErrorState` si `snapshot.hasError`. Por eso, si el usuario ve "error", **el stream de Firestore está fallando de verdad** (permisos, índice faltante, documento mal formado o caída de red). No es un problema de "mensaje equivocado" únicamente.
2. Hay 35 `snapshot.hasError` en `lib/`, cada uno con su propio texto y sin reintento ni diagnóstico. No hay un componente único que decida entre cargando, vacío, error y datos.
3. `watchApproved()` (catálogo) combina dos streams: barberías aprobadas **y** `platformSettings/main`. Si el segundo falla, el catálogo entero falla, aunque los días de gracia tengan valor por defecto (4). Además parsea cada documento sin protección: un documento con un campo de tipo inesperado rompe toda la lista.
4. Nada en la app llama a `FirebaseAppCheck`. Si App Check estuviera forzado en la consola, todas las lecturas fallarían en teléfono real.
5. `FirebaseStorageService.uploadBytes` llama a `putData(bytes)` sin `contentType`. Las reglas de Storage exigen `request.resource.contentType.matches('image/.*')`. En Android/iOS el tipo llega vacío, la regla rechaza la subida y luego `getDownloadURL()` falla con "object-not-found", que es el mensaje que describe el usuario. `errorText` no traduce ese código.
6. La reserva (`book_appointment_view`) solo tiene servicio, barbero, día/hora y pago. **No tiene paso de productos**, aunque el usuario lo espera.
7. `Product` no tiene stock ni movimientos. Las reglas de `products` solo dejan escribir al dueño y al admin; un barbero no puede.
8. `CloudShopClosureService` exige fecha final, solo aplaza reservas **pagadas** dentro del rango y no notifica a nadie. Las reglas de `notifications` solo permiten crear al admin.
9. Hay 5 emojis/símbolos en `lib/`: el emoji de mano saludando en el saludo de los 4 dashboards y la marca de verificación en `edit_barbershop_view.dart:281`.
10. `AppColors`: claro `background F1F5F9` vs `surface FFFFFF` y oscuro `000000` vs `1A1A1A`, con borde `E2E8F0` / `2A2A2A` y sin sombras. La separación es mínima, coherente con la queja.
11. `firestore.indexes.json` sí declara los índices que usan las consultas revisadas (citas por cliente, compras por comprador, etc.). El código y los índices del repositorio están alineados.

**No verificable desde aquí (requiere el teléfono o la consola de Firebase)**
- Si las reglas, los índices y Storage de `barber-5082f` están desplegados con la versión actual del repositorio. Es la causa más probable de que fallen a la vez catálogo, datos de cobro, compras y citas, porque todo esto funcionó en emulador.
- Si el teléfono corre contra el proyecto real o contra emuladores (`USE_EMULATOR`). Con teléfono físico, `10.0.2.2` no funciona.
- El código exacto de error (`permission-denied`, `failed-precondition` por índice, `unavailable`...). Hoy la app lo oculta tras un texto genérico.

Por eso la Fase 0 es diagnóstico, no código de corrección. No se debe "arreglar" a ciegas.

## 3. Principios de diseño (SOLID aplicado a este problema)

- **S, responsabilidad única:** un widget `AsyncStateView<T>` decide cargando/vacío/error/datos; las pantallas solo dicen cómo pintar los datos. Un `FailureMapper` traduce excepciones a mensajes; ya no se hace en cada pantalla.
- **O, abierto/cerrado:** nuevos estados (por ejemplo "sin permiso" o "sin conexión") se agregan al mapper sin tocar las 35 pantallas.
- **L, Liskov:** todo repositorio devuelve el mismo contrato: lista vacía cuando no hay datos, error tipado solo cuando algo falla. Un documento inexistente (`platformSettings/main`, usuario sin citas) nunca es error.
- **I, segregación de interfaces:** separar `BarbershopRepository` (hoy ~25 métodos) en lectura de catálogo, gestión del dueño y administración. Los widgets del cliente dependen solo de la lectura.
- **D, inversión de dependencias:** las pantallas siguen dependiendo de interfaces (ya se hace); el nuevo servicio de inventario y el de notificaciones de cierre entran igual por `Provider`.

Contrato de errores (tipos propios, en `lib/core/failures.dart` o similar):

| Situación | Tipo | Qué ve el usuario |
|---|---|---|
| Colección o documento sin datos | (no es error) | Estado vacío con mensaje motivador y acción |
| Sin red / `unavailable` / timeout | `NetworkFailure` | "Sin conexión" + Reintentar |
| `permission-denied` | `AccessFailure` | "No tienes acceso a esto" (y log técnico) |
| `failed-precondition` por índice | `ConfigFailure` | Mensaje genérico al usuario; en debug, el enlace del índice |
| Documento mal formado | `DataFailure` | Se omite el documento y se registra; la lista sigue |
| Cualquier otra | `UnknownFailure` | "Algo salió mal" + Reintentar |

## 4. Fases

### Fase 0. Diagnóstico de causa raíz (bloquea las fases 1 a 3)
Objetivo: saber por qué falla la carga en el teléfono antes de corregir nada.
1. Añadir un registro de errores (`debugPrint` con `code`, `message`, ruta de la consulta) en un único punto: `SharedStreams` (todos los servicios pasan por ahí).
2. Verificar con el usuario o la consola: ¿teléfono contra proyecto real o contra emulador?
3. Comparar lo desplegado con el repositorio: `firebase deploy --only firestore:rules,firestore:indexes,storage --dry-run` y revisar en la consola que la versión de reglas coincide. Confirmar que existe el bucket de Storage.
4. Revisar App Check en la consola (Firestore y Storage: ¿en "Enforce"?).
5. Reproducir los tres casos (catálogo, datos de cobro, mis compras) y anotar el código exacto.
6. Entregable: sección "Causa raíz" añadida a `docs/AUDITORIA.md` con el código de error y la decisión.

Salida posible: (a) reglas/índices sin desplegar, se despliegan y se documenta el paso; (b) App Check forzado sin inicializar, se inicializa en la app o se desactiva el enforcement; (c) emulador mal apuntado, se documenta; (d) dato corrupto, se resuelve en la Fase 1.

### Fase 1. Capa de datos resiliente (núcleo)
1. `FailureMapper` + tipos de falla (tabla anterior); reemplaza el uso suelto de `errorText` y se amplía con `object-not-found`, `unauthorized` y `canceled` de Storage.
2. `AsyncStateView<T>`: recibe un `Stream<T>`, un `isEmpty`, un `empty` y un `builder`. Incluye tiempo máximo de espera (por ejemplo 12 s) que pasa de "cargando" a error con Reintentar, para eliminar el spinner infinito.
3. `SharedStreams`: al fallar una consulta, descartar la entrada para que "Reintentar" abra una nueva; hoy puede quedar un oyente muerto hasta 20 s.
4. Parseo tolerante: `Barbershop.fromMap` y los demás modelos devuelven `null`/omiten el documento dañado y registran el id.
5. Desacoplar `watchApproved()` de `platformSettings`: si la configuración no carga o no existe, usar `kDefaultGraceDays`. El catálogo nunca depende de un documento del admin.
6. Migrar las 35 pantallas con `hasError` al nuevo componente, en este orden de prioridad: catálogo, destacadas del cliente, reserva, mis citas, mis compras, mis barberías, datos de cobro, dashboards.
7. Tests: documento inexistente → vacío; `permission-denied` → error; timeout → error con reintento; un documento malformado entre cinco sanos → cuatro visibles.

### Fase 2. Cliente: catálogo y reserva completa
1. Catálogo y "Barberías destacadas" sobre `AsyncStateView`. Vacío: "Aún no hay barberías cerca. Vuelve pronto." con acción de actualizar.
2. Reserva por pasos con resumen persistente: servicio, barbero, día y hora, **productos opcionales**, forma de pago.
3. Productos en la reserva: lista de productos activos con cantidad; al confirmar se crea la compra con `appointmentId` (el parámetro ya existe en `createPurchase`). Se valida en reglas que el producto pertenezca a esa barbería (ya se hace).
4. Horarios: las horas salen del horario de la barbería y del barbero, descontando `appointmentSlots` ocupados y cierres vigentes. Si no hay horas libres, mensaje explícito y sugerencia de otro día.
5. Si la barbería no tiene servicios o barberos aún, estado vacío que lo explique y no un spinner.
6. Tests de widget con repositorios falsos: barbería sin servicios, sin barberos, con cierre vigente, con horario ocupado.

### Fase 3. Estados vacíos motivadores (cuenta nueva)
Regla: vacío nunca usa el estilo de error. Textos propuestos (a validar con el usuario):

| Pantalla | Título | Subtítulo | Acción |
|---|---|---|---|
| Mis citas | Tu primera cita te espera | Elige una barbería y reserva en menos de un minuto. | Reservar cita |
| Mis compras | Aún no has comprado nada | Cuando compres un producto, aquí verás tu código de reclamo. | Ver barberías |
| Mis barberías | Registra tu primera barbería | Empieza a recibir reservas y gestiona tu equipo desde aquí. | Registrar barbería |
| Notificaciones | Todo al día | Te avisaremos de reservas, pagos y cierres. | (ninguna) |
| Barberos / productos / servicios (dueño) | Aún no hay [barberos] | Agrega el primero para que los clientes puedan [reservar / comprar]. | Agregar |

Estos estados vacíos ya existen en varias pantallas pero no se alcanzan porque el stream falla; la Fase 1 los hace visibles. Aquí solo se unifican textos y se agregan las acciones.

### Fase 4. Administrador: Datos de cobro
1. Causa probable: el mismo fallo de la Fase 0 (la lectura de `platformSettings/main` falla). Confirmar en Fase 0.
2. Corrección de lógica: documento inexistente = formulario con valores por defecto vacíos y botón "Guardar" habilitado (primera configuración), nunca error.
3. Validar el formulario con las mismas reglas que Firestore (Nequi de 10 dígitos que empieza por 3, tarifa mayor que 0, gracia entre 0 y 30) y mostrar errores por campo.
4. Renombrar de forma consistente el apartado: "Datos de cobro (Nequi)".
5. Test: admin sin documento → formulario vacío → guardar → documento creado.

### Fase 5. Fotos de productos, servicios y barbería
1. `StorageRepository.uploadBytes` recibe `contentType` obligatorio. El tipo se toma de `XFile.mimeType` y, si es nulo, de la extensión del archivo (`jpg`, `png`, `webp`, `heic`).
2. Verificar `TaskSnapshot.state == success` antes de pedir `getDownloadURL()`; si no, lanzar `StorageFailure` con el código real.
3. `FailureMapper`: mensajes claros para `object-not-found`, `unauthorized`, `quota-exceeded`, `canceled`, `retry-limit-exceeded`.
4. Orden de operaciones al crear: subir foto → crear documento con `photoUrl`; si el documento falla, borrar la foto subida (evita huérfanas).
5. Aplicar a servicios, productos, portada de barbería y borradores (los cuatro comparten el servicio).
6. Comprobar que `storage.rules` aceptan el `contentType` enviado y que el límite de 5 MB se respeta (`image_picker` ya reduce a 1280 px, calidad 85).
7. Tests: unitario del resolvedor de `contentType`; prueba de reglas de Storage (imagen válida pasa, sin tipo o tipo no imagen falla). Prueba manual en teléfono con foto de galería y de cámara.

### Fase 6. Dueño y barberos: alcance por rol, precios e inventario
**Alcance:** un dueño solo ve y edita lo de sus barberías (ya lo exigen las reglas con `isOwnerOfShop`); añadir pruebas de reglas que lo demuestren con dos dueños distintos.

**Precio desde el inicio:** en el formulario ya es obligatorio; endurecer la regla a `price > 0` para productos y servicios (hoy `>= 0`).

**Inventario básico (nuevo):**
- `Product.stock` (entero, mínimo 0) y subcolección `barbershops/{id}/products/{pid}/movements/{mid}` con `type` (`in`/`out`), `quantity`, `reason`, `byUserId`, `createdAt`.
- `InventoryRepository.registerMovement(...)`: transacción que valida stock suficiente, actualiza `stock` y crea el movimiento. Tipo `out` con motivo "venta en local", "reclamo de compra", "merma".
- Reglas: el personal de la barbería (dueño y barberos asignados, `isStaffOfShop`) puede crear movimientos y modificar **solo** el campo `stock` del producto, sin cambiar nombre ni precio. Solo el dueño edita el catálogo.
- Reclamo de compra (`claim_purchase_view`): al marcar reclamada, registrar la salida automática.
- UI barbero: pantalla "Inventario" con lista, stock actual, botones Entrada/Salida y el historial de movimientos. UI dueño: mismo historial con filtro por barbero.
- Stock bajo: etiqueta visible cuando es 0 o menor al umbral (por defecto 3, a confirmar).
- Tests de transacción (no permite stock negativo; dos salidas simultáneas) y de reglas por rol.

### Fase 7. Cierre de barbería con confirmación y notificaciones
**Modelo:** `closedUntil` pasa a ser opcional. `closedUntil == null` significa cierre indefinido, "hasta nuevo aviso".

**Flujo en `close_shop_view`:**
1. El dueño elige inicio, fin opcional y motivo.
2. Sin fecha de regreso, aparece un modal con dos opciones: "Sí, cerrar hasta nuevo aviso" y "No, elegir fecha". El texto explica que no se volverá a abrir hasta que el dueño la reabra y que se avisará a todos los clientes con reservas o compras abiertas.
3. Con fecha, se mantiene la confirmación actual.

**Afectados:** todas las citas futuras en estado `pending`, `accepted` o `postponed` (pagadas o no) y las compras `pending_payment` o `pending_claim`, dentro del rango o sin límite si es indefinido.
- Citas pagadas: se aplazan y se conserva el descuento de calificación ya definido en la especificación (3.4). Citas sin pago: se cancelan con motivo "cierre de la barbería", sin penalización.
- Compras por reclamar: se mantienen y se avisa; si el cierre es indefinido, el aviso indica contactar a la barbería.

**Notificaciones (sin Cloud Functions, porque no hay plan Blaze):**
- Hoy solo el admin puede crear `notifications`. Nueva regla: el dueño de la barbería puede crear una notificación de tipo `shop_closure` solo si el id del documento es determinista (`closure_{closureId}_{appointmentId|purchaseId}`) y el `toUserId` coincide con el `clientId`/`buyerId` de ese documento (verificado con `get()` en la regla). Esto impide que un dueño escriba a usuarios ajenos.
- Escritura en lotes de máximo 400 operaciones por batch, con id determinista para que reintentar sea idempotente.
- El cliente ve la notificación al abrir la app y se programa un aviso local con `flutter_local_notifications` si el dispositivo tiene la sesión abierta. No habrá push cuando la app está cerrada hasta que exista backend; queda documentado como limitación.
- Estado visible de "cerrada" en catálogo y detalle; la reserva y la compra se bloquean mientras dure el cierre (regla y UI). Botón "Reabrir barbería" para el cierre indefinido, que también notifica.
- Tests: cierre con y sin fecha, modal de confirmación (ambas ramas), idempotencia, regla de notificaciones (dueño ajeno rechazado), más de 400 afectados.

### Fase 8. Sistema visual y emojis
- **Aviso:** pediste usar la skill de estilo Apple "ya configurada", pero en esta sesión no hay ninguna skill con ese nombre disponible (solo `artifact-design`, `dataviz` y otras ajenas a Flutter). Hasta que me indiques cuál es o la agregues al repositorio, el criterio será el de Apple Human Interface (jerarquía por capas, tipografía clara, espacio generoso) aplicado sobre los tokens existentes de `AppColors` y `AppTokens`.
- **Capas de color:** definir tres niveles explícitos (fondo, superficie, superficie elevada) con separación visible. Claro: fondo `E8EDF3`, tarjeta `FFFFFF`. Oscuro: fondo `000000`, tarjeta `1C1C1E`, elevada `2C2C2E`. Borde más visible (`CBD5E1` claro, `38383A` oscuro). Valores a validar con la prueba de contraste existente (`contrast.dart`).
- **Profundidad sin ruido:** una sombra suave de una sola capa solo en tarjetas tocables y hojas modales (la auditoría anterior quitó las sombras decorativas; esta es funcional, no decorativa). Decisión a confirmar contigo.
- **Servicios y productos:** `catalog_tile` con foto cuadrada grande, nombre, precio destacado, estado activo/oculto y, en productos, stock. Formularios con la foto arriba y el precio visible desde el inicio.
- **Emojis:** quitar el emoji del saludo de los cuatro dashboards y la marca de verificación de `edit_barbershop_view.dart`; usar `Icons.*` o `CustomIcons`. Añadir un test que recorre `lib/` y `functions/src/` y falla si encuentra emojis o símbolos pictográficos, para que no vuelvan.
- Matriz responsive existente (4 tamaños, claro/oscuro, letra 1.0/1.5) se vuelve a ejecutar tras el cambio de color.

### Fase 9. Inicio de sesión inestable
- Investigar por qué a veces se necesitan varios intentos: `catchError((_) {})` en `auth_controller.dart:98`, `catch (_)` en `:238` y `:337`, y la carga del perfil en `auth_gate`.
- Registrar el código real de cada fallo, distinguir credenciales inválidas de red o de perfil aún no creado, y reintentar automáticamente la lectura del perfil una vez antes de mostrar error.
- Test del controlador con servicio de autenticación falso que falla una vez y luego responde.

### Fase 10. Verificación y entrega
- `flutter analyze` sin hallazgos, `flutter test` completo, y en `functions/`: build, lint, jest y `npm run test:rules` (con JDK 21).
- Recorrido con emuladores: cuenta nueva por cada rol (cliente, dueño recién aprobado, barbero, admin) comprobando que ninguna pantalla muestra error con base vacía.
- Prueba en teléfono real contra el proyecto real con la lista de comprobación: catálogo, reserva con producto, mis citas/compras/barberías vacías, foto de producto, datos de cobro, cierre con y sin fecha, inventario del barbero.
- Registrar en `docs/AUDITORIA.md` hallazgo, causa raíz, corrección y test por cada fase.
- Paso de despliegue documentado: reglas, índices y Storage (acción tuya o con tu autorización explícita; yo no despliego a producción sin que lo pidas).

## 5. Orden y dependencias

```
Fase 0 (diagnóstico)
   |
Fase 1 (capa resiliente) ----+--> Fase 2 (cliente) --> Fase 3 (vacíos)
   |                         +--> Fase 4 (admin: datos de cobro)
   |
Fase 5 (fotos)  [independiente, puede ir en paralelo con la 1]
   |
Fase 6 (dueño/inventario) --> Fase 7 (cierres, usa citas y compras)
   |
Fase 8 (visual + emojis)  [al final de cada bloque, o en paralelo; toca muchos archivos]
Fase 9 (login) [independiente]
Fase 10 (verificación) al cierre de cada fase y final
```

Una rama, un commit por fase, cada commit con analyze y tests en verde. Sin push a producción ni despliegue sin tu aprobación.

## 6. Decisiones que necesito de ti

1. ¿Cuál es la skill de estilo Apple que mencionas y dónde está configurada? No aparece en esta sesión.
2. ¿Teléfono real contra el proyecto Firebase real, o contra emulador? Y, si tienes acceso a la consola, ¿están desplegadas las últimas reglas e índices y está activado App Check?
3. Cierre sin fecha: ¿las citas sin pago se **cancelan** o se **aplazan** como las pagadas? (propongo cancelar, sin penalización).
4. Cierre y notificaciones: ¿aceptas que, sin plan Blaze, el aviso llegue dentro de la app (y como aviso local si está abierta), sin push con la app cerrada?
5. Inventario: ¿umbral de stock bajo en 3 unidades? ¿Los barberos pueden también ajustar el precio? (propongo que no).
6. Sombra suave funcional en tarjetas tocables y modales: ¿sí o no?

## 7. Riesgos

- Si la causa de la Fase 0 es de despliegue, parte de lo reportado se corrige sin código; el riesgo es aplicar cambios de código innecesarios. Por eso se diagnostica primero.
- Migrar 35 pantallas a un componente común toca muchos archivos; se hace por bloques con tests de widget para no romper la matriz responsive.
- Las reglas nuevas (notificaciones de cierre, stock) usan `get()`; Firestore limita las lecturas por evaluación. Se prueban en el emulador con los casos máximos antes de dar por buena la fase.
- Sin backend no hay push con la app cerrada: es una limitación de plataforma, no de este plan.
