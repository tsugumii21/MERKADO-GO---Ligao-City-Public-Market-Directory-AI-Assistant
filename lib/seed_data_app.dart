export 'seed_database_app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'seed_database_app.dart';

/// Legacy runner alias forwarding to the canonical 134-vendor database seeder
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SeedDatabaseApp());
}
