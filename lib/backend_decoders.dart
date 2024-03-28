import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

Stop stopFromJson(String str) => Stop.fromJson(json.decode(str));
List<Stop> stopsFromJson(String str) =>
    List<Stop>.from(json.decode(str).map((x) => Stop.fromJson(x)));

String stopToJson(Stop data) => json.encode(data.toJson());

class Stop {
  String id;
  String name;
  LatLng position;
  int type;

  Stop({
    required this.id,
    required this.name,
    required this.position,
    required this.type,
  });

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        id: json["stopId"],
        name: json["stopName"],
        position:
            LatLng(json["stopLat"]?.toDouble(), json["stopLon"]?.toDouble()),
        type: json["locationType"],
      );

  Map<String, dynamic> toJson() => {
        "stopId": id,
        "stopName": name,
        "stopLat": position.latitude,
        "stopLon": position.longitude,
        "locationType": type,
      };
}

Trip tripFromJson(String str) => Trip.fromJson(json.decode(str));

List<Trip> tripsFromJson(String str) =>
    List<Trip>.from(json.decode(str).map((x) => Trip.fromJson(x)));

String tripToJson(Trip data) => json.encode(data.toJson());

class Trip {
  String tripId;
  String routeId;
  String tripHeadsign;
  String routeColor;
  String routeTextColor;

  Trip({
    required this.tripId,
    required this.routeId,
    required this.tripHeadsign,
    required this.routeColor,
    required this.routeTextColor,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        tripId: json["tripId"],
        routeId: json["routeId"],
        tripHeadsign: json["tripHeadsign"],
        routeColor: json["routeColor"],
        routeTextColor: json["routeTextColor"],
      );

  Map<String, dynamic> toJson() => {
        "tripId": tripId,
        "routeId": routeId,
        "tripHeadSign": tripHeadsign,
        "routeColor": routeColor,
        "routeTextColor": routeTextColor,
      };
}

Bus busFromJson(String str) => Bus.fromJson(json.decode(str));

List<Bus> busesFromJson(String str) =>
    List<Bus>.from(json.decode(str).map((x) => Bus.fromJson(x)));

String busToJson(Bus data) => json.encode(data.toJson());

class Bus {
  LatLng position;
  int sequence;
  Trip trip;
  Bus({required this.position, required this.sequence, required this.trip});

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
      position: LatLng(json["lat"]?.toDouble(), json["lon"]?.toDouble()),
      sequence: json["sequence"],
      trip: Trip.fromJson(json["trip"]));

  Map<String, dynamic> toJson() => {
        "lat": position.latitude,
        "lon": position.longitude,
        "sequence": sequence,
        "trip": trip.toJson()
      };
}
