import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/gemini_service.dart';
import '../features/chat/domain/chat_message.dart';

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier(this._geminiService) : super([]) {
    _addWelcomeMessage();
  }
  
  final GeminiService _geminiService;
  
  void _addWelcomeMessage() {
    state = [
      ChatMessage(
        id: 'welcome',
        content:
          'Magandang araw po! Ako si **Aling Suki** \n\n'
          'Ang inyong digital na gabay sa Ligao City Public Market!\n\n'
          'Maaari kayong magtanong tungkol sa:\n'
          '• Mga stalls at lokasyon nila\n'
          '• Operating hours ng mga tindahan\n'
          '• Mga available na produkto\n'
          '• Paano mag-navigate sa palengke\n\n'
          'Ano po ang maipaglilingkod ko sa inyo? 😊',
        role: 'aling_suki',
        timestamp: DateTime.now(),
      ),
    ];
  }
  
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Add user message
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text.trim(),
      role: 'user',
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];
    
    // Add streaming placeholder for Aling Suki
    final alingSukiId = '${DateTime.now().millisecondsSinceEpoch}_aling_suki';
    final alingSukiMsg = ChatMessage(
      id: alingSukiId,
      content: '',
      role: 'aling_suki',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = [...state, alingSukiMsg];
    
    // Stream the response
    String fullResponse = '';
    await for (final chunk in _geminiService.sendMessage(text)) {
      fullResponse += chunk;
      state = state.map((msg) {
        if (msg.id == alingSukiId) {
          return msg.copyWith(
            content: fullResponse,
            isStreaming: true,
          );
        }
        return msg;
      }).toList();
    }
    
    // Mark streaming as done
    state = state.map((msg) {
      if (msg.id == alingSukiId) {
        return msg.copyWith(
          content: fullResponse,
          isStreaming: false,
        );
      }
      return msg;
    }).toList();
  }
  
  void clearChat() {
    _geminiService.clearChat();
    _addWelcomeMessage();
  }
  
  Future<void> refreshStalls() async {
    await _geminiService.refreshStalls();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  try {
    final gemini = ref.watch(geminiServiceProvider);
    return ChatNotifier(gemini);
  } catch (e) {
    debugPrint('❌ Failed: Failed to create ChatNotifier: $e');
    // Return a safe default - the service will handle errors gracefully
    final gemini = ref.read(geminiServiceProvider);
    return ChatNotifier(gemini);
  }
});
