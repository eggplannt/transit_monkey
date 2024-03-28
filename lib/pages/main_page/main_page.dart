// ignore_for_file: non_constant_identifier_names, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_monkey/pages/main_page/main_page_map.dart';

class MainPage extends StatefulWidget {
  final LatLng initialPosition;
  const MainPage({super.key, required this.initialPosition});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MainPageMap( widget.initialPosition),
      ]
    );
  }
}


