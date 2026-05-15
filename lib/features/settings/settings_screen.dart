import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_tracker/core/services/hive_service.dart';
import 'package:dose_tracker/app_shell.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:dose_tracker/core/constants/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    // 1. First, quickly load the offline default from Hive so the UI renders instantly
    final box = await Hive.openBox('settings');
    if (mounted) {
      setState(() {
        _notificationsEnabled = box.get(
          'notifications_enabled',
          defaultValue: true,
        );
      });
    }

    // 2. Then, fetch the absolute truth from Supabase (The Cloud)
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        // We use maybeSingle() so it doesn't crash if the row doesn't exist yet
        final data = await supabase
            .from('user_tokens')
            .select('notifications_enabled')
            .eq('user_id', userId)
            .maybeSingle();

        if (data != null && mounted) {
          final cloudState = data['notifications_enabled'] as bool;

          setState(() {
            _notificationsEnabled = cloudState;
          });

          // Force Hive to synchronize with the cloud truth
          await box.put('notifications_enabled', cloudState);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch cloud settings: $e');
      // If the user has no internet, it just safely relies on the Hive state we loaded in Step 1
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const CustomText(
          'Settings',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: ListView(
        children: [
          // Section 1 - Preferences
          _buildSectionTitle('Preferences', color: AppColors.textPrimary),
          _buildListTileContainer(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: _buildLeadingIcon(
                Icons.notifications_none,
                AppColors.scaffoldBg,
                AppColors.textPrimary,
              ),
              title: const CustomText(
                'Notifications',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              subtitle: const CustomText(
                'Pause all medication reminders',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              trailing: Switch(
                value: _notificationsEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (val) async {
                  final previousValue = _notificationsEnabled;

                  // Optimistic UI update
                  setState(() {
                    _notificationsEnabled = val;
                  });

                  try {
                    // Local Hive update
                    final box = await Hive.openBox('settings');
                    await box.put('notifications_enabled', val);

                    // Cloud Sync
                    final supabase = Supabase.instance.client;
                    final userId = supabase.auth.currentUser?.id;
                    if (userId != null) {
                      await supabase
                          .from('user_tokens')
                          .update({'notifications_enabled': val})
                          .eq('user_id', userId);
                    }
                  } catch (e) {
                    debugPrint('Cloud sync error: $e');
                    // Revert local state and Hive
                    if (mounted) {
                      setState(() {
                        _notificationsEnabled = previousValue;
                      });
                      final box = await Hive.openBox('settings');
                      await box.put('notifications_enabled', previousValue);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: CustomText(
                            'Failed to sync settings with the cloud.',
                            color: Colors.white,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ),

          // Section 2 - Legal
          _buildSectionTitle('Legal', color: AppColors.textPrimary),
          _buildListTileContainer(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: _buildLeadingIcon(
                Icons.privacy_tip_outlined,
                AppColors.scaffoldBg,
                AppColors.textPrimary,
              ),
              title: const CustomText(
                'Privacy Policy',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              trailing: const Icon(
                Icons.open_in_new,
                color: AppColors.textSecondary,
              ),
              onTap: () {
                _showCustomCupertinoDialog(
                  context: context,
                  title: 'External Link',
                  content:
                      'You are leaving the app to view our Privacy Policy in a secure browser. Continue?',
                  cancelText: 'Cancel',
                  actionText: 'Open Browser',
                  actionColor: AppColors.primary,
                  onAction: (dialogContext) async {
                    Navigator.of(dialogContext).pop();
                    try {
                      final uri = Uri.parse(
                        'https://doc-hosting.flycricket.io/dosetrack-privacy-policy/eb3a8936-0772-4934-9e7d-86065794aa7f/privacy',
                      );
                      await launchUrl(uri);
                    } catch (e) {
                      debugPrint('Error launching URL: $e');
                    }
                  },
                );
              },
            ),
          ),

          // Section 3 - Danger Zone
          _buildSectionTitle('Danger Zone', color: Colors.red),
          _buildListTileContainer(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: _buildLeadingIcon(
                Icons.delete_forever,
                Colors.red.withValues(alpha: 0.1),
                Colors.red,
              ),
              title: const CustomText(
                'Wipe My Data',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
              onTap: () {
                final hasMeds = HiveService.getAllMedications().isNotEmpty;
                final hasLogs = HiveService.getAllDoseLogs().isNotEmpty;

                if (!hasMeds && !hasLogs) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const CustomText(
                        textAlign: TextAlign.center,
                        'Nothing to Wipe',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      content: const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: CustomText(
                          textAlign: TextAlign.center,
                          'Your database is currently empty. There is no medication data or dose history to wipe.',
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const CustomText(
                            'OK',
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                _showCustomCupertinoDialog(
                  context: context,
                  title: 'Are you sure?',
                  content:
                      'This will permanently delete all your medication data from this device and the cloud.',
                  cancelText: 'Cancel',
                  actionText: 'Wipe Data',
                  loadingActionText: 'Wiping...',
                  actionColor: Colors.red,
                  onAction: (dialogContext) async {
                    try {
                      final supabase = Supabase.instance.client;
                      // Step A (Cloud Wipe)
                      final userId = supabase.auth.currentUser?.id;
                      if (userId != null) {
                        await supabase
                            .from('medications')
                            .delete()
                            .eq('user_id', userId);
                      }

                      // Step B (Local Wipe)
                      await HiveService.clearAll();

                      // Step C (Identity Wipe)
                      await supabase.auth.signOut();

                      // Step D (Navigation Reset)
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      debugPrint('Wipe Error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: CustomText(
                              'Failed to wipe data. Please check your connection and try again.',
                              color: Colors.white,
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          // Footer
          const Center(
            child: CustomText(
              'DoseTrack v1.0.0',
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 48),
          // TextButton(
          //   onPressed: () {
          //     // Forces a fatal crash
          //     FirebaseCrashlytics.instance.crash();
          //   },
          //   child: const Text("Test Fatal Crash"),
          // ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: CustomText(
        title,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  Widget _buildListTileContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(
          top: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(color: Colors.white, child: child),
    );
  }

  Widget _buildLeadingIcon(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor),
    );
  }

  void _showCustomCupertinoDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String cancelText,
    required String actionText,
    String? loadingActionText,
    required Color actionColor,
    required Future<void> Function(BuildContext dialogContext) onAction,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CupertinoAlertDialog(
              title: CustomText(
                textAlign: TextAlign.center,
                title,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: CustomText(
                  textAlign: TextAlign.center,
                  content,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: CustomText(
                    cancelText,
                    fontSize: 14,
                    color: isLoading
                        ? AppColors.textHint
                        : AppColors.textSecondary,
                  ),
                ),
                CupertinoDialogAction(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (loadingActionText != null) {
                            setStateDialog(() => isLoading = true);
                          }

                          await onAction(context);

                          if (loadingActionText != null && context.mounted) {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: (isLoading && loadingActionText != null)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CustomText(
                              loadingActionText,
                              fontSize: 14,
                              color: actionColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        )
                      : CustomText(
                          actionText,
                          fontSize: 14,
                          color: actionColor,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
