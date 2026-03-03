import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UpdateStallCoordinatesApp());
}

class UpdateStallCoordinatesApp extends StatefulWidget {
  const UpdateStallCoordinatesApp({super.key});

  @override
  State<UpdateStallCoordinatesApp> createState() => _UpdateStallCoordinatesAppState();
}

class _UpdateStallCoordinatesAppState extends State<UpdateStallCoordinatesApp> {
  String _status = 'Ready to update stall coordinates';
  bool _isUpdating = false;

  Future<void> _updateCoordinates() async {
    setState(() {
      _isUpdating = true;
      _status = 'Updating stall coordinates...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // New coordinates for Ligao City Public Market (exact location from Google Maps)
      // Center: 13.2419233, 123.5385460
      final updates = {
        "Aling Maria's Pork Stall": {'latitude': 13.2419233, 'longitude': 123.5385460},
        "Manang Rosa's Poultry": {'latitude': 13.2420000, 'longitude': 123.5386000},
        "Tatay Ben's Fresh Vegetables": {'latitude': 13.2418500, 'longitude': 123.5384900},
        "Kuya Jun's Seafood": {'latitude': 13.2420500, 'longitude': 123.5386500},
        "Mang Pedro's Beef & Carabao": {'latitude': 13.2418000, 'longitude': 123.5384000},
      };

      int updatedCount = 0;
      
      for (final entry in updates.entries) {
        final stallName = entry.key;
        final coords = entry.value;
        
        // Find stall by name
        final querySnapshot = await firestore
            .collection('stalls')
            .where('name', isEqualTo: stallName)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final docId = querySnapshot.docs.first.id;
          await firestore.collection('stalls').doc(docId).update(coords);
          updatedCount++;
          setState(() {
            _status = 'Updated $updatedCount/${updates.length} stalls...';
          });
        }
      }

      setState(() {
        _status = '✅ Successfully updated $updatedCount stalls!\n\nAll stalls now positioned at Ligao City Public Market.\n\nYou can close this app and hot restart the main app.';
        _isUpdating = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Update Stall Coordinates'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.edit_location_alt_outlined,
                  size: 80,
                  color: Color(0xFF1B5E20),
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                if (!_isUpdating)
                  ElevatedButton.icon(
                    onPressed: _updateCoordinates,
                    icon: const Icon(Icons.update_rounded),
                    label: const Text('Update Coordinates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
