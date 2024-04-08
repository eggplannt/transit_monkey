// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin;

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:clippy_flutter/clippy_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/globals.dart';
import 'package:transit_monkey/apis.dart';
import 'package:transit_monkey/pages/bus_stop_page/bus_stop_page_loader.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

class MainPageMap extends StatefulWidget {
  final LatLng initPosition;
  const MainPageMap(
    this.initPosition, {
    super.key,
  });

  @override
  State<MainPageMap> createState() => _MainPageMapState();
}

class _MainPageMapState extends State<MainPageMap> {
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  StreamController<Set<Marker>> busStoMarkerStream = StreamController();
  bool updatingTimer = false;

  Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;

  Future<GoogleMapController> get controller async {
    return await _mapControllerCompleter.future;
  }

  Set<Stop> busStops = {};
  LatLng? _lastCameraPosition;
  late LatLng initPosition;
  BitmapDescriptor? busStopIcon;
  static const busStopCheckDistance = 0.6;
  static const minBusStopZoom = 15;

  @override
  void initState() {
    initPosition = widget.initPosition;
    _updateNearbyStop(initPosition, busStopCheckDistance);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<Marker>>(
        stream: busStoMarkerStream.stream,
        initialData: const {},
        builder: (context, snapshot) {
          var busMarkers = snapshot.data!;
          // markers.add(getBusStopMarker('Test Stop', initPosition, 'Test Stop'));
          return backgroundMap(initPosition, busMarkers);
        });
  }

  void _updateNearbyStop(LatLng location, double distance) async {
    updatingTimer = true;
    var c = await controller;
    var zoomeLevel = await c.getZoomLevel();
    if (zoomeLevel < minBusStopZoom) {
      busStoMarkerStream.add(const {});
      updatingTimer = false;
      return;
    }
    Set<Stop> newBusStops = busStops;
    var url = Uri.http(backendIp, '/stops/in_range/$distance', {
      'lat': location.latitude.toString(),
      'lon': location.longitude.toString()
    });
    var responce = await http.get(url);
    if (responce.statusCode != 200) {
      log(responce.body);
      return;
    }

    List<Stop> filteredStopDatas = stopsFromJson(responce.body);

    if (filteredStopDatas.isEmpty) return;
    for (var stopData in filteredStopDatas) {
      newBusStops.add(stopData);
    }
    busStops = newBusStops;

    Set<Marker> markers = {};
    for (var busStop in busStops) {
      if (busStop.type != 0) continue;
      var marker = await getBusStopMarker(
        busStop.id,
        busStop.position,
        busStop.name,
      );
      markers.add(marker);
    }
    busStoMarkerStream.add(markers);
    updatingTimer = false;
  }

  Future<Marker> getBusStopMarker(
      String stopId, LatLng markerPosition, String title) async {
    busStopIcon ??= await Image.asset('assets/imgs/bus_marker.png')
        .toBitmapDescriptor(imageSize: const Size(75, 75));

    return Marker(
      markerId: MarkerId(stopId),
      position: markerPosition,
      icon: busStopIcon!,
      onTap: () {
        var thisMarker = Marker(
          markerId: MarkerId(stopId),
          position: markerPosition,
          icon: busStopIcon!,
        );
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => BusStopPageLoader(
            stopId: stopId,
            initPosition: markerPosition,
            busStopMarker: thisMarker
          )
        ));
      },

    );
  }

  Widget busStopWindow(String title) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Bevel(
            cutLength: 10,
            child: Container(
                // decoration: BoxDecoration(
                //         color: Theme.of(context).colorScheme.primaryContainer,
                //         borderRadius: BorderRadius.circular(6)),
                // child: ListTile(
                //   tileColor: Theme.of(context).colorScheme.primaryContainer,
                //   leading: const ImageIcon(AssetImage(busImagePath)),
                //   title: Text(title),
                //   subtitle: Text('as of ${secondsAgo + snapshot.data!}s ago'),

                // ),
                )),
      ],
    );
  }

  Widget backgroundMap(LatLng currentPosition, Set<Marker> markers) {
    if (_mapController != null) _mapControllerCompleter = Completer();
    setMapTheme();
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentPosition.latitude, currentPosition.longitude),
          zoom: 17,
        ),
        onTap: (position) {
          _customInfoWindowController.hideInfoWindow!();
        },
        onCameraMove: (position) {
          _customInfoWindowController.onCameraMove!();
          _lastCameraPosition = position.target;
        },
        onCameraIdle: () {
          if (!updatingTimer) {
            _updateNearbyStop(_lastCameraPosition!, busStopCheckDistance);
          }
        },
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          _mapControllerCompleter.complete(controller);
          _customInfoWindowController.googleMapController = controller;
        },
      ),
      CustomInfoWindow(
        controller: _customInfoWindowController,
        height: 75,
        width: 300,
        offset: 50,
      ),
    ]);
  }

  void setMapTheme() async {
    final c = await controller;
    late String mapStyle;
    if (Theme.of(context).colorScheme.brightness == Brightness.dark) {
      mapStyle = await rootBundle.loadString('assets/json/map_darkmode.json');
      c.setMapStyle(mapStyle);
      return;
    }
    mapStyle = await rootBundle.loadString('assets/json/map_lightmode.json');
    c.setMapStyle(mapStyle);
  }
}

/// returns distance between [p1] and [p2] in kelometers
double calculatePointDistance(LatLng p1, LatLng p2) {
  double p = 0.017453292519943295;
  double a = 0.5 -
      cos((p2.latitude - p1.latitude) * p) / 2 +
      cos(p1.latitude * p) *
          cos(p2.latitude * p) *
          (1 - cos((p2.longitude - p1.longitude) * p)) /
          2;
  return 12742 * asin(sqrt(a));
}
