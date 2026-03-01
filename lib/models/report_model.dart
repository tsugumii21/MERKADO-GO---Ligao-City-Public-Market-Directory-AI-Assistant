// TODO: Define Report Model
class ReportModel {
  final String reportId;
  final String userId;
  final String stallId;
  final String stallName;
  final String description;
  final String status; // 'pending', 'reviewed', 'resolved'
  final DateTime createdAt;

  ReportModel({
    required this.reportId,
    required this.userId,
    required this.stallId,
    required this.stallName,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  // TODO: Add fromJson, toJson, copyWith methods
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError();
  }

  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
