import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// High-fidelity iOS-style spring bounce tap.
///
/// Why an explicit AnimationController instead of AnimatedScale?
/// → AnimatedScale uses an implicit animation that can't have different
///   forward/reverse durations or curves. With an explicit controller we get:
///   - Fast press-down (100ms, easeOut) — instant visual feedback
///   - Slow spring-back (320ms, overshoot curve) — the "juicy" bounce
///   - HapticFeedback.lightImpact() on release for physical feel
class BounceTap extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BounceTap({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  ConsumerState<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends ConsumerState<BounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _scale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: const Cubic(0.34, 1.56, 0.64, 1),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
