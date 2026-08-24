import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFD7193F);
  static const Color primaryDark = Color(0xFFB0172F);
  static const Color accent = Color(0xFF4CAF50);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray900 = Color(0xFF212121);

  static const Color btnGreen = Color(0xFF4CAF50);
  static const Color cardBorder = Color(0xFFCCCCCC);

  static const Color red = Color(0xFFD7193F);
  static const Color green = Color(0xFF4CAF50);
  static const Color darkRed = Color(0xFFB0172F);
}

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    color: AppColors.gray900,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.gray900,
  );
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.gray100,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        useMaterial3: true,
      );
}
