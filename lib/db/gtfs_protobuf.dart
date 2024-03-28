import 'package:http/http.dart' as http;

import 'generated/gtfs-realtime.pb.dart';

Future<FeedMessage> getVehiclePositionMessage() async {
  final url = Uri.parse(
      'http://gtfs.edmonton.ca/TMGTFSRealTimeWebService/Vehicle/VehiclePositions.pb');
  final response = await http.get(url);

  if (response.statusCode != 200) {
    throw Exception('Failed to load vehicle positions');
  }
  return FeedMessage.fromBuffer(response.bodyBytes);
}
