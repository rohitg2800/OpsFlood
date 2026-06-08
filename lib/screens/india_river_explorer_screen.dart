import 'package:flutter/material.dart';

class IndiaRiverExplorerScreen extends StatelessWidget {
  const IndiaRiverExplorerScreen({super.key});
  static const String route = '/india_river_explorer';
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.map_rounded, size: 56, color: Color(0xFF3A4A58)),
        SizedBox(height: 16),
        Text('India River Explorer', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('Coming soon', style: TextStyle(color: Color(0xFF7B8A99), fontSize: 12)),
      ]),
    );
  }
}
