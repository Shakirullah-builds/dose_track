import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/app_shell.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/constants/app_colors.dart';

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
        backgroundColor: AppColors.scaffoldBg,
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
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Preferences
          _buildSectionHeader('PREFERENCES', isFirst: true),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_rounded,
                iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                iconColor: AppColors.primary,
                title: 'Enable Notifications',
                subtitle: 'Medication reminders and alerts',
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
                      // Revert Hive first (no context needed)
                      final box = await Hive.openBox('settings');
                      await box.put('notifications_enabled', previousValue);

                      // Now check mounted once, with no await between
                      // the check and the context usage
                      if (context.mounted) {
                        setState(() {
                          _notificationsEnabled = previousValue;
                        });
                        TopToast.showError(
                          context,
                          'Failed to sync settings with the cloud.',
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),

          // Section 2: Support & Legal
          _buildSectionHeader('SUPPORT & LEGAL', isFirst: false),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.mail_rounded,
                iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                iconColor: AppColors.primary,
                title: 'Send Feedback',
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  final uri = Uri.parse(
                    'mailto:omotososakiru25@gmail.com?subject=DoseVault Feedback',
                  );
                  try {
                    await launchUrl(uri);
                  } catch (e) {
                    debugPrint('Error launching URL: $e');
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                iconColor: AppColors.primary,
                title: 'Privacy Policy',
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
                          'https://doc-hosting.flycricket.io/dosevault-privacy-policy/c8c8b110-b272-45fa-b7a0-46878c10ed1b/privacy',
                        );
                        await launchUrl(uri);
                      } catch (e) {
                        debugPrint('Error launching URL: $e');
                      }
                    },
                  );
                },
              ),
            ],
          ),

          // Section 3: Danger Zone
          _buildSectionHeader('DANGER ZONE', isFirst: false),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconBgColor: Colors.red.withValues(alpha: 0.1),
                iconColor: Colors.red,
                title: 'Wipe My Data',
                titleColor: Colors.red,
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
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
                          TopToast.showError(
                            context,
                            'Failed to wipe data. Please check your connection and try again.',
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),

          // Footer
          const Padding(
            padding: EdgeInsets.only(top: 32.0),
            child: Center(
              child: CustomText(
                'Version 1.0.0',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool isFirst}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16, top: isFirst ? 0 : 24),
      child: CustomText(
        title,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      list.add(children[i]);
      if (i < children.length - 1) {
        list.add(
          const Divider(height: 1, color: AppColors.divider, indent: 64),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: list),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  title,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppColors.textPrimary,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  CustomText(
                    subtitle!,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      tile = InkWell(onTap: onTap, child: tile);
    }

    return tile;
  }
}
