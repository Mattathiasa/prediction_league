import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A square increment/decrement button used by the score steppers.
///
/// Replaces two private copies that had drifted apart: the admin sheet's
/// version had no disabled state at all, so at the 0–20 bounds the button kept
/// looking tappable while doing nothing.
class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.semanticLabel,
  });

  final IconData icon;

  /// Null renders the disabled appearance and ignores taps.
  final VoidCallback? onPressed;

  final double size;
  final String? semanticLabel;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _enabled
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _enabled
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.white12,
            ),
          ),
          child: Icon(
            icon,
            size: size * 0.47,
            color: _enabled ? AppColors.accent : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}
