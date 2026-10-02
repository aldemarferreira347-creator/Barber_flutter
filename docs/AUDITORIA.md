# Bitácora de auditoría integral

Rama: `audit/integral`. Plan: `docs/superpowers/plans/2026-10-02-auditoria-y-redisenio-integral.md`.
Cada hallazgo se registra como **Hallazgo · Causa raíz · Corrección · Test**.

## Línea base (2026-10-02)

| Indicador | Antes | Después |
|---|---|---|
| `flutter analyze` / `flutter test` | 0 issues / 109 pasan | _(final)_ |
| Functions build / lint / jest | OK / 1 error / 251 | _(final)_ |
| `npm audit --omit=dev` | 2 moderate (`gaxios`) | _(final)_ |
| `Color(0x…)` en `lib/` | 92 | _(final)_ |
| `Colors.white/black` directos | 81 | _(final)_ |
| `Semantics(` / `tooltip:` / `IconButton(` | 1 / 4 / 11 | _(final)_ |
| `.animate(` en vistas / `BoxShadow` / gradientes | 94 / 26 / 8 | _(final)_ |
| Archivos > 400 líneas | 5 vistas (hasta 1351) | _(final)_ |
| Copias del cobro simulado | 4 | _(final)_ |
| `catch (_)` que traga el error | 3 | _(final)_ |
| Tests de reglas ejecutados | 0 (sin JDK ≥ 21) | _(final)_ |

## Decisiones del dueño del producto

- Sin servicios de pago por ahora: no se activa Blaze, ni Nequi real, ni Twilio/SendGrid. El cobro sigue simulado.
- El logo actual (`BrandMark`) es el definitivo.

## Fase 0 — Preparación

- Lint de `functions` en 0 errores (variable `_omit` sin usar en `barbershops.rules.test.ts`).
- **Tests de reglas ejecutables por primera vez.** Se instaló JDK 21 (Temurin). En este Windows el emulador además exige `-Djava.net.preferIPv4Stack=true` y un TEMP corto (`C:/tmp`); `functions/scripts/test-rules.cjs` lo aplica solo → `npm run test:rules`. Resultado: 12 suites, 107 tests (80 previos + 27 nuevos). Antes nunca se habían ejecutado.

## Fase 1 — Seguridad

### Hallazgos de reglas corregidos (cada uno con test que falló antes)

| # | Gravedad | Hallazgo | Causa raíz | Corrección |
|---|---|---|---|---|
| 1 | **Alta** | Un barbero podía cambiarse su propio `barbershopId` a otra barbería y pasar a ser su personal (leer compras, reclamar, responder comentarios) | La rama de auto-edición de `users` no limitaba qué campos tocaba | `barbershopId` inmutable por el propio usuario; solo admin o el dueño de esa barbería lo mueven |
| 2 | **Alta** | Cualquiera podía crear *slots* sueltos y bloquear la agenda entera de un barbero (el id es predecible), o borrar el slot de una cita ajena y reservar encima | `appointmentSlots` permitía `create`/`delete` a cualquier autenticado ("alcance aceptado") | El slot solo existe atado (vía `getAfter`) a una cita **pagada** de quien escribe, con el id exacto de su minuto UTC (`slotIdFor`); borrar solo el cliente de la cita, su barbero, el dueño o el admin |
| 3 | Media | Una cita pagada aceptaba cualquier pago propio: ya usado en otra cita, de otra categoría o ajeno al id | Solo se comprobaba `payerId` | El pago debe ser `category == 'appointment'`, `relatedId ==` id de la cita y `pending` |
| 4 | Media | Cliente, barbero o dueño podían reescribir `clientId`, `barbershopId`, `serviceId` y `servicePrice` de una cita al actualizarla | La rama general de `update` no fijaba la identidad | Esos 4 campos inmutables en toda actualización normal |
| 5 | Media | El dueño, al contratar o dar de baja un barbero, podía alterar cualquier otro dato del perfil (email, teléfono…) | Sin `affectedKeys().hasOnly` | Solo `role` y `barbershopId` |
| 6 | Media | Un autorregistro podía traer `ratingSum/ratingCount` precargados y llegar a Barbero con promedio inflado | `create` de `users` sin restricción de claves | Rechaza `ratingSum`, `ratingCount`, `awaySince`, `awayUntilEstimate` y `barbershopId` no nulo |
| 7 | Media | Cualquier usuario autenticado leía email y teléfono de **todos** los clientes | Lectura de perfiles `role == 'client'` abierta | Solo dueños (`isOwnerRole`), admin y el propio usuario; la búsqueda por correo del dueño sigue funcionando |
| 8 | Baja | Una solicitud de reembolso podía apuntar a una barbería distinta de la de su cita (aparecía en la bandeja equivocada) | No se comparaba `barbershopId` con el de la cita | Debe coincidir |
| 9 | Baja | Servicios/productos aceptaban precio negativo, no numérico o duración 0 | `write` sin validar | `price is number && >= 0`; servicios además `durationMinutes is int && > 0` |

