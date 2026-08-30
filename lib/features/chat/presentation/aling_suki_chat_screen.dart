import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/stall_provider.dart';
import '../domain/chat_message.dart';

/// Clean, modern, engaging Aling Suki Chatbot modal / screen
class AlingSukiChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const AlingSukiChatScreen({
    super.key,
    this.onClose,
  });

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    if (isDesktop) {
      return showGeneralDialog(
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AlingSukiChatScreen(
                        onClose: () => Navigator.pop(context),
                      ),
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
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height,
        width: MediaQuery.sizeOf(ctx).width,
        child: AlingSukiChatScreen(
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  ConsumerState<AlingSukiChatScreen> createState() =>
      _AlingSukiChatScreenState();
}

class _AlingSukiChatScreenState extends ConsumerState<AlingSukiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentLanguage = 'EN';
  bool _isSending = false;

  final List<String> _suggestedPrompts = [
    '🐟 Where can I buy fresh fish?',
    '🥩 Who sells pork liempo?',
    '📍 Where is the meat section?',
    '🕒 Stalls open right now',
  ];

  final List<String> _suggestedPromptsTL = [
    '🐟 Saan makakabili ng sariwang isda?',
    '🥩 Sino nagtitinda ng pork liempo?',
    '📍 Nasaan ang meat section?',
    '🕒 Mga stall na bukas ngayon',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(instant: true);
      unawaited(ref.read(chatProvider.notifier).initializeChat());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool instant = false}) {
    if (!_scrollController.hasClients) return;
    if (instant) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _startNewChat() async {
    await HapticFeedback.mediumImpact();
    ref.read(chatProvider.notifier).clearChat();
    _inputController.clear();
    _scrollToBottom(instant: true);
  }

  Future<void> _toggleLanguage() async {
    await HapticFeedback.selectionClick();
    setState(() {
      _currentLanguage = _currentLanguage == 'EN' ? 'TL' : 'EN';
    });
    final langKey = _currentLanguage == 'EN' ? 'english' : 'tagalog';
    await ref.read(chatProvider.notifier).setLanguage(langKey);
  }

  Future<void> _sendMessage([String? promptText]) async {
    final text = (promptText ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() => _isSending = true);
    await HapticFeedback.lightImpact();

    _scrollToBottom();

    try {
      await ref.read(chatProvider.notifier).sendMessage(text);
    } catch (_) {
      // Handled inside provider
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final stallsAsync = ref.watch(allStallsProvider);
    final isTagalog = _currentLanguage == 'TL';
    final suggestions = isTagalog ? _suggestedPromptsTL : _suggestedPrompts;

    // Calculate market open count
    final openCount = stallsAsync.maybeWhen(
      data: (stalls) => stalls.where((s) => StallUtils.isStallOpenNow(s)).length,
      orElse: () => 0,
    );
    final isMarketOpen = openCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Header Bar: Solid Forest Green (#1B5E20)
            Container(
              width: double.infinity,
              color: const Color(0xFF1B5E20),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Avatar with pulsing green online dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B), // Gold ring
                              width: 1.8,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/aling_suki.png',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Bot Name & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aling Suki',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'AI Market Assistant • Ligao Market',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFE8F5E9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Right Actions: New Chat, Language Pill & Close Icon
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                      tooltip: 'New Chat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _startNewChat,
                    ),
                    const SizedBox(width: 10),

                    GestureDetector(
                      onTap: _toggleLanguage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentLanguage,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 2. Chat Message List Flow
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isBot = msg.role == 'aling_suki';
                  final isWelcomeMsg = msg.id == 'welcome';

                  if (isWelcomeMsg) {
                    return _buildWelcomeMessageCard(
                      isMarketOpen: isMarketOpen,
                      openCount: openCount,
                      suggestions: suggestions,
                    );
                  }

                  return _buildMessageBubble(msg, isBot);
                },
              ),
            ),

            // 3. Bottom Elevated Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pill-shaped TextField (#F9FAFB fill)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF1F2937),
                        ),
                        decoration: InputDecoration(
                          hintText: isTagalog
                              ? 'Magtanong kay Aling Suki...'
                              : 'Ask Aling Suki anything...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: const Color(0xFF9CA3AF),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Solid Forest Green Send Button (#1B5E20)
                  Material(
                    color: const Color(0xFF1B5E20),
                    shape: const CircleBorder(),
                    elevation: 1.5,
                    shadowColor: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                    child: InkWell(
                      onTap: _sendMessage,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Welcome State: Greeting Bubble + Market Status + Popular Question Chips
  Widget _buildWelcomeMessageCard({
    required bool isMarketOpen,
    required int openCount,
    required List<String> suggestions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot Small Avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/aling_suki.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Welcome Bubble
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Short Greeting
                    Text(
                      _currentLanguage == 'TL'
                          ? 'Kumusta! Ako si Aling Suki 🛒. Matutulungan kita mahanap ang mga stall, sariwang produkto, at direksyon sa loob ng Ligao Public Market.'
                          : 'Kumusta! I\'m Aling Suki 🛒. I can help you find stalls, fresh produce, and directions inside Ligao Public Market.',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: const Color(0xFF1F2937),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Status Card Widget (Compact soft-tinted pill)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isMarketOpen
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isMarketOpen
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCA5A5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isMarketOpen
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isMarketOpen
                                  ? 'Market is active • $openCount stalls open'
                                  : 'Market is currently quiet • 0 stalls open',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isMarketOpen
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Suggested Prompt Chips (Directly below welcome message)
        Padding(
          padding: const EdgeInsets.only(left: 42, bottom: 6),
          child: Text(
            'Popular questions:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 42, right: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((prompt) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendMessage(prompt),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // Regular Chat Bubble
  Widget _buildMessageBubble(ChatMessage msg, bool isBot) {
    if (isBot) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot Avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/aling_suki.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Message Bubble
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: msg.isStreaming && msg.content.isEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Aling Suki is typing...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        msg.content,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: const Color(0xFF1F2937),
                          height: 1.45,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    // User Bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
