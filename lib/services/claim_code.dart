import 'dart:math';

// Puerto a Dart de functions/src/products/claimCode.ts.
// Sin 0/O/1/I: se lee en voz alta y se escribe a mano en el mostrador.
const _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const _codeLength = 8;
final _random = Random.secure();

/// Código de reclamo de una compra completa (spec 10.4): 32^8 combinaciones.
String generateClaimCode() {
  final buffer = StringBuffer();
  for (var i = 0; i < _codeLength; i++) {
    buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}
