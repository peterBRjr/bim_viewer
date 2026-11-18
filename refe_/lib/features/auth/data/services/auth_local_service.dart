import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/user_account_model.dart';

/// Banco de dados local de usuários e sessão, estruturado como repositório desacoplado
/// pronto para futura migração transparente para o Supabase Auth.
class AuthLocalService {
  static const String _dbFileName = 'auth_local_db.json';
  final Uuid _uuid;

  // Fallback em memória para execução instantânea e determinística em testes ou ambientes sem disco
  final List<UserAccountModel> _memoryUsers = [
    UserAccountModel(
      id: 'usr-master-pedro',
      username: 'pedro',
      password: '1234',
      displayName: 'Pedro',
      role: 'Engenharia Estrutural & Aço • BIM',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
  final Set<String> _completedTutorialUsers = {};
  bool _loadedFromDisk = false;

  AuthLocalService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<File?> _getDbFile() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final dir = await getApplicationDocumentsDirectory().timeout(
        const Duration(milliseconds: 400),
      );
      return File(p.join(dir.path, _dbFileName));
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loadedFromDisk) return;
    _loadedFromDisk = true;

    try {
      final file = await _getDbFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            final usersList = decoded['users'];
            if (usersList is List) {
              for (final item in usersList.whereType<Map<String, dynamic>>()) {
                final acc = UserAccountModel.fromMap(item);
                if (acc.username.isNotEmpty &&
                    !_memoryUsers.any((u) => u.username.toLowerCase() == acc.username.toLowerCase())) {
                  _memoryUsers.add(acc);
                }
              }
            }
            final onboarded = decoded['completedTutorialUsers'];
            if (onboarded is List) {
              for (final u in onboarded.whereType<String>()) {
                _completedTutorialUsers.add(u.toLowerCase());
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistToDisk() async {
    try {
      final file = await _getDbFile();
      if (file == null) return;
      final payload = {
        'users': _memoryUsers.map((u) => u.toMap()).toList(),
        'completedTutorialUsers': _completedTutorialUsers.toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {}
  }

  /// Valida credenciais no banco local (conta mestre padrão: login `pedro`, senha `1234`).
  Future<UserAccountModel?> authenticate(String username, String password) async {
    await _ensureLoaded();
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    for (final acc in _memoryUsers) {
      if (acc.username.toLowerCase() == cleanUser && acc.password == cleanPass) {
        return acc;
      }
    }
    return null;
  }

  /// Registra um novo usuário no banco de dados local.
  Future<UserAccountModel> registerAccount({
    required String username,
    required String password,
    required String displayName,
    String role = 'Engenharia Estrutural & BIM',
  }) async {
    await _ensureLoaded();
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();
    final cleanName = displayName.trim().isEmpty ? username.trim() : displayName.trim();

    if (cleanUser.isEmpty || cleanPass.isEmpty) {
      throw Exception('Preencha o login e a senha para concluir o cadastro.');
    }

    final exists = _memoryUsers.any((u) => u.username.toLowerCase() == cleanUser);
    if (exists) {
      throw Exception('O login "$cleanUser" já está cadastrado no sistema.');
    }

    final newAccount = UserAccountModel(
      id: _uuid.v4(),
      username: cleanUser,
      password: cleanPass,
      displayName: cleanName,
      role: role.trim().isEmpty ? 'Engenharia Estrutural & BIM' : role.trim(),
      createdAt: DateTime.now(),
    );

    _memoryUsers.add(newAccount);
    await _persistToDisk();
    return newAccount;
  }

  Future<bool> hasCompletedTutorial(String username) async {
    await _ensureLoaded();
    return _completedTutorialUsers.contains(username.trim().toLowerCase());
  }

  Future<void> setTutorialCompleted(String username, {bool completed = true}) async {
    await _ensureLoaded();
    final key = username.trim().toLowerCase();
    if (completed) {
      _completedTutorialUsers.add(key);
    } else {
      _completedTutorialUsers.remove(key);
    }
    await _persistToDisk();
  }
}
