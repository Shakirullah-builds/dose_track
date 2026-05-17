import 'dart:async';

import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

/// Premium top toast notification using Flutter's native Overlay API.
///
/// Why Overlay instead of ScaffoldMessenger?
/// → ScaffoldMessenger pins the SnackBar to the *bottom* of the Scaffold,
///   making it fight with bottom nav bars and FABs. An Overlay entry can be
///   positioned anywhere — we put it at the top with a slide-in animation
///   for a modern, iOS-like feel.
///
/// Three variants mirror the old AppSnackBar API for a zero-friction migration:
///   • TopToast.show()         — info (dark premium grey)
///   • TopToast.showError()    — error (soft red)
///   • TopToast.showWithUndo() — info + UNDO action button
class TopToast {
  TopToast._(); // Prevent instantiation

  /// Currently visible entry — tracked so we can dismiss it if a new
  /// toast fires before the old one has auto-dismissed.
  static OverlayEntry? _currentEntry;

  // ── Info toast ──────────────────────────────────────────────────────

  static void show(BuildContext context, String message) {
    _dismiss();
    final entry = OverlayEntry(
      builder: (_) => _TopToastWidget(
        message: message,
        isError: false,
        onDismiss: _dismiss,
      ),
    );
    _currentEntry = entry;
    Overlay.of(context).insert(entry);
  }

  // ── Error toast ─────────────────────────────────────────────────────

  static void showError(BuildContext context, String message) {
    _dismiss();
    final entry = OverlayEntry(
      builder: (_) => _TopToastWidget(
        message: message,
        isError: true,
        onDismiss: _dismiss,
      ),
    );
    _currentEntry = entry;
    Overlay.of(context).insert(entry);
  }

  // ── Undo toast ──────────────────────────────────────────────────────

  static void showWithUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismiss();
    final entry = OverlayEntry(
      builder: (_) => _TopToastWidget(
        message: message,
        isError: false,
        onDismiss: _dismiss,
        undoLabel: 'UNDO',
        onUndo: onUndo,
        duration: duration,
      ),
    );
    _currentEntry = entry;
    Overlay.of(context).insert(entry);
  }

  // ── Internal ────────────────────────────────────────────────────────

  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ANIMATED TOAST WIDGET (private to this file)
// ═══════════════════════════════════════════════════════════════════════

class _TopToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final Duration duration;

  const _TopToastWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.undoLabel,
    this.onUndo,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    // Slide in
    _controller.forward();

    // Auto-dismiss after duration
    _autoCloseTimer = Timer(widget.duration, _startDismiss);

    // When reverse completes, remove the overlay entry
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onDismiss();
      }
    });
  }

  void _startDismiss() {
    if (mounted) _controller.reverse();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isError
        ? const Color(0xFFE53935) // Soft red
        : const Color(0xFF2D3748); // Premium dark grey

    final glowColor = widget.isError
        ? const Color(0xFFE53935).withValues(alpha: 0.3)
        : AppColors.primary.withValues(alpha: 0.2);

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Icon(
                    widget.isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),

                  const SizedBox(width: 12),

                  // Message
                  Expanded(
                    child: CustomText(
                      widget.message,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // UNDO button (optional)
                  if (widget.undoLabel != null && widget.onUndo != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _autoCloseTimer?.cancel();
                        widget.onUndo!();
                        _startDismiss();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomText(
                          widget.undoLabel!,
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
