import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../utils/log_helper.dart';

class TokenInfo {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  TokenInfo({required this.accessToken, this.refreshToken, this.expiresIn = 0});
}

class DeviceCodeInfo {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;
  final String mensagem;
  DeviceCodeInfo(
      {required this.deviceCode,
      required this.userCode,
      required this.verificationUri,
      required this.interval,
      required this.expiresIn,
      this.mensagem = ""});
}

class MicrosoftOAuth {
  static final Dio _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  static String? ultimoErro;
  static String? ultimoCodigoDispositivo;

  static String getAuthorizeUrl({String state = "mloja"}) {
    return "${MicrosoftOAuthConfig.authorizeUrl}?"
        "client_id=${MicrosoftOAuthConfig.clientId}"
        "&response_type=code"
        "&redirect_uri=${Uri.encodeComponent(MicrosoftOAuthConfig.redirectUri)}"
        "&scope=${Uri.encodeComponent(MicrosoftOAuthConfig.scopes)}"
        "&response_mode=query"
        "&state=$state"
        "&nonce=mloja$state";
  }

  static bool isRedirectUrl(String url) =>
      url.startsWith(MicrosoftOAuthConfig.redirectUri);

  static String? extrairCodigo(String url) {
    final match = RegExp(r"[?&]code=([^&]+)").firstMatch(url);
    return match?.group(1);
  }

  static String? extrairErro(String url) {
    final match = RegExp(r"[?&]error=([^&]+)").firstMatch(url);
    return match?.group(1);
  }

  static Future<TokenInfo?> trocarCodigoPorToken(String accessCode) async {
    return _postToken({
      'client_id': MicrosoftOAuthConfig.clientId,
      'client_secret': MicrosoftOAuthConfig.clientSecret,
      'grant_type': 'authorization_code',
      'code': accessCode,
      'redirect_uri': MicrosoftOAuthConfig.redirectUri,
      'scope': MicrosoftOAuthConfig.scopes,
    });
  }

  static Future<TokenInfo?> renovarToken(String refreshToken) async {
    return _postToken({
      'client_id': MicrosoftOAuthConfig.clientId,
      'client_secret': MicrosoftOAuthConfig.clientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': MicrosoftOAuthConfig.scopes,
      'redirect_uri': MicrosoftOAuthConfig.redirectUri,
    });
  }

  static Future<TokenInfo?> loginComCredenciais(
      String email, String senha) async {
    return _postToken({
      'client_id': MicrosoftOAuthConfig.clientId,
      'client_secret': MicrosoftOAuthConfig.clientSecret,
      'grant_type': 'password',
      'username': email,
      'password': senha,
      'scope': MicrosoftOAuthConfig.scopes,
    });
  }

  static Future<DeviceCodeInfo?> iniciarFluxoDispositivo() async {
    try {
      final resp = await _http.post(MicrosoftOAuthConfig.deviceCodeUrl,
          data: FormData.fromMap(
              {'client_id': MicrosoftOAuthConfig.clientId, 'scope': MicrosoftOAuthConfig.scopes}));
      final body = resp.data is String
          ? jsonDecode(resp.data)
          : resp.data;
      if (resp.statusCode != 200) {
        ultimoErro = _extrairDescricaoErro(body);
        LogHelper.e("OAuth: devicecode ${resp.statusCode} body=$body");
        return null;
      }
      final deviceCode = body['device_code'] ?? '';
      final userCode = body['user_code'] ?? '';
      if (deviceCode.isEmpty || userCode.isEmpty) {
        ultimoErro = _extrairDescricaoErro(body) ?? 'resposta sem device_code';
        return null;
      }
      ultimoErro = null;
      return DeviceCodeInfo(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri:
            body['verification_uri'] ?? 'https://microsoft.com/devicelogin',
        interval: body['interval'] ?? 5,
        expiresIn: body['expires_in'] ?? 0,
        mensagem: body['message'] ?? '',
      );
    } catch (e) {
      ultimoErro = e.toString();
      LogHelper.e("OAuth: exceção em iniciarFluxoDispositivo", e);
      return null;
    }
  }