Test obsoleto corregido (no era una regla rota): `users.rules.test.ts` afirmaba que el barbero no puede marcar su regreso, pero la regla vigente lo permite a propósito (`markBarberReturned` sin Blaze); ahora afirma el comportamiento real y que limpiar **un solo** campo falla.

### Revisado y sin cambios

- **Cloud Functions (20 callables):** todas exigen `request.auth`, validan tipo y longitud de cada campo, y la autorización por rol/propiedad vive en los servicios (`shopAuthorization`, `purchaseService`, `commentService`…) con 251 tests Jest en verde. Quedan sin desplegar mientras no haya plan Blaze.
- **Storage:** rutas cerradas por defecto, 5 MB y `image/*`, escritura solo del dueño de esa barbería (o del cupo `{uid}_{1..5}` en borradores).
- **Moderación:** la lista de términos del cliente (Dart) y la del backend (TS) son idénticas y ahora lo comprueba un test.
- **Llaves en el repo:** solo las API keys públicas de Firebase (`firebase_options.dart`, `google-services.json`), que no son secretos; su protección real son las reglas y App Check. No hay claves privadas, `.env` ni keystores versionados.

### Riesgos aceptados (documentados, no corregibles sin servicios de pago)

- **El cobro es simulado en el cliente:** quien paga puede aprobar su propio pago pendiente; las reglas ya impiden reutilizarlo, cambiar el monto una vez creado o usarlo en otra entidad, pero no pueden impedir que el cliente "apruebe" su pago ficticio. Solo un backend con pasarela real lo cierra (requiere Blaze + credenciales).
- **App Check no se fuerza** en las callables (`enforceAppCheck`): es un punto del checklist previo a desplegar Functions, no se puede probar sin Blaze.
- **`npm audit --omit=dev`: 2 moderate** (`uuid` <11.1.1 vía `gaxios` ← `@google-cloud/storage` ← `firebase-admin`). Transitivas; el defecto afecta a `uuid` v3/v5/v6 con `buf`, y `gaxios` usa v4 sin `buf`: sin ruta explotable. `npm audit fix` no puede resolverlas sin `--force` (cambio mayor).
- **Acciones del dueño en la consola de Google Cloud (gratis):** restringir las API keys de Firebase por app/paquete.

### Dependencias

`flutter pub upgrade` dentro de rangos: `geolocator` 14.1.1, `url_launcher` 6.3.3, `image_picker_*`, `google_sign_in_ios` y otras 10 transitivas (14 en total). Sin saltos mayores (`google_fonts` 9 y `cupertino_icons` 2 quedan fuera: cambian de API sin beneficio). `flutter analyze` 0 issues; 110 tests.

## Fase 2 — Errores funcionales e integridad

### Matriz spec → realidad (qué funciona hoy sin servidor)

Leyenda: ✅ funciona de verdad con Firebase gratis (Spark) · ⚠️ existe pero depende de Cloud Functions (plan Blaze), por lo tanto **no corre** hoy · ❌ no existe · 🟡 existe pero engaña o es incompleto.

