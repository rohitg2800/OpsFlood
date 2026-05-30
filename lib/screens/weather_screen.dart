// lib/screens/weather_screen.dart
// EQUINOX-BH — Weather forecast via Open-Meteo (no backend needed).
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/river_theme.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool   _loading = true;
  String _error   = '';
  Map<String, dynamic>? _data;

  // Default location: Patna, Bihar
  static const _lat = 25.5941;
  static const _lon = 85.1376;
  static const _city = 'Patna, Bihar';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_lat&longitude=$_lon'
        '&current=temperature_2m,relative_humidity_2m,precipitation,weathercode'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode'
        '&forecast_days=7&timezone=Asia%2FKolkata',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() { _data = jsonDecode(res.body) as Map<String, dynamic>; });
      } else {
        setState(() { _error = 'HTTP ${res.statusCode}'; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('Weather — $_city'),
        backgroundColor: AppPalette.navy1,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_data == null) return const SizedBox();
    final current = _data!['current'] as Map<String, dynamic>? ?? {};
    final daily   = _data!['daily']   as Map<String, dynamic>? ?? {};

    final temp    = current['temperature_2m'];
    final humid   = current['relative_humidity_2m'];
    final precip  = current['precipitation'];

    final dates    = (daily['time']                as List?)?.cast<String>()  ?? [];
    final maxTemps = (daily['temperature_2m_max']  as List?)?.cast<num>()    ?? [];
    final minTemps = (daily['temperature_2m_min']  as List?)?.cast<num>()    ?? [];
    final rains    = (daily['precipitation_sum']   as List?)?.cast<num?>()   ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current conditions card
        Card(
          color: AppPalette.navy1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Current Conditions',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${temp ?? '--'}°C',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(Icons.water_drop, '${humid ?? '--'}%', 'Humidity'),
                    _stat(Icons.umbrella,   '${precip ?? '--'} mm', 'Precipitation'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('7-Day Forecast',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(dates.length, (i) => Card(
          color: AppPalette.navy1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              dates[i],
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              'Rain: ${rains.elementAtOrNull(i) ?? '--'} mm',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: Text(
              '${maxTemps.elementAtOrNull(i)?.round() ?? '--'}° / ${minTemps.elementAtOrNull(i)?.round() ?? '--'}°',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        )),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
