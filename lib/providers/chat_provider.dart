// TODO: Implement Chat Provider (Riverpod)
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Chat messages state provider
final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<Map<String, dynamic>>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  ChatMessagesNotifier() : super([]);

  void addMessage(String message, bool isUser) {
    state = [
      ...state,
      {
        'message': message,
        'isUser': isUser,
        'timestamp': DateTime.now(),
      },
    ];
  }

  void clearMessages() {
    state = [];
  }
}

// Is loading provider for chat
final isChatLoadingProvider = StateProvider<bool>((ref) => false);