| Spec | Estado | Observación |
|---|---|---|
| 2 Roles y permisos | ✅ | Reforzado en la Fase 1 |
| 3.1 Centro de notificaciones | 🟡 | La pantalla existe, pero las reglas solo dejan **crear** notificaciones al admin: para cliente/barbero/dueño solo habría avisos manuales |
| 3.1 Push / SMS / correo de respaldo | ⚠️ | Solo backend; el token FCM se guarda, nada envía |
| 3.2 Recordatorios 1 h / 15 min | ⚠️ | `sendAppointmentReminders` es un job programado: no corre. **Se resuelve con recordatorios locales en el dispositivo (Fase 8)** |
| 3.3 Salir/volver del barbero | ✅ | Control funciona y la regla lo permite |
| 3.3 Aplazar solas las citas si no vuelve | ⚠️ | `processOverdueBarbers` no corre |
| 3.4 Cierre por evento externo + penalización | ✅ | Cliente hace el aplazamiento; la notificación a clientes ⚠️ |
| 3.5 Tono de notificaciones | ✅ | |
| 4.1 / 4.2 Vistas, historial, logo | ✅ | Rediseño en Fases 5–6 |
| 5.1 Google + vinculación segura | ✅ | Con tests |
| 6.1 Reserva con y sin pago | ✅ | |
| 6.2 Un solo ganador del horario | ✅ | Transacción + slot; ahora además protegido por reglas |
| 6.3 Cancelar → primero posponer → reembolso con justificación | ✅ | |
| 6.4 Posponer con historial | ✅ | |
| 6.5 Reembolso con checklist de ítems | ✅ | |
| 6.5 Devolución digital **o presencial en efectivo** | ❌ | No hay forma de indicar el medio. **Fase 8** |
| 6.6 Reservar más allá del corte | ✅ | |
| 7.1–7.3 Calificar, comentar, moderar | ✅ | Moderación cliente = backend (test de paridad) |
| 7.4 Lineamientos de conducta | ✅ | En `rate_appointment_view` |
| 8.1 Abrir Google Maps | ✅ | |
| 9.x Recomendación de peinados con IA | ❌ | No empezada (necesita ML Kit + catálogo de diseños). Evaluar al final |
| 10.1–10.2 Catálogo y gestión de productos | ✅ | |
| 10.3 Compra vinculada a cita / directa | 🟡 | Compra directa existe; **vincular a una cita existente no** (`appointmentId` siempre null en la UI) |
| 10.4 Código de reclamo, 24 h | 🟡 | Código y reclamo ✅; **la regla no impide reclamar una compra ya vencida** y nada la marca vencida (`expirePurchases` es un job) |
| 10.5 Verificar ítems ya reembolsados con el código | ✅ | |
| 11.1 Cámara | ✅ | |
| 12.1 Rol Dueño sin barbería aprobada = Cliente | ✅ | `_OwnerGate` |
| 12.2 Múltiples barberías | ✅ | |
| 12.3 Panel del dueño: **reportes, clientes atendidos, actividad por barbero** | ❌ | Hay gestión, no hay reportes. **Fase 8** |
| 12.4 Panel admin: barberías, usuarios, mensualidad | ✅ | |
| 12.5 Mensualidad: registro manual del admin | ✅ | `_confirmPaymentReceived` |
| 12.5 Período de gracia y bloqueo **automáticos** | ⚠️ | `processBarbershopBilling` no corre; existe `paymentInsight` (derivado en pantalla) pero el catálogo no oculta una barbería con gracia agotada. **Fase 8: estado derivado** |
| 12.6 Cancelar y reembolsar citas atrapadas por el bloqueo | ⚠️ | Solo job. Se resuelve junto con el estado derivado (Fase 8) |
| 13 Pagos con Nequi | 🟡 | **No hay integración**: la app crea y "aprueba" el pago ella misma y le dice al usuario "Confirma el pago en tu app Nequi". Engaña. **Fase 8: Nequi manual con confirmación** |

