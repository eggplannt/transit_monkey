import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Database? _database;

Map<String, GtfsTable> tablesMap = {
  'stops': GtfsTable(csvPath: 'assets/csvs/stops.txt', tableName: 'stops'),
  'trips': GtfsTable(csvPath: 'assets/csvs/trips.txt', tableName: 'trips')

};

// Function to initialize database
Future<void> initDatabase() async {
  if (_database != null) return;

  var dbPath = await getDatabasesPath();
  var path = join(dbPath, 'gtfs.db');
  _database = await openDatabase(
    path,
    onCreate: _createTable,
    version: 1,
  );
}

Future<Database> getDatabase() async{
  if(_database != null) return _database!;
  await initDatabase();
  return _database!;
}
// Function to create table dynamically
Future<void> _createTable(Database db, int version) async{

  for (var key in tablesMap.keys){

    List<Map<String, dynamic>> data = await tablesMap[key]!.getCsvLoaded();
    final firstMap = data.first;
    final tableName = key;

    
    List<String> primaryKeys = [];
    String columns = firstMap.keys.map((key) {
      if(key.contains('id')) primaryKeys.add(key);
      final value = firstMap[key];
      if (value is int) {
        return '$key INTEGER';
      } else if (value is double) {
        return '$key REAL';
      } else{
        return '$key TEXT';
      }
    }).join(', ');
    if(primaryKeys.isNotEmpty){
      columns = '$columns, PRIMARY KEY(${primaryKeys.join(', ')})';
    }
    print('CREATEING TABLE $tableName ( $columns )');
    await db.execute('CREATE TABLE $tableName ( $columns )');
    // Insert initial data if provided
    for (final entry in data) {
      print('${data.indexOf(entry) + 1} / ${data.length}');
      await db.insert(tableName, entry);
    }

  }
}
class GtfsTable {

  String csvPath;
  String tableName;

  GtfsTable({required this.csvPath, required this.tableName});

  Future<List<Map<String, dynamic>>> getCsvLoaded() async {

    final rawData = await rootBundle.loadString(csvPath);
    List<List<dynamic>> csvLists = const CsvToListConverter().convert(rawData, convertEmptyTo: 'Empty');
    List<String> header = csvLists[0].map((item) => item as String).toList();
    List<Map<String, dynamic>> maps = [];
    for (int i = 1; i < csvLists.length; i++){
      Map<String, dynamic> map = {};
      for(int j = 0; j < header.length; j++){
        map[header[j]] = csvLists[i][j];
      }
      maps.add(map);
    }
    return maps;
  }
  Future<List<Map<String, dynamic>>> queryDatabase(String query, List<dynamic> args) async {
    Database db = await getDatabase();
    List<Map<String, dynamic>> output = [];
    query = query.replaceFirst('FROM', 'FROM $tableName');

    await db.transaction((txn) async {
      output =  await txn.rawQuery(query, args);
    });
    return output;
  }
  
}