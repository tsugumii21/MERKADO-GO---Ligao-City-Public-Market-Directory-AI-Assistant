import 'dart:ui';
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
    debugPrint('🔴 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('🔴 STACK: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 PLATFORM ERROR: $error');
    debugPrint('🔴 STACK: $stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ dotenv loaded successfully');
  } catch (e, stack) {
    debugPrint('🔴 dotenv load failed: $e');
    debugPrint('🔴 STACK: $stack');
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stack) {
    debugPrint('🔴 Firebase init failed: $e');
    debugPrint('🔴 STACK: $stack');
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
