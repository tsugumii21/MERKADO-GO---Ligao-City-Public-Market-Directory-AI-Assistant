import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/gemini_service.dart';
import '../features/chat/domain/chat_message.dart';
import '../models/stall_model.dart';
import 'stall_provider.dart';

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier(this._geminiService) : super([]) {
    _addWelcomeMessage();
  }
  
  final GeminiService _geminiService;
  
  void _addWelcomeMessage() {
    state = [
      ChatMessage(
        id: 'welcome',
        content: _geminiService.buildIntroMessage(),
        role: 'aling_suki',
        timestamp: DateTime.now(),
      ),
    ];
  }

  Future<void> initializeChat({bool reset = false}) async {
    await _geminiService.refreshStalls();

    final hasUserMessages = state.any((m) => m.role == 'user');
    if (reset || !hasUserMessages) {
      _addWelcomeMessage();
    }
  }

  void updateStalls(List<StallModel> stalls) {
    _geminiService.updateStalls(stalls);
    final hasUserMessages = state.any((m) => m.role == 'user');
    if (!hasUserMessages) {
      _addWelcomeMessage();
    }
  }

  Future<void> setLanguage(String language) async {
    _geminiService.setLanguage(language);
    await _geminiService.refreshStalls();

    final hasUserMessages = state.any((m) => m.role == 'user');
    if (!hasUserMessages) {
      _addWelcomeMessage();
    }
  }

  String get language => _geminiService.language;
  bool get stallsLoaded => _geminiService.stallsLoaded;
  int get stallsCount => _geminiService.stallsCount;
  
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
  final gemini = ref.watch(geminiServiceProvider);
  final notifier = ChatNotifier(gemini);

  ref.listen<AsyncValue<List<StallModel>>>(allStallsProvider, (_, next) {
    next.whenData((stalls) {
      if (stalls.isNotEmpty) {
        notifier.updateStalls(stalls);
      }
    });
  });

  final currentStalls = ref.read(allStallsProvider).asData?.value;
  if (currentStalls != null && currentStalls.isNotEmpty) {
    notifier.updateStalls(currentStalls);
  }

  return notifier;
});
