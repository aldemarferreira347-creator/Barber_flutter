# Auditoría integral + rediseño visual — Plan de implementación

> **Para quien ejecute:** usar `superpowers:executing-plans` (inline). Los pasos usan `- [ ]` para seguimiento. Cada fase termina en un commit verde sobre la rama `audit/integral`.

**Goal:** dejar BarberFlow (Flutter + Firebase) seguro, consistente, mantenible y con una identidad visual única, sobria y responsive, sin regresiones.

**Architecture:** auditar de adentro hacia afuera: primero reglas/backend/datos (donde el error es más caro), luego estructura del código, luego rendimiento, y al final un sistema de diseño único sobre el que se rediseñan las pantallas por rol. Cada fase corrige, prueba y deja constancia en `docs/AUDITORIA.md`.

**Tech Stack:** Flutter (Provider, Firestore, Auth, Storage, Functions, App Check, flutter_animate, shimmer, google_fonts), Cloud Functions TypeScript (Node 20, Jest), reglas Firestore/Storage.

**Spec:** `Especificacion_Funcionalidades_App_Barberia.md` (secciones 2–13) y `PENDIENTE.md` (decisiones de producto ya tomadas).

## Línea base medida (2026-10-02)

| Indicador | Valor | Qué significa |
|---|---|---|
| `flutter analyze` / `flutter test` | 0 issues / 109 pasan | punto de partida verde |
| Functions: build / jest | OK / 251 pasan | backend verde |
| Functions: lint | **1 error** (`_omit` sin usar, `barbershops.rules.test.ts:66`) | arreglar en Fase 0 |
| `npm audit --omit=dev` | **2 vulnerabilidades moderate** (`gaxios`) | Fase 1 |
| `Color(0x…)` en `lib/` | **92** | riesgo de dark mode roto y deriva de paleta |
| `Colors.white/black` directos | **81** | ídem |
| `Semantics(` | **1** · `tooltip:` **4** frente a **11** `IconButton` | accesibilidad casi nula |
| `.animate(`/`Animate(` en vistas | **94** · `BoxShadow` **26** · gradientes **8** | contradice "estética seria" |
| `Navigator.push` | **44** · diálogos/sheets **24** | candidatos a cambiar de patrón |
| Archivos > 400 líneas | `manage_users_view` 1351, `manage_barbershops_view` ~936, `login_view` 653, `add_barbershop_view` 521, `register_view` 502 | violan responsabilidad única |
| Lógica "pago simulado" duplicada | 4 servicios (barbería ×2, cita, compra), cada uno con su `_simulatedApprovalDelay` | Fase 3 |
| `catch (_)` que traga el error | `auth_controller.dart:231,301`, `firebase_auth_service.dart:159` | Fase 2 |
| Responsive | 11 vistas con `maxWidth`; ninguna con layout de tablet/desktop; navegación solo `BottomNavigationBar` | Fase 6 |
| Tests de reglas (`functions/test/rules`) | escritos, **nunca ejecutados** (el emulador exige JDK ≥ 21: el JDK 17 instalado es muy viejo y el Java 25 de Android Studio falla en este Windows) | Fase 0 |

## Global Constraints

- **Paleta intacta:** no se cambia ningún valor de `AppColors` (primary, accent, success, warning, error, y el negro/dorado del modo oscuro actual). Los colores sueltos se reemplazan por tokens, no por colores nuevos.
- **Sin dependencias nuevas** salvo que una fase demuestre un beneficio concreto; se permiten parches de versión de las existentes.
- **Datos de negocio no se inventan:** `kBarbershopMonthlyFee` (50000), `lib/support_info.dart` (placeholders), credenciales Nequi/Twilio, plan Blaze y catálogo de peinados (Fase 12 de IA) quedan fuera de alcance y se listan al final como pendientes de negocio.
- **El pago sigue simulado en cliente** (decisión documentada en `PENDIENTE.md`: no hay plan Blaze). Se endurece lo que se pueda con reglas, sin cambiar el modelo.
- **Cada fase deja verde:** `flutter analyze` sin issues, `flutter test` completo, y en `functions/`: `npm run build && npm run lint && npm test`.
- **Un test por corrección** (primero rojo, luego verde). No se editan tests para ocultar un fallo.
- Commits por fase en `audit/integral`; merge local a `master` al final. **No hay `git push` sin permiso explícito.**
- Animaciones: una sola transición de página, feedback de pulsación y shimmer de carga. Se eliminan las animaciones de entrada escalonadas y las decorativas. Ninguna animación infinita (rompe tests, ver `PENDIENTE.md`).

