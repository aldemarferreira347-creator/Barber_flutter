# Estado del proyecto y pendientes

Este documento resume qué está hecho, qué sigue en progreso y qué falta,
para retomar el trabajo sin perder contexto. Se basa en el plan original
(`C:\Users\jaime\.claude\plans\immutable-noodling-seal.md`) y en el estado
real del código a la fecha.

## Hecho y commiteado (Fases 0–11 + alineación visual)

Todo esto ya está en `master` y subido a
https://github.com/aldemarferreira347-creator/Barber_flutter :

- **Fase 0** — Backend Cloud Functions, `StorageRepository`, harness de tests.
- **Fase 1** — Sistema de notificaciones (push/SMS/correo, tono personalizado).
- **Fase 2** — Identidad visual, historial de citas, geolocalización.
- **Fase 3** — Vinculación segura de cuentas Google.
- **Fase 4** — `PaymentGateway` + Nequi simulado.
- **Fase 5** — Productos, compras con código de reclamo y expiración 24h.
- **Fase 6** — Citas pagadas, bloqueo transaccional de horario, posponer/reembolso.
- **Fase 7** — Recordatorios automáticos de cita (1h / 15min).
- **Fase 8** — Disponibilidad del barbero y aplazamiento automático.
- **Fase 9** — Cierre de tienda por evento externo (penalización de calificación).
- **Fase 10** — Calificaciones, comentarios y moderación automática.
- **Fase 11** — Gestión multi-barbería: aprobación de barberías, mensualidad,
  ascenso a Dueño (spec 12.1–12.6). Verificada: `flutter analyze` sin
  hallazgos, `flutter test` 52/52, `dart format` aplicado; en `functions/`
  build + lint + test (40 suites / 251 tests) en verde.
- **UI** — Login/registro/dashboards alineados al sistema de diseño de referencia
  compartido por el usuario; barbería con foto de portada real.
- **UI — rediseño completo (mockups Splash/Login/Registro/Homes/Perfil/Gestión)**:
  - `BrandMark` (`lib/views/widgets/brand_mark.dart`): poste de barbería
    dibujado con `CustomPainter`, reemplaza el ícono de tijeras genérico en
    splash, login, registro y registro exitoso.
  - Splash con fondo degradado + tagline "Gestiona · Organiza · Crece".
  - Registro: header con marca + wordmark, línea de "Términos y condiciones"
    (diálogo informativo). Se decidió a propósito **no** agregar selector de
    rol aunque el mockup lo muestre — el autorregistro sigue creando siempre
    una cuenta de Cliente (ver comentario en `register_view.dart`); las
    demás vías de alta (Dueño paga suscripción, Barbero lo crea su Dueño,
    Admin no se autorregistra) ya están documentadas y protegidas en backend.
  - Headers de los 4 dashboards (Admin/Dueño/Cliente/Barbero) con ícono de
    notificaciones + avatar.
  - Admin: tercera acción rápida "Configuración del sistema".
  - Perfil: botón "Cerrar sesión" pasó de outline rojo a `FilledButton`.
  - Panel de Barbero (`barber_dashboard_tab.dart`) rediseñado por completo
    siguiendo el mockup detallado: banner "Hoy N citas" con degradado +
    botón "Ver calendario", fila de accesos rápidos (Perfil/Disponibilidad/
    Servicios), tarjeta "Tu barbería" (si tiene una asignada) y tarjeta
    "Resumen". Los items de su menú de perfil se extrajeron a
    `barber_profile_items.dart` para compartirlos entre el tab "Perfil" y
    el acceso rápido del panel.
  - Verificado en vivo con `flutter run -d web-server`: Splash/Login/Registro
    calzan pixel a pixel con el mockup. Las pantallas autenticadas (Homes,
    Perfil, Gestión de usuarios/barberías, Detalle) no se probaron en el
    navegador porque requieren iniciar sesión contra el Firebase real del
    proyecto — se validaron por revisión de código, `flutter analyze` y
    `flutter test` (52/52 en verde). El resto de las ~40 vistas del proyecto
    ya comparte el mismo sistema de diseño (`AppColors`/tarjetas/badges):
    una búsqueda de colores fuera de `AppColors` no encontró ninguno.
- **Modo oscuro real** — `AppColors` pasó de constantes fijas a getters
  dinámicos (`lib/theme/app_colors.dart`) según `AppColors.isDark`;
  `ThemeController` (`lib/theme/theme_controller.dart`, con
  `shared_preferences` para persistirlo) notifica y fuerza un rebuild de
  toda la app vía `Consumer<ThemeController>` en `main.dart`, porque casi
  todas las pantallas leen `AppColors.x` directamente y no `Theme.of(context)`.
  Switch "Modo oscuro" en el menú de perfil (todos los roles). Esto obligó
  a quitar `const` de ~90 sitios que ya no son compile-time constants
  (mecánico, cubierto por `flutter analyze`). Verificado en vivo en
  Login/Registro con el navegador — fondo, tarjetas y botones cambian
  correctamente entre claro/oscuro.
