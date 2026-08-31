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
import 'package:minhaloja/utils/buscar_anim.dart';
import 'package:minhaloja/widgets/cards.dart';

  String _formatToday() {
    final d = DateTime.now();
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  PrintingData _toPrintingData(SingleLabelPrintingData d) => PrintingData(
      ean: d.ean,
      description: d.description,
      department: d.department,
      displayPrice: d.displayPrice,
      price: d.price,
      promotionalPrice: d.promotionalPrice,
      quantity: d.quantity,
      movementType: d.movementType,
      unit: d.unit,
      unitQty: d.unitQty,
      unitValue: d.unitValue,
      printUnitValue: d.printUnitValue,
      codSap: d.codSap,
      takeAndWin: d.takeAndWin,
      referenceDate: d.referenceDate,
      template: d.template,
    );

PriceTag _singleToPriceTag(SingleLabelItem item) => PriceTag(
      id: item.id,
      sap: item.sap,
      department: item.department,
      ean: item.ean,
      description: item.description,
      startDate: item.startDate,
      endDate: item.endDate,
      duration: item.duration,
      price: item.price,
      movement: item.movement,
      status: item.status,
      checkbox: false,
      quantity: item.quantity,
      printingData:
          item.printingData != null ? _toPrintingData(item.printingData!) : null,
    );

class EtiquetasFragment extends StatefulWidget {
  const EtiquetasFragment({super.key});

  @override
  State<EtiquetasFragment> createState() => _EtiquetasFragmentState();
}

class _EtiquetasFragmentState extends State<EtiquetasFragment>
    with BuscarAnimMixin {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());

  late final String _storeId;
  late final String _today;

  List<PriceTag> _tags = [];

  bool _loading = false;
  bool _fabNoLugar = false;

  final TextEditingController _eanController = TextEditingController();
  String _buscaTipo = 'EAN';
  String _eanHint = 'Digite o EAN';
  TextInputType _eanKeyboardType = TextInputType.number;
  String _printer = 'Zebra 1';

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

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    _today = _formatToday();
    _loadSaved();
  }

  @override
  void dispose() {
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      _tags = List<PriceTag>.from(await ListaStore.instance.getEtiquetas());
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.saveEtiquetas(_tags);
  }

  void _deleteTag(PriceTag tag) {
    setState(() => _tags.removeWhere((e) => e.id == tag.id));
    ListaStore.instance.removeEtiqueta(tag);
  }

  Future<void> _addByScan() async {
    final result = await Navigator.pushNamed(context, '/barcode');
    if (result is String && result.isNotEmpty) {
      _eanController.text = result;
      await _fetchAndAdd(result);
    }
  }

  Future<void> _fetchAndAdd(String code) async {
    final c = code.trim();
    if (c.isEmpty) {
      ToastUtils.show(context, 'Digite um código');
      return;
    }
    setState(() {
      _loading = true;
      _eanHint = 'BUSCANDO...';
    });
    startBuscarAnim();
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: _buscaTipo == 'EAN' ? c : null,
        sapId: _buscaTipo == 'SAP' ? c : null,
        description: _buscaTipo == 'Descrição' ? c : null,
        startDate: _today,
      );
      if (!mounted) return;
      if (resp.items.isEmpty) {
        ToastUtils.showInfo(context, 'Nenhuma etiqueta encontrada');
        setState(() {
          _loading = false;
          _eanHint = _baseHint;
        });
        return;
      }
      int added = 0;
      int incremented = 0;
      for (final item in resp.items) {
        final idx = _tags.indexWhere((t) => t.ean == item.ean);
        if (idx >= 0) {
          _tags[idx].quantity += 1;
          incremented++;
        } else {
          _tags.add(_singleToPriceTag(item));
          added++;
        }
      }
      await _persist();
      ToastUtils.showSuccess(
          context, '$added adicionado(s) | $incremented incrementado(s)');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao adicionar', e);
      ToastUtils.showError(context, 'Erro ao buscar etiqueta');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _eanHint = _baseHint;
        });
      }
      stopBuscarAnim();
    }
  }

  Future<void> _sendToPrinter() async {
    final selected = _tags.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }
    final printingDataList = <PrintingData>[];
    for (final t in selected) {
      final pd = t.printingData;
      if (pd == null) continue;
      final template = pd.takeAndWin != null
          ? Constants.signTemplateModelo
          : Constants.templateNormalizado(pd.template);
      for (int i = 0; i < t.quantity; i++) {
        printingDataList
            .add(pd.copyWith(quantity: 1, template: template));
      }
    }
    if (printingDataList.isEmpty) {
      ToastUtils.show(context, 'Dados de impressão não disponíveis');
      return;
    }
    final printerId = _printer == 'Zebra 1'
        ? Constants.printerZebra1
        : Constants.printerZebra2;
    setState(() => _loading = true);
    try {
      await api.sendPriceTagsToPrinter(
        _storeId,
        printerId,
        Constants.tagGondola,
        SendPriceTagsRequest(products: printingDataList),
      );
      if (!mounted) return;
      setState(() {
        for (final t in selected) {
          _tags.removeWhere((e) => e.id == t.id);
        }
      });
      await _persist();
      ToastUtils.showSuccess(context, 'Enviado para impressão');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao enviar', e);
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _imprimirItem(PriceTag tag) async {
    setState(() => tag.checkbox = true);
    await _sendToPrinter();
  }

  Future<void> _imprimirTodas() async {
    if (_tags.isEmpty) {
      ToastUtils.show(context, 'Nenhuma etiqueta para imprimir');
      return;
    }
    for (final t in _tags) {
      t.checkbox = true;
    }
    setState(() {});
    await _sendToPrinter();
  }

  Future<void> _limparLista() async {
    if (_tags.isEmpty) {
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
      setState(() => _tags.clear());
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
                  value: _printer,
                  items: const ['Zebra 1', 'Zebra 2'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _printer = v);
                  },
                ),
              ),
              const SizedBox(width: 4),
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
                      _eanKeyboardType = v == 'Descrição'
                          ? TextInputType.text
                          : TextInputType.number;
                    });
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
                    onSubmitted: (v) => _fetchAndAdd(v),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  height: 40,
                  child: ElevatedButton(
                    onPressed: buscando ? null : () => _fetchAndAdd(_eanController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    child: buscando ? Text(buscandoLabel) : const Text('BUSCAR'),
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
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_tags.length} item(ns) na lista',
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0x1A000000),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/icons/ic_etiqueta.png',
                color: const Color(0xFFA0A0A0)),
          ),
          const SizedBox(height: 20),
          const Text(
            '0 item(a) na lista\n\nEscaneie ou digite\npara adicionar à lista',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ],
      ),
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
              child: _tags.isEmpty
                  ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          itemCount: _tags.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 0),
                          itemBuilder: (_, i) {
                            final tag = _tags[i];
                            return Dismissible(
                              key: ValueKey(tag.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD32F2F),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteTag(tag),
                              child: EtiquetaCard(
                                tag: tag,
                                onImprimir: (q) {
                                  tag.quantity = q;
                                  _imprimirItem(tag);
                                },
                                onRemover: () => _deleteTag(tag),
                                onChangedQuantity: (q) {
                                  tag.quantity = q;
                                  _persist();
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            // Igual ao MLoja: começa um pouco pro lado; 1º clique volta à
            // posição original, 2º clique abre o scanner.
            offset: _fabNoLugar ? Offset.zero : const Offset(0.6, 0),
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFD32F2F),
              onPressed: () {
                if (!_fabNoLugar) {
                  setState(() => _fabNoLugar = true);
                  return;
                }
                _addByScan();
              },
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