### Revisado y sin cambios

- **Errores tragados:** los 3 `catch (_)` son legítimos (uno relanza tras limpiar la cuenta huérfana, uno cierra una app temporal, uno es limpieza opcional de Google). No se tocan.
- **Estados de error de streams:** los 22 `StreamBuilder/FutureBuilder` ya tienen rama de error con `ErrorState`.
- **Doble envío:** las vistas con formulario (`book_appointment`, `buy_product`, `add_*`, `edit_*`, `rate_appointment`, `close_shop`…) ya bloquean con un flag. **Sin protección:** `owner_barbershop_manage_view._paySubscription` (dos toques = dos cobros, y sin confirmar el monto), `client_appointments_view` (cancelar/posponer), `refund_requests_view._resolve`, `manage_barbershops_view` (aprobar/bloquear), `manage_users_view`, `manage_barbers_view`, `claim_purchase_view`. Se resuelve con un `AsyncButton` compartido (Fase 5) y se aplica en la Fase 6.

### Tests añadidos

- Dueño con barbería **bloqueada**: alerta, ofrece pagar y permite eliminar.
- Regla de borrado: solo se elimina una barbería no aprobada o ya bloqueada.

## Fase 3 — Arquitectura y limpieza

### Ajuste al plan (decisión de eficiencia)

- **T3.1 (unificar el cobro simulado)** se mueve a la **Fase 8**: ahí el cobro simulado desaparece y se reemplaza por Nequi con confirmación manual, así que extraer ahora un helper para borrarlo después sería trabajo doble.
- **T3.2 (partir las vistas gigantes)** se hace **dentro de la Fase 6**, al rediseñar cada una (`manage_users_view` 1351 líneas, `manage_barbershops_view`, `login_view`, `register_view`, `add_barbershop_view`).

### Hecho

| Hallazgo | Corrección | Test |
|---|---|---|
| Al cerrar sesión el token FCM del dispositivo quedaba en el perfil del usuario anterior (`removeFcmToken` existía pero nadie lo llamaba) | `AuthController.signOut` lo retira antes de cerrar la sesión, con límite de 3 s y sin bloquear el cierre si falla | 2 tests nuevos (orden y tolerancia a fallo) |
| Código muerto | Eliminados `models/rating.dart`, `views/widgets/coming_soon_view.dart` y `requestOwnership` (repositorio, servicio y su test; con ello `FirestoreBarbershopService` deja de depender de `cloud_functions`) | suite completa verde |
| Lints permisivos | Activados `avoid_print`, `unawaited_futures`, `use_build_context_synchronously`, `prefer_const_*`, `prefer_final_locals`, `avoid_redundant_argument_values`, `sort_child_properties_last`, `prefer_single_quotes`. `dart fix` aplicó 67 correcciones mecánicas en 24 archivos y se arregló a mano 1 `unawaited` | `flutter analyze`: 0 issues |
| Formato inconsistente (mezcla de 80 y 120 columnas) | `dart format` único sobre `lib/` y `test/` (ancho por defecto) | sin cambios de comportamiento |

### Revisado y sin cambios

- Las únicas referencias de las vistas a `cloud_firestore` son un `GeoPoint` del modelo de dominio: no es acceso a datos.
- Las 5 vistas más grandes siguen pendientes (ver ajuste).
- Pendiente de la Fase 8 (marcados como muertos hoy): `PaymentGateway` / `NequiPaymentGateway` (nadie los consume), `purchase_repository.refundItems` (el reembolso de ítems de productos no está conectado a ninguna pantalla).

## Fase 4 — Rendimiento

