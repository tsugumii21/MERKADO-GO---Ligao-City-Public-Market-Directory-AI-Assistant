import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data/seed_stalls.dart';

/// Standalone script to seed Firestore with sample stall data
/// 
/// To run this script:
/// flutter run -t lib/seed_data_app.dart
/// 
/// After seeding is complete, stop the app and run the main app normally.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SeedDataApp());
}

class SeedDataApp extends StatefulWidget {
  const SeedDataApp({super.key});

  @override
  State<SeedDataApp> createState() => _SeedDataAppState();
}

class _SeedDataAppState extends State<SeedDataApp> {
  String _status = 'Ready to seed data...';
  bool _isSeeding = false;
  bool _isComplete = false;

  Future<void> _seedData() async {
    setState(() {
      _isSeeding = true;
      _status = 'Seeding stall data to Firestore...';
    });

    try {
      await seedStallData();
      setState(() {
        _isComplete = true;
        _status = '✅ Seed data complete!\n\nCheck your Firestore console to verify the stalls were added.';
      });
    } catch (e) {
      setState(() {
        _isComplete = true;
        _status = '❌ Error seeding data:\n\n$e';
      });
    } finally {
      setState(() {
        _isSeeding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merkado Go - Seed Data',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Seed Stall Data'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: Color(0xFF1B5E20),
                ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                if (!_isComplete && !_isSeeding)
                  ElevatedButton.icon(
                    onPressed: _seedData,
                    icon: const Icon(Icons.upload),
                    label: const Text('Seed Stall Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                if (_isSeeding)
                  const CircularProgressIndicator(),
                if (_isComplete)
                  const Text(
                    'You can now close this app and run the main Merkado Go app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
