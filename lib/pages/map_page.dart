// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'dart:async';

import 'package:collection/collection.dart';
import  'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../db/gtfs_protobuf.dart' as gtfs_pb;
import '../db/generated/gtfs-realtime.pb.dart' hide  Position;
import '../db/gtfs_database.dart' as gtfs_db;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  bool hasLocationPermission = false;
  bool initializedDatabase = false;

  FeedMessage? vehiclesFeed;
  Position? currentPosition;
  int busAddedSeconds = 0;

  List<Future<List<Map<String, dynamic>>>> previosFutureGtfsDataLists = [];
  List<List<Map<String, dynamic>>>?  gtfsDataLists;

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
  Future<Position?> getCurrentPosition() async {
    currentPosition =  await Geolocator.getCurrentPosition( desiredAccuracy: LocationAccuracy.best);
    return currentPosition!;
  }
  Future<void> initGtfsDatabase() async{
    await gtfs_db.initDatabase();
    setState(() {initializedDatabase = true;});

  }
  Future<void> setVehicleFeed(bool firstRun) async{
    print('getting feed');
    await gtfs_pb.vehiclePositionMessage.then((feed ) {
      print('got feed');
      if(firstRun) {vehiclesFeed = feed; return;}
      setState(() {
         vehiclesFeed = feed;
      });
    });
  }
  Future<FeedMessage> initGetVehicleFeed()async{
    await setVehicleFeed(true);
    Timer.periodic(const Duration(seconds: 10), (timer) {setVehicleFeed(false);});
    return vehiclesFeed!;
  }
  @override
  void initState() {
    super.initState();
    handleLocationPermission();
    initGtfsDatabase();
    Timer.periodic(const Duration(seconds: 1), (timer) => setState(() => busAddedSeconds++)) ;
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
            future: Future.wait([
              getCurrentPosition(),
              initGetVehicleFeed()
              
            ]),
            builder: (context, snapshot){
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                Position currentPosition = snapshot.data![0]! as Position;
                FeedMessage vehiclesFeed = snapshot.data![1]! as FeedMessage;

                return getScaffoldBody(currentPosition, vehiclesFeed);
              }
              else {
                return const LoadingWidget(text: 'Loading Map');
              } 
            },
          ):getScaffoldBody(currentPosition!, vehiclesFeed!)
        ): const LoadingWidget(text: 'Loading Backend')
      ): null
    );
  }

  Widget getScaffoldBody(Position currentPosition, FeedMessage vehiclesFeed) {

    List<Future<List<Map<String, dynamic>>>> futureGtfsDataLists = [];
    Set<Marker> markers = {};
    busAddedSeconds = 0;
    for (int i = 0; i < vehiclesFeed.entity.length; i++) {
      var timestamp =  DateTime.fromMillisecondsSinceEpoch(vehiclesFeed.entity[i].vehicle.timestamp.toInt() * 1000);
      int secondsAgo = timestamp.difference(DateTime.now()).inSeconds;
      futureGtfsDataLists.add(gtfs_db.tablesMap['trips']!.queryDatabase('SELECT trip_headsign FROM WHERE trip_id =?', [vehiclesFeed.entity[i].vehicle.trip.tripId]));
      markers.add(
        Marker(
          markerId: MarkerId('Trip ${vehiclesFeed.entity[i].vehicle.trip.tripId}'),
          position: LatLng(vehiclesFeed.entity[i].vehicle.position.latitude, vehiclesFeed.entity[i].vehicle.position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue
          ),
          infoWindow: InfoWindow(
            title: 'Loading...', 
            snippet: 'as of ${secondsAgo}s ago'
          )
        ),
      );
    }
    return gtfsDataLists == null ? FutureBuilder(
      future: getGtfsDataLists(futureGtfsDataLists),
      builder:(context, snapshot) {
        if(snapshot.connectionState == ConnectionState.done){
          markers = handleMarkers(markers, snapshot.data!);
        }
        return mainGoogleMap(currentPosition, markers);
      },
    ) : mainGoogleMap(currentPosition, handleMarkers(markers, gtfsDataLists!));
  }

  GoogleMap mainGoogleMap(Position currentPosition, Set<Marker> markers) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(currentPosition.latitude, currentPosition.longitude),
        zoom: 15,
      ),
      // myLocationEnabled: true,
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  Set<Marker> handleMarkers(Set<Marker> markers, List<List<Map<String, dynamic>>> gtfsDataLists) {
    Set<Marker> newMarkers = {};
    for(int i = 0; i < markers.length; i++){
      Map<String, dynamic> data = gtfsDataLists[i].first;
      newMarkers.add(
        Marker(
          markerId: markers.elementAt(i).mapsId,
          position: markers.elementAt(i).position,
          icon: markers.elementAt(i).icon,
          infoWindow: InfoWindow(
            title: data['trip_headsign'], 
            snippet: markers.elementAt(i).infoWindow.snippet
          )
        )
      );
    }
    markers = newMarkers;
    return markers;
  }

  Future<List<List<Map<String, dynamic>>>> getGtfsDataLists(List<Future<List<Map<String, dynamic>>>> futureGtfsDataLists) async {
    if(gtfsDataLists != null && const DeepCollectionEquality().equals(previosFutureGtfsDataLists, futureGtfsDataLists)){
      return gtfsDataLists!;
    }
    gtfsDataLists = await Future.wait(futureGtfsDataLists);
    previosFutureGtfsDataLists = futureGtfsDataLists;
    return gtfsDataLists!;
    
  }
}

class LoadingWidget extends StatelessWidget {
  final String text;
  const LoadingWidget({
    super.key,
    required this.text
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitCircle(color: Theme.of(context).colorScheme.primary,),
          Text(text)
        ],
      ),
    );
  }
}