## Review Focus

Entradas que la spec implica y ninguna fase cubriría por inercia; cada una tiene su test en la tarea indicada:

1. **Cliente escribe campos protegidos directo** (`role`, `ratingSum`, `payments.status='approved'` al crear, `paymentStatus` de barbería ajena) → la regla debe rechazar. *(T1.2)*
2. **Doble toque en "Pagar" / "Reservar" / "Comprar"** → un solo pago y una sola cita. *(T2.3)*
3. **Stream que falla o sin red** → estado de error con "Reintentar", nunca spinner infinito. *(T2.4)*
4. **Dueño con 0 barberías, con solo borradores, con 5 borradores, o con barbería bloqueada** → cada caso muestra su estado y ninguna acción prohibida. *(T2.2)*
5. **Pantalla de 320 px, texto al 150 % y modo oscuro** → ninguna vista principal con overflow ni texto ilegible (contraste AA). *(T7.1)*

---

## Fase 0 — Preparación y red de seguridad

### T0.1 Rama, bitácora y limpieza de línea base
**Files:** crear `docs/AUDITORIA.md`; modificar `functions/test/rules/barbershops.rules.test.ts:66`.
- [ ] `git switch -c audit/integral` desde `master`.
- [ ] Crear `docs/AUDITORIA.md` con la tabla de línea base de arriba y secciones vacías por fase (Hallazgo · Causa raíz · Corrección · Test).
- [ ] Quitar la variable `_omit` sin usar (el lint de `functions` debe quedar en 0 errores).
- [ ] **Verifica:** `cd functions && npm run build && npm run lint && npm test` → 0 errores, 251 tests.
- [ ] Commit `chore: línea base de auditoría`.

### T0.2 Poder ejecutar los tests de reglas
**Files:** ninguno del proyecto (entorno).
- [ ] Instalar JDK 21+ (Temurin) — **requiere tu autorización de descarga** (ver pregunta al final).
- [ ] `cd functions && npm run test:rules` con `JAVA_HOME` apuntando al JDK 21.
- [ ] Si algún test de reglas ya existente falla, es un hallazgo de la Fase 1 (no se ignora).
- [ ] **Si no se puede instalar:** continuar con revisión estática de reglas + `tsc --noEmit` de los tests, y dejar constancia en `AUDITORIA.md` de que quedaron sin ejecutar.

---

## Fase 1 — Seguridad (prioridad 1)

### T1.1 Matriz de permisos reglas × rol
**Files:** `firestore.rules`, `storage.rules`, `docs/AUDITORIA.md`.
- [ ] Construir en `AUDITORIA.md` una matriz `colección/ruta × (anónimo, cliente, barbero, dueño propio, dueño ajeno, admin) × (read, create, update, delete)` leyendo cada `match` (users, barbershopDrafts, barbershops y subcolecciones, appointments, appointmentSlots, shopClosures, refundRequests, payments, purchases, ratings, comments, notifications; storage por ruta).
- [ ] Marcar cada celda como "correcta", "demasiado abierta" o "demasiado cerrada" contra la spec (roles §2, panel §12.3–12.4).
- [ ] Revisar con atención: el comodín `match /{document=**}` dentro de `barbershops` (lectura a cualquier autenticado de todas las subcolecciones), lectura de `users` (exposición de teléfono/email/token FCM), ruta `/{allPaths=**}` de storage.

### T1.2 Corregir hallazgos de reglas con test
**Files:** `firestore.rules`, `storage.rules`, `functions/test/rules/*.rules.test.ts`.
- [ ] Por cada celda "demasiado abierta" de T1.1: escribir primero el test de reglas que debería fallar (p. ej. `cliente no puede crear payment con status approved`, `cliente no puede modificar role`, `dueño ajeno no puede leer purchases de otra barbería`, `ratingSum fuera de rango rechazado`), verlo rojo, ajustar la regla, verlo verde.
- [ ] Reglas con `get()`/`exists()`: confirmar que no lanzan por claves ausentes (usar `.get('campo', default)`, como ya se hizo con `ratingSum`).
- [ ] **Verifica:** `npm run test:rules` (si T0.2 lo permitió) o revisión estática documentada.