- **Checklist UX (dos tandas de 20 y 15 puntos que compartió el usuario,
  del estilo "cosas que le faltan a tu web/app")** — se adaptó lo que
  aplica a una app Flutter nativa:
  - Toggle de contraseña visible también en Registro (ya existía en Login).
  - Botón de copiar al portapapeles en el código de reclamo de compra
    (`buy_product_view.dart`).
  - Confirmación antes de "Rechazar" una solicitud de barbería (antes era
    un solo tap sin vuelta atrás).
  - Feedback de éxito al registrar una barbería nueva (antes cerraba la
    pantalla sin avisar).
  - Pantalla de Ayuda (`lib/views/help/help_view.dart`): FAQ expandible +
    contacto por correo/teléfono (`lib/support_info.dart`, valores
    **placeholder** — reemplazar antes de publicar) + enlace a Política de
    privacidad (`privacy_policy_view.dart`, texto real, no un stub).
    Reemplaza los stubs "La ayuda próximamente" de Admin/Dueño y se agregó
    también a Cliente/Barbero, que no la tenían.
  - Botón flotante de ayuda en el panel de Cliente.
  - `ScrollToTopFab` (`lib/views/widgets/scroll_to_top_fab.dart`) aplicado
    en Usuarios y Notificaciones (listas largas sin FAB propio ya).
  - Texto alternativo (`Semantics`/`semanticLabel`) en la foto de portada
    de barbería y en las fotos de servicios/productos, para lectores de
    pantalla.
  - **No aplican a una app móvil nativa** (se explicó al usuario en vez de
    forzarlas): banner de cookies, hoja de estilo de impresión, enlace
    "saltar al contenido", sitemap.xml, meta-título por página, UTM
    tracking. "Menús móviles" y "encabezados fijos" ya están cubiertos de
    forma nativa (bottom nav + `AppBar`).
  - **Deliberadamente no implementados esta vuelta** (quedan como mejora
    futura si se necesitan): analíticas (requeriría agregar
    `firebase_analytics` y decidir qué eventos trackear — no es un ajuste
    de UI), búsqueda global unificada (ya hay búsqueda por pantalla en
    Usuarios/Barberías/servicios/productos; una búsqueda "de todo el
    sistema" no encaja con la navegación por rol actual), breakpoints
    responsivos más allá de los que ya existen (formularios de auth con
    `ConstrainedBox(maxWidth: 400)`), ícono de app/favicon generado a
    partir del `BrandMark` (la Fase 13 ya lista esto como intervención
    humana pendiente en la sección de abajo).

## Historial — cierre de Fase 11

Backend y wiring de Flutter quedaron commiteados (commit `1895cc7`). Se
corrieron los pasos de "Para retomar Fase 11" pendientes:

- Corrige el hallazgo de seguridad ya documentado: `barbershops/{id}` ya
  no puede nacer `active` ni aprobada — nace `approvalStatus: 'pending'`,
  `active: false` obligatoriamente (antes cualquier usuario autenticado
  podía crear su barbería ya visible en el catálogo).
- `OwnershipService.requestOwnership` — sube al cliente a rol Dueño al
  registrar su barbería (spec 12.1), vía Cloud Function porque el propio
  usuario no puede tocar su rol.
- `SubscriptionService` — pagar/cancelar mensualidad (spec 12.5), revisión
  periódica (`processBarbershopBilling`, cada 24h) que vence → gracia
  (3-5 días) → bloquea, y cancela+reembolsa automáticamente las citas
  pagadas que caen después del corte de mensualidad (spec 12.6), sin
  tocar las que ya estaban dentro del período pagado.
- Notificaciones nuevas: mensualidad vencida/bloqueada (al dueño), cita
  cancelada por bloqueo (al cliente) — 4 tonos cada una.
- El precio de la mensualidad (`MONTHLY_FEE` en
  `functions/src/barbershops/subscriptionService.ts`) es un **placeholder
  de 50000** hasta que el negocio defina el precio real.

**Cliente Flutter: wiring hecho y ya verificado** (`flutter analyze` sin
hallazgos, `flutter test` 52/52 incluyendo los tests nuevos de
`FirestoreBarbershopService`):

- `Barbershop` gana `approvalStatus` (pending/approved/rejected) y
  `isVisibleInCatalog`.
- `BarbershopRepository`/`FirestoreBarbershopService` ganan
  `watchApproved()` (catálogo del cliente, filtra por aprobada+activa),
  `requestOwnership`, `resolveApproval` (admin, escritura directa —
  arranca el primer ciclo de 30 días de mensualidad), `paySubscription`,
  `cancelSubscription`.
- `AddBarbershopView` ahora crea la barbería pendiente y llama
  `requestOwnership`; muestra aviso de "pendiente de revisión".
- `AuthGate` — nuevo `_OwnerGate`: un usuario con rol Dueño pero SIN
  ninguna barbería aprobada ve `ClientHomeView`, no `OwnerHomeView`
  (spec 12.1: "no otorga ningún permiso de gestión adicional").
- `ManageBarbershopsView` — el catálogo de cliente ahora usa
  `watchApproved()`; el panel de admin muestra aprobar/rechazar para
  solicitudes pendientes; la vista del propio dueño muestra el badge de
  estado de aprobación.
- `OwnerDashboardTab` — tarjeta de estado de mensualidad con
  pagar/cancelar, y lista de "otras barberías" del mismo dueño (spec
  12.2) con su estado.
- `ClientHomeView` — "Registrar mi barbería" ahora navega de verdad al
  formulario (antes era un stub "próximamente").

### Fase 11 — cerrada

Todos los pasos de la lista original quedaron completados: `flutter
analyze` limpio, tests de `FirestoreBarbershopService` ya existentes y en
verde, `dart format --line-length=120` aplicado, `flutter test` completo
en verde, y el gate de `functions/` (`npm run build && npm run lint && npm
test`) repetido sin regresiones.

Queda pendiente, para cuando haya forma de probarlo manualmente (no
bloquea seguir desarrollando):

- Revisar el flujo end-to-end: cliente registra barbería → aparece
  pendiente → admin aprueba → dueño ve panel completo → paga/cancela
  mensualidad.

## No empezado

### Fase 12 — Recomendación de peinados con IA (spec 9.1–9.4)

- `google_mlkit_face_detection` para landmarks faciales on-device.
- `FaceShapeClassifier` (Dart puro, sin Firebase, 100% testeable por
  proporciones geométricas).
- Catálogo estático de estilos por forma de rostro con puntaje 1–10 por
  reglas (no LLM) y explicaciones en tono respetuoso.
- Visor de maniquí genérico rotable (no la foto real del usuario).
- El campo de observación libre pasa por el mismo filtro de moderación
  de la Fase 10 (`functions/src/shared/contentModerationFilter.ts`),
  reutilizado, no reimplementado.
- **Intervención pendiente:** el catálogo de imágenes/renders de
  peinados por forma de rostro debe aportarlo el usuario/diseño.

### Fase 13 — Endurecimiento final de seguridad y regresión

- Auditoría completa de `firestore.rules`/`storage.rules`/Cloud
  Functions: mínimo privilegio, ningún secreto expuesto, App Check en
  todas las callables sensibles, rate-limiting básico en el webhook de
  Nequi (cuando exista).
- Correr el skill `security-review` sobre el conjunto completo de
  cambios y aplicar los hallazgos.
- Suite de regresión completa (`flutter test` + `flutter analyze` sin
  warnings + suite Jest de `functions/` + reglas con emulador — esto
  último sigue bloqueado, ver limitación abajo).
- Consolidar este mismo documento con el resultado final para el
  usuario.

## Limitación conocida y aceptada: reglas de Firestore/Storage sin ejecutar

El emulador de Firebase (`@firebase/rules-unit-testing`) necesita un
JRE/Java que no está disponible en este entorno sandbox (el intento de
`winget install` falló). Por eso **todos** los tests de reglas
(`functions/test/rules/*.rules.test.ts`) están escritos y se
type-chequean (`npx tsc --noEmit --strict ...`) pero nunca se ejecutan
de verdad contra el emulador. Quedan excluidos de `npm test`
(`testPathIgnorePatterns` en `functions/jest.config.js`) y solo
correrían con `npm run test:rules`, que requiere el emulador. Si en
algún momento hay una máquina con Java disponible, correr
`npm run test:rules` en `functions/` para validar por primera vez todas
las reglas escritas hasta ahora.

## Intervenciones humanas pendientes (no bloquean seguir desarrollando)

1. Activar plan **Blaze** en el proyecto Firebase — necesario para
   desplegar Cloud Functions a producción (incluye las nuevas
   `processBarbershopBilling`, `requestBarbershopOwnership`,
   `payBarbershopSubscription`, `cancelBarbershopSubscription`).
2. Credenciales reales de comercio/API de **Nequi** (hoy todo corre en
   modo simulado vía `SimulatedNequiGateway`).
3. Definir el **precio real de la mensualidad** (hoy es un placeholder
   de 50000 en `subscriptionService.ts`).
4. Cuenta y credenciales de **Twilio** (SMS) y **SendGrid** o activar la
   extensión "Trigger Email" para el canal de respaldo de notificaciones.
5. Configurar **APNs** si se necesita push en iOS además de Android/Web.
6. Asset de **logo/ícono** de la app para `flutter_launcher_icons`/splash.
7. **Catálogo de imágenes** de peinados por forma de rostro (Fase 12).
8. Registrar **App Check** (Play Integrity / App Attest) en la consola
   de Firebase para los proyectos Android/iOS reales.
9. Una máquina con **Java/JRE** disponible para correr por fin las
   pruebas de reglas de Firestore/Storage contra el emulador real.
10. Correo y teléfono reales de soporte en `lib/support_info.dart` (hoy
    son placeholders: `soporte@barberflow.com` / `+573000000000`),
    mostrados en la pantalla de Ayuda.
