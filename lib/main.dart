import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  // CRITICAL: Catch all Flutter errors before anything else
  FlutterError.onError = (details) {
    debugPrint('Error: ${details.exceptionAsString()}');
    debugPrint('Stack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('❌ Failed: dotenv load failed: $e');
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('❌ Failed: Firebase init failed: $e');
  }
  
  // Create ProviderContainer and set it for AppRouter
  final container = ProviderContainer();
  AppRouter.setContainer(container);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache brand assets in memory for instant zero-lag loading across all screens
    precacheImage(
      const AssetImage('assets/icons/MerkadoGo_Transparent Logo.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/splash_logo.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/street_map_bg.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router();
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Merkado Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            // Full-screen on mobile phone browsers (<500px width)
            if (constraints.maxWidth <= 500) {
              return child ?? const SizedBox.shrink();
            }
            // Centered elegant phone kiosk container on wide desktop/tablet browsers
            return Container(
              color: const Color(0xFF141914), // Dark civic backdrop
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                    maxHeight: 920,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
