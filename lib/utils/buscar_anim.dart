import 'dart:async';
import 'package:flutter/widgets.dart';

/// Mixin que anima o texto de um botão BUSCAR durante o carregamento,
/// ciclando os pontos: "BUSCANDO." -> "BUSCANDO.." -> "BUSCANDO...".
/// Substitui o indicador de carregamento central (CircularProgressIndicator)
/// pelo próprio rótulo do botão, evitando ícones duplicados na tela.
mixin BuscarAnimMixin<T extends StatefulWidget> on State<T> {
  Timer? _buscarTimer;
  int _buscarDot = 0;
  bool buscando = false;

  void startBuscarAnim() {
    buscando = true;
    _buscarDot = 0;
    _buscarTimer?.cancel();
    _buscarTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) {
        setState(() => _buscarDot = (_buscarDot + 1) % 3);
      }
    });
  }

  void stopBuscarAnim() {
    buscando = false;
    _buscarTimer?.cancel();
    _buscarTimer = null;
  }

  String get buscandoLabel => 'BUSCANDO${'.' * _buscarDot}';

  @override
  void dispose() {
    _buscarTimer?.cancel();
    super.dispose();
  }
}
