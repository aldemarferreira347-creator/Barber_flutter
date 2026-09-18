const LEET_MAP: Record<string, string> = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's' };

// Lista moderada de groserías/insultos en español usada por el filtro
// local (spec 7.3) — no incluye jerga regional ambigua (p.ej. "chimba",
// positiva en Colombia) para evitar falsos positivos.
const OFFENSIVE_TERMS = new Set([
  'puto',
  'puta',
  'putos',
  'putas',
  'mierda',
  'mierdas',
  'pendejo',
  'pendeja',
  'pendejos',
  'pendejas',
  'idiota',
  'idiotas',
  'estupido',
  'estupida',
  'estupidos',
  'estupidas',
  'imbecil',
  'imbeciles',
  'marica',
  'maricon',
  'maricones',
  'verga',
  'vergas',
  'culo',
  'culos',
  'cabron',
  'cabrona',
  'cabrones',
  'zorra',
  'zorras',
  'perra',
  'perras',
  'gonorrea',
  'hijueputa',
  'hijoeputa',
  'hijodeputa',
  'malparido',
  'malparida',
  'malparidos',
  'malparidas',
  'gilipollas',
]);

function normalize(text: string): string {
  let out = text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
  out = out.replace(/[013457@$]/g, (char) => LEET_MAP[char] ?? char);
  out = out.replace(/[^a-z\s]/g, ' ');
  return out;
}

/** Une letras sueltas separadas por espacios ("p u t o") sin tocar palabras normales. */
function collapseSpacedOutLetters(text: string): string {
  return text.replace(/\b[a-z](?:\s+[a-z]){2,}\b/g, (match) => match.replace(/\s+/g, ''));
}

/** "puuutooo" -> "puto": colapsa letras repetidas consecutivas. */
function collapseRepeatedLetters(word: string): string {
  return word.replace(/([a-z])\1+/g, '$1');
}

/**
 * Filtro local de groserías en español (spec 7.3), reutilizado también en
 * las observaciones libres de la recomendación de peinados (spec 9.2).
 * Compara PALABRA POR PALABRA (nunca substrings) para no marcar falsos
 * positivos en palabras que contienen una prohibida por casualidad
 * (p.ej. "vínculo" contiene "culo" pero es una palabra distinta). Antes de
 * comparar, normaliza acentos, leetspeak ("p3ndejo"), letras sueltas
 * separadas por espacios ("p u t o") y letras repetidas ("puuutooo"). No
 * pretende cubrir cada evasión posible — es un filtro simple y barato,
 * no un modelo de lenguaje.
 */
export function containsOffensiveContent(text: string): boolean {
  if (!text || !text.trim()) return false;
  const normalized = collapseSpacedOutLetters(normalize(text));
  return normalized
    .split(/\s+/)
    .filter(Boolean)
    .some((word) => OFFENSIVE_TERMS.has(collapseRepeatedLetters(word)));
}
