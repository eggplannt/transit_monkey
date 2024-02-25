// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin;

import  'package:flutter/material.dart';
import 'package:clippy_flutter/clippy_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tuple/tuple.dart';

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
  Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  StreamController<Tuple2<Set<BusStop>, bool>> busStopDateStream = StreamController();
  Timer? updateBusStopTimer;

  Future<GoogleMapController> get controller async {
    if(_mapController != null) return _mapController!;
    _mapController = await _mapControllerCompleter.future;
    return _mapController!;
  }
  Set<BusStop> busStops = {};
  LatLng? _lastCameraPosition;
  late LatLng initPosition; 

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
    return StreamBuilder<Tuple2<Set<BusStop>, bool>>(
      stream: busStopDateStream.stream,
      initialData: const Tuple2({}, false),
      builder: (context, snapshot){
        var busStops = snapshot.data!.item1;
        var loadingMarkers = snapshot.data!.item2;
        Set<Marker> markers = loadingMarkers ?  
          busStops.map((busStop) =>
            getBusStopMarker(
              busStop.id,
              busStop.position,
              busStop.name
          )).toSet()
          : {};
        // markers.add(getBusStopMarker('Test Stop', initPosition, 'Test Stop'));
        return backgroundMap(initPosition, markers);
      }
    );    
  }
  void _updateNearbyStop(LatLng location, double distance) async{
    var c = await controller;
    var zoomeLevel = await c.getZoomLevel();
    if(zoomeLevel < minBusStopZoom){
      busStopDateStream.add(
        const Tuple2({}, false)
      );
      return;
    }
    Set<BusStop> newBusStops = busStops;
    await gtfs_db.queryTable(
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

    busStopDateStream.add(Tuple2(
      busStops = newBusStops,
      true
    ));
  }
  Marker getBusStopMarker(String markerId, LatLng markerPosition, String title) {
    
    return  Marker(
      markerId: MarkerId(markerId),
      position: markerPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen
      ),
      onTap: () async {
        gtfs_db.queryDatabase(
          '''
            SELECT DISTINCT r.route_short_name
            FROM stop_times st
            INNER JOIN trips t ON t.trip_id = st.trip_id
            INNER JOIN routes r ON r.route_id = t.route_id
            WHERE st.stop_id = ?
          ''', 
          [markerId]
        ).then((value) => log(value.toString()));
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
    _mapControllerCompleter = Completer();
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
            if(updateBusStopTimer == null){
              Timer.periodic(const Duration(milliseconds: 500), (timer) { 
                _updateNearbyStop(_lastCameraPosition!, busStopCheckDistance);
                timer.cancel();
              });
            }
            else if(!updateBusStopTimer!.isActive){
              Timer.periodic(const Duration(milliseconds: 500), (timer) { 
                _updateNearbyStop(_lastCameraPosition!, busStopCheckDistance);
                timer.cancel();
              });
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