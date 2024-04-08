import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/pages/bus_stop_page/bus_stop_map_page.dart';
import 'package:transit_monkey/apis.dart';


class BusStopPage extends StatelessWidget {
  final Marker busStopMarker;
  final Stop stop;
  final List<Departure> departures;
  const BusStopPage({
    super.key,
    required this.stop,
    required this.busStopMarker,
    required this.departures
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BusStopMapPage(
            stop: stop,
            busStopMarker: busStopMarker
          ),
          DraggableScrollableSheet(
            minChildSize: 0.1,
            maxChildSize: max(departures.length * 0.1 + 0.1, 0.3),
            initialChildSize: 0.2,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                // add border radius on top left and top right corners
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                child: departuresList(departures, stop.name, scrollController)
              );
            },  
          )
        ],
      ),
    );
  } 
}
Color hexToColor(String code) {
  return Color(int.parse(code.substring(0, 6), radix: 16) + 0xFF000000);
}

Widget departureTile(Departure departure, String stopName) {
  // converts departure time to time and subtracts departure time by current time to get time till departure
  var timeToArrival = timeDifferenceInMinutes(departure.departureTime);
  var routeColor = hexToColor(departure.trip.routeColor);
  var routeTextColor = hexToColor(departure.trip.routeTextColor);

  return ListTile(
      leading: Icon(
        Icons.directions_bus,
        color: routeTextColor,
        size: 50,
      ),
      title: Text(
        departure.trip.tripHeadsign,
        style: TextStyle(
          color: routeTextColor,
          fontSize: 25
        ),
      ),
      subtitle: Text(
        stopName,
        style: TextStyle(
          color: routeTextColor,
          fontSize: 13
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: routeTextColor,
                fontSize: 30,
              ),
              children: [
                TextSpan(
                  text: timeToArrival.toString(),
                ),
                const TextSpan(
                  text: ' min',
                  style: TextStyle(
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      tileColor: routeColor,
    );

}

ListView departuresList (List<Departure> departures, String stopName, ScrollController scrollController) {
  return ListView.builder(
    padding: EdgeInsets.only(top: 10),
    controller: scrollController,
    itemCount: departures.length,
    itemBuilder: (context, index) {
      return departureTile(departures[index], stopName);
    },
  );
}
int timeDifferenceInMinutes(String timeString) {
  // Split the time string into hours, minutes, and seconds
  List<String> timeParts = timeString.split(':');
  int hours = int.parse(timeParts[0]);
  int minutes = int.parse(timeParts[1]);
  int seconds = int.parse(timeParts[2]);

  // Calculate total seconds from the provided time
  int providedTimeInSeconds = hours * 3600 + minutes * 60 + seconds;

  // Get the current time
  DateTime now = DateTime.now();
  int currentTimeInSeconds = now.hour * 3600 + now.minute * 60 + now.second;

  // Calculate the time difference in minutes
  int timeDifferenceInMinutes =
      ((providedTimeInSeconds - currentTimeInSeconds) / 60).round();

  return timeDifferenceInMinutes;
}