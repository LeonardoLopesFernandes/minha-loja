import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';

String _formatToday() {
  final d = DateTime.now();
  final y = d.year.toString();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

PrintingData _toPrintingData(SingleLabelPrintingData d, int quantity) => PrintingData(
      ean: d.ean,
      description: d.description,
      department: d.department,
      displayPrice: d.displayPrice,
      price: d.price,
      promotionalPrice: d.promotionalPrice,
      quantity: quantity,
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

class EtiquetasScreen extends StatefulWidget {
  const EtiquetasScreen({super.key});

  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final TextEditingController _searchController = TextEditingController();

  late final String _storeId;
  late final String _today;

  String _searchType = 'ean';
  List<SingleLabelItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager._instance?.getUserStore() ?? Constants.defaultStore;
    _today = _formatToday();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ToastUtils.showInfo(context, 'Informe um valor para buscar');
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: _searchType == 'ean' ? query : null,
        description: _searchType == 'descricao' ? query : null,
        sapId: _searchType == 'sap' ? query : null,
        startDate: _today,
      );
      setState(() => _items = resp.items);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasScreen: erro ao buscar', e);
      ToastUtils.showError(context, 'Erro ao buscar etiqueta');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeQuantity(SingleLabelItem item, int delta) {
    setState(() {
      item.quantity = (item.quantity + delta).clamp(1, 9999);
    });
  }

  Future<void> _sendToPrinter() async {
    if (_items.isEmpty) return;
    setState(() => _loading = true);
    try {
      final resp = await api.getPrinters(_storeId);
      if (!mounted) return;
      final choice = await _showPrinterDialog(resp);
      if (choice == null) {
        setState(() => _loading = false);
        return;
      }
      final products = _items
          .where((e) => e.printingData != null)
          .map((e) => _toPrintingData(e.printingData!, e.quantity))
          .toList();
      if (products.isEmpty) {
        ToastUtils.showInfo(context, 'Nenhum dado de impressão disponível');
        setState(() => _loading = false);
        return;
      }
      await api.sendPriceTagsToPrinter(
        _storeId,
        choice.printerId,
        choice.tagId,
        SendPriceTagsRequest(products: products),
      );
      ToastUtils.showSuccess(context, 'Enviado para impressão');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasScreen: erro ao enviar', e);
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_PrinterChoice?> _showPrinterDialog(PrinterResponse resp) async {
    return showDialog<_PrinterChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecione a impressora e etiqueta'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: resp.printers.length,
            itemBuilder: (_, pi) {
              final p = resp.printers[pi];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...p.tags.map(
                    (t) => ListTile(
                      dense: true,
                      title: Text(t.name),
                      subtitle: Text(t.orientation),
                      onTap: () => Navigator.pop(
                        ctx,
                        _PrinterChoice(printerId: p.id, tagId: t.id),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(SingleLabelItem item) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                style: AppTextStyles.title.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text('Departamento: ${item.department}'),
              Text('EAN: ${item.ean}'),
              Text('Preço: ${item.price}'),
              Text('Movimento: ${item.movement}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Qtd:'),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _changeQuantity(item, -1),
                  ),
                  Text('${item.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _changeQuantity(item, 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiqueta Avulsa'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'EAN / Descrição / SAP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppColors.primary),
                      onPressed: _search,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _typeChip('EAN', 'ean'),
                      _typeChip('Descrição', 'descricao'),
                      _typeChip('SAP', 'sap'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Nenhuma etiqueta encontrada'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _buildItemCard(_items[i]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        color: AppColors.primary,
        child: SafeArea(
          child: TextButton(
            onPressed: !_loading ? _sendToPrinter : null,
            child: Text(
              'ENVIAR PARA IMPRESSORA',
              style: AppTextStyles.button,
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _searchType == value,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: _searchType == value ? AppColors.white : AppColors.gray900,
          ),
          onSelected: (_) => setState(() => _searchType = value),
        ),
      );
}

class _PrinterChoice {
  final String printerId;
  final String tagId;
  _PrinterChoice({required this.printerId, required this.tagId});
}
