// Planned: Implement Stall Category Screen
import 'package:flutter/material.dart';

class StallCategoryScreen extends StatelessWidget {
  final String category;

  const StallCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    // Planned: Implement category filtering UI
    return Scaffold(
      appBar: AppBar(title: Text('$category Stalls')),
      body: const Center(
        child: Text('📂 Category Screen - Planned'),
      ),
    );
  }
}
