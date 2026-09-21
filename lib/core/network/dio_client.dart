import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_interceptor.dart';

class DioClient {
  static Dio? _instance;

  static Future<Dio> getInstance() async {
    if (_instance != null) return _instance!;

    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(ApiConstants.baseUrlKey) ?? ApiConstants.defaultBaseUrl;

    _instance = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
      headers: {
        ApiConstants.contentType: ApiConstants.applicationJson,
      },
      responseType: ResponseType.json,
    ));

    const storage = FlutterSecureStorage();
    _instance!.interceptors.addAll([
      ApiInterceptor(dio: _instance!, secureStorage: storage),
      LogInterceptor(
        request: false,
        requestHeader: false,
        responseHeader: false,
        error: true,
        logPrint: (log) => debugPrint(log.toString()),
      ),
    ]);

    return _instance!;
  }

  /// بازنشانی وقتی URL سرور تغییر کرد
  static void reset() => _instance = null;

  // ignore: avoid_print
  static void debugPrint(String msg) => print('[DioClient] $msg');
}
