class LogHelper {
  static const String _tag = "MinhaLoja";

  static void d(String message) {
    // ignore: avoid_print
    print("[$_tag] $message");
  }

  static void e(String message, [Object? error]) {
    // ignore: avoid_print
    print("[$_tag] ERROR: $message ${error ?? ''}");
  }
}