| Hallazgo | Corrección | Test |
|---|---|---|
| Las listas de citas (cliente, barbero, barbería) descargaban **todo el historial** en cada apertura, sin tope | `orderBy('date', descending)` + `limit(200)` (incluye las futuras) y se devuelven en orden ascendente para la UI; usan los índices compuestos que ya existían | `watchByClient` con 205 citas entrega 200, en orden |
| Compras, solicitudes de reembolso y notificaciones sin tope | `limit(100)` sobre las más recientes (ya venían ordenadas desc) | suite verde |
| **Defecto:** las reseñas publicadas se mostraban con `.reversed` sobre documentos sin `orderBy` → orden arbitrario | `orderBy('createdAt', desc)` + `limit(100)`; índice compuesto `comments(barbershopId, status, createdAt desc)` añadido a `firestore.indexes.json` | suite verde |

### Revisado y sin cambios

- **Subida de fotos:** ya se comprimen (`maxWidth: 1280`, `imageQuality: 85`) en los 4 puntos de captura.
- **Listeners de `watchByBarbershops`:** abre uno por barbería a propósito (las reglas solo pueden demostrar la propiedad con una consulta por barbería) y los cancela en `onCancel`.
- **Rebuild del tema:** `Consumer<ThemeController>` solo reconstruye al cambiar de tema.
- **No se acotó** `watchAll()` de usuarios (solo admin) ni el catálogo de barberías: sin paginación en pantalla, un tope las ocultaría en silencio. Queda como mejora si la plataforma crece.
- **Imágenes de red:** 13 usos de `Image.network` sin caché en disco (se vuelven a descargar en cada arranque). Se resuelve con un componente compartido (`AppNetworkImage`, `cached_network_image`) en las Fases 5–6.
- **Animaciones:** 94 usos de `flutter_animate` en las vistas; se reducen en la Fase 5.

## Fase 5 — Sistema de diseño

### Referencia

El mockup del repo (`lib/views/img/mockup.png`) es la fuente: negro `#000`, tarjetas `#1A1A1A`, bordes `#2A2A2A`, **botón primario blanco en oscuro**, azul `#3B82F6`, y **badges con fondo teñido y texto de color** (no sólidos). La paleta no cambia; el modo oscuro se alinea a él.

### Hallazgos y correcciones

| Hallazgo | Corrección |
|---|---|
| **El login es inutilizable en modo oscuro** (comprobado en pantalla): usa colores claros fijos (`0xFF0F172A`…) → título casi invisible, campos y botón invisibles | Se corrige al rehacer las pantallas de acceso en la Fase 6; los tokens y el test de abajo impiden que vuelva |
| Accesibilidad: el gris secundario del modo claro daba **4.34:1** sobre el fondo (AA exige 4.5) | `#64748B → #5E6E85` (4.74:1), mismo matiz |
| Badges sólidos con texto blanco: éxito (2.5:1), ámbar (2.1:1) y rojo (3.8:1) **no cumplen AA** | `StatusBadge` teñido con texto `AppColors.readable()` (contraste garantizado por construcción); `AppColors.solid()` para rellenos con texto blanco |
| Navegación inferior propia con `GestureDetector` sin semántica (lectores de pantalla no la ven) y sin versión para pantallas anchas | `RoleShell` sobre `NavigationBar` (teléfono) / `NavigationRail` compacto (tablet) / extendido (escritorio) |
| Decoración sin función: `AnimatedBackground` (manchas flotantes), `PromoBannerCard` (frases motivacionales ×4), degradados, sombras tintadas, animaciones de entrada en todos los componentes | Eliminados; componentes planos con borde fino. Quedan: transición de página, feedback de pulsación y shimmer de carga |
| Tres widgets de etiqueta casi iguales (`StatusBadge`, `ApprovalStatusBadge`, `_PaymentBadge`) + uno más dentro de `AppointmentCard` | Un solo `StatusBadge` |
| Sin forma de evitar doble envío en acciones que escriben datos o cuestan dinero | `AppButton`: si `onPressed` devuelve un `Future`, se deshabilita con indicador hasta terminar |
| 13 `Image.network` sin caché en disco | `AppNetworkImage` (`cached_network_image`, esqueleto y fallback) — se aplica en la Fase 6 |

### Piezas nuevas

