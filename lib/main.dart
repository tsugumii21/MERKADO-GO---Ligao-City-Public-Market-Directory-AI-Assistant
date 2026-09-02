import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  // CRITICAL: Catch all Flutter errors before anything else
  FlutterError.onError = (details) {
    debugPrint('❌ Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Error: $error');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  
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
    );
  }
}
