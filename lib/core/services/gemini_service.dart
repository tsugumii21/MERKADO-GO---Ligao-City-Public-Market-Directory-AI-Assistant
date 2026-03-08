import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/stall_model.dart';
import '../../providers/stall_provider.dart';
import '../constants/app_secrets.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';
  
  GenerativeModel? _model;
  ChatSession? _chat;
  final Ref _ref;
  bool _isInitialized = false;
  String _stallsContext = '';
  
  GeminiService(this._ref);
  
  Future<String> _fetchStallsContext() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stalls')
          .get();
      
      if (snapshot.docs.isEmpty) {
        return 'Walang available na stall data sa ngayon.';
      }
      
      final stallsData = snapshot.docs.map((doc) {
        final data = doc.data();
        return '''
Stall ID: ${doc.id}
Pangalan: ${data['name'] ?? 'Unknown'}
Category: ${data['category'] ?? 'Unknown'}
Lokasyon: ${data['address'] ?? 'Unknown'}
Operating Hours: ${data['openTime'] ?? 'N/A'} - ${data['closeTime'] ?? 'N/A'}
Days Open: ${(data['daysOpen'] as List?)?.join(', ') ?? 'N/A'}
Products: ${(data['products'] as List?)?.join(', ') ?? 'N/A'}
Contact: ${data['contactNumber'] ?? 'N/A'}
''';
      }).join('\n---\n');
      
      return stallsData;
    } catch (e) {
      print('🔴 Error fetching stalls: $e');
      return 'Hindi makuha ang stall data sa ngayon.';
    }
  }
  
  Future<void> _initializeModel() async {
    if (_isInitialized) return;
    
    try {
      print('🔍 Fetching stalls from Firestore...');
      _stallsContext = await _fetchStallsContext();
      print('✅ Fetched ${_stallsContext.split('---').length} stalls');
      
      final apiKey = AppSecrets.geminiApiKey;
      
      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system('''
Ikaw si Aling Suki, ang digital na gabay ng Ligao City Public Market 
sa Ligao City, Albay, Pilipinas.

MAHALAGANG ALITUNTUNIN:
Sumagot LAMANG batay sa tunay na datos ng mga stall na ito. 
Huwag mag-imbento ng impormasyong wala sa listahan.

[STALL DATA - ITO LANG ANG TOTOO]
$_stallsContext
[END STALL DATA]

GABAY SA PAGSAGOT:
1. Kung tinanong tungkol sa stall, produkto, o lokasyon - tingnan ang datos sa itaas
2. Kung walang nakalagay sa datos, sabihin honestly: "Pasensya po, wala pa akong 
   impormasyon tungkol diyan sa aking database. Maaari po kayong magtanong sa 
   market information desk para sa mas detalyadong impormasyon. 😊"
3. Kung hindi tungkol sa palengke ang tanong, mahinahon na sabihin:
   "Ay naku, iyan ay wala sa aking alam! Pero kung may tanong kayo tungkol 
   sa Ligao Public Market, nandito po ako para tumulong! 😊"

TONO AT UGALI:
- Palaging gumamit ng po/opo para magiliw
- Maging makulay at friendly sa pagsagot
- Sumagot sa Filipino kung Filipino ang tanong
- Sumagot sa English kung English ang tanong
- Tulungan ang mamimili na makahanap ng hinahanap nila
- Maging totoong "Aling" - mapagkaibigan at matulungin

FORMATTING RULES:
- When listing items, always use bullet points on separate lines with \n before each bullet
- Never put multiple bullets on the same line
- Always add a blank line (\n\n) between paragraphs for breathing room
- Use **bold** for emphasis on important information
        '''),
      );
      
      _chat = _model!.startChat();
      _isInitialized = true;
      
      print('✅ Aling Suki initialized successfully with model: $_modelName');
    } catch (e) {
      print('🔴 Failed to initialize Aling Suki: $e');
      _model = null;
      _chat = null;
      _isInitialized = false;
    }
  }
  
  Future<void> refreshStalls() async {
    print('🔄 Refreshing stall data...');
    _stallsContext = await _fetchStallsContext();
    
    // Reinitialize the model with fresh data
    _isInitialized = false;
    await _initializeModel();
    
    print('✅ Stall data refreshed');
  }
  
  Stream<String> sendMessage(String message) async* {
    // Lazy initialization - only initialize when first message is sent
    if (_model == null) {
      await _initializeModel();
    }
    
    // If initialization failed, return error message
    if (_model == null || _chat == null) {
      yield 'Ay naku, may error po si Aling Suki! Pakisubukan ulit. 😊';
      return;
    }
    
    try {
      final response = _chat!.sendMessageStream(
        Content.text(message),
      );
      
      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      print('🔴 Gemini API Error: $e');
      yield 'Ay naku, may error po! Pakisubukan ulit. Salamat po! 😊';
    }
  }
  
  void clearChat() {
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }
}

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(ref),
);
