import 'package:dose_tracker/core/constants/app_colors.dart';
import 'package:dose_tracker/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

/// Centralized snackbar utility.
///
/// Why a utility class instead of a widget?
/// → SnackBars are *shown* imperatively via ScaffoldMessenger, not built
///   declaratively. A static helper keeps the API clean and one-liner.
///   Change the style here, and every snackbar in the app updates.
class AppSnackBar {
  AppSnackBar._(); // Prevent instantiation

  static const Duration _defaultDuration = Duration(seconds: 3);

  // ── Simple info snackbar ────────────────────────────────────────────

  /// Shows a standard info snackbar with a [message].
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: _defaultDuration,
        //behavior: SnackBarBehavior.floating,
        //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       // margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: CustomText(message, color: Colors.white),
      ),
    );
  }

  // ── Error snackbar ──────────────────────────────────────────────────

  /// Shows a red error snackbar with a [message].
  static void showError(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: _defaultDuration,
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: CustomText(message, color: Colors.white),
      ),
    );
  }

  // ── Undo snackbar ───────────────────────────────────────────────────

  /// Shows a snackbar with an UNDO action button.
  ///
  /// The snackbar auto-dismisses after [duration]. If the user taps UNDO,
  /// [onUndo] fires and the snackbar closes immediately.
  static void showWithUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = _defaultDuration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final snackBar = SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: CustomText(message, color: Colors.white),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: AppColors.accent,
        onPressed: onUndo,
      ),
    );

    final controller = messenger.showSnackBar(snackBar);

    // Safety net: force-close after the duration in case the framework
    // doesn't auto-dismiss (rare edge case on some Android skins).
    Future.delayed(duration, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }
}
