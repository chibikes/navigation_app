import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class LocData {
  Stream<Position> getPosition();
  void setBatteryLow(bool isBatteryLow);
  bool getBatteryLow();
}

class RealLocationData implements LocData {
  bool _batteryLow = false;
  @override
  Stream<Position> getPosition() {
    return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
            accuracy: _batteryLow
                ? LocationAccuracy.reduced
                : LocationAccuracy.bestForNavigation));
  }

  @override
  setBatteryLow(bool isBatteryLow) {
    if (isBatteryLow != _batteryLow) {
      _batteryLow = isBatteryLow;
    }
  }

  @override
  bool getBatteryLow() {
    return _batteryLow;
  }
}

class TestLocationData extends LocData {
  final List<LatLng> testPoints;

  TestLocationData(this.testPoints);
  @override
  Stream<Position> getPosition() {
    var point = 0;
    double? speed = 8.0;
    double heading = GeolocatorPlatform.instance.bearingBetween(
        testPoints[0].latitude,
        testPoints[0].longitude,
        testPoints[1].latitude,
        testPoints[1].longitude);

    return Stream.periodic(const Duration(seconds: 5), (x) {
      if (point < testPoints.length - 1) {
        point++;
      }

      heading = point < testPoints.length - 2
          ? GeolocatorPlatform.instance.bearingBetween(
              testPoints[point].latitude,
              testPoints[point].longitude,
              testPoints[point + 1].latitude,
              testPoints[point + 1].longitude)
          : heading;

      return Position.fromMap({
        'latitude': testPoints[point].latitude,
        'longitude': testPoints[point].longitude,
        'speed': speed,
        'heading': heading,
      });
    });
  }

  @override
  bool getBatteryLow() {
    return true;
  }

  @override
  void setBatteryLow(bool isBatteryLow) {}
}
