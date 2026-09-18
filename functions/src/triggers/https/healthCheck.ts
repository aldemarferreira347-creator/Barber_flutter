import { onRequest } from 'firebase-functions/v2/https';

/**
 * Endpoint mínimo para verificar que el pipeline de build/deploy de
 * Cloud Functions funciona antes de agregarle lógica de negocio encima.
 */
export const healthCheck = onRequest((_request, response) => {
  response.status(200).json({ status: 'ok' });
});
