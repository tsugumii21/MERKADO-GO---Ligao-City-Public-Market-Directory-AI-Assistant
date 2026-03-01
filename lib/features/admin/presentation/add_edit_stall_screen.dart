// TODO: Implement Add/Edit Stall Screen
import 'package:flutter/material.dart';

class AddEditStallScreen extends StatelessWidget {
  final String? stallId;

  const AddEditStallScreen({super.key, this.stallId});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement add/edit stall UI
    return Scaffold(
      appBar: AppBar(
        title: Text(stallId == null ? 'Add Stall' : 'Edit Stall'),
      ),
      body: const Center(
        child: Text('➕ Add/Edit Stall - TODO'),
      ),
    );
  }
}
