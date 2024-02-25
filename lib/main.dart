import 'package:flutter/material.dart';
import 'package:transit_monkey/pages/map_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  static const Color themeColor = Color(0x0000b548);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor)
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor, brightness: Brightness.dark)
      ),
      themeMode: ThemeMode.dark,
      home: const MapPage()
    );
  }
}
