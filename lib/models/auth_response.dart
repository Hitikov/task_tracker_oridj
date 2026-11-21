import 'user.dart';

/// Ответ `POST /api/v1/auth/register` и `POST /api/v1/auth/login`
/// (схема `AuthResponse`).
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      tokenType: json['tokenType'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Подписанный JWT.
  final String token;

  /// Схема передачи токена (`Bearer`).
  final String tokenType;

  /// Время жизни токена в секундах.
  final int expiresIn;

  /// Профиль пользователя.
  final User user;

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'expiresIn': expiresIn,
        'user': user.toJson(),
      };
}
