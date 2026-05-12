import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:dose_tracker/core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

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
          fontSize: 18,
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
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
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
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const CustomText(
                      textAlign: TextAlign.center,
                      'External Link',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    content: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: CustomText(
                        textAlign: TextAlign.center,
                        'You are leaving the app to view our Privacy Policy in a secure browser. Continue?',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const CustomText(
                          'Cancel',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      CupertinoDialogAction(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            final uri = Uri.parse(
                              'https://docs.google.com/document/d/e/2PACX-1vS4aYvV4WILUamUkcJRdMoqRjoNugAAHcexCH8HCDH5YYwkjNBF1vYBrUc4UX_oPNaWtC9JhLmXSI0J/pub',
                            );
                            await launchUrl(uri);
                          } catch (e) {
                            debugPrint('Error launching URL: $e');
                          }
                        },
                        child: const CustomText(
                          'Open Browser',
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
              //trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const CustomText(
                      'Are you sure?',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    content: const CustomText(
                      'This will permanently delete all your medication data from this device and the cloud.',
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const CustomText(
                          'Cancel',
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement Supabase wipe and sign out
                          Navigator.of(context).pop();
                        },
                        child: const CustomText(
                          'Wipe Data',
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
      child: Material(
        color: Colors.white,
        child: child,
      ),
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
}
