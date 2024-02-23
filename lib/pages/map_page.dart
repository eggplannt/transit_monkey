// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';

import  'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../db/generated/gtfs-realtime.pb.dart' hide  Position;
import '../db/gtfs_database.dart' as gtfs_db;

import 'map_page_body.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  bool hasLocationPermission = false;
  bool initializedDatabase = false;
  bool vehicleUpdateTimerOn = false;
  bool controllerSet = false;


  FeedMessage? vehiclesFeed;
  LatLng? currentPosition;



  handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable the services')));
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {   
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied, we cannot request permissions.')));
    }
    setState(() {
      hasLocationPermission = true;
    });
  }


  Future<void> getCurrentPosition() async {
    print('getting location');
    currentPosition =  await Geolocator.getLastKnownPosition()
    .then((value) { 
      if(value != null) {
        return LatLng(value.latitude, value.longitude);
      }
      return null;
    });
    currentPosition ??= await Geolocator.getCurrentPosition( desiredAccuracy: LocationAccuracy.best)
    .then((value) => LatLng(value.latitude, value.longitude));
    print('got location');
  }

  Future<void> initGtfsDatabase() async{
    await gtfs_db.initDatabase();
    setState(() {initializedDatabase = true;});

  }

  @override
  void initState() {
    super.initState();
    handleLocationPermission();
    initGtfsDatabase();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hasLocationPermission == false ? AppBar(
        actions: [
          TextButton.icon( 
            onPressed: () { handleLocationPermission();}, 
            icon: const Icon(Icons.location_disabled), 
            label: const Text('Get Location Permission')
          )
        ]
      ) : null,
      body: hasLocationPermission ? (
        initializedDatabase ? (
          vehiclesFeed == null || currentPosition == null ? FutureBuilder(
            future: getCurrentPosition(),
            builder: (context, snapshot){
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");

                return MapPageBody(currentPosition!);
              }
              else {
                return loadingWidget('Getting Postion', context);
              } 
            },
          ):MapPageBody(currentPosition!)
        ): loadingWidget('Loading Backend', context)
      ): null
    );
  }

}
Widget loadingWidget(text, context) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SpinKitCircle(color: Theme.of(context).colorScheme.primary,),
      Text(text)
    ],
  ),
);

