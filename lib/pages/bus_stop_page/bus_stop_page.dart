import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusStopPage extends StatelessWidget {
  final LatLng initPosition;
  final Marker busStopMarker;
  final String stopId;
  const BusStopPage({
    super.key,
    required this.stopId,
    required this.initPosition,
    required this.busStopMarker,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BusStopPage(
          stopId: stopId, 
          initPosition: initPosition, 
          busStopMarker: busStopMarker
        )
      ],
    );
  }
}