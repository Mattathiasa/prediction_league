import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A circular user avatar that falls back to the initial of [displayName].
///
/// Replaces four near-identical private implementations that differed only in
/// radius and font size, and whose fallback behaviour had already drifted apart.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 18,
  });

  final String photoUrl;
  final String displayName;
  final double radius;

  /// Initials scale with the circle so one widget covers every size in use.
  double get _fontSize => radius * 0.78;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      child: photoUrl.isEmpty
          ? _initial()
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initial(),
              ),
            ),
    );
  }

  Widget _initial() => Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      );
}
