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
  
  String _getCurrentPhilippineTime() {
    // Get current Philippine time (UTC+8)
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    
    final days = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final currentTime24 = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final currentDay = days[now.weekday - 1];
    final currentDate = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final amPm = now.hour < 12 ? 'AM' : 'PM';
    final hour12 = now.hour == 0 ? 12 : 
                   now.hour > 12 ? now.hour - 12 : 
                   now.hour;
    final timeReadable = '$hour12:'
        '${now.minute.toString().padLeft(2, '0')} $amPm';
    
    return '''
CURRENT DATE AND TIME (Philippine Standard Time):
Date: $currentDate
Day: $currentDay
Time: $timeReadable (24hr: $currentTime24)

Use this to determine which stalls are currently open or closed based on their operating hours.

HOW TO DETERMINE IF A STALL IS OPEN:
- Compare current time against the stall's opening and closing hours
- Consider the current day against the stall's operating days
- If current time is BETWEEN opening and closing time AND today is an operating day, the stall is OPEN
- Otherwise it is CLOSED

When asked about open stalls, ALWAYS:
1. State the current time you are using
2. List which stalls are open RIGHT NOW
3. List which stalls are closed with their opening time so user knows when they open
''';
  }
  
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
Stall: ${data['name'] ?? 'Unknown'}
Category: ${data['category'] ?? 'Unknown'}
Hours: ${data['openTime'] ?? 'N/A'} - ${data['closeTime'] ?? 'N/A'}
Days: ${(data['daysOpen'] as List?)?.join(', ') ?? 'N/A'}
Status: ${data['isActive'] == true ? 'Active' : 'Inactive'}
Location: ${data['address'] ?? 'Unknown'}
Products: ${(data['products'] as List?)?.join(', ') ?? 'N/A'}
---''';
      }).join('\n');
      
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
      
      // Get current Philippine time
      final currentTimeInfo = _getCurrentPhilippineTime();
      
      final apiKey = AppSecrets.geminiApiKey;
      
      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system('''
Ikaw si Aling Suki, ang digital na gabay ng Ligao City Public Market 
sa Ligao City, Albay, Pilipinas.

$currentTimeInfo

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
- Sumagot sa PAREHONG WIKA na ginamit ng user (Filipino o English)
- Tulungan ang mamimili na makahanap ng hinahanap nila
- Maging totoong "Aling" - mapagkaibigan at matulungin
- Laging gamitin ang Philippine time context para sa katumpakan

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
