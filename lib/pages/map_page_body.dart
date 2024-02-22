// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/foundation.dart';
import  'package:flutter/material.dart';
import 'package:clippy_flutter/clippy_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../db/generated/gtfs-realtime.pb.dart' hide  Position;
import '../db/gtfs_database.dart' as gtfs_db;
import '../db/gtfs_protobuf.dart' as gtfs_pb;
import 'package:transit_monkey/constants.dart';

class MapPageBody extends StatefulWidget {
  final LatLng initPosition; 
  final FeedMessage vehiclesFeed;
  const MapPageBody(
    this.initPosition,
    this.vehiclesFeed,
    {super.key,}
  );

  @override
  State<MapPageBody> createState() => _MapPageBodyState();
}
class _MapPageBodyState extends State<MapPageBody> {
  Completer<GoogleMapController> _controller = Completer();
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  final _busMarkersStreamController = StreamController<Set<Marker>>();
  final _busTimerStreamController = StreamController<int>();

  int _busTimerIncrement = 0;

  List<String> _previosTripIds = [];
  List<Map<String, dynamic>>?  _gtfsTripDataLists;

  Set<Marker> markers = {};
  
  late LatLng initPosition; 
  late FeedMessage initVehiclesFeed;

  @override
  void initState() {
    initPosition = widget.initPosition;
    initVehiclesFeed = widget.vehiclesFeed;

    updateVehicleMarkerStream();
    updateMarkerTimerStream();
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    List<String> tripIds = [];
    markers = {};

    
    for (int i = 0; i < initVehiclesFeed.entity.length; i++) {
      String title = 'Loading...';
      String markerId = 'Trip ${initVehiclesFeed.entity[i].vehicle.trip.tripId}';
      LatLng markerPosition = LatLng(initVehiclesFeed.entity[i].vehicle.position.latitude, initVehiclesFeed.entity[i].vehicle.position.longitude);
      var timestamp =  DateTime.fromMillisecondsSinceEpoch(initVehiclesFeed.entity[i].vehicle.timestamp.toInt() * 1000);
      int secondsAgo = DateTime.now().difference(timestamp).inSeconds;
      String tripId = initVehiclesFeed.entity[i].vehicle.trip.tripId;
      tripIds.add(tripId);
      addBusMarker(markerId, markerPosition, title, secondsAgo);
    }
    addBusMarker('Test Bus', initPosition, 'Test Bus', 5);

    return StreamBuilder(
      stream: _busMarkersStreamController.stream, 
      initialData: markers,
      builder: ((context, snapshot) {
        return backgroundMap(initPosition, markers);
      })
    );
  }

  void addBusMarker(String markerId, LatLng markerPosition, String title, int secondsAgo) {
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: markerPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue
        ),
        onTap: () {
          _customInfoWindowController.addInfoWindow!(
            busItemWindow(title, secondsAgo),
            markerPosition,
          );
        },
      ),
    );
  }
  
  Widget busItemWindow(String title, int secondsAgo) {
    return StreamBuilder(
      stream: _busTimerStreamController.stream,
      initialData: _busTimerIncrement,
      builder: (context, snapshot) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Bevel(
              cutLength: 10, 
              child: Container(
                decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6)),
                child: ListTile(
                  tileColor: Theme.of(context).colorScheme.primaryContainer,
                  leading: const ImageIcon(AssetImage(busImagePath)),
                  title: Text(title),
                  subtitle: Text('as of ${secondsAgo + snapshot.data!}s ago'),
                  
                ),
              )
            ),
          ],
        );
      }
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
          myLocationButtonEnabled: false,
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
  Set<Marker> handleMarkers(List<Map<String, dynamic>> gtfsDataLists) {
    Set<Marker> newMarkers = {};
    
    for(int i = 0; i < _gtfsTripDataLists!.length; i++){
      var timestamp =  DateTime.fromMillisecondsSinceEpoch(initVehiclesFeed.entity[i].vehicle.timestamp.toInt() * 1000);
      int secondsAgo = DateTime.now().difference(timestamp).inSeconds;
      Map<String, dynamic> data = gtfsDataLists[i];
      newMarkers.add(
        Marker(
          markerId: markers.elementAt(i).mapsId,
          position: markers.elementAt(i).position,
          icon: markers.elementAt(i).icon,
          onTap: () {
            _customInfoWindowController.addInfoWindow!(
              busItemWindow(data['trip_headsign'], secondsAgo),
              markers.elementAt(i).position,
            );
          },
        )
      );
    }
    markers = newMarkers;
    addBusMarker('Test Bus', initPosition, 'Test Bus', 5);
    return markers;
  }

  Future<void> getGtfsDataLists(List<String> tripIds) async {
    if(listEquals(_previosTripIds, tripIds)) return;
    List<Map<String, dynamic>> newGtfsTripDataLists = [];
    for(var tripId in tripIds){
      var list =  await gtfs_db.tablesMap['trips']!.queryDatabase('SELECT trip_headsign FROM WHERE trip_id =?', [tripId]);
      if(list.isNotEmpty){
        print(list.first.toString());
        newGtfsTripDataLists.add(list.first);
      }
      else{
        Map<String, dynamic> noData = {'trip_headsign': 'No Data'};
        print(noData.toString());
        newGtfsTripDataLists.add(noData);
      }
    }
    _gtfsTripDataLists = newGtfsTripDataLists;
    _previosTripIds = tripIds;
    
  }
  
  updateVehicleMarkerStream() async {
    while(true){
      await Future.delayed(const Duration(seconds: 10));
      print('getting feed');
      FeedMessage feed = await gtfs_pb.vehiclePositionMessage.then((feed ) {
        print('got feed');
        return feed;
      });
      List<String> tripIds = [];
      for(var entry in feed.entity){
        tripIds.add(entry.vehicle.trip.tripId);
      }
      await getGtfsDataLists(tripIds);
      _busTimerIncrement = 0;
      _busMarkersStreamController.add(handleMarkers(_gtfsTripDataLists!));
    }
  }
  updateMarkerTimerStream() async {
    while (true){
      await Future.delayed(const Duration(seconds: 1));
      _busTimerIncrement++;
      _busTimerStreamController.add(_busTimerIncrement);
    }
  }

  void dispose() {
    _busMarkersStreamController.close();
    _busTimerStreamController.close();
    super.dispose();
  }
}