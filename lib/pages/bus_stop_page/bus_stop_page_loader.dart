
// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/apis.dart';
import 'package:http/http.dart' as http;
import 'package:transit_monkey/globals.dart';
import 'package:transit_monkey/pages/bus_stop_page/bus_stop_page.dart';

class BusStopPageLoader extends StatelessWidget {
  final LatLng initPosition;
  final Marker busStopMarker;
  final String stopId;
  const BusStopPageLoader({
    super.key,
    required this.stopId,
    required this.initPosition,
    required this.busStopMarker,
  });

  Future<void> load(BuildContext context) async {
    var url = Uri.http(backendIp, '/departures/$stopId');
    var responce = await http.get(url);
    log(stopId);
    if (responce.statusCode != 200) {
      log(responce.body);
      Navigator.pop(context);
    }

    List<Departure> departures = departuresFromJson(responce.body);

    url = Uri.http(backendIp, '/stops/$stopId');
    responce = await http.get(url);

    var stop = stopFromJson(responce.body);
    Navigator.pushReplacement(context, 
      MaterialPageRoute(builder: (context) => BusStopPage(
        stop: stop,
        busStopMarker: busStopMarker,
        departures: departures
      ))
    );
  }
  @override
  Widget build(BuildContext context) {
    load(context);
    return loadingWidget('Loading...', context);
  }
}
Widget loadingWidget(text, context) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SpinKitCircle(
        color: Theme.of(context).colorScheme.primary,
      ),
      Text(text)
    ],
  ),
);