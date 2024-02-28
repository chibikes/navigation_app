import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigation_app/google_map_repository.dart';
import 'package:navigation_app/navigation.dart';
import 'package:wakelock/wakelock.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as map_kit;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const NavigationPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key, required this.title});

  final String title;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  var _currentLocation = const LatLng(0, 0);

  late GoogleMapController _mapController;
  late LocData locData;
  List<LatLng> polylineCoordinates = [];
  List<LatLng> destinations = [];
  var _instruction = '';
  bool hasFecthedDirection = false;
  bool navigationStarted = false;
  String speed = '', distance = '';
  Destination currentDestination = const Destination(
    pathToDestination: [],
    to: LatLng(0, 0),
    from: LatLng(0, 0),
    instruction: '',
    distance: 0,
    maneuver: '',
    index: 0,
  );
  late StreamSubscription<Position> locSub;

  final BitmapDescriptor _bitmapLocation = BitmapDescriptor.defaultMarker;

  final GoogleMapRepository _googleMapRepository = GoogleMapRepository();
  final _formKey = GlobalKey<FormState>();

  late Direction directions;
  String originAddress = '', destinationAddress = '';
  LatLng origin = const LatLng(0, 0), destination = const LatLng(0, 0);

  PolylineId poLyLineId = const PolylineId('route');
  Map<PolylineId, Polyline> polyLines = {};

  final Set<Marker> _markers = {};

  String time = '';

  @override
  void initState() {
    getCurrentLocation();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLocation != const LatLng(0, 0)
          ? Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: GoogleMap(
                    markers: _markers,
                    initialCameraPosition:
                        CameraPosition(target: _currentLocation, zoom: 19),
                    onMapCreated: _mapCreated,
                    polylines: Set<Polyline>.of(polyLines.values),
                  ),
                ),
                !navigationStarted
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 80),
                        child: Form(
                          key: _formKey,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: MediaQuery.of(context).size.width,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey
                                            .withOpacity(0.5), // Softer shadow
                                        spreadRadius: 3, // Spread the shadow
                                        blurRadius: 7, // Blur for a softer edge
                                        offset: const Offset(
                                            0, 3), // Offset it slightly
                                      ),
                                    ],
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(16.0)),
                                  ),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide:
                                            const BorderSide(width: 0.0),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      fillColor: Colors.blue,
                                      // labelText: 'Destination',
                                      hintText: 'Enter destination address',
                                    ),
                                    validator: (value) {
                                      return validateAddress(value ?? '');
                                    },
                                    onChanged: (text) {
                                      hasFecthedDirection = false;
                                      destinationAddress = text;
                                    },
                                  ),
                                ),
                              ]),
                        ),
                      )
                    : const SizedBox(),
                _instruction.isNotEmpty
                    ? Positioned(
                        top: 50,
                        left: 0.10 * MediaQuery.of(context).size.width,
                        child: Container(
                          decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey
                                      .withOpacity(0.5), // Softer shadow
                                  spreadRadius: 3, // Spread the shadow
                                  blurRadius: 7, // Blur for a softer edge
                                  offset:
                                      const Offset(0, 3), // Offset it slightly
                                ),
                              ],
                              color: const Color(0xff34BB78),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8.0))),
                          width: 0.80 * MediaQuery.of(context).size.width,
                          height: 150,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _instruction,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ],
            )
          : Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              color: Colors.blue,
            ),
      bottomSheet: BottomSheet(
        builder: (context) {
          return navigationStarted
              ? Container(
                  width: MediaQuery.of(context).size.width,
                  height: 100,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [Text(speed), const Text('km/h')],
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(time),
                            const SizedBox(
                              height: 8.0,
                            ),
                            Text(distance)
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, border: Border.all()),
                          child: Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: IconButton(
                                onPressed: () {
                                  resetState();
                                },
                                icon: const Icon(Icons.close)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox();
        },
        onClosing: () {},
      ),
      floatingActionButton: !navigationStarted
          ? FloatingActionButton(
              child: const Icon(
                Icons.navigation,
                color: Color(0xff34BB78),
              ),
              onPressed: () async {
                if (!hasFecthedDirection) {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    destination =
                        await getLatLngFromAddress(destinationAddress);
                    getDirection(
                        origin: _currentLocation, destination: destination);
                  }
                } else {
                  startNavigation();
                }
              })
          : const SizedBox(),
    );
  }

  void getCurrentLocation() async {
    await askLocationPermission();
    await Geolocator.requestPermission();
    final location = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(location.latitude, location.longitude);
    });
  }

  void _mapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  double getRemainingDistance() {
    // computes distance in meters
    final wayPoints = directions.wayPoints;

    double lowest = double.infinity;
    int index = 0;
    var dist = 0.0;
    for (int i = 0; i < wayPoints.length; i++) {
      dist = Geolocator.distanceBetween(
          _currentLocation.latitude,
          _currentLocation.longitude,
          wayPoints[i].latitude,
          wayPoints[i].longitude);
      if (lowest > dist) {
        lowest = dist;
        index = i;
      }
    }
    // then calculate distance
    List<LatLng> distances = wayPoints.sublist(index);
    List<map_kit.LatLng> path = [
      map_kit.LatLng(_currentLocation.latitude, _currentLocation.longitude)
    ];
    for (var element in distances) {
      path.add(map_kit.LatLng(element.latitude, element.longitude));
    }

    return map_kit.SphericalUtil.computeLength(path) as double;
  }

  void resetState() {
    setState(() {
      navigationStarted = false;
      locSub.cancel();
      hasFecthedDirection = false;
      _instruction = '';
      speed = '';
      distance = '';
      time = '';
    });
    refocusMap();
  }

  void computeTime(double distance, double speed) {
    /// distance should be in meters
    /// speed is in m/s
    var timex = ((distance / speed) / 60).roundToDouble(); // time in minutes

    time = timex.toStringAsFixed(0);
    if (timex >= 60) {
      //convert time to hours
      timex = timex / 60;
      if (timex >= 24) {
        timex = timex / 24;
        time = timex.toStringAsFixed(0);
        time = timex < 2 ? '$timex day' : '$timex days';
      }
      time = timex.toStringAsFixed(0);
      time = timex < 2 ? '$timex hr' : '$timex hrs';
    }
    if (timex < 1) {
      // convert to seconds
      time = time * 60;
      time = timex.toStringAsFixed(0);
      time = '$timex secs';
    }
    time = timex < 2 ? '$timex min' : '$timex mins';
  }

  void startNavigation() {
    setState(() {
      navigationStarted = true;
    });

    Wakelock.enable();

    _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation, zoom: 19, tilt: 80)));

    if (kDebugMode) {
      locData = TestLocationData(directions.wayPoints);
    } else {
      locData = RealLocationData();
    }

    double bearing = 0;

    locSub = locData.getPosition().listen((event) {
      _currentLocation = LatLng(event.latitude, event.longitude);
      if ((event.heading - bearing).abs() > 5) {
        bearing = event.heading;
        _mapController.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
                target: _currentLocation,
                bearing: event.heading,
                zoom: 19,
                tilt: 80)));
      } else {
        _mapController.animateCamera(CameraUpdate.newLatLng(_currentLocation));
      }

      _markers.removeWhere(
        (element) => element.markerId == const MarkerId('location'),
      );

      setState(() {
        _markers.add(Marker(
            icon: _bitmapLocation,
            markerId: const MarkerId('location'),
            position: _currentLocation));
      });

      var computedDistance = getRemainingDistance();
      speed = ((event.speed * 3600) / 1000).toStringAsFixed(0);
      if (computedDistance >= 1000) {
        // convert to km
        distance = '${(computedDistance / 1000).toStringAsFixed(2)} km';
      } else {
        distance = '${computedDistance.toStringAsFixed(2)} m';
      }

      computeTime(computedDistance, event.speed);

      updateNavigationData();
    });
  }

  Future<void> askLocationPermission() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }
    } catch (e) {
      // ErrorReportingService.log('Error getting location permissions: $e');
    }
  }

  Destination getDestination() {
    try {
      // returns destination based on current position
      double lowest = double.infinity;
      int index = 0;
      var dist = 0.0;
      for (int i = 0; i < directions.destinations.length; i++) {
        dist = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
            directions.destinations[i].from.latitude,
            directions.destinations[i].from.longitude);
        if (lowest > dist) {
          lowest = dist;
          index = i;
        }
      }
      // checks to see if you are going towards destinations[index].from or away
      debugPrint('Index is $index');
      if (index == 0) {
        return directions.destinations[index];
      } else if (calcDist(
              _currentLocation, directions.destinations[index - 1].from) <
          calcDist(directions.destinations[index - 1].from,
              directions.destinations[index].from)) {
        return directions.destinations[index - 1];
      } else {
        return directions.destinations[index];
      }
    } catch (e) {
      debugPrint('error trying to : $e');
    }
    return directions.destinations[0];
  }

  void getDirection(
      {required LatLng origin, required LatLng destination}) async {
    directions =
        await _googleMapRepository.getDirectionDetails(origin, destination);
    for (int i = 0; i < directions.destinations.length; i++) {
      // get all destinations that will have to be reached to get to final destination
      // which is all the [from] parameters and the last [to] parameter
      destinations.add(LatLng(directions.destinations[i].from.latitude,
          directions.destinations[i].from.longitude));
      if (i == directions.steps.length - 1) {
        // also retrieve last destination
        destinations.add(LatLng(directions.destinations[i].to.latitude,
            directions.destinations[i].to.longitude));
      }
    }
    if (directions.wayPoints.isNotEmpty) {
      hasFecthedDirection = true;
    }
    createPolyLine();
  }

  double calcDist(LatLng start, LatLng end) {
    ///calculate distance between two coordinates and returns it in metres
    return Geolocator.distanceBetween(
        start.latitude, start.longitude, end.latitude, end.longitude);
  }

  Future<void> createPolyLine() async {
    polylineCoordinates.clear();
    final wayPoints = directions.wayPoints;
    if (wayPoints.isNotEmpty) {
      for (var element in wayPoints) {
        polylineCoordinates.add(LatLng(element.latitude, element.longitude));
      }
    }

    Polyline polyline = Polyline(
      endCap: Cap.buttCap,
      startCap: Cap.roundCap,
      polylineId: poLyLineId,
      color: Colors.black,
      points: polylineCoordinates,
      width: 7,
    );

    setState(() {
      polyLines[poLyLineId] = polyline;
    });
    refocusMap();
  }

  void refocusMap() {
    List<LatLng> points = directions.wayPoints;
    if (points.isEmpty) return;
    _markers.removeWhere((element) =>
        element.markerId == const MarkerId('origin') ||
        element.markerId == const MarkerId('destination'));
    setState(() {
      _markers.addAll({
        Marker(
          icon: _bitmapLocation,
          markerId: const MarkerId('origin'),
          position: points.first,
        ),
        Marker(
          icon: _bitmapLocation,
          markerId: const MarkerId('destination'),
          position: points.last,
        ),
      });
    });

    var latLngBounds = getMapBounds(points);

    if (mounted) {
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(
        latLngBounds!,
        100,
      ));
    }
  }

  LatLngBounds? getMapBounds(List<LatLng> points) {
    // focus map camera on points
    if (points.isEmpty) return null;
    double minLat = points.first.latitude;
    double minLong = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLong = points.first.longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLong) minLong = point.longitude;
      if (point.longitude > maxLong) maxLong = point.longitude;
    }

    return LatLngBounds(
        southwest: LatLng(minLat, minLong), northeast: LatLng(maxLat, maxLong));
  }

  void updateNavigationData() {
    final nextDestination = getDestination();
    debugPrint((nextDestination != currentDestination).toString());
    if (nextDestination != currentDestination) {
      currentDestination = nextDestination;
      setState(() {
        _instruction = nextDestination.instruction
            .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
      });
    }
  }

  String? validateAddress(String address) {
    if (address.isEmpty) {
      return 'Address should not be empty';
    }
    return null;
  }

  Future<LatLng> getLatLngFromAddress(String address) async {
    var locations = [];
    var ltLng = const LatLng(0, 0);
    try {
      locations = await GeocodingPlatform.instance.locationFromAddress(address);
      ltLng = LatLng(locations.first.latitude, locations.first.longitude);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location: $e');
      }
    }
    return ltLng;
  }
}
