import 'chat_directory_action.dart';
import 'chat_route_action.dart';

class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' | 'aling_suki'
  final DateTime timestamp;
  final bool isStreaming;
  final ChatRouteAction? routeAction;
  final ChatDirectoryAction? directoryAction;
  
  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
    this.routeAction,
    this.directoryAction,
  });
  
  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    ChatRouteAction? routeAction,
    ChatDirectoryAction? directoryAction,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      routeAction: routeAction ?? this.routeAction,
      directoryAction: directoryAction ?? this.directoryAction,
    );
  }
}
