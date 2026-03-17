import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_secrets.dart';
import '../../models/stall_model.dart';
import '../utils/stall_utils.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';

  bool _isInitialized = false;
  String _language = 'english';
  List<StallModel> _stalls = [];
  final List<Map<String, String>> _conversationHistory = [];
  
  GeminiService(Ref _);

  String get language => _language;
  bool get stallsLoaded => _isInitialized;
  int get stallsCount => _stalls.length;

  void setLanguage(String language) {
    _language = language == 'tagalog' ? 'tagalog' : 'english';
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrentDay() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  Future<void> _loadStalls() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stalls').get();
      _stalls = snapshot.docs.map((doc) => StallModel.fromFirestore(doc)).toList();
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error: Failed to fetch stalls context: $e');
      _stalls = [];
      _isInitialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await _loadStalls();
  }

  String buildIntroMessage({String? language}) {
    final lang = language ?? _language;
    final openCount = _stalls.where((s) => StallUtils.isStallOpenNow(s)).length;

    if (lang == 'tagalog') {
      return 'Kamusta! Ako si **Aling Suki** 🛒\n\n'
          'Ako ang iyong gabay sa **Ligao City Public Market**. '
          'Matutulungan kita mahanap ang mga stall, produkto, at seksyon sa loob ng palengke.\n\n'
          'Sa ngayon, **$openCount stalls** ang bukas.\n\n'
          'Subukan mong itanong:\n'
          '• *Saan ako makakabili ng isda?*\n'
          '• *Anong mga stall ang bukas?*\n'
          '• *Nasaan ang meat section?*\n'
          '• *Sino ang nagbebenta ng pork liempo?*';
    }

    return 'Hello! I\'m **Aling Suki** 🛒\n\n'
        'I\'m your digital guide for **Ligao City Public Market**. '
        'I can help you find stalls, products, and sections inside the market.\n\n'
        'Right now, **$openCount stalls** are open.\n\n'
        'Try asking me:\n'
        '• *Where can I buy fish?*\n'
        '• *Which stalls are open now?*\n'
        '• *Where is the meat section?*\n'
        '• *Who sells pork liempo?*';
  }

  String _buildSystemPrompt() {
    final timeStr = _formatCurrentTime();
    final dayStr = _formatCurrentDay();
    final stallData = StringBuffer();

    for (final stall in _stalls) {
      final isOpen = StallUtils.isStallOpenNow(stall);
      final cats = stall.categories.isNotEmpty
          ? stall.categories.join(', ')
          : stall.category;
      final products = stall.products.isNotEmpty
          ? stall.products.join(', ')
          : 'not specified';
      final tags = stall.tags.isNotEmpty
          ? stall.tags.map((t) => StallUtils.getTagLabel(t)).join(', ')
          : 'none';
      final section = (stall.section != null && stall.section!.trim().isNotEmpty)
          ? stall.section!.trim()
          : 'not specified';

      stallData.writeln(
        '- STALL: ${stall.name} | '
        'STATUS: ${isOpen ? 'OPEN' : 'CLOSED'} | '
        'CATEGORY: $cats | '
        'PRODUCTS: $products | '
        'TAGS: $tags | '
        'SECTION: $section | '
        'HOURS: ${stall.openTime} - ${stall.closeTime} | '
        'DAYS: ${stall.daysOpen.join(', ')}',
      );
    }

    final langInstruction = _language == 'english'
        ? 'ALWAYS respond in English.'
        : 'ALWAYS respond in Filipino/Tagalog language. Use natural conversational Tagalog.';

    return '''
You are Aling Suki, the official AI assistant of Ligao City Public Market in Ligao City, Albay, Philippines.

CURRENT TIME: $timeStr
CURRENT DAY: $dayStr

$langInstruction

YOUR STRICT RULES:
1. You ONLY answer questions about the Ligao City Public Market.
2. If someone greets you (hello, hi, kumusta), respond warmly but immediately steer to market topics.
3. If asked something NOT about the market (weather, news, math, etc.), politely say you can only help with market-related questions.
4. ALWAYS check if stalls are OPEN or CLOSED based on provided STATUS and schedule context.
5. When listing stalls, ALWAYS show their current open/closed status.
6. Keep responses SHORT and SPECIFIC.
7. Maximum 5 stalls per response.
8. If user asks about a product, find which stalls sell that product and list only those stalls.
9. Format stall info clearly like:
   📍 [Stall Name] - [Status]
      Sells: [products]
      Hours: [hours]
10. Never make up stall information. Only use the data provided below.
11. If no stalls match the query, say so honestly.
12. Prefer OPEN stalls unless user explicitly asks for all stalls.

MARKET STALL DATA:
$stallData

RESPONSE FORMAT RULES:
- Be concise and direct.
- Use bullet points for stall lists.
- Always mention open/closed status.
- If giving directions, mention market section.
- For greetings: warm but brief, then ask how you can help with the market.
- For off-topic: politely decline in 1 sentence.
- Maximum response length: 150 words unless listing stalls.
''';
  }
  
  Future<void> refreshStalls() async {
    _isInitialized = false;
    await _ensureInitialized();
  }

  bool _looksIncompleteResponse(String text) {
    final trimmed = text.trimRight();
    if (trimmed.length < 24) return false;

    if (RegExp(r'[.!?)]$').hasMatch(trimmed)) return false;

    final lastToken = trimmed.split(RegExp(r'\s+')).last.toLowerCase();
    const danglingTokens = {
      'at',
      'and',
      'or',
      'ng',
      'sa',
      'na',
      'pero',
      'dahil',
    };
    if (danglingTokens.contains(lastToken)) return true;

    if (trimmed.endsWith(',') || trimmed.endsWith(':') || trimmed.endsWith('-')) {
      return true;
    }

    final markdownAsterisks = RegExp(r'\*\*').allMatches(trimmed).length;
    if (markdownAsterisks.isOdd) return true;

    return false;
  }

  Future<String> _requestContinuation({
    required GenerativeModel model,
    required List<Content> contents,
    required String partialReply,
  }) async {
    final continuationPrompt = _language == 'tagalog'
        ? 'Mukhang naputol ang huling sagot mo. Ipagpatuloy at tapusin ito sa Filipino/Tagalog. Huwag ulitin ang naibigay na.'
        : 'Your last answer appears cut off. Continue and finish it in English without repeating previous lines.';

    final continued = await model.generateContent([
      ...contents,
      Content.model([TextPart(partialReply)]),
      Content.text(continuationPrompt),
    ]);

    return (continued.text ?? '').trim();
  }

  String _mergeReplyAndContinuation(String reply, String continuation) {
    final base = reply.trimRight();
    final tail = continuation.trimLeft();
    if (tail.isEmpty) return base;

    if (base.endsWith('.') || base.endsWith('!') || base.endsWith('?')) {
      return '$base\n$tail';
    }
    return '$base $tail';
  }

  Stream<String> sendMessage(String message) async* {
    if (message.trim().isEmpty) return;

    await _ensureInitialized();
    final apiKey = AppSecrets.geminiApiKey;
    if (apiKey.isEmpty) {
      yield _language == 'english'
          ? 'Sorry, Gemini API key is missing. Please configure it first.'
          : 'Paumanhin, kulang ang Gemini API key. Paki-configure muna.';
      return;
    }

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system(_buildSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 768,
          topP: 0.8,
          topK: 40,
        ),
      );

      final recentTurns = _conversationHistory.length <= 10
          ? _conversationHistory
          : _conversationHistory.sublist(_conversationHistory.length - 10);

      final contents = <Content>[];
      for (final turn in recentTurns) {
        final role = turn['role'] ?? 'user';
        final text = turn['text'] ?? '';
        if (text.isEmpty) continue;
        if (role == 'model') {
          contents.add(Content.model([TextPart(text)]));
        } else {
          contents.add(Content.text(text));
        }
      }

      contents.add(Content.text(message.trim()));

      final response = await model.generateContent(contents);
      final botReply = (response.text ?? '').trim();

      if (botReply.isEmpty) {
        yield _language == 'english'
            ? 'Sorry, I could not generate a response. Please try again.'
            : 'Paumanhin, walang nabuong sagot. Subukan po ulit.';
        return;
      }

      var finalReply = botReply;
      if (_language == 'tagalog' && _looksIncompleteResponse(botReply)) {
        try {
          final continuation = await _requestContinuation(
            model: model,
            contents: contents,
            partialReply: botReply,
          );
          if (continuation.isNotEmpty) {
            finalReply = _mergeReplyAndContinuation(botReply, continuation);
          }
        } catch (e) {
          debugPrint('⚠️ Warning: Continuation request failed: $e');
        }
      }

      _conversationHistory.add({'role': 'user', 'text': message.trim()});
      _conversationHistory.add({'role': 'model', 'text': finalReply});
      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(0, _conversationHistory.length - 20);
      }

      yield finalReply;
    } catch (e) {
      debugPrint('❌ Error: Gemini API error: $e');
      yield _language == 'english'
          ? 'Sorry, I\'m having trouble connecting. Please try again.'
          : 'Paumanhin, may problema sa koneksyon. Subukan ulit.';
    }
  }

  void clearChat() {
    _conversationHistory.clear();
  }
}

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(ref),
);
