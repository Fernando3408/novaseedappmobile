import 'package:dio/dio.dart';

class MobileApiClient {
  MobileApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20)));

  final Dio _dio;

  Future<Response<dynamic>> bootstrap() {
    return _dio.get('/api/mobile/v1/bootstrap');
  }

  Future<Response<dynamic>> push(List<Map<String, dynamic>> mutations) {
    return _dio.post('/api/mobile/v1/sync/push', data: {'mutations': mutations});
  }
}
