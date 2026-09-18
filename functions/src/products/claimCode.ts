import { randomInt } from 'crypto';

// Sin 0/O/1/I: se lee en voz alta y se escribe a mano en el mostrador.
const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const CODE_LENGTH = 8;

/** Código de reclamo de una compra completa (spec 10.4): 32^8 combinaciones. */
export function generateClaimCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += ALPHABET[randomInt(ALPHABET.length)];
  }
  return code;
}