  static Future<TokenInfo?> verificarAutorizacaoDispositivo(
      String deviceCode) async {
    try {
      final resp = await _http.post(MicrosoftOAuthConfig.tokenUrl,
          data: FormData.fromMap({
            'client_id': MicrosoftOAuthConfig.clientId,
            'client_secret': MicrosoftOAuthConfig.clientSecret,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'device_code': deviceCode,
          }));
      final body = resp.data is String ? jsonDecode(resp.data) : resp.data;
      if (resp.statusCode != 200) {
        ultimoCodigoDispositivo = body['error'];
        ultimoErro = _extrairDescricaoErro(body);
        return null;
      }
      final access = body['access_token'] ?? '';
      if (access.isEmpty) {
        ultimoCodigoDispositivo = body['error'];
        ultimoErro = _extrairDescricaoErro(body) ?? 'sem access_token';
        return null;
      }
      ultimoErro = null;
      ultimoCodigoDispositivo = null;
      return TokenInfo(
        accessToken: access,
        refreshToken:
            body['refresh_token'] != null ? body['refresh_token'] : null,
        expiresIn: body['expires_in'] ?? 0,
      );
    } catch (e) {
      ultimoErro = e.toString();
      LogHelper.e("OAuth: exceção em verificarAutorizacaoDispositivo", e);
      return null;
    }
  }

  static Future<String?> validarSessao(String accessToken) async {
    try {
      final resp = await _http.post(MicrosoftOAuthConfig.validarUrl,
          data: {'accessToken': accessToken, 'token': accessToken});
      final body =
          resp.data is String ? jsonDecode(resp.data) : resp.data;
      if (resp.statusCode != 200) {
        ultimoErro = _extrairDescricaoErro(body) ?? 'HTTP ${resp.statusCode}';
        LogHelper.e("OAuth: validarSessao ${resp.statusCode} body=$body");
        return null;
      }
      final parsed = body is Map ? body : null;
      String? sessionToken;
      if (parsed != null) {
        sessionToken = parsed['newToken'] ??
            parsed['session_token'] ??
            parsed['sessionToken'] ??
            parsed['token'];
      }
      if (sessionToken == null || sessionToken.isEmpty) {
        if (body is String && body.isNotEmpty && !body.startsWith('{')) {
          sessionToken = body.trim();
        }
      }
      if (sessionToken == null || sessionToken.isEmpty) {
        ultimoErro = 'resposta sem token de sessão';
        LogHelper.e("OAuth: validarSessao sem token body=$body");
        return null;
      }
      ultimoErro = null;
      return sessionToken;
    } catch (e) {
      ultimoErro = e.toString();
      LogHelper.e("OAuth: exceção em validarSessao", e);
      return null;
    }
  }

  static Future<TokenInfo?> _postToken(Map<String, String> fields) async {
    try {
      final resp = await _http.post(MicrosoftOAuthConfig.tokenUrl,
          data: FormData.fromMap(fields));
      final body =
          resp.data is String ? jsonDecode(resp.data) : resp.data;
      if (resp.statusCode != 200) {
        ultimoErro = _extrairDescricaoErro(body) ?? 'HTTP ${resp.statusCode}';
        return null;
      }
      final access = body['access_token'] ?? '';
      if (access.isEmpty) {
        ultimoErro = _extrairDescricaoErro(body) ?? 'sem access_token';
        return null;
      }
      ultimoErro = null;
      return TokenInfo(
        accessToken: access,
        refreshToken:
            body['refresh_token'] != null ? body['refresh_token'] : null,
        expiresIn: body['expires_in'] ?? 0,
      );
    } catch (e) {
      ultimoErro = e.toString();
      return null;
    }
  }

  static String? _extrairDescricaoErro(dynamic body) {
    if (body is Map && body['error_description'] != null) {
      return body['error_description'].toString();
    }
    return null;
  }
}