### T1.3 Cloud Functions: autorización y validación de entrada
**Files:** `functions/src/triggers/https/*.ts`, `functions/src/shared/shopAuthorization.ts`.
- [ ] Revisar las 19 callables HTTPS: cada una debe (a) exigir `request.auth`, (b) validar tipo/longitud de cada campo, (c) autorizar por rol/propiedad con `shopAuthorization`, (d) no devolver datos de otro usuario.
- [ ] App Check exigido en las callables sensibles (`enforceAppCheck`) — comprobar cuáles ya lo hacen; las que no, corregirlas con test Jest que llame sin auth y sin token.
- [ ] `sendNotification`: confirmar que un cliente no puede enviar notificaciones arbitrarias a terceros.
- [ ] **Verifica:** `npm test` en `functions/` (nuevos tests de "rechaza sin auth / rol incorrecto / entrada inválida").

### T1.4 Cliente: secretos, validación y dependencias
**Files:** `lib/**`, `functions/package.json`, `pubspec.yaml`.
- [ ] `git grep` de claves/tokens/URLs sensibles en `lib/`, `android/`, `web/`, `firebase.json` (las API keys de Firebase no son secretas, pero sí cualquier otra).
- [ ] Revisar validadores de formularios (email, teléfono, contraseña, longitudes) y el filtro de moderación `content_moderation_filter.dart` frente a su gemelo del backend `contentModerationFilter.ts`: deben dar el mismo resultado (test de paridad con la misma lista de casos).
- [ ] `npm audit fix` para las 2 vulnerabilidades moderate de `gaxios`; `flutter pub upgrade --major-versions` **solo** para parches seguros (`geolocator`, `url_launcher`); `google_fonts` y `cupertino_icons` mayores solo si no hay cambio de API.
- [ ] **Verifica:** `flutter analyze`, `flutter test`, `npm audit --omit=dev` sin moderate+.
- [ ] Commit `fix(seguridad): …` (uno por T1.2, T1.3, T1.4).

---

## Fase 2 — Errores funcionales e integridad de datos (prioridades 2–3)

### T2.1 Matriz spec → implementación
**Files:** `docs/AUDITORIA.md`.
- [ ] Recorrer spec §3, §6, §7, §10, §12, §13 y marcar cada requisito como implementado / parcial / ausente, con archivo que lo implementa. Lo "ausente" que no dependa de datos de negocio se implementa; la IA de peinados (§9) queda fuera (necesita catálogo de imágenes).

### T2.2 Flujos completos con sus estados límite
**Files:** `lib/views/home/owner_*`, `lib/views/barbershop/*`, `lib/views/widgets/auth_gate.dart`, `test/views/owner_barbershops_views_test.dart`.
- [ ] Test por estado del Dueño: 0 barberías → `ClientHomeView`; solo borradores; 5 borradores (botón de nuevo borrador deshabilitado con mensaje); barbería `pending`; `rejected`; `blocked` (sin acciones de gestión, con CTA "Pagar").
- [ ] Flujos end-to-end con repos falsos: registrar barbería → pendiente → admin aprueba → dueño ve panel → paga/cancela mensualidad; cliente reserva → paga → cancela con reembolso; compra de producto → código → reclamo → expiración.

### T2.3 Integridad: operaciones duplicadas y transacciones
**Files:** `lib/services/firestore_appointment_service.dart`, `cloud_purchase_service.dart`, `firestore_barbershop_service.dart`, vistas con botón de pago.
- [ ] Test: dos llamadas simultáneas a `bookPaidAppointment`/`createPaid`/`paySubscription`/compra → un solo pago y un solo efecto (bloqueo del botón mientras `_busy` + idempotencia en el servicio).
- [ ] Revisar que cada escritura multi-documento use `batch`/`transaction` (pago + entidad + slot) y que un fallo a mitad no deje pagos aprobados huérfanos (compensar o marcar `rejected`).
- [ ] Contador de citas/ratings: confirmar que `appointmentSlots` impide doble reserva bajo concurrencia.

