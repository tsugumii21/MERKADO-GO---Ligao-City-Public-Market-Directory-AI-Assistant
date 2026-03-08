import 'package:cloud_firestore/cloud_firestore.dart';

/// Seed data for Ligao City Public Market stalls
/// 
/// Run this script once to populate Firestore with sample stall data.
/// This creates 5 realistic stalls with Ligao Market data.
/// 
/// Coordinates: Ligao City Public Market (exact location from Google Maps)
/// Center: Latitude 13.2419233, Longitude 123.5385460

Future<void> seedStallData() async {
  final firestore = FirebaseFirestore.instance;
  
  // Sample stalls with realistic Ligao Market data
  final stalls = [
    {
      'name': 'Aling Maria\'s Pork Stall',
      'category': 'Pork',
      'products': [
        'Pork Belly',
        'Pork Chop',
        'Ground Pork',
        'Pork Ribs',
        'Lechon Kawali',
        'Pork Liver',
        'Pork Intestine',
      ],
      'address': 'Section A, Stall 12, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/meat.jpg',
        'https://res.cloudinary.com/demo/image/upload/samples/food/pork.jpg',
      ],
      'openTime': '5:00 AM',
      'closeTime': '5:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.2419233,
      'longitude': 123.5385460,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Manang Rosa\'s Poultry',
      'category': 'Poultry',
      'products': [
        'Whole Chicken',
        'Chicken Breast',
        'Chicken Thighs',
        'Chicken Wings',
        'Native Chicken',
        'Duck',
        'Eggs',
      ],
      'address': 'Section B, Stall 08, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/chicken.jpg',
        'https://res.cloudinary.com/demo/image/upload/samples/food/poultry.jpg',
      ],
      'openTime': '5:30 AM',
      'closeTime': '6:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.2420000,
      'longitude': 123.5386000,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Tatay Ben\'s Fresh Vegetables',
      'category': 'Vegetables',
      'products': [
        'Tomatoes',
        'Onions',
        'Garlic',
        'Eggplant',
        'Kangkong',
        'Sitaw',
        'Okra',
        'Pechay',
        'Cabbage',
        'Carrots',
        'Malunggay',
      ],
      'address': 'Section C, Stall 15, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/vegetables.jpg',
        'https://res.cloudinary.com/demo/image/upload/samples/food/veggie-stand.jpg',
      ],
      'openTime': '4:00 AM',
      'closeTime': '4:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.2418500,
      'longitude': 123.5384900,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Kuya Jun\'s Seafood',
      'category': 'Fish',
      'products': [
        'Tilapia',
        'Bangus',
        'Galunggong',
        'Tuna',
        'Squid',
        'Shrimp',
        'Crabs',
        'Mussels',
        'Dried Fish',
      ],
      'address': 'Section D, Stall 22, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/fish-market.jpg',
        'https://res.cloudinary.com/demo/image/upload/samples/food/seafood.jpg',
      ],
      'openTime': '4:30 AM',
      'closeTime': '12:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.2420500,
      'longitude': 123.5386500,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Mang Pedro\'s Beef & Carabao',
      'category': 'Beef',
      'products': [
        'Beef Steak',
        'Ground Beef',
        'Beef Ribs',
        'Beef Brisket',
        'Beef Tripe',
        'Carabao Meat',
        'Beef Liver',
      ],
      'address': 'Section A, Stall 18, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/beef.jpg',
        'https://res.cloudinary.com/demo/image/upload/samples/food/meat-market.jpg',
      ],
      'openTime': '5:00 AM',
      'closeTime': '5:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      'latitude': 13.2418000,
      'longitude': 123.5384000,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Carinderia ni Nena',
      'category': 'Eatery',
      'products': [
        'adobo',
        'sinigang',
        'pinakbet',
        'rice',
        'soup',
      ],
      'address': 'Section D, Stall 1, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/restaurant.jpg',
      ],
      'openTime': '6:00 AM',
      'closeTime': '2:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      'latitude': 13.24178,
      'longitude': 123.53878,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Bigas ni Mang Tomas',
      'category': 'Rice',
      'products': [
        'sinandomeng',
        'jasmine rice',
        'dinorado',
        'malagkit',
      ],
      'address': 'Section B, Stall 12, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/rice.jpg',
      ],
      'openTime': '5:00 AM',
      'closeTime': '12:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.24172,
      'longitude': 123.53868,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Tindahan ni Aling Rosa',
      'category': 'Sari-Sari',
      'products': [
        'canned goods',
        'snacks',
        'softdrinks',
        'toiletries',
        'condiments',
      ],
      'address': 'Section A, Stall 8, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/grocery.jpg',
      ],
      'openTime': '5:00 AM',
      'closeTime': '6:00 PM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.24190,
      'longitude': 123.53898,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Ukay-Ukay Ligao',
      'category': 'Ukay-Ukay',
      'products': [
        't-shirts',
        'pants',
        'dresses',
        'tela',
        'secondhand clothes',
      ],
      'address': 'Section E, Stall 3, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/ecommerce/clothing.jpg',
      ],
      'openTime': '7:00 AM',
      'closeTime': '5:00 PM',
      'daysOpen': ['Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      'latitude': 13.24183,
      'longitude': 123.53908,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Prutas ni Aling Clara',
      'category': 'fruits',
      'products': [
        'mangga',
        'saging',
        'papaya',
        'pakwan',
        'lansones',
        'rambutan',
        'santol',
      ],
      'address': 'Section C, Stall 5, Ligao City Public Market',
      'photoUrls': [
        'https://res.cloudinary.com/demo/image/upload/samples/food/fruit.jpg',
      ],
      'openTime': '5:00 AM',
      'closeTime': '11:00 AM',
      'daysOpen': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      'latitude': 13.24186,
      'longitude': 123.53888,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
  ];

  // Add stalls to Firestore
  print('🌱 Seeding stall data to Firestore...');
  
  for (final stall in stalls) {
    try {
      await firestore.collection('stalls').add(stall);
      print('✅ Added: ${stall['name']}');
    } catch (e) {
      print('❌ Error adding ${stall['name']}: $e');
    }
  }
  
  print('🎉 Seed data complete! Check Firestore console.');
}

/// Instructions to run this seed script:
/// 
/// 1. Create a temporary Dart file in your project (e.g., scripts/seed_stalls.dart)
/// 2. Add this code to that file
/// 3. Import Firebase and initialize it
/// 4. Call seedStallData() in main()
/// 5. Run: flutter run -t scripts/seed_stalls.dart
/// 6. After seeding, delete the temporary script file
/// 
/// Or manually add this data through Firebase Console:
/// - Go to Firestore Database
/// - Create 'stalls' collection
/// - Add documents with the data above
