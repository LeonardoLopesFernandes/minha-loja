import 'package:flutter/material.dart';
import '../core/session_manager.dart';
import 'log_helper.dart';

class SessionExpiredHandler {
  static void handleSessionExpired(BuildContext context) {
    try {
      LogHelper.d("SessionExpiredHandler: Redirecionando para login...");
      final sessionManager = SessionManager.instance;
      sessionManager?.clearToken();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      LogHelper.d("SessionExpiredHandler: Redirecionamento concluído");
    } catch (e) {
      LogHelper.e("SessionExpiredHandler: Erro ao redirecionar", e);
    }
  }
}
