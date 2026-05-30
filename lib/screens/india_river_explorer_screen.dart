// lib/screens/india_river_explorer_screen.dart
// OpsFlood — IndiaRiverExplorerScreen v3  (Premium minimal)
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import 'india_rivers_screen.dart';

class IndiaRiverExplorerScreen extends StatelessWidget {
  const IndiaRiverExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss1,
        elevation: 0,
        title: const Text('India River Explorer',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppPalette.textWhite)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppPalette.textGrey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const IndiaRiversScreen(),
    );
  }
}
