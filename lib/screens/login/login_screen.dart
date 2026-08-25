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

  final SessionManager _session = SessionManager.instance!;

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
        child: Image.asset(
          'assets/icons/minha_loja_logo.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, 0.75),
                child: Transform.scale(
                  scale: 6.0,
                  child: const Text(
                    'a',
                    style: TextStyle(
                      fontSize: 320,
                      color: Color(0xFFBDBDBD),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 4),
                    const Text(
                      'minha loja',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Para ter acesso ao portal, vamos manter os fluxos de '
                        'autenticação segura.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_reconectando)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sessão expirada. Reconectando automaticamente...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
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
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    );
    return Card(
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'E-mail',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Microsoft',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Senha',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _senhaController,
                obscureText: !_mostrarSenha,
                decoration: InputDecoration(
                  hintText: 'Senha',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarSenha
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppColors.gray900,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _entrar,
                child: const Text(
                  'ENTRAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () =>
                  setState(() => _salvarCredenciais = !_salvarCredenciais),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _salvarCredenciais,
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      onChanged: (v) =>
                          setState(() => _salvarCredenciais = v ?? false),
                    ),
                    const Text(
                      'Salvar credenciais e ativar login automático',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
