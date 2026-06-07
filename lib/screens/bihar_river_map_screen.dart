import 'package:flutter/material.dart';

class BiharRiverMapScreen extends StatelessWidget {
  const BiharRiverMapScreen({super.key});

  static const String route = '/bihar_river_map';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bihar River Map'),
      ),
      body: const Center(
        child: Text(
          'Bihar River Map\nComing Soon',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
