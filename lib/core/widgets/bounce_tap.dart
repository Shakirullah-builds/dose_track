import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _BounceTapState extends ConsumerState<BounceTap> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _scale = 0.95);
      },
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
