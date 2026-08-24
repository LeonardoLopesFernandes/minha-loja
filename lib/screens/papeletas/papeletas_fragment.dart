import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/lista_store.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/widgets/cards.dart';

class PapeletasFragment extends StatefulWidget {
  const PapeletasFragment({super.key});

  @override
  State<PapeletasFragment> createState() => _PapeletasFragmentState();
}

class _PapeletasFragmentState extends State<PapeletasFragment> {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager _session = SessionManager.instance!;

  late String _store;
  late String _startDate;

  bool _loading = false;
  List<PriceSign> _items = [];

  String _tipo = 'Promocional'; // Comum / Promocional (default Promocional)
  String _modelo = 'Misto'; // Misto / Promocional / Promocional Editável / Comum / Comum Editável / Vencimentos
  String _buscaTipo = 'EAN'; // EAN / SAP / Descrição
  String _size = '4×1'; // 1×1 / 2×1 / 4×1 / 6×1

  final TextEditingController _eanController = TextEditingController();
  String _eanHint = 'Digite o EAN';
  TextInputType _eanKeyboardType = TextInputType.number;

  @override
  void initState() {
    super.initState();
    _store = _session.getUserStore();
    _startDate = _today();
    _loadSaved();
  }

  @override
  void dispose() {
    _eanController.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _baseHint {
    switch (_buscaTipo) {
      case 'EAN':
        return 'Digite o EAN';
      case 'SAP':
        return 'Digite o SAP';
      default:
        return 'Buscar Por Descrição';
    }
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _items = List<PriceSign>.from(await ListaStore.instance.getPapeletas());
    } catch (e) {
      LogHelper.e('Erro ao carregar papeletas', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.savePapeletas(_items);
  }

  void _delete(PriceSign item) {
    setState(() => _items.removeWhere((e) => e.id == item.id));
    ListaStore.instance.removePapeleta(item);
  }

  // ---- Helpers (espelho do Kotlin) ----
  bool get _usarMisto => _modelo == 'Misto';
  bool get _usarModeloEditavel =>
      _modelo == 'Promocional' || _modelo == 'Promocional Editável';
  bool get _usarComumEditavel =>
      _modelo == 'Comum' || _modelo == 'Comum Editável';
  bool get _usarVencimentos => _modelo == 'Vencimentos';
  bool get _isModoEditavel =>
      _modelo == 'Promocional Editável' || _modelo == 'Comum Editável';

  static int _maxItens(String size) {
    switch (size) {
      case '1×1':
        return 1;
      case '2×1':
        return 2;
      case '4×1':
        return 4;
      default:
        return 6;
    }
  }

  static String _templatePorMovimento(String? movement) {
    final m = (movement ?? '').toLowerCase();
    if (m == 'de/por') return Constants.signTemplateDepor;
    if (m == 'parcelado') return Constants.signTemplateDeporParcelado;
    return Constants.signTemplateModeloEditavel;
  }

  PapeletaPrintingData _ajustarDadosLeveGanhe(PapeletaPrintingData d) {
    if (d.template != Constants.signTemplateLeveGanheCada) return d;
    final total = Constants.totalLeveGanhe(
        d.promotionPrice, d.takeAndWinPrice, d.takeAndWinQuantity);
    final qty = d.takeAndWinQuantity ?? 0;
    final unitario = (d.takeAndWinPrice != null && d.takeAndWinPrice! > 0)
        ? d.takeAndWinPrice!
        : (qty > 0 ? total / qty : total);
    return d.copyWith(
      template: Constants.signTemplateLeveGanheTotal,
      promotionPrice: unitario,
      takeAndWinPrice: total,
      installmentPrice: null,
      installmentQuantity: null,
    );
  }

  bool _isItemComum(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    if (d.template == 'por_de_parcelado' ||
        d.template == Constants.signTemplateDeporParcelado) return true;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasPromo || hasTW) return false;
    return true;
  }

  bool _isComumElegivel(PriceSign item) {
    final d = item.printingData;
    if (d == null) return true;
    final hasInst =
        d.installmentQuantity != null && d.installmentQuantity! > 0;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasInst && !hasPromo && !hasTW) return (d.price) > 149.99;
    return true;
  }

