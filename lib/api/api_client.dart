import 'dart:async';
import 'dart:io' as io show HttpHeaders;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_error.dart';

/// Единая точка выхода в REST API.
///
/// - Базовый URL: `--dart-define=API_BASE_URL`,
///   по умолчанию `http://localhost:8080`.
/// - Перехватчик прикладывает `Authorization: Bearer <токен>`; токен читается
///   через [getToken] (например, из хранилища сессии).
/// - Ошибки разбираются в [ApiException] по конверту OpenAPI.
/// - Логирование — только метод, путь и статус: ни токены, ни пароли,
///   ни тела ответов.
class ApiClient {
  ApiClient({Dio? dio, this.getToken, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ??
                    String.fromEnvironment('API_BASE_URL',
                        defaultValue: 'http://localhost:8080'),
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                receiveDataWhenStatusError: true,
              ),
            ) {
    _dio.interceptors.add(_BearerInterceptor(getToken));
    _dio.interceptors.add(_SanitizedLogger());
  }

  final Dio _dio;

  /// Текущий токен или null.
  final FutureOr<String?> Function()? getToken;

  /// Возвращает объект по схеме `User`/`Project` (мапим в репозитории).
  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw e.asApiException();
    }
  }

  /// Возвращает массив объектов по схеме `Project[]` и других массивов.
  Future<List<Map<String, dynamic>>> getList(String path) async {
    try {
      // Тип generic — `List<dynamic>`: JSON-массив десериализуется в список
      // `dynamic`, поэтому явно приводим элементы к картам.
      final response = await _dio.get<List<dynamic>>(path);
      final data = response.data;
      if (data == null) {
        return const <Map<String, dynamic>>[];
      }
      return [for (final entry in data) entry as Map<String, dynamic>];
    } on DioException catch (e) {
      throw e.asApiException();
    }
  }

  /// Создаёт/обновляет объект.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw e.asApiException();
    }
  }

  /// Частичное обновление объекта.
  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: body,
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw e.asApiException();
    }
  }

  /// Удаление объекта.
  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(path);
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw e.asApiException();
    }
  }

  // --- Задачи (этап 2) -------------------------------------------------

  /// `GET /api/v1/projects/{projectId}/tasks` с опциональными query-фильтрами.
  Future<List<Map<String, dynamic>>> getProjectTasks(
    String projectId, {
    Map<String, String>? query,
  }) {
    return getList(_withQuery('/api/v1/projects/$projectId/tasks', query));
  }

  /// `POST /api/v1/projects/{projectId}/tasks`.
  Future<Map<String, dynamic>> createProjectTask(
    String projectId, {
    required Map<String, dynamic> body,
  }) {
    return post('/api/v1/projects/$projectId/tasks', body: body);
  }

  /// `GET /api/v1/tasks/{id}`.
  Future<Map<String, dynamic>> getTask(String id) => get('/api/v1/tasks/$id');

  /// `PATCH /api/v1/tasks/{id}`.
  Future<Map<String, dynamic>> patchTask(
    String id, {
    required Map<String, dynamic> body,
  }) {
    return patch('/api/v1/tasks/$id', body: body);
  }

  /// `DELETE /api/v1/tasks/{id}`.
  Future<Map<String, dynamic>> deleteTask(String id) =>
      delete('/api/v1/tasks/$id');

  /// `GET /api/v1/projects/{projectId}/task-types`.
  Future<List<Map<String, dynamic>>> getProjectTaskTypes(String projectId) =>
      getList('/api/v1/projects/$projectId/task-types');

  /// `GET /api/v1/projects/{projectId}/statuses`.
  Future<List<Map<String, dynamic>>> getProjectStatuses(String projectId) =>
      getList('/api/v1/projects/$projectId/statuses');

  /// `GET /api/v1/projects/{projectId}/members`.
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) =>
      getList('/api/v1/projects/$projectId/members');

  /// `GET /api/v1/projects/{projectId}/board`.
  ///
  /// Возвращает колонки доски: `[{status: Status, tasks: Task[]}]`.
  Future<List<Map<String, dynamic>>> getBoard(String projectId) =>
      getList('/api/v1/projects/$projectId/board');

  /// `PATCH /api/v1/tasks/{taskId}/status`.
  ///
  /// Меняет статус задачи; тело запроса: `{statusId}`.
  Future<Map<String, dynamic>> updateTaskStatus(
    String taskId,
    String statusId,
  ) {
    return patch('/api/v1/tasks/$taskId/status', body: {'statusId': statusId});
  }

  /// Добавляет query-параметры к пути (пустые значения игнорируются).
  String _withQuery(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final entries =
        query.entries.where((e) => e.value.isNotEmpty).toList(growable: false);
    if (entries.isEmpty) return path;
    final uri = Uri(path: path, queryParameters: {
      for (final entry in entries) entry.key: entry.value,
    });
    return uri.toString();
  }
}

/// Перехватчик, прикладывающий `Authorization: Bearer <токен>`.
class _BearerInterceptor implements Interceptor {
  const _BearerInterceptor(this._getToken);

  final FutureOr<String?> Function()? _getToken;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _getToken?.call();
    if (token != null && token.isNotEmpty) {
      options.headers[io.HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) =>
      handler.next(response);

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) =>
      handler.next(error);
}

/// Логгер без чувствительных данных.
class _SanitizedLogger implements Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    debugPrint('[ApiClient] → ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[ApiClient] ← ${response.statusCode} '
      '${response.requestOptions.uri.path}',
    );
    handler.next(response);
  }

  @override
  void onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    final status = error.response?.statusCode;
    debugPrint(
      '[ApiClient] ✗ ${error.requestOptions.uri.path}'
      '${status != null ? ' → $status' : ''}',
    );
    handler.next(error);
  }
}
