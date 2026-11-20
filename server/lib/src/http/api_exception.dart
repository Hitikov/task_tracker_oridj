/// An error that is safe to expose to API clients.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message, {this.details});

  /// HTTP status code to send.
  final int statusCode;

  /// Machine-readable snake_case error code.
  final String code;

  /// Human-readable message safe for clients.
  final String message;

  /// Optional structured context included in the error envelope.
  final Object? details;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
