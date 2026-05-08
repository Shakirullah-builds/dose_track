import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CustomEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const CustomEmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  }); 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              //Icons.medication_outlined,
              size: 80,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              // 'No medications yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
             // 'Tap the + button to add your first medication',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}