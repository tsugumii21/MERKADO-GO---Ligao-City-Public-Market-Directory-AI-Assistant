// Planned: Define Stall Model
class StallModel {
  final String stallId;
  final String name;
  final String category;
  final List<String> products;
  final String address;
  final List<String> photoUrls;
  final String openTime;
  final String closeTime;
  final List<String> daysOpen;
  final double latitude;
  final double longitude;
  final bool isActive;

  StallModel({
    required this.stallId,
    required this.name,
    required this.category,
    required this.products,
    required this.address,
    required this.photoUrls,
    required this.openTime,
    required this.closeTime,
    required this.daysOpen,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  // Planned: Add fromJson, toJson methods
}
