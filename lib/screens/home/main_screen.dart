import 'package:flutter/material.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/screens/etiquetas/etiquetas_fragment.dart';
import 'package:minhaloja/screens/papeletas/papeletas_fragment.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _menuOpen = false;
  int _currentBody = 0; // 0 = Etiquetas, 1 = Papeletas

  final SessionManager _session = SessionManager.instance!;

  // Título exibido no header após selecionar uma seção (null = mostra logo)
  String? _sectionTitle;
  String? _sectionIcon;

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _selecionarCorpo(int index, String titulo, String icon) {
    setState(() {
      _currentBody = index;
      _sectionTitle = titulo;
      _sectionIcon = icon;
      _menuOpen = false;
    });
  }

  void _onMenuItem(int index) {
    switch (index) {
      case 0:
        _selecionarCorpo(0, 'ETIQUETA AVULSA', 'assets/icons/eti_avulsa.png');
        break;
      case 1:
        _selecionarCorpo(1, 'PAPELETA AVULSA', 'assets/icons/pap_avulsa.png');
        break;
      case 2:
        setState(() => _menuOpen = false);
        Navigator.pushNamed(context, '/etiquetas');
        break;
      case 3:
        setState(() => _menuOpen = false);
        Navigator.pushNamed(context, '/papeletas_diarias');
        break;
    }
  }

  void _confirmarSaida() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
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
        LogHelper.d('Main: logout efetuado');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_menuOpen) {
      setState(() => _menuOpen = false);
      return false;
    }
    bool sair = false;
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
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
    ).then((v) => sair = v == true);
    if (sair) {
      _session.clearAll();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
    return false;
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 20, right: 20),
      child: Row(
        children: [
          // Hamburger
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: 45,
              height: 45,
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _menuOpen ? '✕' : '☰',
                style: const TextStyle(
                  color: Color(0xFFD81B3A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _sectionTitle == null
                ? Image.asset('assets/icons/icon_header.png',
                    height: 36, fit: BoxFit.contain)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(_sectionIcon!,
                          height: 24,
                          color: const Color(0xFFD81B3A),
                          fit: BoxFit.contain),
                      const SizedBox(width: 6),
                      Text(_sectionTitle!,
                          style: const TextStyle(
                            color: Color(0xFFD81B3A),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
          ),
          // Avatar
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              width: 45,
              height: 45,
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 22, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Image.asset(icon,
                width: 24, height: 24, fit: BoxFit.contain, color: Colors.white),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(_menuOpen ? 0 : -300, 0, 0),
      width: 280,
      margin: const EdgeInsets.only(top: 62, left: 4),
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFE5093A),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/logo_menu.png',
                  width: 40, height: 40, fit: BoxFit.contain),
              const SizedBox(width: 8),
              const Text(
                'minha loja',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _menuItem('assets/icons/eti_avulsa.png', 'ETIQUETA AVULSA',
              () => _onMenuItem(0)),
          _divider(),
          _menuItem('assets/icons/pap_avulsa.png', 'PAPELETA AVULSA',
              () => _onMenuItem(1)),
          _divider(),
          _menuItem('assets/icons/ic_etiqueta.png', 'ETIQUETAS DIÁRIAS',
              () => _onMenuItem(2)),
          _divider(),
          _menuItem('assets/icons/ic_papeletas.png', 'PAPELETAS DIÁRIAS',
              () => _onMenuItem(3)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 0.5,
        color: Colors.white.withOpacity(0.15),
      );

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! > 0 && !_menuOpen) {
              setState(() => _menuOpen = true);
            } else if (details.primaryVelocity! < 0 && _menuOpen) {
              setState(() => _menuOpen = false);
            }
          },
          child: Stack(
            children: [
              Column(
                children: [
                  SafeArea(
                    top: true,
                    child: _buildHeader(),
                  ),
                  Expanded(
                    child: _currentBody == 0
                        ? const EtiquetasFragment()
                        : const PapeletasFragment(),
                  ),
                ],
              ),
              if (_menuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(color: const Color(0x33000000)),
                  ),
                ),
              if (_menuOpen) Positioned(top: 0, left: 0, child: _buildMenu()),
            ],
          ),
        ),
      ),
    );
  }
}
