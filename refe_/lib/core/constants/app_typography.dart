import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Hierarquia tipográfica técnica para o Visualizador BIM.
/// Utiliza a fonte padrão de engenharia com métricas precisas para visualização técnica.
abstract final class AppTypography {
  /// Família tipográfica base
  static const String fontFamily = 'Roboto';

  /// dashboardTitle: 24sp, Semi-Bold (w600).
  /// Utilizado em cabeçalhos principais, títulos de painéis e seções destacadas.
  static const TextStyle dashboardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// cardTitle: 16sp, Medium (w500).
  /// Utilizado em nomes de projetos, títulos de cards e diálogos informativos.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// bodySmall: 12sp, Regular (w400).
  /// Utilizado em metadados técnicos (tamanho em MB, data de criação, formato de arquivo).
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0,
    height: 1.4,
  );

  /// bodyMedium: 14sp, Regular (w400).
  /// Utilizado em descrições, estados vazios e textos de suporte.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0,
    height: 1.45,
  );

  /// buttonLabel: 14sp, Semi-Bold (w600).
  /// Utilizado no texto de botões primários e interativos.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
    letterSpacing: 0.1,
  );

  /// badgeLabel: 11sp, Semi-Bold (w600).
  /// Utilizado em tags de formato técnico (.GLB, .gltf, .IFC).
  static const TextStyle badgeLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}