### T2.4 Manejo de errores y estados de carga/error
**Files:** `lib/controllers/auth_controller.dart:231,301`, `lib/services/firebase_auth_service.dart:159`, las 31 vistas con `StreamBuilder/FutureBuilder`.
- [ ] Reemplazar los 3 `catch (_)` por captura tipada y mensaje al usuario (o comentario justificado si ignorar es correcto).
- [ ] Cada `StreamBuilder`/`FutureBuilder`: rama `hasError` → `ErrorState` con "Reintentar"; rama vacía → `EmptyState`; carga → `ShimmerList`. Test de un stream que emite error y verificación de que aparece `ErrorState` (no spinner).
- [ ] **Verifica y commit:** `fix(funcional): …` por T2.2, T2.3, T2.4.

---

## Fase 3 — Arquitectura, SOLID y limpieza (prioridad 4)

### T3.1 Una sola implementación del cobro simulado
**Files:** crear `lib/services/simulated_payment.dart`; modificar los 4 servicios; tests existentes.
- [ ] `Future<String> SimulatedPayment.charge({required FirebaseFirestore firestore, required String payerId, required double amount, required String category, required String relatedId, required String description, required Duration delay})` → crea `pending`, espera, marca `approved`, devuelve el id. Reutiliza el helper `_chargeSubscription` ya extraído en `firestore_barbershop_service.dart`.
- [ ] Reemplazar las 4 copias; `delay` inyectable (tests), una constante de retardo compartida.
- [ ] **Verifica:** los tests existentes de los 4 servicios siguen verdes sin tocar sus aserciones.

### T3.2 Partir las vistas gigantes
**Files:** `lib/views/admin/manage_users_view.dart` → `lib/views/admin/users/{manage_users_view,user_list_tile,user_actions_sheet,user_filters}.dart`; `manage_barbershops_view.dart` → idem; `login_view.dart` y `register_view.dart` → extraer formularios/segmentos.
- [ ] Cortar por responsabilidad (lista, fila, filtros, hoja de acciones, diálogos), sin cambiar comportamiento. Ningún archivo resultante > ~400 líneas.
- [ ] **Verifica:** tests de vistas + `role_dashboards_smoke_test` sin cambios de aserción.

### T3.3 Capas y código muerto
**Files:** `lib/views/barbershop/add_barbershop_view.dart` (usa `cloud_firestore` directo), repos/servicios, widgets no usados.
- [ ] Sacar el acceso a Firestore de `add_barbershop_view.dart` a `BarbershopRepository`.
- [ ] Buscar y borrar código muerto: símbolos y archivos sin referencias (`animated_background.dart`, `coming_soon_view.dart`, `custom_icons.dart`, métodos de repos sin uso) con `dart analyze` + búsqueda de referencias; `functions/`: exports sin uso.
- [ ] Endurecer `analysis_options.yaml` con reglas útiles (`prefer_const_constructors`, `avoid_print`, `unawaited_futures`, `use_build_context_synchronously`) y arreglar lo que salga.
- [ ] Commit `refactor: …` por T3.1, T3.2, T3.3.

---

## Fase 4 — Rendimiento (prioridad 5)

### T4.1 Escuchas, rebuilds y consultas
**Files:** `lib/repositories/appointment_repository.dart` (`watchByBarbershops`), `lib/main.dart` (rebuild global por tema), listas largas, `firestore.indexes.json`.
- [ ] `watchByBarbershops` abre un listener por barbería: acotarlo (límite de resultados/fecha) y cerrarlos al salir; test de cancelación de suscripciones.
- [ ] Revisar el rebuild total de la app al cambiar de tema (`Consumer<ThemeController>` + `AppColors.isDark`): confirmar que es solo al cambiar el tema y no en cada frame.
- [ ] Listas de usuarios/citas/barberías: paginación o `limit()` + `ListView.builder` en toda lista que pueda crecer; índices compuestos faltantes en `firestore.indexes.json` para cada consulta con `where + orderBy`.
- [ ] Imágenes: `cacheWidth/cacheHeight` o thumbnails en listas; subida de fotos con compresión (`image_picker` `maxWidth/imageQuality`).
- [ ] **Verifica:** tests, `flutter analyze`; commit `perf: …`.

---

## Fase 5 — Sistema de diseño único (cimientos del rediseño)

