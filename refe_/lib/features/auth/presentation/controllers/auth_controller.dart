import 'package:flutter/foundation.dart';
import '../../data/services/auth_local_service.dart';
import '../../domain/models/user_account_model.dart';

/// Controller reativo de autenticação e controle do Guia Interativo de Boas-Vindas.
class AuthController extends ChangeNotifier {
  final AuthLocalService _authService;

  UserAccountModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showOnboardingTour = false;
  int _onboardingStep = 0;
  bool _dontShowAgain = true;

  AuthController({
    AuthLocalService? authService,
    bool initialAuthenticated = false,
  }) : _authService = authService ?? AuthLocalService() {
    if (initialAuthenticated) {
      _currentUser = UserAccountModel(
        id: 'usr-master-pedro',
        username: 'pedro',
        password: '1234',
        displayName: 'Pedro',
        role: 'Engenharia Estrutural & Aço • BIM',
        createdAt: DateTime(2026, 1, 1),
      );
    }
  }

  UserAccountModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showOnboardingTour => _showOnboardingTour;
  int get onboardingStep => _onboardingStep;
  bool get dontShowAgain => _dontShowAgain;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Realiza login no banco local (padrão: `pedro` / `1234`) e aciona o Guia Interativo se o usuário ainda não optou por ocultá-lo.
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _authService.authenticate(username, password);
      if (account == null) {
        _errorMessage = 'Credenciais inválidas. Verifique seu login e senha.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = account;
      final completed = await _authService.hasCompletedTutorial(account.username);
      _dontShowAgain = completed ? true : true;
      _onboardingStep = 0;
      _showOnboardingTour = !completed;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cadastra uma nova conta local e autentica imediatamente exibindo o Guia Interativo.
  Future<bool> register({
    required String username,
    required String password,
    required String displayName,
    String role = 'Engenharia Estrutural & Aço • BIM',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await _authService.registerAccount(
        username: username,
        password: password,
        displayName: displayName,
        role: role,
      );
      _currentUser = account;
      _dontShowAgain = true;
      _onboardingStep = 0;
      _showOnboardingTour = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void nextOnboardingStep(int totalSteps) {
    if (_onboardingStep + 1 < totalSteps) {
      _onboardingStep++;
      notifyListeners();
    } else {
      completeOnboardingTour();
    }
  }

  void previousOnboardingStep() {
    if (_onboardingStep > 0) {
      _onboardingStep--;
      notifyListeners();
    }
  }

  Future<void> setDontShowAgain(bool value) async {
    _dontShowAgain = value;
    notifyListeners();
    if (_currentUser != null) {
      await _authService.setTutorialCompleted(
        _currentUser!.username,
        completed: value,
      );
    }
  }

  Future<void> completeOnboardingTour({bool? dontShowAgain}) async {
    if (dontShowAgain != null) {
      _dontShowAgain = dontShowAgain;
    }
    _showOnboardingTour = false;
    _onboardingStep = 0;
    notifyListeners();
    if (_currentUser != null) {
      await _authService.setTutorialCompleted(
        _currentUser!.username,
        completed: _dontShowAgain,
      );
    }
  }

  Future<void> startOnboardingTour() async {
    if (_currentUser != null) {
      _dontShowAgain = await _authService.hasCompletedTutorial(_currentUser!.username);
    }
    _onboardingStep = 0;
    _showOnboardingTour = true;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _showOnboardingTour = false;
    _onboardingStep = 0;
    _dontShowAgain = false;
    _errorMessage = null;
    notifyListeners();
  }
}
