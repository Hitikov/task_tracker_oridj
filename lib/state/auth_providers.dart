import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../auth/auth_repository.dart';
import '../auth/token_store.dart';
import '../models/user.dart';

/// Хранилище токена (инъекция зависимостей).
final tokenStoreProvider = Provider<TokenStore>(
  (_) => const FlutterSecureTokenStore(),
);

/// Dio-клиент; токен читается из [tokenStoreProvider].
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getToken: () => ref.read(tokenStoreProvider).read(),
    onUnauthorized: () async {
      await ref.read(tokenStoreProvider).delete();
      ref.invalidate(authSessionProvider);
    },
  );
});

/// Репозиторий аутентификации и проектов.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.read(apiClientProvider),
    tokens: ref.read(tokenStoreProvider),
  );
});

/// Состояние сессии: `AsyncValue<User?>` — `isLoading` / `hasValue` /
/// `hasError`; значение — пользователь или null (пока не авторизован).
class AuthSession extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repository = ref.read(authRepositoryProvider);
    try {
      return await repository.currentUser();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await repository.logout();
        return null;
      }
      rethrow;
    }
  }

  /// Текущий пользователь из состояния (null, пока сессия не активна).
  User? get user => state.value;

  /// Войти по email и паролю.
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    state = AsyncValue.loading();
    try {
      final response = await repository.login(
        email: email,
        password: password,
      );
      state = AsyncValue.data(response.user);
      return response.user;
    } on Exception catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Зарегистрироваться и открыть сессию.
  Future<User?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue<User?>.loading();
    try {
      final response = await repository.register(
        email: email,
        password: password,
        name: name,
      );
      // Сервер уже выдал JWT, и репозиторий его сохранил: сессия активна
      // сразу после регистрации, повторный вход не требуется.
      state = AsyncValue<User?>.data(response.user);
      return response.user;
    } on Exception catch (e, stackTrace) {
      state = AsyncValue<User?>.error(e, stackTrace);
      rethrow;
    }
  }

  /// Выйти: токен удаляется, сессия — null.
  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    state = AsyncValue.loading();
    await repository.logout();
    state = AsyncValue.data(null);
  }
}

final authSessionProvider = AsyncNotifierProvider<AuthSession, User?>(
  AuthSession.new,
);
