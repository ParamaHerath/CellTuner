import 'package:flutter/material.dart';

void main() {
  runApp(const CellTunerApp());
}

class CellTunerApp extends StatelessWidget {
  const CellTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CellTuner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CellTuner'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cell_tower, size: 64),
            SizedBox(height: 16),
            Text(
              'CellTuner',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Router signal dashboard',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
