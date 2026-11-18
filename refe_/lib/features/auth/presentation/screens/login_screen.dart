import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/auth_controller.dart';

/// Tela de Login e Cadastro Local com design clean, comercial e sóbrio
/// em tons de cinza aço (#0F172A / #334155), azul (#2563EB) e branco (#FFFFFF).
class LoginScreen extends StatefulWidget {
  final AuthController controller;

  const LoginScreen({
    super.key,
    required this.controller,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode(bool registerMode) {
    if (_isRegisterMode == registerMode) return;
    HapticFeedback.selectionClick();
    widget.controller.clearError();
    setState(() {
      _isRegisterMode = registerMode;
    });
  }

  void _fillDefaultCredentials() {
    HapticFeedback.selectionClick();
    widget.controller.clearError();
    setState(() {
      _isRegisterMode = false;
      _usernameController.text = 'pedro';
      _passwordController.text = '1234';
    });
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Informe o login e a senha para prosseguir.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isRegisterMode) {
      await widget.controller.register(
        username: username,
        password: password,
        displayName: _displayNameController.text.trim(),
      );
    } else {
      await widget.controller.login(username, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // 1. Painel Superior em Cinza Aço & Azul com Malha Estrutural Discreta
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: math.max(280, size.height * 0.40),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF1D4ED8),
                      ],
                      stops: [0.0, 0.68, 1.0],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _SteelStructureBlueprintPainter(),
                  ),
                ),
              ),

              // 2. Conteúdo Centralizado Clean
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCleanHeader(),
                          const SizedBox(height: 24),
                          _buildAuthCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCleanHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.view_in_ar_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visualizador BIM',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Engenharia Estrutural & Modelos 3D',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    final errorMsg = widget.controller.errorMessage;
    final isLoading = widget.controller.isLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle Clean: Entrar | Criar Conta
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeTabButton(
                    label: 'Entrar',
                    isSelected: !_isRegisterMode,
                    onTap: () => _toggleMode(false),
                  ),
                ),
                Expanded(
                  child: _buildModeTabButton(
                    label: 'Criar Conta',
                    isSelected: _isRegisterMode,
                    onTap: () => _toggleMode(true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_isRegisterMode) ...[
            _buildInputField(
              key: const ValueKey('register_name_field'),
              controller: _displayNameController,
              label: 'Nome',
              hint: 'Seu nome',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
          ],

          _buildInputField(
            key: const ValueKey('login_username_field'),
            controller: _usernameController,
            label: 'Login',
            hint: 'Digite seu login',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          _buildInputField(
            key: const ValueKey('login_password_field'),
            controller: _passwordController,
            label: 'Senha',
            hint: 'Digite sua senha',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: AppColors.textMuted,
              ),
            ),
          ),

          if (errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMsg,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.destructive,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('login_submit_button'),
              onPressed: isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isRegisterMode ? 'Cadastrar e Entrar' : 'Entrar',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          if (!_isRegisterMode) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                key: const ValueKey('quick_fill_credentials_button'),
                onPressed: _fillDefaultCredentials,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Acesso padrão: pedro • 1234',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: (_) => widget.controller.clearError(),
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF64748B)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Desenha linhas técnicas sutis de estrutura metálica em aço no cabeçalho.
class _SteelStructureBlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final trussPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final startX = size.width * 0.52;
    final endX = size.width + 16;
    const topY = 24.0;
    const bottomY = 92.0;
    const bays = 4;
    final bayWidth = (endX - startX) / bays;

    canvas.drawLine(Offset(startX, topY), Offset(endX, topY), trussPaint);
    canvas.drawLine(Offset(startX, bottomY), Offset(endX, bottomY), trussPaint);

    for (int i = 0; i <= bays; i++) {
      final x = startX + i * bayWidth;
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), trussPaint);
      if (i < bays) {
        final nextX = startX + (i + 1) * bayWidth;
        canvas.drawLine(Offset(x, topY), Offset(nextX, bottomY), trussPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
