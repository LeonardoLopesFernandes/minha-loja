import 'package:flutter/material.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/screens/login/login_webview_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _mostrarSenha = false;
  bool _salvarCredenciais = false;
  bool _showForm = false;
  bool _reconectando = false;

  final SessionManager _session = SessionManager._instance!;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _controller.forward();

    if (_session.isLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      });
      return;
    }

    _emailController.text = _session.getUserEmail() ?? '';
    _salvarCredenciais = _session.hasSavedCredentials();

    if (_session.hasSavedCredentials()) {
      _senhaController.text = _session.getSavedPassword() ?? '';
      _iniciarReconexaoSilenciosa();
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showForm = true);
      });
    }
  }

  void _iniciarReconexaoSilenciosa() {
    setState(() {
      _reconectando = true;
      _showForm = false;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _abrirWebView(autoLogin: true, silencioso: true);
    });
  }

  void _abrirWebView({required bool autoLogin, bool silencioso = false}) {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (_salvarCredenciais) {
      _session.saveCredentials(email, senha);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(arguments: {
          LoginWebViewScreen.EXTRA_AUTO_LOGIN: autoLogin,
          LoginWebViewScreen.EXTRA_EMAIL: email,
          LoginWebViewScreen.EXTRA_SENHA: senha,
          LoginWebViewScreen.EXTRA_SILENCIOSO: silencioso,
        }),
        builder: (_) => const LoginWebViewScreen(),
      ),
    );
  }

  void _entrar() {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha e-mail e senha.'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _abrirWebView(autoLogin: true);
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Text(
              'ML',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 24),
                if (_reconectando)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Sessão expirada. Reconectando automaticamente...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.gray900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (_showForm)
                  AnimatedOpacity(
                    opacity: _showForm ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: _buildForm(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Minha Loja',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: const Icon(Icons.email, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senhaController,
              obscureText: !_mostrarSenha,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.gray900,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarSenha = !_mostrarSenha),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () =>
                  setState(() => _salvarCredenciais = !_salvarCredenciais),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _salvarCredenciais
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Salvar credenciais',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _entrar,
              child: const Text(
                'ENTRAR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}
