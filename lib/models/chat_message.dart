import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' or 'model'
  final DateTime timestamp;
  final bool isStreaming;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
  });

  /// Create a copy with optional modifications
  ChatMessage copyWith({
    String? id,
    String? content,
    String? role,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'role': role,
      'timestamp': Timestamp.fromDate(timestamp),
      'isStreaming': isStreaming,
    };
  }

  /// Create from map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      content: map['content'] as String,
      role: map['role'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isStreaming: map['isStreaming'] as bool? ?? false,
    );
  }
}