### T5.1 Tokens y tema
**Files:** `lib/theme/app_colors.dart`, `app_theme.dart`, crear `lib/theme/app_spacing.dart`, `app_text.dart`, `app_motion.dart` (ya existe, reducir).
- [ ] Definir escala de espaciado (4/8/12/16/24/32), radios (8/12/16/pill), elevación (0/1/2, sin sombras tintadas), y escala tipográfica (display/title/body/label) vía `TextTheme` de `google_fonts`.
- [ ] Añadir tokens semánticos que faltan **derivados de la paleta actual** (`onPrimary`, `onSuccess`, `surfaceVariant`, `scrim`) para eliminar los `Colors.white/black` y `Color(0x…)` sueltos.
- [ ] Reducir `AppMotion` a: transición de página sobria + presión + shimmer. Quitar animaciones de entrada escalonadas, pulsos y manchas flotantes (`AnimatedBackground`).

### T5.2 Biblioteca de componentes compartidos
**Files:** `lib/views/widgets/*` (`status_badge`, `stat_card`, `action_list_tile`, `appointment_card`, `empty_state`, `error_state`, `shimmer_box`, `gradient_button`, `promo_banner_card`, `dashboard_scaffold`, `role_shell`) + nuevos `app_dialog.dart` (diálogo de confirmación estándar), `app_bottom_sheet.dart`, `section_header.dart`, `app_text_field.dart`, `responsive_body.dart`.
- [ ] `GradientButton` → botón primario plano (mismo color, sin degradado ni sombra) con estados `loading` y `disabled`; mantener `PressableScale`.
- [ ] Quitar `BoxShadow` y degradados ornamentales de las tarjetas; bordes finos + `surface`.
- [ ] `ResponsiveBody`: centra y limita el ancho del contenido (≈ 720 px lectura, ≈ 1100 px paneles) en tablet/desktop.
- [ ] Tamaño mínimo táctil 48 dp, `tooltip` obligatorio en `IconButton`, `Semantics` en componentes compartidos.
- [ ] **Verifica:** golden-less: tests de widget de cada componente en claro/oscuro; `flutter analyze`.

### T5.3 Eliminar colores sueltos
**Files:** los archivos con `Color(0x` (92) y `Colors.white/black` (81), `git grep` como guía.
- [ ] Sustituir cada uso por un token; los que sean de una ilustración (p. ej. `BrandMark`) se documentan como excepción.
- [ ] **Verifica:** `git grep -E "Color\(0x|Colors\.(white|black)"` en `lib/views` → solo excepciones documentadas. Commit `refactor(ui): tokens y componentes`.

---

## Fase 6 — Rediseño por área, responsive y accesibilidad

Para cada área: aplicar tokens y componentes de la Fase 5, revisar jerarquía/espaciado/iconografía/copy, estados vacío-carga-error, y cambiar el patrón de interacción **solo** donde mejore la experiencia.

### T6.1 Navegación responsive
**Files:** `lib/views/widgets/role_shell.dart`, `dashboard_scaffold.dart`.
- [ ] Ancho < 600 → `BottomNavigationBar` (actual). 600–1023 → `NavigationRail` compacto. ≥ 1024 → `NavigationRail` extendido con etiquetas. Misma lista de pestañas por rol (no se cambia la estructura de producto).

### T6.2 Auth y onboarding
**Files:** `lib/views/auth/*`, `splash_view.dart`, `brand_mark.dart`.
- [ ] Login/registro/teléfono/éxito con la misma jerarquía de formulario (`AppTextField`, errores bajo el campo, botón con `loading`). Quitar el franja decorativa `_LoginFooterStrip` si solo es ornamental; `BrandMark` estático (sin loop de tijeras).

### T6.3 Cliente
**Files:** `lib/views/home/client_*`, `lib/views/appointment/*`, `lib/views/barbershop/barbershop_detail_view.dart`, `barbershop_reviews_view.dart`, `lib/views/product/buy_product_view.dart`, `claim_purchase_view.dart`.
- [ ] Explorar barberías con filtros claros; detalle con CTA fijo "Reservar"; reserva en pasos con resumen y confirmación; **calificar cita pasa de vista independiente a bottom sheet** (acción corta y contextual); compra/ reclamo con código copiable.

