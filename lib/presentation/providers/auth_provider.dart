import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/repositories/local_auth_repository.dart';
import '../../services/log_service.dart';
import 'product_provider.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final String? username;
  final int? userId;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.username,
    this.userId,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    String? username,
    int? userId,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error: error,
        username: username ?? this.username,
        userId: userId ?? this.userId,
      );
}

class RememberedCredentials {
  final String username;
  final String password;

  const RememberedCredentials({
    required this.username,
    required this.password,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const _sessionKey = 'local_session_token';
  static const _rememberedUsernameKey = 'remembered_username';
  static const _rememberedPasswordKey = 'remembered_password';
  final FlutterSecureStorage _secureStorage;
  final LocalAuthRepository _repository;
  String? _sessionToken;

  AuthNotifier(this._secureStorage, this._repository)
      : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _secureStorage.read(key: _sessionKey);
      if (token != null) {
        final session = await _repository.resumeSession(token);
        if (session != null) {
          _sessionToken = token;
          state = AuthState(
            isLoggedIn: true,
            isInitialized: true,
            username: session.username,
            userId: session.userId,
          );
          return;
        }
        await _secureStorage.delete(key: _sessionKey);
      }
    } catch (error, stack) {
      await LogService.error('بازیابی session محلی ناموفق بود', error, stack);
    }
    state = state.copyWith(isInitialized: true);
  }

  Future<bool> hasStoredToken() async =>
      await _secureStorage.read(key: _sessionKey) != null;

  Future<RememberedCredentials?> loadRememberedCredentials() async {
    try {
      final username = await _secureStorage.read(key: _rememberedUsernameKey);
      final password = await _secureStorage.read(key: _rememberedPasswordKey);
      if (username == null || username.isEmpty || password == null) return null;
      return RememberedCredentials(username: username, password: password);
    } catch (error, stack) {
      await LogService.error(
          'بازیابی اطلاعات ورود ذخیره‌شده ناموفق بود', error, stack);
      return null;
    }
  }

  Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberedUsernameKey);
    await _secureStorage.delete(key: _rememberedPasswordKey);
  }

  Future<void> _saveRememberedCredentials(
      String username, String password) async {
    await _secureStorage.write(
        key: _rememberedUsernameKey, value: username.trim());
    await _secureStorage.write(key: _rememberedPasswordKey, value: password);
  }

  Future<bool> login(String username, String password,
      {bool remember = true}) async {
    if (username.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'نام کاربری و رمز عبور الزامی است',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _repository.authenticate(username, password);
      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'نام کاربری یا رمز عبور اشتباه است',
        );
        return false;
      }
      _sessionToken = session.token;
      if (remember) {
        await _secureStorage.write(key: _sessionKey, value: session.token);
        await _saveRememberedCredentials(session.username, password);
      } else {
        await _secureStorage.delete(key: _sessionKey);
        await clearRememberedCredentials();
      }
      state = AuthState(
        isLoggedIn: true,
        isInitialized: true,
        username: session.username,
        userId: session.userId,
      );
      return true;
    } catch (error, stack) {
      await LogService.error('ورود محلی ناموفق بود', error, stack);
      state = state.copyWith(isLoading: false, error: 'خطا در ورود محلی');
      return false;
    }
  }

  Future<bool> loginWithBiometric() async {
    final token = await _secureStorage.read(key: _sessionKey);
    if (token == null) return false;
    final session = await _repository.resumeSession(token);
    if (session == null) return false;
    _sessionToken = token;
    state = AuthState(
      isLoggedIn: true,
      isInitialized: true,
      username: session.username,
      userId: session.userId,
    );
    return true;
  }

  Future<void> changeCredentials({
    required String username,
    required String currentPassword,
    String? newPassword,
  }) async {
    final id = state.userId;
    if (id == null) throw const AuthException('کاربر وارد نشده است');
    await _repository.changeCredentials(
      userId: id,
      username: username,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    final remembered = await loadRememberedCredentials();
    if (remembered != null) {
      await _saveRememberedCredentials(
        username,
        newPassword != null && newPassword.isNotEmpty
            ? newPassword
            : currentPassword,
      );
    }
    state = state.copyWith(username: username.trim());
  }

  Future<void> logout() async {
    final token = _sessionToken ?? await _secureStorage.read(key: _sessionKey);
    if (token != null) await _repository.revokeSession(token);
    await _secureStorage.delete(key: _sessionKey);
    _sessionToken = null;
    state = const AuthState(isInitialized: true);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final localAuthRepositoryProvider = Provider<LocalAuthRepository>(
  (ref) => LocalAuthRepository(ref.watch(databaseProvider)),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(secureStorageProvider),
    ref.watch(localAuthRepositoryProvider),
  );
});
