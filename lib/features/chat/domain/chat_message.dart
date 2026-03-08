class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' | 'aling_suki'
  final DateTime timestamp;
  final bool isStreaming;
  
  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
  });
  
  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
