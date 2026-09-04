import 'package:flutter/material.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/utils/log_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SessionManager _session = SessionManager.instance!;

  String get _nome => _session.getUserName() ?? 'Usuário';
  String get _email => _session.getUserEmail() ?? 'email@exemplo.com';
  String get _loja => _session.getUserStore();

  void _confirmarSaida() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        _session.clearAll();
        LogHelper.d('Profile: logout efetuado');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFDA1C2E);
    const textSecondary = Color(0xFF5F6368);
    const textPrimary = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: brandRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 18),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Avatar
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: brandRed, size: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Card de informações
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Nome
                          Text(
                            _nome,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: brandRed,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, color: brandRed, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _email,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Loja
                          Row(
                            children: [
                              const Icon(Icons.store_outlined, color: brandRed, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Loja $_loja',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Divisor
                          Container(
                            height: 1,
                            color: const Color(0xFFE9EAEE),
                          ),
                        ],
                      ),
                    ),

                    // Espaço
                    const Spacer(),

                    // Botão Sair
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _confirmarSaida,
                              borderRadius: BorderRadius.circular(14),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, color: Colors.white, size: 18),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sair da conta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
}
