import 'package:flutter/material.dart';

class AppColors {
  // App Primary
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF534BAE);
  static const Color primaryDark = Color(0xFF000051);
  static const Color accent = Color(0xFFFF6D00);
  static const Color adminPrimary = Color(0xFF0F172A);

  // Admin Warm Palette (Kutbi Brand-Aligned - Legacy)
  static const Color adminRed        = Color(0xFFC8391B);
  static const Color adminRedDark    = Color(0xFF8B1A0D);
  static const Color adminRedLight   = Color(0xFFFDF1EE);
  static const Color adminGold       = Color(0xFFC9952A);
  static const Color adminGoldLight  = Color(0xFFFFF8E7);
  static const Color adminSand       = Color(0xFFF7F0E8);
  static const Color adminWarmCard   = Color(0xFFFFFDF9);
  static const Color adminWarmBorder = Color(0xFFECE4D8);
  static const Color adminNavy       = Color(0xFF0F1F35);

  // Admin SaaS Professional Palette (Stripe/Linear Inspired)
  static const Color adminBg         = Color(0xFFFFF1E0);
  static const Color adminCardBg     = Color(0xFFFFFFFF);
  static const Color adminBorder     = Color(0xFFE2E8F0);
  static const Color adminAccent     = Color(0xFF635BFF);
  static const Color adminAccentLight= Color(0xFFEEECFF);
  static const Color textSlate       = Color(0xFF0F172A);
  static const Color textSlateLight  = Color(0xFF64748B);


  // Backgrounds
  static const Color scaffoldBg = Color(0xFFA8E6CF);
  static const Color cardBg = Colors.white;
  static const Color darkBg = Color(0xFF1E1E2C);
  static const Color darkCard = Color(0xFF2A2A3C);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Brand Colors
  static const Color asianPaintsPrimary = Color(0xFF0D47A1);
  static const Color asianPaintsSecondary = Color(0xFFE53935);
  static const Color asianPaintsGradientStart = Color(0xFF1565C0);
  static const Color asianPaintsGradientEnd = Color(0xFF0D47A1);

  static const Color bergerPrimary = Color(0xFFF9A825);
  static const Color bergerSecondary = Color(0xFF2E7D32);
  static const Color bergerGradientStart = Color(0xFFFBC02D);
  static const Color bergerGradientEnd = Color(0xFFF9A825);

  static const Color birlaOpusPrimary = Color(0xFF00695C);
  static const Color birlaOpusSecondary = Color(0xFF26A69A);
  static const Color birlaOpusGradientStart = Color(0xFF00897B);
  static const Color birlaOpusGradientEnd = Color(0xFF00695C);

  // Tools Brand Colors
  static const Color toolsPrimary = Color(0xFF9C5522);
  static const Color toolsSecondary = Color(0xFFBF6D28);
  static const Color toolsGradientStart = Color(0xFFBF6D28);
  static const Color toolsGradientEnd = Color(0xFF9C5522);

  // Tier Colors
  static const Color goldTier = Color(0xFFFFD700);
  static const Color silverTier = Color(0xFFC0C0C0);

  // ── Futuristic Design System ──────────────────────────────────

  // Skeuomorphic Background
  static const Color futuristicBgStart = Color(0xFFE8ECF4);
  static const Color futuristicBgMid = Color(0xFFF0F2F8);
  static const Color futuristicBgEnd = Color(0xFFF8F6F2);
  static const Color lightSource = Color(0x18FFFFFF);

  // Claymorphism
  static const Color clayBase = Color(0xFFF0EDE8);
  static const Color clayLightShadow = Color(0xFFFFFFFF);
  static const Color clayDarkShadow = Color(0xFFD1CCC4);
  static const Color clayPastelBlue = Color(0xFFE8EEF8);
  static const Color clayPastelPink = Color(0xFFF8E8F0);
  static const Color clayPastelAmber = Color(0xFFF8F0E0);
  static const Color clayPastelGreen = Color(0xFFE0F4EE);
  static const Color clayPastelPurple = Color(0xFFEDE8F8);

  // Glassmorphism
  static const Color glassWhite = Color(0x26FFFFFF);     // 15%
  static const Color glassBorder = Color(0x33FFFFFF);     // 20%
  static const Color glassInnerGlow = Color(0x1AFFFFFF);  // 10%

  // Liquid Glass Navbar
  static const Color navGlassBg = Color(0x1AFFFFFF);     // 10%
  static const Color navGlowBlue = Color(0xFF4F8CFF);
  static const Color navGlowPink = Color(0xFFFF6BB5);
  static const Color navGlowAmber = Color(0xFFFFBE45);
  static const Color navGlowGreen = Color(0xFF4FD1A5);

  // Brand Glass Tints
  static const Color asianPaintsGlassTint = Color(0x1A1565C0);
  static const Color bergerGlassTint = Color(0x1AFBC02D);
  static const Color birlaOpusGlassTint = Color(0x1A00897B);
  static const Color toolsGlassTint = Color(0x1ABF6D28);

  // Get brand colors
  static Color getBrandPrimary(String brand) {
    switch (brand.toLowerCase()) {
      case 'asian paints':
        return asianPaintsPrimary;
      case 'berger':
        return bergerPrimary;
      case 'birla opus':
        return birlaOpusPrimary;
      case 'tools':
        return toolsPrimary;
      default:
        return primary;
    }
  }

  static List<Color> getBrandGradient(String brand) {
    switch (brand.toLowerCase()) {
      case 'asian paints':
        return [asianPaintsGradientStart, asianPaintsGradientEnd];
      case 'berger':
        return [bergerGradientStart, bergerGradientEnd];
      case 'birla opus':
        return [birlaOpusGradientStart, birlaOpusGradientEnd];
      case 'tools':
        return [toolsGradientStart, toolsGradientEnd];
      default:
        return [primaryLight, primary];
    }
  }
}
