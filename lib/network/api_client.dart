import 'dart:async';
import 'package:dio/dio.dart';
import '../core/session_manager.dart';
import '../core/constants.dart';
import '../utils/log_helper.dart';

class AuthInterceptor extends Interceptor {
  final SessionManager sessionManager;
  AuthInterceptor(this.sessionManager);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = sessionManager.getToken();
    final store = sessionManager.getUserStore() ?? "L291";
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json, text/plain, */*';
    options.headers['Accept-Language'] = 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7';
    options.headers['Platform-Version'] = 'minhaloja/4.0.5';
    options.headers['User-Store'] = 'minhaloja/$store';
    super.onRequest(options, handler);
  }
}

class CookieInterceptor extends Interceptor {
  final Map<String, String> cookies;
  CookieInterceptor(this.cookies);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (cookies.isNotEmpty) {
      options.headers['Cookie'] = cookies.values.join('; ');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      for (final header in setCookie) {
        for (final part in header.split(',')) {
          final cookieString = part.split(';').first;
          final idx = cookieString.indexOf('=');
          if (idx > 0) {
            final name = cookieString.substring(0, idx).trim();
            final value = cookieString.substring(idx + 1).trim();
            cookies[name] = cookieString.trim();
          }
        }
      }
    }
    super.onResponse(response, handler);
  }
}

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  late SessionManager sessionManager;
  final Map<String, String> cookies = <String, String>{};

  late final Dio slDio;
  late final Dio minhaLojaDio;

  void init(SessionManager sm) {
    sessionManager = sm;

    slDio = Dio(BaseOptions(
      baseUrl: ApiUrls.baseUrlSl,
      connectTimeout: const Duration(seconds: 30),
      readTimeout: const Duration(seconds: 30),
      writeTimeout: const Duration(seconds: 30),
    ));
    slDio.interceptors.addAll([
      AuthInterceptor(sessionManager),
      CookieInterceptor(cookies),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => LogHelper.d(o.toString()),
      ),
    ]);

    minhaLojaDio = Dio(BaseOptions(
      baseUrl: ApiUrls.baseUrlMinhaloja,
      connectTimeout: const Duration(seconds: 30),
      readTimeout: const Duration(seconds: 30),
      writeTimeout: const Duration(seconds: 30),
    ));
    minhaLojaDio.interceptors.addAll([
      AuthInterceptor(sessionManager),
      CookieInterceptor(cookies),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => LogHelper.d(o.toString()),
      ),
    ]);
  }

  Dio getSlApiService() => slDio;
  Dio getMinhaLojaApiService() => minhaLojaDio;

  Dio getSlApiServiceWithToken(String token) {
    final d = Dio(BaseOptions(
      baseUrl: ApiUrls.baseUrlSl,
      connectTimeout: const Duration(seconds: 30),
      readTimeout: const Duration(seconds: 30),
      writeTimeout: const Duration(seconds: 30),
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
    d.interceptors.add(LogInterceptor(logPrint: (o) => LogHelper.d(o.toString())));
    return d;
  }

  void clearCookies() => cookies.clear();
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}
