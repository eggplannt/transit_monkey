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
  db.execute('PRAGMA foreign_keys = ON;');

  Map<String, List<Map<String, dynamic>>> tableData = {};
  for (var key in tablesMap.keys) {
    tableData[key] = await tablesMap[key]!.getCsvLoaded();
  }

  Map<String, List<String>> foreignKeyConstraints = {};
  for (var tableName in tablesMap.keys) {
    List<Map<String, dynamic>> data = tableData[tableName]!;
    final firstMap = data.first;

    
    List<String> primaryKeys = [];
    String columns = firstMap.keys.map((column) {
      if(column.contains('_id')) {
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


    print('CREATEING TABLE $tableName ( $columns )');
    await db.execute('CREATE TABLE $tableName ( $columns )');
    // Insert initial data if provided
    for (final entry in data) {
      print('${data.indexOf(entry) + 1} / ${data.length}');
      await db.insert(tableName, entry);
    }

  }
  for (var tableName in foreignKeyConstraints.keys) {
    List<String> foreignKeys = [];
    for (var relatedTableName in tablesMap.keys) {
      if (relatedTableName != tableName) {
        final relatedColumns = tableData[relatedTableName]!.first.keys;
        final firstMap = tableData[tableName]!.first;
        for (var column in firstMap.keys) {
          if (column.endsWith('_id') && relatedColumns.contains(column)) {
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
        print('ADDING FOREIGN KEY CONSTRAINT: $columns');
        await db.execute('ALTER TABLE $tableName ADD $columns');
      }
    }
  }
}
class GtfsTable {

  String csvPath;
  String tableName;

  List<String>? _header;
  

  GtfsTable({required this.csvPath, required this.tableName});

  Future<List<Map<String, dynamic>>> getCsvLoaded() async {

    final rawData = await rootBundle.loadString(csvPath);
    List<List<dynamic>> csvLists = const CsvToListConverter().convert(rawData, convertEmptyTo: 'Empty');
    _header = csvLists[0].map((item) => item as String).toList();
    List<Map<String, dynamic>> maps = [];
    for (int i = 1; i < csvLists.length; i++){
      Map<String, dynamic> map = {};
      for(int j = 0; j < _header!.length; j++){
        map[_header![j]] = csvLists[i][j];
      }
      maps.add(map);
    }
    return maps;
  }
  Future<List<String>> get header async{
    if(_header != null) return _header!;
    final rawData = await rootBundle.loadString(csvPath);
    List<List<dynamic>> csvLists = const CsvToListConverter().convert(rawData, convertEmptyTo: 'Empty');
    _header = csvLists[0].map((item) => item as String).toList();
    return _header!;
  }

  Future<List<Map<String, dynamic>>> queryTable(String query, List<dynamic> args) async {
    Database db = await getDatabase();
    List<Map<String, dynamic>> output = [];
    query = query.replaceFirst('FROM', 'FROM $tableName');
    
    String debugMessage = query;
    for(var arg in args){
      debugMessage = debugMessage.replaceFirst('?', arg.toString());
    }
    print(debugMessage);

    await db.transaction((txn) async {
      output =  await txn.rawQuery(query, args);
    });
    return output;
  }
  
}