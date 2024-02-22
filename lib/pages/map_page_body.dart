// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';
import 'dart:ffi';
import 'dart:math' show cos, sqrt, asin, pi;

import  'package:flutter/material.dart';
import 'package:clippy_flutter/clippy_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../db/gtfs_database.dart' as gtfs_db;

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
  Completer<GoogleMapController> _controller = Completer();
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  Set<Marker> markers = {};
  
  late LatLng initPosition; 

  @override
  void initState() {
    initPosition = widget.initPosition;
    _getNearbyStopMarkers(initPosition, .5);
    super.initState();
  }
  @override
  Widget build(BuildContext context) {    
    markers.add(getBusStopMarker('Test Stop', initPosition, 'Test Stop',));
    return backgroundMap(initPosition, markers);
  }
  void _getNearbyStopMarkers(LatLng location, double distance) async{

    double deltaLatitude = (180/pi)*(distance/6378.137);
    double deltaLongitude = (180/pi)*(distance/6378.137)/cos(pi/180*location.latitude);


    print('getting data');
    List<Map<String, dynamic>> stopDatas = await gtfs_db.tablesMap['stops']!.queryTable(
      'SELECT stop_id, stop_name, stop_lat, stop_lon FROM ',
      []
    );

    print('got data');
    Set<Marker> newMarkers = markers;
    

    var filteredStopDatas = stopDatas.where((stopData) {
      var lat = stopData['stop_lat'];
      var lon = stopData['stop_lon'];
      return lat >= location.latitude - deltaLatitude
          && lat <= location.latitude + deltaLatitude
          && lon >= location.longitude - deltaLongitude
          && lon <= location.longitude + deltaLongitude;
    });
    if(filteredStopDatas.isEmpty) return;
    for (var stopData in filteredStopDatas){
      newMarkers.add(getBusStopMarker(
        stopData['stop_id'].toString(),
        LatLng(stopData['stop_lat'], stopData['stop_lon']),
        stopData['stop_name'],
      ));
    }
    print('used data');
    setState(() {
      markers = newMarkers;
    });
  }
  Marker getBusStopMarker(String markerId, LatLng markerPosition, String title) {
    
    return  Marker(
      markerId: MarkerId(markerId),
      position: markerPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen
      ),
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
    _controller = Completer();
    setMapTheme();
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(currentPosition.latitude, currentPosition.longitude),
            zoom: 15,
          ),
          onTap: (position) {
            _customInfoWindowController.hideInfoWindow!();
          },
          onCameraMove: (position) {
            _customInfoWindowController.onCameraMove!();
          },
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (controller) {
              _controller.complete(controller);
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
    final controller = await _controller.future;
    late String mapStyle;
    if(Theme.of(context).colorScheme.brightness == Brightness.dark){
      mapStyle  = await rootBundle.loadString('assets/json/map_darkmode.json');
      controller.setMapStyle(mapStyle);
      return;
    }
    mapStyle  = await rootBundle.loadString('assets/json/map_lightmode.json');
    controller.setMapStyle(mapStyle);
  }
}
class BusStop {
  String stopName;
  LatLng stopPosisiton;
  int stopType;
  int stopId;

  BusStop(
    this.stopName,
    this.stopPosisiton,
    this.stopType,
    this.stopId
  );
}

/// returns distance between [p1] and [p2] in kelometers
double calculatePointDistance(LatLng p1, LatLng p2){
    double p = 0.017453292519943295;
    double a = 0.5 - cos((p2.latitude - p1.latitude) * p)/2 +
        cos(p1.latitude * p) * cos(p2.latitude * p) *
            (1 - cos((p2.longitude - p1.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }