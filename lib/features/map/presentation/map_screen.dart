import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../providers/chat_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/market_svg_map_view.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final GlobalKey<MarketSvgMapViewState> _svgMapKey = GlobalKey<MarketSvgMapViewState>();

  bool _isChatOpen = false;
  double _mapRotationAngle = 0.0;

  void resetUI() {
    if (!mounted) return;

    if (_isChatOpen) {
      setState(() => _isChatOpen = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Master Interactive Vector Floor Plan
          Positioned.fill(
            child: MarketSvgMapView(
              key: _svgMapKey,
              onRotationChanged: (angle) {
                if (mounted) {
                  setState(() => _mapRotationAngle = angle);
                }
              },
            ),
          ),

              // Floating Controls (Compass, Zoom +/- , Recenter Button & Aling Suki AI Chatbot)
              Positioned(
                bottom: MediaQuery.sizeOf(context).width >= 600 ? 24 : 76,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compass Reset Button (Only appears when rotation != 0)
                    AnimatedOpacity(
                      opacity: _mapRotationAngle.abs() > 0.02 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedScale(
                        scale: _mapRotationAngle.abs() > 0.02 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _svgMapKey.currentState?.resetRotation(),
                              borderRadius: BorderRadius.circular(22),
                              child: Center(
                                child: Transform.rotate(
                                  angle: -_mapRotationAngle,
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: Color(0xFFE53935),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Zoom In / Out Controls Stack
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Zoom In (+)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _svgMapKey.currentState?.zoomIn(),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: AppColors.ink,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderLight,
                          ),
                          // Zoom Out (-)
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _svgMapKey.currentState?.zoomOut(),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(22),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.remove_rounded,
                                    color: AppColors.ink,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Recenter / Reset View Button
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _svgMapKey.currentState?.resetView(),
                          borderRadius: BorderRadius.circular(22),
                          child: const Center(
                            child: Icon(
                              Icons.center_focus_strong_rounded,
                              color: AppColors.ink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Aling Suki AI Assistant Button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() => _isChatOpen = true);
                                _showAlingSukiOverlay();
                              },
                              borderRadius: BorderRadius.circular(28),
                              child: const Center(
                                child: CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  backgroundImage:
                                      AssetImage('assets/images/aling_suki.png'),
                                  radius: 24,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Unread indicator dot
                        if (!_isChatOpen && ref.watch(chatProvider).length > 1)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

  void _showAlingSukiOverlay() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    if (isDesktop) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Aling Suki Chat',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, anim1, anim2) {
          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 24),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 400,
                  height: 600,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: const _AlingSukiChatSheet(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final curve = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
            alignment: Alignment.bottomRight,
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          );
        },
      ).then((_) {
        if (mounted) {
          setState(() {
            _isChatOpen = false;
          });
        }
      });
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height,
          width: MediaQuery.sizeOf(context).width,
          child: const _AlingSukiChatSheet(),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isChatOpen = false;
          });
        }
      });
    }
  }
}

// Aling Suki Chat Overlay Widget
class _AlingSukiChatSheet extends ConsumerStatefulWidget {
  const _AlingSukiChatSheet();

  @override
  ConsumerState<_AlingSukiChatSheet> createState() =>
      _AlingSukiChatSheetState();
}

class _AlingSukiChatSheetState extends ConsumerState<_AlingSukiChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  String _language = 'english';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(instant: true);
    });
    _initializeChat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await ref.read(chatProvider.notifier).initializeChat();
    _language = ref.read(chatProvider.notifier).language;
    setState(() => _isRefreshing = false);
  }

  Future<void> _toggleLanguage() async {
    final newLanguage = _language == 'english' ? 'tagalog' : 'english';
    setState(() {
      _language = newLanguage;
    });
    await ref.read(chatProvider.notifier).setLanguage(newLanguage);
  }

  List<String> get _suggestions => _language == 'english'
      ? [
          'Open stalls now',
          'Where to buy fish?',
          'Meat section',
          'Vegetable stalls',
        ]
      : [
          'Anong bukas ngayon?',
          'Saan makabili ng isda?',
          'Meat section',
          'Mga gulay na stall',
        ];

  void _scrollToBottom({bool instant = false}) {
    if (!_scrollController.hasClients) return;
    if (instant) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _sendSuggestion(String suggestion) {
    _inputController.text = suggestion;
    ref.read(chatProvider.notifier).sendMessage(suggestion);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasUserMessages = messages.where((m) => m.role == 'user').isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty && messages.last.isStreaming) {
        _scrollToBottom();
      }
    });

    return Container(
      height: screenHeight * 0.7 + keyboardHeight,
      decoration: const BoxDecoration(
        color: AppColors.chatBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inkSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 1),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/aling_suki.png'),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Aling Suki',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.navActive,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notifier.stallsLoaded
                            ? '${notifier.stallsCount} stalls in directory'
                            : 'AI Market Assistant',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _toggleLanguage,
                  tooltip: 'Switch Language',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _language == 'english' ? 'EN' : 'TL',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message.role == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage:
                              AssetImage('assets/images/aling_suki.png'),
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUser
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: isUser
                              ? Text(
                                  message.content,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                )
                              : MarkdownBody(
                                  data: message.content,
                                  styleSheet: MarkdownStyleSheet(
                                    p: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.ink,
                                    ),
                                    strong: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Suggestions Bar (if no messages)
          if (!hasUserMessages)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(
                      _suggestions[index],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.ink,
                      ),
                    ),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: () => _sendSuggestion(_suggestions[index]),
                  );
                },
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: _language == 'english'
                          ? 'Ask Aling Suki...'
                          : 'Magtanong kay Aling Suki...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.inkSubtle,
                      ),
                      filled: true,
                      fillColor: AppColors.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
