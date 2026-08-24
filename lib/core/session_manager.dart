import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyBearerToken = "BEARER_TOKEN";
  static const String _keyTokenExpiry = "TOKEN_EXPIRY";
  static const String _keyUserEmail = "USER_EMAIL";
  static const String _keyUserName = "USER_NAME";
  static const String _keyUserStore = "USER_STORE";
  static const String _keyRememberLogin = "REMEMBER_LOGIN";
  static const String _keyMsPassword = "MS_PASSWORD";
  static const int tokenExpiryDays = 14;

  static SessionManager? _instance;
  static SharedPreferences? _prefs;

  static Future<SessionManager> getInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    _instance ??= SessionManager._();
    return _instance!;
  }

  SessionManager._();

  void saveToken(String token) {
    final expiry =
        DateTime.now().millisecondsSinceEpoch + (tokenExpiryDays * 24 * 60 * 60 * 1000);
    _prefs!.setString(_keyBearerToken, token);
    _prefs!.setInt(_keyTokenExpiry, expiry);
    _prefs!.setBool(_keyRememberLogin, true);
  }

  String? getToken() {
    final token = _prefs!.getString(_keyBearerToken);
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired()) {
      clearToken();
      return null;
    }
    return token;
  }

  bool isLoggedIn() {
    final remember = _prefs!.getBool(_keyRememberLogin) ?? false;
    final token = getToken();
    return remember && token != null && token.isNotEmpty;
  }

  bool isTokenExpired() {
    final expiry = _prefs!.getInt(_keyTokenExpiry) ?? 0;
    if (expiry == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiry;
  }

  void clearToken() {
    _prefs!.remove(_keyBearerToken);
    _prefs!.remove(_keyTokenExpiry);
    _prefs!.putBool(_keyRememberLogin, false);
  }

  void saveUserInfo(String email, String name, String store) {
    _prefs!.setString(_keyUserEmail, email);
    _prefs!.setString(_keyUserName, name);
    _prefs!.setString(_keyUserStore, store);
  }

  String? getUserEmail() => _prefs!.getString(_keyUserEmail);
  String? getUserName() => _prefs!.getString(_keyUserName);
  String getUserStore() => _prefs!.getString(_keyUserStore) ?? "L291";

  void saveCredentials(String email, String password) {
    _prefs!.setString(_keyUserEmail, email);
    _prefs!.setString(_keyMsPassword, password);
  }

  String? getSavedPassword() => _prefs!.getString(_keyMsPassword);

  bool hasSavedCredentials() {
    final email = getUserEmail();
    final senha = getSavedPassword();
    return email != null &&
        email.isNotEmpty &&
        senha != null &&
        senha.isNotEmpty;
  }

  void clearCredentials() {
    _prefs!.remove(_keyMsPassword);
  }

  void clearAll() {
    _prefs!.clear();
  }
}
