//lib\core\services\location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {

  Future<Map<String, dynamic>> getLocation() async {

    double? lat;
    double? lng;
    double? accuracy;

    try {

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        lat = position.latitude;
        lng = position.longitude;
        accuracy = position.accuracy;
      }

    } catch (e) {
      print("Location error: $e");
    }

    return {
      "latitude": lat,
      "longitude": lng,
      "accuracy": accuracy,
      "timestamp": DateTime.now(),
    };
  }
}