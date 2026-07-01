import 'package:flutter/material.dart';

class AppColors {
  // Grayscale palette
  static const Color background = Color(0xFF080808);
  static const Color cardBackground = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color mutedText = Color(0xFF555555);
  
  static const Color borderLight = Color(0xFF2C2C2E);
  static const Color borderDark = Color(0xFF1C1C1E);
  static const Color highlight = Color(0xFFE5E5EA);
  
  static const Color error = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppBorders {
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;

  static const BorderSide thinSide = BorderSide(
    color: AppColors.borderLight,
    width: 1.0,
  );

  static final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusSm),
    borderSide: thinSide,
  );

  static final OutlineInputBorder inputFocusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusSm),
    borderSide: const BorderSide(
      color: AppColors.primaryText,
      width: 1.5,
    ),
  );

  static final OutlineInputBorder inputErrorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusSm),
    borderSide: const BorderSide(
      color: AppColors.error,
      width: 1.0,
    ),
  );
}
