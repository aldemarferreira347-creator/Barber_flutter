/// Tono en el que el usuario prefiere recibir el contenido de sus
/// notificaciones (spec 3.5). Solo afecta la redacción del texto que arma
/// el backend — nunca el resto de la interfaz.
enum NotificationTone { formal, normal, friendly, informal }

extension NotificationToneX on NotificationTone {
  String get value => name;

  String get label => switch (this) {
        NotificationTone.formal => 'Formal',
        NotificationTone.normal => 'Normal',
        NotificationTone.friendly => 'Amigable',
        NotificationTone.informal => 'Informal / coloquial',
      };

  static NotificationTone? fromValue(String? value) {
    if (value == null) return null;
    for (final tone in NotificationTone.values) {
      if (tone.name == value) return tone;
    }
    return null;
  }
}
