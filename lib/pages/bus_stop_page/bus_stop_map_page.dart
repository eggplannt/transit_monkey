// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/globals.dart';
import 'package:transit_monkey/backend_decoders.dart';

class BusStopMapPage extends StatefulWidget {
  final LatLng initPosition;
  final Marker busStopMarker;
  final String stopId;
  const BusStopMapPage(
      {super.key,
      required this.initPosition,
      required this.busStopMarker,
      required this.stopId});

  @override
  State<BusStopMapPage> createState() => _BusStopMapPageState();
}

class _BusStopMapPageState extends State<BusStopMapPage> {
  Completer<GoogleMapController> _mapControllerCompleter = Completer();

  Future<GoogleMapController> get mapController async {
    return await _mapControllerCompleter.future;
  }

  StreamController<Set<Marker>> busMarkerStream = StreamController();
  Timer? timer;

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateBusStream();
    });
    _updateBusStream();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<Marker>>(
        stream: busMarkerStream.stream,
        initialData: {},
        builder: (context, snapshot) {
          snapshot.data!.add(widget.busStopMarker);
          return backgroundMap(widget.initPosition, snapshot.data!);
        });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _updateBusStream() async {
    Set<Marker> markers = {};

    var url = Uri.http(backendIp, '/bus/heading_to_stop/${widget.stopId}');
    log('getting busses');
    var responce = await http.get(url);
    log('got busses');

    if (responce.statusCode != 200) {
      log(responce.body);
      return;
    }

    List<Bus> busses = busesFromJson(responce.body);
    if (busses.isEmpty) return;

    for (var bus in busses) {
      markers.add(
          getBusMarker(bus.trip.tripId, bus.position, bus.trip.tripHeadsign));
    }
    busMarkerStream.add(markers);
  }

  Widget backgroundMap(LatLng currentPosition, Set<Marker> markers) {
    if (_mapControllerCompleter.isCompleted) {
      _mapControllerCompleter = Completer();
    }
    setMapTheme(Theme.of(context).colorScheme.brightness);
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentPosition.latitude, currentPosition.longitude),
          zoom: 17,
        ),
        onCameraIdle: () {},
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          _mapControllerCompleter.complete(controller);
        },
      ),
    ]);
  }

  void setMapTheme(brightness) async {
    final controller = await mapController;
    late String mapStyle;
    if (brightness == Brightness.dark) {
      mapStyle = await rootBundle.loadString('assets/json/map_darkmode.json');
      controller.setMapStyle(mapStyle);
      return;
    }
    mapStyle = await rootBundle.loadString('assets/json/map_lightmode.json');
    controller.setMapStyle(mapStyle);
  }

  static Marker getBusMarker(
      String markerId, LatLng markerPosition, String title) {
    return Marker(
      markerId: MarkerId(markerId),
      position: markerPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      onTap: () {
        log(title);
      },
    );
  }
}
