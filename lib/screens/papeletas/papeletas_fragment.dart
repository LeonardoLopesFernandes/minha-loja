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

  List<SupplyType> _supplyTypes = [];
  List<String> _sizes = [];

  String _type = Constants.tipoComum;
  String _modelo = 'Misto';
  String _buscaTipo = 'EAN';
  String? _size;
  String _status = Constants.statusAll;

  final TextEditingController _eanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = _session.getUserStore();
    _startDate = _today();
    _loadFilters();
    _loadSavedAndSigns();
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

  Future<void> _loadFilters() async {
    try {
      final resp = await _api.getPriceSignFilters(_store);
      if (!mounted) return;
      setState(() {
        _supplyTypes = resp.supplyTypes;
        _sizes = resp.size;
        if (_size == null && _sizes.isNotEmpty) _size = _sizes[2];
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      LogHelper.e('Erro ao carregar filtros de papeletas', e);
    } catch (e) {
      LogHelper.e('Erro ao carregar filtros de papeletas', e);
    }
  }

  Future<void> _loadSavedAndSigns() async {
    final saved = await ListaStore.instance.getPapeletas();
    if (!mounted) return;
    setState(() => _items = List<PriceSign>.from(saved));
    await _loadSigns();
  }

  Future<void> _loadSigns() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final resp = await _api.getPriceSigns(
        _store,
        _type,
        department: null,
        size: _size,
        status: _status,
        startDate: _startDate,
      );
      if (!mounted) return;
      final merged = List<PriceSign>.from(resp.priceSigns);
      for (final s in _items) {
        if (!merged.any((e) => e.id == s.id)) merged.add(s);
      }
      setState(() {
        _items = merged;
        _loading = false;
      });
      await _persist();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      LogHelper.e('Erro ao carregar papeletas', e);
      if (mounted) setState(() => _loading = false);
      ToastUtils.showError(context, 'Erro ao carregar papeletas');
    } catch (e) {
      LogHelper.e('Erro ao carregar papeletas', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.savePapeletas(_items);
  }

  Future<void> _addStandalone() async {
    final ean = _eanController.text.trim();
    if (ean.isEmpty) {
      ToastUtils.show(context, 'Informe um código');
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await _api.getPriceSignStandalone(
        _store,
        _type,
        ean: _buscaTipo == 'EAN' ? ean : null,
        sapId: _buscaTipo == 'SAP' ? ean : null,
        description: _buscaTipo == 'Descrição do item' ? ean : null,
        startDate: _startDate,
      );
      if (!mounted) return;
      final newItems = resp.items
          .where((e) => !_items.any((i) => i.id == e.id))
          .toList();
      setState(() {
        _items.addAll(newItems);
        _loading = false;
      });
      await _persist();
      ToastUtils.showSuccess(
          context, '${newItems.length} papeleta(s) adicionada(s)');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      LogHelper.e('Erro ao buscar papeleta', e);
      if (mounted) setState(() => _loading = false);
      ToastUtils.showError(context, 'Erro ao buscar papeleta');
    } catch (e) {
      LogHelper.e('Erro ao buscar papeleta', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(PriceSign item) async {
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await ListaStore.instance.removePapeleta(item);
  }

  void _editModelo(PriceSign item) {
    Navigator.pushNamed(context, '/modelo_editavel', arguments: item);
  }

  Future<void> _send() async {
    final selected = _items
        .where((e) => e.checkbox)
        .map((e) => e.printingData)
        .whereType<PapeletaPrintingData>()
        .toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos uma papeleta');
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.sendPriceSigns(
        _store,
        SendPriceSignRequest(products: selected),
      );
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Papeletas enviadas para impressora');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      LogHelper.e('Erro ao enviar papeletas', e);
      ToastUtils.showError(context, 'Erro ao enviar papeletas');
    } catch (e) {
      LogHelper.e('Erro ao enviar papeletas', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _imprimirItem(PriceSign item) async {
    setState(() => item.checkbox = true);
    await _send();
  }

  Future<void> _imprimirTodas() async {
    if (_items.isEmpty) {
      ToastUtils.show(context, 'Nenhuma papeleta para imprimir');
      return;
    }
    for (final t in _items) {
      t.checkbox = true;
    }
    setState(() {});
    await _send();
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
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
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
                  value: _type == Constants.tipoComum ? 'Comum' : 'Promocional',
                  items: const ['Comum', 'Promocional'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _type = v == 'Comum'
                        ? Constants.tipoComum
                        : Constants.tipoPromocional);
                    _loadSigns();
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
                    setState(() => _modelo = v);
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
                  items: const ['EAN', 'SAP', 'Descrição do item'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _buscaTipo = v;
                      _eanController.hint = v == 'EAN'
                          ? 'Digite o EAN'
                          : v == 'SAP'
                              ? 'Digite o SAP'
                              : 'Buscar Por Descrição';
                      _eanController.keyboardType = v == 'Descrição do item'
                          ? TextInputType.text
                          : TextInputType.number;
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _spinnerBox(
                  value: _size ?? (_sizes.isNotEmpty ? _sizes[2] : '4×1'),
                  items: (_sizes.isNotEmpty ? _sizes : ['1×1', '2×1', '4×1', '6×1'])
                      .map((e) => e)
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _size = v);
                    _loadSigns();
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
                    decoration: const InputDecoration(
                      hintText: 'DIGITE O EAN',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
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
                                onImprimir: (q) {
                                  item.quantity = q;
                                  _imprimirItem(item);
                                },
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
            onPressed: () async {
              final r = await Navigator.pushNamed(context, '/barcode');
              if (r is String && r.isNotEmpty) {
                _eanController.text = r;
                await _addStandalone();
              }
            },
            child: Image.asset('assets/icons/ic_scanner.png',
                width: 24, height: 24, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
