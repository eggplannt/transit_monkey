import 'package:http/http.dart' as http;

import 'generated/gtfs-realtime.pb.dart';

FeedMessage? _vehiclePositionMessage;


Future<FeedMessage> get vehiclePositionMessage async{
  if(_vehiclePositionMessage != null) return _vehiclePositionMessage!;
  final url = Uri.parse('http://gtfs.edmonton.ca/TMGTFSRealTimeWebService/Vehicle/VehiclePositions.pb');
  final response = await http.get(url);

  if (response.statusCode == 200) _vehiclePositionMessage = FeedMessage.fromBuffer(response.bodyBytes);
  return _vehiclePositionMessage!;
}