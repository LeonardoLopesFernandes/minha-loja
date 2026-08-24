import 'dart:async';
import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginWebViewScreen extends StatefulWidget {
  static const String EXTRA_AUTO_LOGIN = 'extra_auto_login';
  static const String EXTRA_EMAIL = 'extra_email';
  static const String EXTRA_SENHA = 'extra_senha';
  static const String EXTRA_SILENCIOSO = 'extra_silencioso';

  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _controller;
  bool _argsRead = false;
  bool _autoLogin = false;
  bool _silencioso = false;
  String _email = '';
  String _senha = '';
  bool _reveal = false;
  bool _saved = false;
  Timer? _injectTimer;
  Timer? _timeoutTimer;

  final SessionManager _session = SessionManager.instance!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      _argsRead = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _autoLogin = args?[LoginWebViewScreen.EXTRA_AUTO_LOGIN] ?? false;
      _email = args?[LoginWebViewScreen.EXTRA_EMAIL] ?? '';
      _senha = args?[LoginWebViewScreen.EXTRA_SENHA] ?? '';
      _silencioso = args?[LoginWebViewScreen.EXTRA_SILENCIOSO] ?? false;
      _reveal = !_silencioso;

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) => _onPageFinished(url),
          ),
        )
        ..loadRequest(Uri.parse(MicrosoftOAuthConfig.loginUrl));

      if (_silencioso) {
        _timeoutTimer = Timer(const Duration(seconds: 60), () {
          if (mounted) setState(() => _reveal = true);
        });
      }

      if (_autoLogin) {
        _injectTimer =
            Timer.periodic(const Duration(milliseconds: 1200), (_) {
          if (!_saved) _injectCredentials();
        });
      }
    }
  }

  String _montarScriptPreenchimento() {
    final email = _email.replaceAll("'", "\\'");
    final senha = _senha.replaceAll("'", "\\'");
    return """
      (function(){
        try {
          var e = document.getElementById('i0116');
          var p = document.getElementById('i0118');
          if (e) { e.value = '$email'; }
          if (p) { p.value = '$senha'; }
          var btn = document.getElementById('idSIButton9');
          if (btn) { btn.click(); }
        } catch(err) {}
      })();
    """;
  }

  Future<void> _injectCredentials() async {
    try {
      await _controller.runJavaScript(_montarScriptPreenchimento());
    } catch (e) {
      LogHelper.e('LoginWebView: erro ao injetar credenciais', e);
    }
  }

  bool _urlPossuiToken(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final t = uri.queryParameters['newToken'] ?? uri.queryParameters['token'];
    return t != null && t.length > 50;
  }

  Future<String?> _extrairToken(String url) async {
    if (_urlPossuiToken(url)) {
      final uri = Uri.parse(url);
      return uri.queryParameters['newToken'] ?? uri.queryParameters['token'];
    }

    try {
      final cookies = await WebViewCookieManager().getCookies(
          domain: Uri.parse('https://minhaloja.americanas.io'));
      for (final c in cookies) {
        if ((c.name == 'newToken' || c.name == 'token') &&
            (c.value?.length ?? 0) > 50) {
          return c.value;
        }
      }
    } catch (e) {
      LogHelper.e('LoginWebView: erro ao ler cookies', e);
    }

    try {
      final result = await _controller.runJavaScriptReturningResult(
        "(()=>{try{return (localStorage.getItem('newToken')||localStorage.getItem('token')||'');}catch(e){return '';}})()",
      );
      if (result is String) {
        final clean = result.replaceAll('"', '').trim();
        if (clean.isNotEmpty && clean.length > 50) return clean;
      }
    } catch (e) {
      LogHelper.e('LoginWebView: erro ao ler localStorage', e);
    }

    return null;
  }

  Future<void> _onPageFinished(String url) async {
    LogHelper.d('LoginWebView: page finished $url');
    final token = await _extrairToken(url);
    if (token != null && token.length > 50) {
      _salvarToken(token);
      return;
    }
    if (_autoLogin) {
      await _injectCredentials();
    }
  }

  void _salvarToken(String token) {
    if (_saved) return;
    _saved = true;
    _injectTimer?.cancel();
    _timeoutTimer?.cancel();
    _session.saveToken(token);
    _session.saveUserInfo(
      'leonardo.lfernandes@americanas.io',
      'Leonardo Lopes Fernandes',
      'L291',
    );
    if (mounted) {
      ToastUtils.showSuccess(context, 'Login realizado com sucesso');
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Widget _buildPulsingLogo() {
    return Container(
      color: const Color(0xFFD81B3A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.85, end: 1.1),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Image.asset(
                'assets/icons/logo_a_branco.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Carregando credenciais...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _silencioso
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Entrar', style: TextStyle(color: Colors.white)),
            ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_reveal)
            Positioned.fill(
              child: _buildPulsingLogo(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _injectTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}
