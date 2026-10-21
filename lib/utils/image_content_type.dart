/// Tipo MIME de una imagen según la extensión de [fileName] (o de una ruta).
///
/// Storage lo necesita al subir: las reglas exigen `image/*` y, sin tipo
/// explícito, Android y iOS suben el archivo como `application/octet-stream`
/// y la subida se rechaza. Una extensión desconocida o ausente (frecuente con
/// archivos de la galería) se trata como JPEG, que es lo que genera la cámara
/// y el reescalado del selector de imágenes.
String imageContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
}

/// Nombre de archivo seguro para una ruta de Storage: sin espacios, tildes ni
/// símbolos que compliquen la URL; conserva la extensión.
String safeFileName(String fileName) {
  final cleaned = fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return cleaned.isEmpty ? 'foto.jpg' : cleaned;
}

/// Tope de peso de una foto (el mismo que exigen las reglas de Storage).
const kMaxPhotoBytes = 5 * 1024 * 1024;
