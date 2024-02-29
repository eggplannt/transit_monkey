import 'dart:async';
import 'dart:convert';
import 'dart:developer';
// import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:http/http.dart' as http;
import 'package:transit_monkey/constants.dart';

Database? _database;

const List<String> gtfsFileNames = [
  'agency.txt',
  'stops.txt',
  'routes.txt',
  'trips.txt',
  'stop_times.txt',
  'calendar.txt',
  'calendar_dates.txt',
  'fare_attributes.txt',
  'fare_rules.txt',
  'shapes.txt',
  'frequencies.txt',
  'transfers.txt',
  'pathways.txt',
  'levels.txt',
  'feed_info.txt',
  'translations.txt',
  'attributions.txt',
];
const List<String> gtfsIdExeptions = [
  'fare_id',
  'shape_id'
];
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
  db.execute('PRAGMA foreign_keys = ON;');
  Map<String, List<Map<String, dynamic>>> tableData = {};

  var url = Uri.parse(gtfsFetch);
  var responce = await http.get(url);
  final bytes = responce.bodyBytes;

  final archive = ZipDecoder().decodeBytes(bytes);

  for(var file in archive){
    if(!file.isFile) continue;
    
    final filename = file.name;
    if(!gtfsFileNames.contains(filename)) continue;

    var content = file.content;
    String rawData = utf8.decode(content);
    String tableName = filename.replaceAll('.txt', '');
    tableData[tableName] = await getCsvParsed(rawData);
  }

  Map<String, List<String>> foreignKeyConstraints = {};
  for (final tableName in tableData.keys) {
    List<Map<String, dynamic>> data = tableData[tableName]!;
    final firstMap = data.first;

    
    List<String> primaryKeys = [];
    String columns = firstMap.keys.map((column) {
      if(column.endsWith('_id') && !gtfsIdExeptions.contains(column) 
      && tableName != 'stop_times') {
        if(tableName.contains(column.replaceAll('_id', '').toLowerCase())) primaryKeys.add(column);
        //automatically make ids text as a failsafe
        return '$column TEXT';
      }
      final value = firstMap[column];
      if (value is int) {
        return '$column INTEGER';
      } else if (value is double) {
        return '$column REAL';
      } else{
        return '$column TEXT';
      }
    }).join(', ');

    if(primaryKeys.isNotEmpty){
      columns = '$columns, PRIMARY KEY(${primaryKeys.join(', ')})\n';
    }

    Batch batch = db.batch();
    log('CREATEING TABLE $tableName ( $columns )');
    await db.execute('CREATE TABLE $tableName ( $columns )');
    // Insert initial data if provided
    log('Started Adding $tableName data Inserts to Batch');
    int rows = 0;
    for (final entry in data) {
      batch.insert(tableName, entry);
      rows++;
      if(rows >= 200000){
        await batch.commit(noResult: true);
        log('Batch Inserted $rows rows of $tableName data');
        batch = db.batch();
        rows = 0;
      }
    }
    await batch.commit(noResult: true);
    log('Batch Inserted $rows rows of $tableName data');
  }
  log('done creating database');
  

  for (var tableName in foreignKeyConstraints.keys) {
    List<String> foreignKeys = [];
    for (var relatedTableName in tableData.keys) {
      if (relatedTableName != tableName) {
        final relatedColumns = tableData[relatedTableName]!.first.keys;
        final firstMap = tableData[tableName]!.first;
        for (var column in firstMap.keys) {
          if (column.endsWith('_id') && relatedColumns.contains(column) && !gtfsIdExeptions.contains(column)
            && !(tableName == 'stops' && column == 'stop_id')) {
            foreignKeys.add(column);
          }
        }
      }
    }
    if (foreignKeys.isNotEmpty) {
      for (var foreignKey in foreignKeys) {
        final relatedTableName = foreignKey.replaceAll('_id', '');
        foreignKeyConstraints[tableName]!.add(foreignKey);
        final columns = 'FOREIGN KEY ($foreignKey) REFERENCES $relatedTableName ($foreignKey) ON DELETE CASCADE';
        log('ADDING FOREIGN KEY CONSTRAINT: $columns');
        await db.execute('ALTER TABLE $tableName ADD $columns');
      }
    }
  }
  await db.execute('CREATE INDEX stop_times_stop_id_trip_id_index ON stop_times(stop_id, trip_id)');
}

Future<List<Map<String, dynamic>>> getCsvParsed(String rawData) async {
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

Future<List<Map<String, dynamic>>> queryTable(String tableName, {String? selections, String? where, List<dynamic>? args}) async {
  Database db = await getDatabase();
  List<Map<String, dynamic>> output = [];
  await db.transaction((txn) async {
    output =  await txn.query(
      tableName,
      where: where, 
      whereArgs: args,
      columns: selections?.split(', ')
    );
  });
  return output;
}

Future<List<Map<String, dynamic>>> queryDatabase(String query, List<dynamic> args) async {
  Database db = await getDatabase();
  List<Map<String, dynamic>> output = [];
  await db.transaction((txn) async {
    output =  await txn.rawQuery(query, args);
  });
  return output;
}