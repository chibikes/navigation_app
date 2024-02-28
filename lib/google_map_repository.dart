import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:navigation_app/consts.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as map_kit;

class GoogleMapRepository {
  final _mapClient = GoogleMapClient();

  Future<Direction> getDirectionDetails(
    LatLng origin,
    LatLng destination,
  ) async {
    List<LatLng> wayPoints = [];
    Direction direction = const Direction(
        duration: 0, distance: 0, wayPoints: [], steps: [], destinations: []);

    try {
      final directionDetails = await _mapClient.getDirectionDetail(
        origin: origin,
        destination: destination,
        googleApiKey: Environment.googleApiKey,
      );

      final duration = getDuration(directionDetails);
      final distance = getDistance(directionDetails);
      final steps = retrieveSteps(directionDetails);
      wayPoints = getWayPoints(directionDetails);

      direction = Direction(
          duration: duration,
          distance: distance,
          wayPoints: wayPoints,
          steps: steps,
          destinations: getDestinations(directionDetails));
    } catch (e) {
      debugPrint('Could not retrieve direction: $e');
    }
    return direction;
  }

  double getDuration(Map<String, dynamic> json) {
    /// returns duration in seconds
    num duration = json["routes"][0]["legs"][0]["duration"]["value"];
    return duration.toDouble();
  }

  double getDistance(Map<String, dynamic> json) {
    num distance = json["routes"][0]["legs"][0]["distance"]["value"];
    return distance.toDouble();
  }

  List<LatLng> getWayPoints(Map<String, dynamic> json) {
    var points = map_kit.PolygonUtil.decode(
        json.isEmpty ? '' : json["routes"][0]["overview_polyline"]["points"]);
    return points.map((e) => LatLng(e.latitude, e.longitude)).toList();
  }

  retrieveSteps(Map<String, dynamic> json) {
    if (json.isEmpty) return;
    List<Map<String, dynamic>> newSteps = [];

    var steps = json["routes"][0]["legs"][0]["steps"];

    for (var step in steps) {
      try {
        newSteps.add(step as Map<String, dynamic>);
      } catch (e) {
        throw UnimplementedError();
      }
    }

    return newSteps;
  }

  List<Destination> getDestinations(Map<String, dynamic> json) {
    try {
      if (json.isEmpty) return [];
      var steps = json["routes"][0]["legs"][0]["steps"];
      List<Destination> destinations = [];
      LatLng from = const LatLng(0, 0);
      LatLng to = const LatLng(0, 0);
      List<LatLng> path = [];
      String maneuver = '';
      for (int i = 0; i < steps.length; i++) {
        from = LatLng(steps[i]["start_location"]["lat"],
            steps[i]["start_location"]["lng"]);
        to = LatLng(
            steps[i]["end_location"]["lat"], steps[i]["end_location"]["lng"]);
        var kitList =
            map_kit.PolygonUtil.decode(steps[i]["polyline"]["points"]);
        path = [];
        for (var ltLng in kitList) {
          path.add(LatLng(ltLng.latitude, ltLng.longitude));
        }
        if (steps[i].containsKey("maneuver")) {
          maneuver = steps[i]["maneuver"];
        } else {
          maneuver = '';
        }
        num distance = steps[i]["distance"]["value"];
        destinations.add(Destination(
            pathToDestination: path,
            from: from,
            to: to,
            instruction: steps[i]["html_instructions"],
            maneuver: maneuver,
            distance: distance.toDouble(),
            index: i));
      }
      return destinations;
    } catch (e) {
      throw 'Parsing Error : $e';
    }
  }
}

enum TravelMode { driving }

class WayPoint {
  String location;

  bool stopOver;

  WayPoint({required this.location, this.stopOver = true});

  @override
  String toString() {
    if (stopOver) {
      return location;
    } else {
      return "via:$location";
    }
  }
}

class GoogleMapClient {
  static const String statusOk = "ok";

  Future<Map<String, dynamic>> getDirectionDetail({
    required LatLng origin,
    required LatLng destination,
    required String googleApiKey,
    bool avoidHighways = false,
    bool avoidFerries = false,
    bool avoidTolls = false,
    TravelMode travelMode = TravelMode.driving,
    bool optimizeWaypoints = true,
    List<WayPoint> wayPoints = const [],
  }) async {
    String mode = travelMode.toString().replaceAll('TravelMode.', '');
    var params = {
      "origin": "${origin.latitude},${origin.longitude}",
      "destination": "${destination.latitude},${destination.longitude}",
      "mode": mode,
      "avoidHighways": "$avoidHighways",
      "avoidFerries": "$avoidFerries",
      "avoidTolls": "$avoidTolls",
      "key": googleApiKey
    };

    if (wayPoints.isNotEmpty) {
      List wayPointsArray = [];
      for (var point in wayPoints) {
        wayPointsArray.add(point.location);
      }
      String wayPointsString = wayPointsArray.join('|');
      if (optimizeWaypoints) {
        wayPointsString = 'optimize:true|$wayPointsString';
      }
      params.addAll({"waypoints": wayPointsString});
    }

    Uri uri =
        Uri.https("maps.googleapis.com", "maps/api/directions/json", params);
    var response = await http.get(uri);
    Map<String, dynamic> directionData = {};

    if (response.statusCode == 200) {
      var parsedJson = json.decode(response.body);
      if (parsedJson["status"]?.toLowerCase() == statusOk &&
          parsedJson["routes"] != null &&
          parsedJson["routes"].isNotEmpty) {
        directionData = parsedJson as Map<String, dynamic>;
      } else {
        debugPrint(parsedJson["error_message"]);
      }
    }
    return directionData;
  }

  List<LatLng> decodeEncodedPolyline(String encoded) {
    if (encoded.isEmpty) return [];
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      LatLng p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }
}

class Direction extends Equatable {
  /// interface for routing api

  /// duration is in seconds
  final double duration;

  /// distance is in meters
  final double distance;
  final List<LatLng> wayPoints;
  final List<Map<String, dynamic>> steps;
  final List<Destination> destinations;

  const Direction(
      {required this.duration,
      required this.distance,
      required this.wayPoints,
      required this.steps,
      required this.destinations});

  @override
  List<Object?> get props =>
      [duration, distance, wayPoints, steps, destinations];
}

class Destination extends Equatable {
  /// end position
  final LatLng to;

  /// starting position
  final LatLng from;
  final List<LatLng> pathToDestination;

  /// distance to get to destination
  final double distance;

  /// instructions on how to get to [to] position from [from]
  final String instruction;

  /// maneuver required to get to [to]
  final String maneuver;
  final int index;

  const Destination(
      {required this.pathToDestination,
      required this.to,
      required this.from,
      required this.instruction,
      required this.distance,
      required this.maneuver,
      required this.index});

  @override
  List<Object?> get props =>
      [from, to, pathToDestination, distance, instruction, maneuver];
}
