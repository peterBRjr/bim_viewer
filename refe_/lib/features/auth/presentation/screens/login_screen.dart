import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/auth_controller.dart';

/// Tela comercial de Autenticação e Cadastro Local com identidade visual
/// inspirada em Engenharia Estrutural, Perfiis Metálicos em Aço e Maquetes Digitais BIM.
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
  final TextEditingController _roleController = TextEditingController(
    text: 'Engenharia Estrutural & Aço',
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _roleController.dispose();
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
        role: _roleController.text.trim(),
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
        final isTabletOrWide = size.width >= 680;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // 1. Painel Superior Metálico / Blueprint de Engenharia Estrutural & Aço
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: math.max(320, size.height * 0.44),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A), // Slate 900
                        Color(0xFF1E293B), // Steel Slate 800
                        Color(0xFF1D4ED8), // Structural Royal Blue
                      ],
                      stops: [0.0, 0.62, 1.0],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _SteelStructureBlueprintPainter(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0F172A).withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Conteúdo Principal Responsivo
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletOrWide ? 36 : 20,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildEngineeringHeader(),
                          const SizedBox(height: 22),
                          _buildAuthCard(),
                          const SizedBox(height: 18),
                          _buildTechnicalFooter(),
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

  Widget _buildEngineeringHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge Metálico de Engenharia e Aço
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.precision_manufacturing_rounded,
                size: 14,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'ENGENHARIA ESTRUTURAL & AÇO • OPENBIM 3D',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE2E8F0),
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                color: Colors.white,
                size: 26,
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
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Inspeção de Estruturas Metálicas, Concreto e Projetos IFC em Alta Precisão',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFCBD5E1),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seletor Segmentado: Entrar | Criar Conta
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeTabButton(
                    label: 'Acessar Conta',
                    icon: Icons.login_rounded,
                    isSelected: !_isRegisterMode,
                    onTap: () => _toggleMode(false),
                  ),
                ),
                Expanded(
                  child: _buildModeTabButton(
                    label: 'Cadastrar',
                    icon: Icons.person_add_alt_1_rounded,
                    isSelected: _isRegisterMode,
                    onTap: () => _toggleMode(true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Título Contextual
          Text(
            _isRegisterMode
                ? 'Cadastro de Credencial Técnica'
                : 'Acesso ao Ambiente de Engenharia',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isRegisterMode
                ? 'Registro local instantâneo estruturado para sincronização futura.'
                : 'Entre com suas credenciais para acessar o catálogo e a maquete 3D.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),

          if (_isRegisterMode) ...[
            _buildInputField(
              key: const ValueKey('register_name_field'),
              controller: _displayNameController,
              label: 'Nome do Profissional / Engenheiro',
              hint: 'Ex: Eng. Pedro',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              key: const ValueKey('register_role_field'),
              controller: _roleController,
              label: 'Especialidade / Setor',
              hint: 'Ex: Estruturas Metálicas & BIM',
              icon: Icons.engineering_outlined,
            ),
            const SizedBox(height: 14),
          ],

          _buildInputField(
            key: const ValueKey('login_username_field'),
            controller: _usernameController,
            label: 'Login de Acesso',
            hint: 'Digite seu login (ex: pedro)',
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
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botão Primário em Azul Royal & Aço
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('login_submit_button'),
              onPressed: isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRegisterMode
                              ? Icons.verified_user_rounded
                              : Icons.arrow_forward_rounded,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRegisterMode
                              ? 'Concluir Cadastro e Entrar'
                              : 'Entrar na Plataforma 3D',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          if (!_isRegisterMode) ...[
            const SizedBox(height: 16),
            // Atalho inteligente para credencial padrão de homologação (pedro / 1234)
            InkWell(
              key: const ValueKey('quick_fill_credentials_button'),
              onTap: _fillDefaultCredentials,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        size: 15,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credencial Oficial de Engenharia',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Login: pedro  •  Senha: 1234 (Toque para preencher)',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
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
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
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
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF475569)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        _buildFooterSpecPill(Icons.speed_rounded, 'iOS Metal 60 FPS'),
        _buildFooterSpecPill(Icons.layers_outlined, 'IFC2x3 & IFC4'),
        _buildFooterSpecPill(Icons.storage_rounded, 'Local DB • Supabase Ready'),
      ],
    );
  }

  Widget _buildFooterSpecPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha uma malha técnica de engenharia e treliça metálica espacial em tons
/// de cinza aço (#334155) e azul ciano técnico (#38BDF8) no cabeçalho da tela de login.
class _SteelStructureBlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minorGridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final majorGridPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.13)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      final isMajor = (x / step).round() % 4 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorGridPaint : minorGridPaint,
      );
    }
    for (double y = 0; y < size.height; y += step) {
      final isMajor = (y / step).round() % 4 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorGridPaint : minorGridPaint,
      );
    }

    // Desenho de treliça espacial de aço (Steel Truss) no canto superior direito
    final beamPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final bracingPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final startX = size.width * 0.45;
    final endX = size.width + 20;
    const topY = 28.0;
    const bottomY = 108.0;
    const bays = 5;
    final bayWidth = (endX - startX) / bays;

    // Banzos superior e inferior da treliça metálica
    canvas.drawLine(Offset(startX, topY), Offset(endX, topY), beamPaint);
    canvas.drawLine(Offset(startX, bottomY), Offset(endX, bottomY), beamPaint);

    // Montantes e diagonais (treliça Pratt/Warren de aço)
    for (int i = 0; i <= bays; i++) {
      final x = startX + i * bayWidth;
      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), beamPaint);
      canvas.drawCircle(Offset(x, topY), 3.0, nodePaint);
      canvas.drawCircle(Offset(x, bottomY), 3.0, nodePaint);

      if (i < bays) {
        final nextX = startX + (i + 1) * bayWidth;
        canvas.drawLine(Offset(x, topY), Offset(nextX, bottomY), bracingPaint);
        canvas.drawLine(Offset(x, bottomY), Offset(nextX, topY), bracingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
