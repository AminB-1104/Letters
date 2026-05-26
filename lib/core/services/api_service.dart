// ignore_for_file: prefer_initializing_formals
// Reason: prefer_initializing_formals would force `this._storage` as the named
// parameter name, leaking the private underscore to callers. Keep the
// `storage` public name and assign via `: _storage = storage`.

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/env_keys.dart';
import '../utils/result.dart';
import 'storage_service.dart';

class ApiError {
  final int? statusCode;
  final String message;
  final Object? cause;

  const ApiError({
    this.statusCode,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'ApiError($statusCode: $message)';
}

class ApiService {
  ApiService({
    required StorageService storage,
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ?? Dio() {
    _dio.options.baseUrl = dotenv.env[EnvKeys.apiBaseUrl] ?? '';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _storage.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;
  final StorageService _storage;

  Future<Result<T, ApiError>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _request<T>(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Result<T, ApiError>> post<T>(
    String path, {
    Object? body,
  }) =>
      _request<T>(() => _dio.post<dynamic>(path, data: body));

  Future<Result<T, ApiError>> put<T>(
    String path, {
    Object? body,
  }) =>
      _request<T>(() => _dio.put<dynamic>(path, data: body));

  Future<Result<T, ApiError>> delete<T>(String path) =>
      _request<T>(() => _dio.delete<dynamic>(path));

  Future<Result<T, ApiError>> _request<T>(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      final body = response.data;
      if (body is Map<String, dynamic> && body['success'] == true) {
        return Success<T, ApiError>(body['data'] as T);
      }
      return Success<T, ApiError>(body as T);
    } on DioException catch (e) {
      return Failure<T, ApiError>(_mapDioError(e));
    } catch (e) {
      return Failure<T, ApiError>(
        ApiError(message: 'Unexpected error', cause: e),
      );
    }
  }

  ApiError _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Network error';
    if (data is Map<String, dynamic> && data['message'] is String) {
      message = data['message'] as String;
    } else if (e.message != null) {
      message = e.message!;
    }
    return ApiError(statusCode: status, message: message, cause: e);
  }
}
