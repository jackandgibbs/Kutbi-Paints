import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Circular user avatar that shows the profile selfie when available and
/// falls back to the first letter of the name. Used across painter and admin
/// screens so a painter's photo appears everywhere consistently.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 44,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary.withValues(alpha: 0.12);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: _hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initial(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _initial(),
            )
          : _initial(),
    );
  }

  Widget _initial() {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: GoogleFonts.poppins(
          fontSize: fontSize ?? size * 0.4,
          fontWeight: FontWeight.w700,
          color: foregroundColor ?? AppColors.primary,
        ),
      ),
    );
  }
}