  // ---- Busca avulsa (ambos os tipos, comportamento "Misto") ----
  Future<void> _addStandalone() async {
    final c = _eanController.text.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, 'Informe um código');
      return;
    }
    setState(() {
      _loading = true;
      _eanHint = 'BUSCANDO...';
    });
    try {
      final results = await Future.wait([
        _api.getPriceSignStandalone(_store, Constants.tipoComum,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: _buscaTipo == 'Descrição' ? c : null,
            startDate: _startDate),
        _api.getPriceSignStandalone(_store, Constants.tipoPromocional,
            ean: _buscaTipo == 'EAN' ? c : null,
            sapId: _buscaTipo == 'SAP' ? c : null,
            description: _buscaTipo == 'Descrição' ? c : null,
            startDate: _startDate),
      ]);
      int added = 0;
      for (final r in results) {
        for (final it in r.items) {
          if (!_items.any((e) => e.id == it.id)) {
            _items.add(it);
            added++;
          }
        }
      }
      if (!mounted) return;
      if (added == 0) {
        ToastUtils.showInfo(context, 'Nenhuma papeleta encontrada');
      } else {
        ToastUtils.showSuccess(context, '$added papeleta(s) adicionada(s)');
      }
      await _persist();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao buscar papeleta', e);
      ToastUtils.showError(context, 'Erro ao buscar papeleta');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _eanHint = _baseHint;
        });
      }
    }
  }

  Future<void> _addByScan() async {
    final r = await Navigator.pushNamed(context, '/barcode');
    if (r is String && r.isNotEmpty) {
      _eanController.text = r;
      await _addStandalone();
    }
  }

  // ---- Impressão ----
  Future<void> _imprimirItem(PriceSign item, int qty) async {
    final signData = item.printingData;
    if (signData == null) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final tamanhoAtual = _size;

    if (_usarComumEditavel && !_isModoEditavel) {
      if (!_isItemComum(item)) {
        ToastUtils.show(context, 'Esta papeleta não é do tipo Comum');
        return;
      }
      final list = List.generate(
          qty,
          (_) => _ajustarDadosLeveGanhe(
              signData.copyWith(quantity: 1, size: tamanhoAtual)));
      await _send(list);
      setState(() => _items.removeWhere((e) => e.id == item.id));
      await _persist();
      return;
    }

    if (_usarModeloEditavel && _isItemComum(item)) {
      ToastUtils.show(context, 'Esta papeleta é do tipo Comum, selecione o modo Comum');
      return;
    }

    final qtd = qty < _maxItens(tamanhoAtual) ? qty : _maxItens(tamanhoAtual);
    final lista = List.generate(
        qtd,
        (_) => _ajustarDadosLeveGanhe(signData.copyWith(
              template: signData.template ?? _templatePorMovimento(item.movement),
              quantity: 1,
              size: tamanhoAtual,
            )));
    await _openPreview(lista, itemToRemove: item);
  }

  Future<void> _imprimirTodas() async {
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Nenhuma papeleta para imprimir');
      return;
    }
    final tamanhoAtual = _size;
    final lista = <PapeletaPrintingData>[];
    for (final item in _items) {
      final ehComum = _isItemComum(item);
      if (!_usarMisto) {
        if (_tipo == 'Comum' && (!ehComum || !_isComumElegivel(item))) continue;
        if (_tipo == 'Promocional' && ehComum) continue;
      }
      final signData = item.printingData;
      if (signData == null) continue;
      final qtd = item.quantity;
      for (int i = 0; i < qtd; i++) {
        lista.add(_ajustarDadosLeveGanhe(signData.copyWith(
          template: signData.template ?? _templatePorMovimento(item.movement),
          quantity: 1,
          size: tamanhoAtual,
        )));
      }
    }
    if (lista.isEmpty) {
      ToastUtils.show(context,
          _tipo == 'Comum' ? 'Nenhum item do tipo Comum' : 'Nenhum item do tipo Promocional');
      return;
    }

    if (_usarComumEditavel && !_isModoEditavel) {
      await _send(lista);
      setState(() => _items.clear());
      await _persist();
      return;
    }
    await _openPreview(lista, clearAll: true);
  }

  Future<void> _send(List<PapeletaPrintingData> lista) async {
    setState(() => _loading = true);
    try {
      await _api.sendPriceSigns(
          _store, SendPriceSignRequest(products: lista));
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Papeletas enviadas para impressora');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('Erro ao enviar papeletas', e);
      ToastUtils.showError(context, 'Erro ao enviar papeletas');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Abre a tela de pré-visualização multi-item (equivalente à
  // ModeloEditavelActivity do Kotlin), que lista TODOS os itens com
  // checkboxes e envia para a impressora ao confirmar.
  Future<void> _openPreview(List<PapeletaPrintingData> lista,
      {PriceSign? itemToRemove, bool clearAll = false}) async {
    if (lista.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final result = await Navigator.pushNamed(context, '/modelo_editavel',
        arguments: {
          'items': lista,
          'size': _size,
          'mostrarCheckbox': true,
          'modoVencimentos': _usarVencimentos,
        });
    if (!mounted) return;
    if (result == true) {
      if (clearAll) {
        setState(() => _items.clear());
      } else if (itemToRemove != null) {
        setState(() => _items.removeWhere((e) => e.id == itemToRemove.id));
      }
      await _persist();
    }
  }

  Future<void> _limparLista() async {
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Lista já está vazia');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Lista'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _items.clear());
      await _persist();
      ToastUtils.show(context, 'Lista limpa');
    }
  }

  Widget _spinnerBox({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _spinnerBox(
                  value: _tipo,
                  items: const ['Comum', 'Promocional'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _tipo = v);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _spinnerBox(
                  value: _modelo,
                  items: const [
                    'Misto',
                    'Promocional',
                    'Promocional Editável',
                    'Comum',
                    'Comum Editável',
                    'Vencimentos'
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _modelo = v;
                      if (v == 'Promocional Editável') _tipo = 'Promocional';
                      if (v == 'Comum Editável') _tipo = 'Comum';
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _spinnerBox(
                  value: _buscaTipo,
                  items: const ['EAN', 'SAP', 'Descrição'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _buscaTipo = v;
                      _eanHint = v == 'EAN'
                          ? 'Digite o EAN'
                          : v == 'SAP'
                              ? 'Digite o SAP'
                              : 'Buscar Por Descrição';
                      _eanKeyboardType =
                          v == 'Descrição' ? TextInputType.text : TextInputType.number;
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _spinnerBox(
                  value: _size,
                  items: const ['1×1', '2×1', '4×1', '6×1'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _size = v);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _eanController,
                    keyboardType: _eanKeyboardType,
                    decoration: InputDecoration(
                      hintText: _eanHint,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (v) => _addStandalone(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _addStandalone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('BUSCAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _limparLista,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('LIMPAR LISTA'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: _imprimirTodas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('IMPRIMIR TODAS'),
                ),
              ),
            ],
          ),
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_items.length} item(ns) na lista',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text('Nenhuma papeleta encontrada'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Dismissible(
                              key: Key('papeleta_${item.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: const Color(0xFFD32F2F),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _delete(item),
                              child: PapeletaCard(
                                item: item,
                                onImprimir: (q) => _imprimirItem(item, q),
                                onRemover: () => _delete(item),
                                onChangedQuantity: (q) {
                                  item.quantity = q;
                                  _persist();
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFD32F2F),
            onPressed: _addByScan,
            child: Image.asset('assets/icons/ic_scanner.png',
                width: 24, height: 24, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
