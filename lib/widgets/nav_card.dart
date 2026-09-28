import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A tappable card that navigates to a destination screen.
///
/// The home screen previously held six of these as separate widget classes
/// spanning ~270 lines, identical apart from an icon, a colour, two strings and
/// a route. They are now one widget driven by a list.
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  /// Builds the destination screen. A builder rather than a widget so the
  /// destination is not constructed until the card is actually tapped.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: builder),
        ),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
