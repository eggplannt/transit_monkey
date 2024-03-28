// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/db/gtfs_database.dart';
import 'package:transit_monkey/pages/main_page/main_page.dart';


class Loading extends StatefulWidget {
  const Loading({Key? key}) : super(key: key);
  
  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {

  bool hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
  }

  void load() async {
    await initDatabase();
    var currentPosition = await getCurrentPosition();
    if (currentPosition != null) {
      Navigator.pushReplacement(context, 
        MaterialPageRoute(builder: (context) => MainPage(initialPosition: currentPosition))
      );
    }
  }
  Future<LatLng?> getCurrentPosition() async {
    log('getting location');
    var currentPosition = await Geolocator.getLastKnownPosition().then((value) {
      if (value != null) {
        return LatLng(value.latitude, value.longitude);
      }
      return null;
    });
    currentPosition ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best)
        .then((value) => LatLng(value.latitude, value.longitude));
    log('got location');
    return currentPosition;
  }

  handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
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
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
    }
    setState(() {
      hasLocationPermission = true;
    });
  }


  @override
  Widget build(BuildContext context) {

    Widget? body;
    if(!hasLocationPermission){
      handleLocationPermission();
      body = const Text("No Permission");
    }
    else{
      load();
      body = const Text("Loading Location...");
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: hasLocationPermission == false?
        [
          TextButton.icon(
            onPressed: () {
              handleLocationPermission();
            },
            icon: const Icon(Icons.location_disabled),
            label: const Text('Get Location Permission'))
        ]: null
      ),

      body: body
    );
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