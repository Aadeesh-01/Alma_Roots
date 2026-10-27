import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Circular avatar that shows the photo when available, otherwise initials
/// on a brand tint picked from the name (never a blank or black circle).
class AppAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final bool ring;

  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.ring = false,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static Color colorFor(String name) {
    final hash = name.trim().toLowerCase().codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return AppColors.avatarPalette[hash % AppColors.avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final tint = colorFor(name);
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.85), tint],
        ),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.78,
          letterSpacing: 0.5,
        ),
      ),
    );

    final avatar = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );

    if (!ring) return avatar;

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: avatar,
    );
  }
}
