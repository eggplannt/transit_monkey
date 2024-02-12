// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';

import  'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../db/gtfs_protobuf.dart' as gtfs_pb;
import '../db/generated/gtfs-realtime.pb.dart' hide  Position;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {


  Position? currentPosition;
  FeedMessage? vehiclesFeed;
  bool gettingPosition = false;
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {   
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }
  Future<void> getCurrentPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return;
    setState(() => gettingPosition = true);
    await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high)
        .then((Position position) {
      setState(() => currentPosition = position);
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e)));
      debugPrint(e);
    });
  }
  Future<void> getVehicleFeed()async{
    
    print('got feed');
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      await gtfs_pb.vehiclePositionMessage
      .then((FeedMessage feed) => setState(() => vehiclesFeed = feed));
      print('getting feed');
    });

  }
  @override
  void initState() {
    super.initState();
    getCurrentPosition();
    getVehicleFeed();
    

    

  }

  @override
  Widget build(BuildContext context) {
    Widget? scaffoldBody;
    if(gettingPosition && (currentPosition == null || vehiclesFeed == null)){
      scaffoldBody  = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitCircle(color: Theme.of(context).colorScheme.primary,),
            const Text('Finding Location')
          ],
        ),
      );
    }
    else if(currentPosition != null && vehiclesFeed != null){
      Set<Marker> markers = {
        Marker(
          markerId: const MarkerId('userPosition'),
          position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        ),
      };
      print(DateTime.fromMillisecondsSinceEpoch(vehiclesFeed!.header.timestamp.toInt() * 1000));
      for (int i = 0; i < vehiclesFeed!.entity.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId('Trip ${vehiclesFeed!.entity[i].vehicle.trip.tripId}'),
            position: LatLng(vehiclesFeed!.entity[i].vehicle.position.latitude, vehiclesFeed!.entity[i].vehicle.position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue
            ),
          ),
        );
      }
      scaffoldBody = GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          zoom: 15,
        ),
        markers: markers,
      );
    }
    return Scaffold(
      appBar: gettingPosition == false ? AppBar(
        actions: [
          TextButton.icon( 
            onPressed: () async { getCurrentPosition();}, 
            icon: const Icon(Icons.edit_location), 
            label: const Text('Get Location')
          )
        ]
      ) : null,
      body: scaffoldBody
    );
  }
}