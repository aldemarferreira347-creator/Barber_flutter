import 'package:geolocator/geolocator.dart';

/// Wrapper sobre geolocator: pide permiso si hace falta y devuelve la
/// posición actual, o lanza [LocationException] con un mensaje ya listo
/// para mostrar en pantalla.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('Activa la ubicación de tu dispositivo para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Necesitamos permiso de ubicación para guardar dónde queda tu barbería.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('El permiso de ubicación está bloqueado. Actívalo desde los ajustes del dispositivo.');
    }

    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }
}
