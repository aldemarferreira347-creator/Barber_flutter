// Puerto a Dart de functions/src/shared/contentModerationFilter.ts — debe
// quedarse en sincronía con esa lista si se agrega o quita algún término.
// Antes moderaba solo el backend (submitAppointmentComment/replyToComment,
// Admin SDK) ANTES de escribir el documento; sin plan Blaze la app corre
// este mismo filtro en el cliente antes de decidir el status ('published'
// vs 'rejected') — ver firestore.rules para el límite aceptado: las reglas
// no pueden re-verificar la moderación en sí, solo que el status declarado
// sea uno de los dos válidos (un cliente manipulado podría en teoría
// falsificar 'published' con texto ofensivo escribiendo Firestore
// directo). No pretende cubrir cada evasión posible — es un filtro simple
// y barato, no un modelo de lenguaje.
const Map<String, String> _leetMap = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  r'$': 's',
};

// Reemplaza los acentos/diéresis españoles más comunes por su letra base —
// equivalente simplificado al normalize('NFD') + strip de diacríticos del
// original en TypeScript (cubre el alfabeto español real, no Unicode
// arbitrario).
const Map<String, String> _accentMap = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
};

// Lista moderada de groserías/insultos en español usada por el filtro local
// (spec 7.3) — no incluye jerga regional ambigua (p.ej. "chimba", positiva
// en Colombia) para evitar falsos positivos.
final Set<String> _offensiveTerms = {
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
};

final RegExp _spacedOutLetters = RegExp(r'\b[a-z](?:\s+[a-z]){2,}\b');
final RegExp _repeatedLetters = RegExp(r'([a-z])\1+');
final RegExp _nonLetterSpace = RegExp(r'[^a-z\s]');
final RegExp _whitespace = RegExp(r'\s+');

String _normalize(String text) {
  final lowered = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? _leetMap[char] ?? char);
  }
  return buffer.toString().replaceAll(_nonLetterSpace, ' ');
}

/// Une letras sueltas separadas por espacios ("p u t o") sin tocar palabras normales.
String _collapseSpacedOutLetters(String text) {
  return text.replaceAllMapped(
    _spacedOutLetters,
    (match) => match.group(0)!.replaceAll(_whitespace, ''),
  );
}

/// "puuutooo" -> "puto": colapsa letras repetidas consecutivas.
String _collapseRepeatedLetters(String word) {
  return word.replaceAllMapped(_repeatedLetters, (match) => match.group(1)!);
}

/// Filtro local de groserías en español (spec 7.3). Compara PALABRA POR
/// PALABRA (nunca substrings) para no marcar falsos positivos en palabras
/// que contienen una prohibida por casualidad (p.ej. "vínculo" contiene
/// "culo" pero es una palabra distinta). Antes de comparar, normaliza
/// acentos, leetspeak ("p3ndejo"), letras sueltas separadas por espacios
/// ("p u t o") y letras repetidas ("puuutooo").
bool containsOffensiveContent(String text) {
  if (text.trim().isEmpty) return false;
  final normalized = _collapseSpacedOutLetters(_normalize(text));
  return normalized
      .split(_whitespace)
      .where((word) => word.isNotEmpty)
      .any((word) => _offensiveTerms.contains(_collapseRepeatedLetters(word)));
}
