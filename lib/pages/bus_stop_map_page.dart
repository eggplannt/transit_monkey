import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/db/generated/gtfs-realtime.pb.dart';
import 'package:transit_monkey/db/gtfs_database.dart';

import '../db/gtfs_protobuf.dart';


class BusStopMapPage extends StatefulWidget {
  final LatLng initPosition;
  final Marker busStopMarker;
  final String stopId;
  const BusStopMapPage({
    super.key, 
    required this.initPosition,
    required this.busStopMarker,
    required this.stopId
  });

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
    timer = Timer.periodic(Duration(seconds: 10), (timer) { _updateBusStream();});
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
      }
    );
  }
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
  void _updateBusStream() async {
    log('getting feed');
    FeedMessage feed = await vehiclePositionMessage.then((feed) {
      log('got feed');
      return feed;
    });
    Set<Marker> markers = {};

    List<VehiclePosition> vehicles = [];
    for(var entity in feed.entity){
      int sequence = await queryDatabase('''
        SELECT st.stop_sequence
        FROM stop_times st
        WHERE st.trip_id = ? AND st.stop_id = ?
      ''',
      [entity.vehicle.trip.tripId, widget.stopId]
      )
      .then((value) {
        if(value.isNotEmpty) return value.first['stop_sequence'] as int;
        return -1;
      });
    

      if(entity.vehicle.currentStopSequence < sequence){
        vehicles.add(entity.vehicle);
      }
    }

    for(var vehicle in vehicles){
      
      var tripId = vehicle.trip.tripId;
      var position = LatLng( vehicle.position.latitude, vehicle.position.longitude);
      var bus = await queryDatabase('''
        SELECT t.trip_headsign, r.route_text_color, r.route_color
        FROM trips t
        JOIN routes r ON t.route_id = r.route_id
        WHERE t.trip_id = ?;
      ''', 
      [vehicle.trip.tripId]
      );
      markers.add(getBusMarker(
        tripId, 
        position, 
        bus.first['trip_headsign']
      ));
    }
    busMarkerStream.add(markers);
  }
  Widget backgroundMap(LatLng currentPosition, Set<Marker> markers) {
    if(_mapControllerCompleter.isCompleted) _mapControllerCompleter = Completer();
    setMapTheme(Theme.of(context).colorScheme.brightness);
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(currentPosition.latitude, currentPosition.longitude),
            zoom: 17,
          ),
          onCameraIdle: () {
          },
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (controller) {
              _mapControllerCompleter.complete(controller);
          },
        ),
      ]
    );
  }
  void setMapTheme(brightness) async{
    final controller = await mapController;
    late String mapStyle;
    if(brightness == Brightness.dark){
      mapStyle  = await rootBundle.loadString('assets/json/map_darkmode.json');
      controller.setMapStyle(mapStyle);
      return;
    }
    mapStyle  = await rootBundle.loadString('assets/json/map_lightmode.json');
    controller.setMapStyle(mapStyle);
  }
  static Marker getBusMarker(String markerId, LatLng markerPosition, String title) {
    return Marker(
        markerId: MarkerId(markerId),
        position: markerPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue
        ),
        onTap: () {
          log(title);
        },
    );
  }
}