// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';
import 'dart:math' show cos, sqrt, asin;

import  'package:flutter/material.dart';
import 'package:clippy_flutter/clippy_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/pages/bus_stop_map_page.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

import '../db/gtfs_database.dart';

class MapPageBody extends StatefulWidget {
  final LatLng initPosition;
  const MapPageBody(
    this.initPosition,
    {super.key,}
  );

  @override
  State<MapPageBody> createState() => _MapPageBodyState();
}
class _MapPageBodyState extends State<MapPageBody> {
  
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  StreamController<Set<Marker>> busStoMarkerStream = StreamController();
  bool updatingTimer = false;

  Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;

  Future<GoogleMapController> get controller async {
    return await _mapControllerCompleter.future;
  }
  Set<BusStop> busStops = {};
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
      builder: (context, snapshot){
        var busMarkers = snapshot.data!;
        // markers.add(getBusStopMarker('Test Stop', initPosition, 'Test Stop'));
        return backgroundMap(initPosition, busMarkers);
      }
    );    
  }
  void _updateNearbyStop(LatLng location, double distance) async{
    busStopIcon ??= await Image.asset(
        'assets/imgs/bus_marker.png'
      ).toBitmapDescriptor(
      logicalSize: const Size(376, 564), imageSize: const Size(56, 82
    ));
    updatingTimer = true;
    var c = await controller;
    var zoomeLevel = await c.getZoomLevel();
    if(zoomeLevel < minBusStopZoom){
      busStoMarkerStream.add(
        const {}
      );
      updatingTimer = false;
      return;
    }
    Set<BusStop> newBusStops = busStops;
    await queryTable(
      'stops',
      selections: 'stop_id, stop_name, stop_lat, stop_lon, location_type'
    )
    .then(
      (stopDatas) => stopDatas.where((stopData) {
        LatLng stopPosition = LatLng(stopData['stop_lat'], stopData['stop_lon']);
        return calculatePointDistance(stopPosition, location) <= distance;
      })
    )
    .then((filteredStopDatas) {
      if(filteredStopDatas.isEmpty) return;
      for (var stopData in filteredStopDatas){
        newBusStops.add(BusStop(
          id: stopData['stop_id'].toString(),
          position: LatLng(stopData['stop_lat'], stopData['stop_lon']),
          name: stopData['stop_name'],
          type: stopData['location_type']
        ));
      }
    });
    busStops = newBusStops;


    Set<Marker> markers = {};
    for (var busStop in busStops){
      if(busStop.type != 0) continue;
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
  Future<Marker> getBusStopMarker(String stopId, LatLng markerPosition, String title) async {
    
    return  Marker(
      markerId: MarkerId(stopId),
      position: markerPosition,
      icon: busStopIcon!,
      onTap: () {
        var thisMarker = Marker(
          markerId: MarkerId(stopId),
          position: markerPosition,
          icon: busStopIcon!,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BusStopMapPage(
              stopId: stopId,
              initPosition: markerPosition,
              busStopMarker: thisMarker
            )
          )
        );
      },
      
      // TODO: add info window
      // onTap: () {
      //   _customInfoWindowController.addInfoWindow!(
      //     busStopWindow(title),
      //     markerPosition,
      //   );
      // },
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
          )
        ),
      ],
    );
  }

  Widget backgroundMap(LatLng currentPosition, Set<Marker> markers) {
    if(_mapController != null) _mapControllerCompleter = Completer();
    setMapTheme();
    return Stack(
      children: [
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
            if(!updatingTimer){
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
      ]
    );
  }

  void setMapTheme() async{
    final c = await controller;
    late String mapStyle;
    if(Theme.of(context).colorScheme.brightness == Brightness.dark){
      mapStyle  = await rootBundle.loadString('assets/json/map_darkmode.json');
      c.setMapStyle(mapStyle);
      return;
    }
    mapStyle  = await rootBundle.loadString('assets/json/map_lightmode.json');
    c.setMapStyle(mapStyle);
  }
}
class BusStop {
  String name;
  LatLng position;
  int type;
  String id;

  BusStop({
    required this.name,
    required this.position,
    required this.type,
    required this.id
  });
}

/// returns distance between [p1] and [p2] in kelometers
double calculatePointDistance(LatLng p1, LatLng p2){
    double p = 0.017453292519943295;
    double a = 0.5 - cos((p2.latitude - p1.latitude) * p)/2 +
        cos(p1.latitude * p) * cos(p2.latitude * p) *
            (1 - cos((p2.longitude - p1.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }