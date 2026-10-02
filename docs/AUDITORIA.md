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
- **Tests de reglas ejecutables por primera vez.** Se instaló JDK 21 (Temurin). En este Windows el emulador además exige `-Djava.net.preferIPv4Stack=true` y un TEMP corto (`C:	mp`); `functions/scripts/test-rules.cjs` lo aplica solo → `npm run test:rules`. Resultado: 12 suites, 107 tests (80 previos + 27 nuevos). Antes nunca se habían ejecutado.

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

_(pendiente)_

## Fase 3 — Arquitectura y limpieza

_(pendiente)_

## Fase 4 — Rendimiento

_(pendiente)_

## Fase 5 — Sistema de diseño

_(pendiente)_

## Fase 6 — Rediseño por área

_(pendiente)_

## Fase 7 — Verificación final

_(pendiente)_
