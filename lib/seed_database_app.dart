import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_spacing.dart';
import 'data/seed_stalls.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('⚠️ dotenv load warning: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('⚠️ Firebase init error: $e');
  }

  runApp(const SeedDatabaseApp());
}

class SeedDatabaseApp extends StatelessWidget {
  const SeedDatabaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MerkadoGo - Database Seeder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        useMaterial3: true,
      ),
      home: const SeedDatabaseScreen(),
    );
  }
}

class SeedDatabaseScreen extends StatefulWidget {
  const SeedDatabaseScreen({super.key});

  @override
  State<SeedDatabaseScreen> createState() => _SeedDatabaseScreenState();
}

class _SeedDatabaseScreenState extends State<SeedDatabaseScreen> {
  bool _isSeeding = false;
  bool _isCompleted = false;
  int _seededCount = 0;
  final List<String> _logs = [];

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _startMigration() async {
    setState(() {
      _isSeeding = true;
      _isCompleted = false;
      _logs.clear();
      _seededCount = 0;
    });

    _addLog('ðŸš€ Starting Firebase Firestore Migration...');
    
    try {
      final count = await purgeAndSeedStalls(
        onProgress: (msg) {
          _addLog(msg);
        },
      );

      if (!mounted) return;
      setState(() {
        _isSeeding = false;
        _isCompleted = true;
        _seededCount = count;
      });
      _addLog('ðŸŽ‰ Successfully migrated $count stalls into Firestore!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSeeding = false;
      });
      _addLog('âŒ Migration failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MerkadoGo - Database Migration',
          style: AppTextStyles.pageTitleWhite,
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ligao City Public Market',
                                style: AppTextStyles.pageTitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Official Stall Dataset (134 Vendors)',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This operation will:\n'
                      '1. Purge all existing demo stalls from Firestore ("stalls" collection).\n'
                      '2. Seed all 134 official vendors with deterministic document keys (id_1 to id_261).\n'
                      '3. Preserve all user accounts, auth records, and issue reports.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Button
              ElevatedButton.icon(
                onPressed: _isSeeding ? null : _startMigration,
                icon: _isSeeding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isSeeding
                      ? 'Purging & Seeding Stalls...'
                      : _isCompleted
                          ? 'Re-Run Migration'
                          : 'Purge Demo Data & Seed 134 Stalls',
                  style: AppTextStyles.button,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  elevation: 0,
                ),
              ),

              if (_isCompleted) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Migration Complete! $_seededCount stalls are now live in Firestore.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Live Logs Box
              Text(
                'Migration Logs',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 220,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'Click "Purge Demo Data & Seed 134 Stalls" to begin.',
                          style: AppTextStyles.caption,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'monospace',
                                color: log.startsWith('âŒ')
                                    ? AppColors.error
                                    : log.startsWith('ðŸŽ‰') || log.startsWith('ðŸš€')
                                        ? AppColors.primary
                                        : AppColors.ink,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
