import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Configuração do tema global do aplicativo com base no Design System.
/// Estabelece cantos arredondados de 12px, tipografia técnica e contraste semântico.
abstract final class AppTheme {
  /// Raio de borda padrão da aplicação (12px)
  static const double borderRadiusValue = 12.0;
  static final BorderRadius borderRadius = BorderRadius.circular(borderRadiusValue);

  /// Tema claro principal da aplicação
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        secondary: AppColors.accent,
        onSecondary: AppColors.surface,
        surface: AppColors.surface,
        onSurface: AppColors.textDark,
        error: AppColors.destructive,
        onError: AppColors.surface,
      ),

      // Configuração de AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.surface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(
          color: AppColors.surface,
        ),
      ),

      // Cards com cantos arredondados padrão de 12px
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Botões de Ação Principal (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),

      // Botões Secundários (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
          textStyle: AppTypography.buttonLabel.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),

      // Botões de Texto (TextButton)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
        ),
      ),

      // Botão de Ação Flutuante (FAB)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.surface,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
      ),

      // Diálogos e Modais
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        titleTextStyle: AppTypography.cardTitle.copyWith(fontSize: 18),
        contentTextStyle: AppTypography.bodyMedium,
      ),

      // Divisores
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Hierarquia tipográfica global
      textTheme: const TextTheme(
        headlineMedium: AppTypography.dashboardTitle,
        titleMedium: AppTypography.cardTitle,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonLabel,
        labelSmall: AppTypography.badgeLabel,
      ),
    );
  }
}
