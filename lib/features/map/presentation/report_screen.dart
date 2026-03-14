// Planned: Implement Report Screen
import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  final String stallId;

  const ReportScreen({super.key, required this.stallId});

  @override
  Widget build(BuildContext context) {
    // Planned: Implement report submission UI
    return Scaffold(
      appBar: AppBar(title: const Text('Report Stall')),
      body: const Center(
        child: Text('🚨 Report Screen - Planned'),
      ),
    );
  }
}