### T6.4 Barbero
**Files:** `lib/views/barber/*`, `lib/views/home/barber_*`.
- [ ] Panel "hoy" con citas ordenadas, acciones de estado con confirmación, disponibilidad (salir/volver) como control de un solo toque con estimado.

### T6.5 Dueño
**Files:** `lib/views/barbershop/{my_barbershops,owner_barbershop_manage,add_barbershop,edit_barbershop}_view.dart`, `lib/views/home/owner_*`, `lib/views/service/*`, `lib/views/product/{add,manage}_*`.
- [ ] Gestión de una barbería organizada en secciones (datos, horario, equipo, catálogo, citas, reseñas, reembolsos, cierre, mensualidad) con el estado de pago/aprobación siempre visible.
- [ ] **Formularios cortos de servicio y producto (`add_service_view`, `add_product_view`) pasan a bottom sheet/diálogo** desde su lista; el alta de barbería (larga, con pago) se mantiene como pantalla.

### T6.6 Admin
**Files:** `lib/views/admin/users/*`, `lib/views/barbershop/manage_barbershops_view.dart`, `lib/views/home/admin_*`.
- [ ] Usuarios y barberías como lista/tabla responsive: en ≥ 1024 px tabla con columnas y filtros en barra; en móvil, tarjetas. Acciones destructivas siempre con `AppDialog` de confirmación; aprobar/rechazar con motivo.

### T6.7 Transversales
**Files:** `lib/views/profile/*`, `notification/*`, `help/*`.
- [ ] Perfil, notificaciones, ayuda y privacidad con los mismos componentes; modo oscuro verificado.
- [ ] Accesibilidad global: `Semantics`/`tooltip` en todos los iconos accionables, contraste AA entre cada par texto/fondo de los tokens (script de contraste en `test/theme/contrast_test.dart`), soporte de texto al 150 %.
- [ ] Commit `feat(ui): rediseño <área>` por tarea.

---

## Fase 7 — Verificación final y entrega

### T7.1 Batería de regresión visual y funcional
**Files:** crear `test/views/responsive_matrix_test.dart`; actualizar `PENDIENTE.md` y `docs/AUDITORIA.md`.
- [ ] Test parametrizado: cada vista principal de los 4 roles × tamaños (320×640, 390×844, 768×1024, 1280×800) × tema (claro/oscuro) × `textScaler` 1.0 y 1.5 → monta sin excepciones ni `RenderFlex overflow`.
- [ ] Si T0.2 consiguió JDK 21: levantar emuladores Auth+Firestore+Storage con datos semilla por rol y recorrer los flujos principales en `flutter run -d web-server` con el navegador integrado (capturas en claro/oscuro, escritorio y móvil). Si no, se declara explícitamente que las pantallas autenticadas se validaron solo con tests.
- [ ] Gate completo: `flutter analyze`, `flutter test`, `functions`: build + lint + test, `test:rules` si fue posible, `dart format`.
- [ ] Actualizar `PENDIENTE.md` (quitar lo obsoleto, reflejar el estado real) y completar `AUDITORIA.md` con la tabla final de línea base (antes → después).
- [ ] Merge local `audit/integral` → `master`. **Sin push** hasta que lo pidas.

---

## Fuera de alcance (necesita datos o decisiones de negocio)

Plan Blaze y despliegue de Functions · credenciales reales de Nequi/Twilio/SendGrid/APNs · precio real de mensualidad · correo y teléfono reales de soporte · logo/ícono definitivo · IA de peinados (§9) por falta del catálogo de imágenes. Se listarán en el informe final.

## Autorrevisión del plan

- **Cobertura:** cada ítem de tu solicitud tiene fase — arquitectura/SOLID (F3), seguridad (F1), integridad (F2), rendimiento (F4), duplicación/código muerto (F3), errores (F2), dependencias (F1/F3), UX/UI y patrón modal vs vista (F6), responsive/accesibilidad/dark mode (F5–F7).
- **Consistencia de nombres:** `SimulatedPayment.charge` (T3.1) reutiliza `_chargeSubscription`; `ResponsiveBody`, `AppDialog`, `AppBottomSheet`, `AppTextField` se definen en T5.2 y se consumen en F6.
- **Riesgo conocido:** las reglas de Firestore no se pueden probar sin JDK ≥ 21 (T0.2). El plan no se bloquea: degrada a revisión estática documentada.
