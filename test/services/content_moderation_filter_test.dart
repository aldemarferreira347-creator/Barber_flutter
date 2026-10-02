import 'package:barber/services/content_moderation_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deja pasar texto normal', () {
    expect(containsOffensiveContent('Excelente corte, muy puntual'), isFalse);
  });

  test('no marca falsos positivos por substring (vínculo contiene culo)', () {
    expect(containsOffensiveContent('Buen vínculo con el barbero'), isFalse);
  });

  test('detecta una grosería directa', () {
    expect(containsOffensiveContent('que pendejo'), isTrue);
  });

  test('detecta leetspeak', () {
    expect(containsOffensiveContent('p3ndejo'), isTrue);
  });

  test('detecta letras repetidas', () {
    expect(containsOffensiveContent('puuutooo'), isTrue);
  });

  test('detecta letras sueltas separadas por espacios', () {
    expect(containsOffensiveContent('p u t o'), isTrue);
  });

  test('detecta acentos', () {
    expect(containsOffensiveContent('imbécil'), isTrue);
  });

  test('texto vacío no es ofensivo', () {
    expect(containsOffensiveContent('   '), isFalse);
  });
}
