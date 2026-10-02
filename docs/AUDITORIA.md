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

## Fase 1 — Seguridad

_(pendiente)_

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
