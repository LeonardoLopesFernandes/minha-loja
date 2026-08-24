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

  final List<_MenuItem> _menuItems = const [
    _MenuItem('ETIQUETAS', Icons.label),
    _MenuItem('PAPELETAS', Icons.description),
    _MenuItem('ETIQUETA AVULSA', Icons.label),
    _MenuItem('PAPELETA DIÁRIA', Icons.description),
    _MenuItem('PERFIL', Icons.person),
    _MenuItem('SAIR', Icons.exit_to_app),
  ];

  String get _titulo =>
      _currentBody == 0 ? 'ETIQUETA AVULSA' : 'PAPELETA AVULSA';

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _selecionarCorpo(int index) {
    setState(() {
      _currentBody = index;
      _menuOpen = false;
    });
  }

  void _onMenuItem(int index) {
    final label = _menuItems[index].label;
    switch (label) {
      case 'ETIQUETAS':
        _selecionarCorpo(0);
        break;
      case 'PAPELETAS':
        _selecionarCorpo(1);
        break;
      case 'ETIQUETA AVULSA':
        setState(() => _menuOpen = false);
        Navigator.pushNamed(context, '/etiquetas');
        break;
      case 'PAPELETA DIÁRIA':
        setState(() => _menuOpen = false);
        Navigator.pushNamed(context, '/papeletas_diarias');
        break;
      case 'PERFIL':
        setState(() => _menuOpen = false);
        Navigator.pushNamed(context, '/profile');
        break;
      case 'SAIR':
        _confirmarSaida();
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

  Future<void> _abrirScanner() async {
    final result = await Navigator.pushNamed(context, '/barcode');
    if (result != null && result is String && result.isNotEmpty) {
      if (mounted) {
        Navigator.pushNamed(context, '/etiquetas', arguments: result);
      }
    }
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
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _menuOpen ? Icons.close : Icons.menu,
              color: Colors.white,
            ),
            onPressed: _toggleMenu,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Minha Loja',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _titulo,
              key: ValueKey<String>(_titulo),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return _currentBody == 0
        ? const EtiquetasFragment()
        : const PapeletasFragment();
  }

  Widget _buildMenu() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(_menuOpen ? 0 : -300, 0, 0),
      width: 280,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: const Text(
              'Minha Loja',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _menuItems.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.cardBorder),
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                return ListTile(
                  leading: Icon(item.icon, color: AppColors.primary),
                  title: Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900,
                    ),
                  ),
                  onTap: () => _onMenuItem(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _abrirScanner,
          child: const Icon(Icons.camera_alt),
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! > 0) {
              if (!_menuOpen) setState(() => _menuOpen = true);
            } else if (details.primaryVelocity! < 0) {
              if (_menuOpen) setState(() => _menuOpen = false);
            }
          },
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildBody()),
                ],
              ),
              if (_menuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(color: Colors.black54),
                  ),
                ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: _buildMenu(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  const _MenuItem(this.label, this.icon);
}
