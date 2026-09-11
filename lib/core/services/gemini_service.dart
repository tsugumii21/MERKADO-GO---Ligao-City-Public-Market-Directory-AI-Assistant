import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_secrets.dart';
import '../../data/seed_stalls.dart';
import '../../features/stalls/data/stall_repository.dart';
import '../../models/stall_model.dart';
import '../utils/stall_utils.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';

  static const Map<String, String> _categoryEnrichment = {
    'Meat': 'Pork cuts, beef, liempo, pork chop, giniling, pata, kasim, tadyang, baka, baboy, karne ning orig, karne ning baka',
    'Fish': 'Bangus, tilapia, galunggong, pusit, hipon, salmon, tuna, tulingan, matang baka, lapu-lapu, asuhos, dried fish, daing, isda',
    'Produce': 'Gulay, prutas, repolyo, sibuyas, bawang, kamatis, patatas, sitaw, kalabasa, luya, sili, kangkong, pechay, saging, mangga, pinya, calamansi, gulayon, lasona, batag, tapayas',
    'Fresh Vegetables': 'Gulay, repolyo, sibuyas, bawang, kamatis, patatas, sitaw, kalabasa, luya, sili, kangkong, pechay, ampalaya, sayote, gulayon, lasona',
    'Fruits': 'Prutas, saging, mangga, pinya, papaya, avocado, pakwan, melon, mansanas, dalandan, batag, tapayas',
    'Rice & Grains': 'Bigas, dinorado, sinandomeng, malagkit, well-milled rice, brown rice, milagrosa, jasmine rice, bigas mais',
    'Eateries': 'Lutong bahay, pancit, tapsilog, bulalo, ulam, sopas, kanin, kape, softdrinks, merienda',
    'Carenderia': 'Lutong bahay, ulam, kanin, bulalo, sinigang, adobo, pancit, merienda',
    'Bakery & Bread': 'Pandesal, monay, ensaymada, sliced bread, spanish bread, biskwit, tinapay',
    'Native Delicacies': 'Puto, bibingka, sapin-sapin, suman, kalamay, kakanin, biko, kutsinta',
    'Spices & Condiments': 'Paminta, suka, toyo, patis, bagoong, asin, lasona, aromatics, chili garlic, bawang, sibuyas',
    'Grocery / Sari-Sari': 'Canned goods, sardines, noodles, kape, gatas, asukal, sabon, shampoo, toothpaste, mantika, de-lata, pancit canton',
    'Sari-Sari': 'Canned goods, sardines, noodles, kape, gatas, asukal, sabon, shampoo, toothpaste, mantika, de-lata, pancit canton',
    'Dry Goods': 'Damit, tela, kurtina, tuwalya, pambahay, kumot, plasticware, banig',
    'Clothing & Apparel': 'Damit, t-shirt, pantalon, pambahay, shorts, sando, palda, blouse, uniform',
    'Footwear': 'Tsinelas, sapatos, sandals, gomang tsinelas, pambata, step-in',
    'Household & Plasticware': 'Timba, planggana, tupperware, tabo, walis, basahan, plastic containers, hanger',
    'Tailoring & Dress Shop': 'Patahian, alterasyon, uniform, dressmaking, burda, tabas damit, repair damit',
    'Specialty Repair': 'Watch repair, jewelry repair, electronics repair, sapatos repair, relo, alahas',
    'Flowers & Plants': 'Bulaklak, fresh flowers, halamang ornamental, paso, bouquet',
  };

  static String _getEnrichedProductsForCategory(String category, List<String> categories) {
    for (final cat in [category, ...categories]) {
      if (_categoryEnrichment.containsKey(cat)) {
        return _categoryEnrichment[cat]!;
      }
      for (final entry in _categoryEnrichment.entries) {
        if (cat.toLowerCase().contains(entry.key.toLowerCase()) ||
            entry.key.toLowerCase().contains(cat.toLowerCase())) {
          return entry.value;
        }
      }
    }
    return '';
  }

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

  void updateStalls(List<StallModel> stalls) {
    if (stalls.isNotEmpty) {
      _stalls = stalls.where((s) => s.isActive != false).toList();
      _isInitialized = true;
    }
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

  List<StallModel> _getStallsFromSeedData() {
    return kMarketVendorsSeedData.map((v) {
      final stallId = (v['stall_id'] as String? ?? 'id_${v['id']}').trim();
      final name = (v['name'] as String? ?? '').trim();
      final category = (v['category'] as String? ?? '').trim();
      final rawCats = v['categories'] as List? ?? [category];
      final categories = rawCats
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final section = (v['section'] as String? ?? '').trim();
      final stallNumber = (v['stall_number'] as String? ?? '').trim();
      final address = (v['address'] as String? ?? '').trim();

      return StallModel(
        stallId: stallId,
        name: name,
        category: category,
        categories: categories.isNotEmpty ? categories : [category],
        products: const [],
        address: address,
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ],
        latitude: 13.2419233,
        longitude: 123.5385460,
        isActive: true,
        status: 'open',
        section: section.isNotEmpty ? section : null,
        stallNumber: stallNumber.isNotEmpty ? stallNumber : null,
        updatedAt: DateTime.now(),
        tags: const [],
      );
    }).toList();
  }

  Future<void> _loadStalls() async {
    // Tier 1: Live Firestore collection
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stalls').get();
      final firestoreStalls = snapshot.docs
          .map((doc) => StallModel.fromFirestore(doc))
          .where((s) => s.isActive != false)
          .toList();

      if (firestoreStalls.isNotEmpty) {
        _stalls = firestoreStalls;
        _isInitialized = true;
        return;
      }
    } catch (e) {
      debugPrint('Warning: Live Firestore stalls fetch failed: $e');
    }

    // Tier 2: Offline cache from StallRepository
    try {
      final cachedStalls = await FirestoreStallRepository().getOfflineCachedStalls();
      if (cachedStalls.isNotEmpty) {
        _stalls = cachedStalls.where((s) => s.isActive != false).toList();
        _isInitialized = true;
        return;
      }
    } catch (e) {
      debugPrint('Warning: Offline cached stalls fetch failed: $e');
    }

    // Tier 3: Pre-bundled 134 vendor stalls dataset
    _stalls = _getStallsFromSeedData();
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized && _stalls.isNotEmpty) return;
    await _loadStalls();
  }

  String buildIntroMessage({String? language}) {
    final lang = language ?? _language;
    final openCount = _stalls.where((s) => StallUtils.isStallOpenNow(s)).length;

    if (lang == 'tagalog') {
      return 'Kamusta! Ako si **Aling Suki**.\n\n'
          'Ako ang iyong gabay sa **Ligao City Public Market**. '
          'Matutulungan kita mahanap ang mga stall, produkto, at seksyon sa loob ng palengke.\n\n'
          'Sa ngayon, **$openCount stalls** ang bukas.\n\n'
          'Subukan mong itanong:\n'
          '• *Saan ako makakabili ng isda?*\n'
          '• *Anong mga stall ang bukas?*\n'
          '• *Nasaan ang meat section?*\n'
          '• *Sino ang nagbebenta ng pork liempo?*';
    }

    return 'Hello! I\'m **Aling Suki**.\n\n'
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

      String productsDesc = stall.products.isNotEmpty
          ? stall.products.join(', ')
          : '';
      if (productsDesc.isEmpty) {
        final enriched = _getEnrichedProductsForCategory(stall.category, stall.categories);
        productsDesc = enriched.isNotEmpty ? enriched : 'General market items for this category';
      }

      final tags = stall.tags.isNotEmpty
          ? stall.tags.map((t) => StallUtils.getTagLabel(t)).join(', ')
          : 'none';
      final section = (stall.section != null && stall.section!.trim().isNotEmpty)
          ? stall.section!.trim()
          : 'Main Market Area';
      final stallNum = (stall.stallNumber != null && stall.stallNumber!.trim().isNotEmpty)
          ? stall.stallNumber!.trim()
          : 'ID: ${stall.stallId}';

      stallData.writeln(
        '- STALL: ${stall.name} ($stallNum) | '
        'SECTION: $section | '
        'STATUS: ${isOpen ? 'OPEN' : 'CLOSED'} | '
        'CATEGORY: $cats | '
        'SELLS: $productsDesc | '
        'TAGS: $tags | '
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
3. If asked something NOT about the market (weather, news, math, general topics), politely say you can only help with Ligao Public Market inquiries.
4. ALWAYS check if stalls are OPEN or CLOSED based on provided STATUS and schedule context.
5. When listing stalls, ALWAYS state their current open or closed status.
6. Keep responses SHORT, FACTUAL, and SPECIFIC.
7. Maximum 5 stalls per response.
8. If user asks about a product (e.g. pork, bangus, bigas, damit, lutong bahay), find which stalls sell that product and list only those matching stalls.
9. Format stall info clearly like:
   - [Stall Name] ([Stall Number], [Section]) - [OPEN / CLOSED]
     Sells: [products or items]
     Hours: [hours]
10. Never make up stall names, stall numbers, or sections. Only use the official market directory provided below.
11. If no stalls match the query, say so honestly.
12. Prioritize recommending OPEN stalls unless the user explicitly asks for all stalls.
13. You understand English, Tagalog, and Bikol (Ligao Bicol dialect) market terms (e.g., orig = pork/baboy, batag = saging, tapayas = papaya, gulayon = gulay, bigas = bagas).
14. STRICT RULE: NEVER use any emojis in your response.

MARKET SECTIONS & LAYOUT:
- Building II: Rice & Grains, Dry Goods, Sari-Sari stalls. Located near Gate 1 and Gate 2.
- Meat Section: Fresh Pork, Beef, Offal, Frozen Meats. Located near Gate 3.
- Fish Section: Fresh Saltwater & Freshwater Fish, Seafood, Dried Fish. Located near Gate 3 and Gate 4.
- New Camarin & Old Camarin: Tailoring, Dressmaking, Specialty Repair, Dry Goods, Footwear. Located near Gate 2.
- Carenderia / Eateries: Cooked Meals, Eateries, Bakeries, Native Delicacies. Located near Gate 1.
- Vegetables & Fruits Section: Fresh Produce, Aromatics, Local Bicol Goods. Located near Gate 4 and Gate 5.

OFFICIAL MARKET STALL DIRECTORY (${_stalls.length} stalls):
$stallData

RESPONSE FORMAT RULES:
- Be concise and direct.
- Use bullet points for stall lists.
- Always include open or closed status.
- Include section and stall number when giving stall locations.
- For greetings: warm but brief, then ask how you can help with the market.
- For off-topic: politely decline in 1 sentence.
- Maximum response length: 150 words unless listing stalls.
- STRICT RULE: Do NOT include any emojis anywhere in your response.
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
