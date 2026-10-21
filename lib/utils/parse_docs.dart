import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'failure.dart';

/// Convierte los documentos de una consulta en modelos sin que uno dañado
/// tumbe toda la lista: el documento que no se puede leer se omite y queda
/// registrado (con su ruta) para corregirlo. Antes, un solo campo con tipo
/// inesperado hacía fallar el catálogo completo.
List<T> parseDocs<T>(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) parse,
) {
  final result = <T>[];
  for (final doc in docs) {
    try {
      result.add(parse(doc));
    } catch (error) {
      debugPrint(
        'Documento ${doc.reference.path} omitido: ${describeFailure(error)}',
      );
    }
  }
  return result;
}
