import 'dart:io';

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

  test('la lista de términos es idéntica a la del backend (functions/)', () {
    Set<String> terms(String path, String start) {
      final source = File(path).readAsStringSync();
      final from = source.indexOf(start);
      final to = source.indexOf(RegExp(r'[}\]]\)?;'), from);
      return RegExp(r"'([a-z]+)'")
          .allMatches(source.substring(from, to))
          .map((m) => m.group(1)!)
          .toSet();
    }

    final dart = terms(
      'lib/services/content_moderation_filter.dart',
      '_offensiveTerms = {',
    );
    final ts = terms(
      'functions/src/shared/contentModerationFilter.ts',
      'OFFENSIVE_TERMS = new Set([',
    );

    expect(dart, isNotEmpty);
    expect(dart, ts);
  });
}
