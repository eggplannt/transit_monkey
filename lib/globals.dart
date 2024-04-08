const String busImagePath = 'assets/imgs/bus_logo.png';
const String gtfsFetch =
    'https://storage.googleapis.com/storage/v1/b/mdb-latest/o/ca-alberta-edmonton-transit-system-gtfs-714.zip?alt=media';

const List<String> dbSchema = [
  'CREATE TABLE stops (stop_id TEXT PRIMARY KEY, stop_code TEXT, stop_name TEXT, stop_desc TEXT, stop_lat FLOAT, stop_lon FLOAT, zone_id TEXT, stop_url TEXT, location_type INTEGER, parent_station TEXT, level_id FLOAT, wheelchair_boarding INTEGER)',
  'CREATE TABLE agency (agency_id INTEGER PRIMARY KEY, agency_name TEXT, agency_url TEXT, agency_phone TEXT, agency_fare_url TEXT, agency_email TEXT, agency_lang TEXT, agency_timezone TEXT)',
  'CREATE TABLE calendar_dates (service_id TEXT, date INTEGER, exception_type INTEGER, PRIMARY KEY (service_id, date))',
  'CREATE TABLE fare_attributes (fare_id TEXT PRIMARY KEY, price FLOAT, payment_method INTEGER, transfers INTEGER, transfer_duration INTEGER, currency_type TEXT, agency_id INTEGER)',
  'CREATE TABLE fare_rules (fare_id TEXT, route_id TEXT, origin_id TEXT, destination_id TEXT, contains_id TEXT, PRIMARY KEY (fare_id, route_id, origin_id, destination_id, contains_id))',
  'CREATE TABLE feed_info (feed_publisher_name TEXT, feed_publisher_url TEXT, feed_lang TEXT, feed_start_date INTEGER, feed_end_date INTEGER, feed_version INTEGER, feed_contact_email TEXT, PRIMARY KEY (feed_publisher_name))',
  'CREATE TABLE levels (level_id FLOAT PRIMARY KEY, level_index FLOAT, level_name TEXT)',
  'CREATE TABLE pathways (pathway_id TEXT PRIMARY KEY, from_stop_id TEXT, to_stop_id TEXT, pathway_mode INTEGER, is_bidirectional INTEGER, length INTEGER, traversal_time INTEGER, stair_count TEXT, max_slope FLOAT, min_width INTEGER, signposted_as TEXT, reversed_signposted_as TEXT)',
  'CREATE TABLE routes (route_id TEXT PRIMARY KEY, agency_id INTEGER, route_short_name TEXT, route_long_name TEXT, route_desc TEXT, route_type INTEGER, route_url TEXT, route_color TEXT, route_text_color TEXT)',
  'CREATE TABLE shapes (shape_id TEXT, shape_pt_lat FLOAT, shape_pt_lon FLOAT, shape_pt_sequence INTEGER)',
  'CREATE TABLE stop_times (trip_id INTEGER, arrival_time TIME, departure_time TIME, stop_id TEXT, stop_sequence INTEGER, stop_headsign TEXT, pickup_type INTEGER, drop_off_type INTEGER, shape_dist_traveled FLOAT, timepoint INTEGER)',
  'CREATE TABLE transfers (from_stop_id TEXT, to_stop_id TEXT, transfer_type INTEGER, min_transfer_time INTEGER, PRIMARY KEY (from_stop_id, to_stop_id))',
  'CREATE TABLE trips (route_id TEXT, service_id TEXT, trip_id TEXT PRIMARY KEY, trip_headsign TEXT, direction_id INTEGER, block_id TEXT, shape_id TEXT, wheelchair_accessible INTEGER, bikes_allowed INTEGER)',
  'CREATE INDEX stop_times_stop_id_trip_id_index ON stop_times(stop_id, trip_id)'
  'CREATE INDEX stop_times_arrival_time_departure_time_stop_sequence_index ON stop_times(arrival_time, departure_time, stop_sequence)'
];

const String backendIp = '142.93.156.43';
const String localhost = '10.0.2.2:8080';
