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

  @override
  void initState() {
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
  void _updateBusStream() async {

    while(true){
      await Future.delayed(const Duration(seconds: 10));
      log('getting feed');
      FeedMessage feed = await vehiclePositionMessage.then((feed) {
        log('got feed');
        return feed;
      });
      Set<Marker> markers = {};
      List<FeedEntity> entitys = feed.entity.where((entity) => entity.vehicle.stopId == widget.stopId).toList();

      for(var entity in entitys){
        
        var tripId = entity.vehicle.trip.tripId;
        var position = LatLng( entity.vehicle.position.latitude, entity.vehicle.position.longitude);
        var bus = await queryDatabase('''
          SELECT DISTINCT t.trip_headsign, r.route_text_colour, r.route_color
          FROM trips t
          JOIN stop_times st ON t.trip_id = st.trip_id
          JOIN stops s ON st.stop_id = s.stop_id
          JOIN routes r ON t.route_id = r.route_id
          WHERE s.stop_id = ?;
        ''', 
        [widget.stopId]
        );
        markers.add(getBusMarker(
          tripId, 
          position, 
          bus.first['trip_headsign']
        ));
      }
      busMarkerStream.add(markers);
    }
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