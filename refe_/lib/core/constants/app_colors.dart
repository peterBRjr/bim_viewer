import 'package:flutter/material.dart';

/// Paleta de cores semântica do aplicativo Visualizador BIM.
/// Baseada nos padrões técnicos estabelecidos na arquitetura do projeto.
abstract final class AppColors {
  /// Primary (#0F172A - Slate Dark): Usado em AppBars, títulos principais e superfícies contrastantes.
  static const Color primary = Color(0xFF0F172A);

  /// Accent (#2563EB - Royal Blue): Cor de ação principal, botões de destaque e FAB.
  static const Color accent = Color(0xFF2563EB);

  /// Background (#F8FAFC - Técnico Neutro): Fundo geral das telas da aplicação.
  static const Color background = Color(0xFFF8FAFC);

  /// Surface (#FFFFFF - Branco): Superfície de cards, modais e containers.
  static const Color surface = Color(0xFFFFFFFF);

  /// Destructive (#EF4444 - Vermelho Alerta): Ações de exclusão e mensagens de erro crítico.
  static const Color destructive = Color(0xFFEF4444);

  /// TextMuted (#64748B - Grafite Neutro): Textos secundários, legendas e metadados.
  static const Color textMuted = Color(0xFF64748B);

  /// TextDark (#0F172A): Cor principal para legibilidade máxima do texto sobre superfícies claras.
  static const Color textDark = Color(0xFF0F172A);

  /// Border (#E2E8F0): Linhas divisórias e contornos sutis de cards e inputs.
  static const Color border = Color(0xFFE2E8F0);

  /// AccentHover (#1D4ED8): Estado hover/pressionado para botões primários.
  static const Color accentHover = Color(0xFF1D4ED8);

  /// Success (#10B981): Indicador de sucesso (ex: importação concluída).
  static const Color success = Color(0xFF10B981);
}