`theme/app_tokens.dart` (espaciado, radios, anchos, `ScreenSize`), `theme/contrast.dart` (WCAG), tokens nuevos en `AppColors` (`action`, `onAction`, `onColor`, `surfaceRaised`, `tint`, `readable`, `solid`, `scrim`), tema completo (tipografía, botones, campos, diálogos, hojas, snackbar, chips, switches, navegación) y los widgets `AppButton`, `AppCard`, `SectionHeader`, `AppDialog.confirm`, `AppBottomSheet`, `ResponsiveBody`, `AppNetworkImage`; `StatCard`, `ActionListTile`, `AppointmentCard`, `EmptyState` (con acción opcional), `ErrorState`, `DashboardScaffold` (campana con indicador de no leídas) reescritos.

### Tests

- `contrast_test`: 11 comprobaciones AA (claro y oscuro): texto, acción, enlaces, badges y rellenos sólidos.
- `app_components_test`: doble toque ejecuta la acción una sola vez, se rehabilita si falla, diálogo de confirmación, ancho máximo responsive, estados vacío/error.

### Herramientas de verificación añadidas

`npm run emulators` + `npm run seed` (en `functions/`) levantan Auth/Firestore/Storage con un usuario por rol y datos de ejemplo, y `flutter run --dart-define=USE_EMULATOR=true` (configuración `barber-web-emulator`) conecta la app a ellos: permite recorrer **cada rol en pantalla** con las reglas reales.

### Pendiente de esta fase (se cierra con la Fase 6)

Eliminar los `Color(0x…)` / `Colors.white|black` restantes de las vistas (login, registro, splash y algunas más) y blindarlo con un test que falle si reaparecen.

## Fase 6 — Rediseño por área (EN CURSO)

**Hecho y verificado en la app real contra emuladores (claro y oscuro):** login, registro, teléfono y éxito (el login era inutilizable en oscuro); los 4 dashboards con contenido operativo (cliente: próxima cita real; barbero: resumen de hoy; dueño: actividad por barbería; admin: "requiere tu atención"); catálogo del cliente nuevo (foto, valoración, abierta ahora, búsqueda y filtros); perfil; navegación `NavigationBar`/`NavigationRail`; cambio de tema que ya no reinicia la app (`ThemeScope`); texto por defecto con color principal; precios unificados con `formatCop`; aviso de pago que mostraba código literal.

**Pendiente de la Fase 6:** `IconButton` sin tooltip (6), `Image.network`/`NetworkImage` sin caché en 10 vistas (usar `AppNetworkImage`), partir `manage_users_view` (1351 líneas) y `manage_barbershops_view`, rediseño de las pantallas de gestión del dueño, agenda del barbero, reserva, detalle y compras; `ResponsiveBody` en las listas restantes.

## Fase 7 — Verificación final

_(pendiente: matriz de tamaños × tema × texto grande)_

## Fase 8 — Funcionalidad real sin servidor (PENDIENTE, diseño listo)

1. **Pagos Nequi manuales con confirmación** (reemplazan el cobro simulado, que le dice al usuario "confirma en tu app Nequi" sin enviar nada): el cliente ve el número Nequi de la barbería, paga desde su app y registra la referencia; el dueño/barbero verifica y confirma (o rechaza y se libera el horario). Mensualidad: el dueño paga al número Nequi de la plataforma (configurable por el admin) y el admin confirma. Las reglas dejan de permitir que el pagador apruebe su propio pago (cierra el riesgo aceptado en la Fase 1). Reembolso con medio (Nequi o efectivo).
2. **Sin servidor:** recordatorios locales 1 h y 15 min antes de la cita; bloqueo por mora con gracia como estado derivado y barrido del admin; compras vencidas (la regla debe impedir reclamar tras 24 h).
3. **Ausentes:** "Mis compras" del cliente (hoy no puede volver a ver su código de reclamo), reportes del dueño (clientes atendidos, actividad por barbero), vincular compra a una cita, quitar el stub "Métodos de pago".
