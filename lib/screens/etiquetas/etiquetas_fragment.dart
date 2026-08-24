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

class _EtiquetasFragmentState extends State<EtiquetasFragment> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());

  late final String _storeId;
  late final String _today;

  List<PriceTag> _tags = [];
  List<Department> _departments = [];
  InfoTag? _infoTag;

  String _status = Constants.statusAll;
  String? _selectedDept;

  bool _loading = false;
  bool _loadingTags = false;

  bool get _hasSelection => _tags.any((e) => e.checkbox);

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager._instance?.getUserStore() ?? Constants.defaultStore;
    _today = _formatToday();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      _tags = await ListaStore.instance.getEtiquetas();
      final filters =
          await api.getPriceTagFilters(_storeId, _today);
      _departments = filters.departments;
      try {
        final menu = await api.getPriceTags(_storeId, _today);
        _infoTag = menu.page.infoTag;
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          SessionExpiredHandler.handleSessionExpired(context);
          return;
        }
      }
      await _fetchServerTags();
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchServerTags() async {
    if (!mounted) return;
    setState(() => _loadingTags = true);
    try {
      final resp = await api.getPriceTagsByStatus(
        _storeId,
        _status,
        department: _selectedDept,
        startDate: _today,
      );
      final map = <String, PriceTag>{for (final t in _tags) t.id: t};
      for (final st in resp.priceTags) {
        if (!map.containsKey(st.id)) {
          _tags.add(st);
          map[st.id] = st;
        }
      }
      await ListaStore.instance.saveEtiquetas(_tags);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
        return;
      }
      if (mounted) ToastUtils.showError(context, e.message);
    } catch (e) {
      LogHelper.e('EtiquetasFragment: erro ao buscar etiquetas', e);
    } finally {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  Future<void> _persist() async {
    await ListaStore.instance.saveEtiquetas(_tags);
  }

  void _toggleCheckbox(PriceTag tag, bool value) {
    setState(() => tag.checkbox = value);
    _persist();
  }

  void _changeQuantity(PriceTag tag, int delta) {
    setState(() {
      tag.quantity = (tag.quantity + delta).clamp(1, 9999);
    });
    _persist();
  }

  Future<void> _deleteTag(PriceTag tag) async {
    setState(() => _tags.removeWhere((e) => e.id == tag.id));
    await ListaStore.instance.removeEtiqueta(tag);
  }

  Future<void> _addByScan() async {
    final result = await Navigator.pushNamed(context, '/barcode');
    if (result is String && result.isNotEmpty) {
      await _fetchAndAdd(result);
    }
  }

  Future<void> _showManualEanDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar etiqueta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'EAN',
            hintText: 'Digite o código de barras',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (ok == true) await _fetchAndAdd(controller.text.trim());
  }

  Future<void> _fetchAndAdd(String ean) async {
    setState(() => _loading = true);
    try {
      final resp = await api.getSingleLabelByEan(
        _storeId,
        ean: ean,
        startDate: _today,
      );
      if (resp.items.isEmpty) {
        ToastUtils.showInfo(context, 'Nenhuma etiqueta encontrada');
        return;
      }
      final item = resp.items.first;
      await ListaStore.instance.addEtiqueta(_singleToPriceTag(item));
      _tags = await ListaStore.instance.getEtiquetas();
      ToastUtils.showSuccess(context, 'Etiqueta adicionada');
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendToPrinter() async {
    final selected = _tags.where((e) => e.checkbox).toList();
    if (selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final resp = await api.getPrinters(_storeId);
      if (!mounted) return;
      final choice = await _showPrinterDialog(resp);
      if (choice == null) {
        setState(() => _loading = false);
        return;
      }
      await api.sendPriceTagsToPrinter(
        _storeId,
        choice.printerId,
        choice.tagId,
        SendPriceTagsRequest(
          products: selected
              .map((e) => e.printingData)
              .whereType<PrintingData>()
              .toList(),
        ),
      );
      for (final e in selected) {
        e.checkbox = false;
      }
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

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_infoTag != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_infoTag!.date.weekday} ${_infoTag!.date.day}',
                      style: AppTextStyles.title,
                    ),
                  ),
                  _infoChip('Impressas', _infoTag!.printedTags),
                  const SizedBox(width: 8),
                  _infoChip('Não impressas', _infoTag!.unprintedTags),
                  const SizedBox(width: 8),
                  _infoChip('Total', _infoTag!.totalTags),
                ],
              ),
            const SizedBox(height: 8),
            if (_departments.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _deptChip('Todos', null, _selectedDept == null),
                    ..._departments.map(
                      (d) => _deptChip(d.label, d.id, _selectedDept == d.id),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _statusChip('Todas', Constants.statusAll),
                  _statusChip('Impressas', Constants.statusImpressas),
                  _statusChip('Não impressas', Constants.statusNaoImpressas),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, int value) => Chip(
        label: Text('$label: $value'),
        backgroundColor: AppColors.gray100,
      );

  Widget _deptChip(String label, String? id, bool selected) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? AppColors.white : AppColors.gray900,
          ),
          onSelected: (_) {
            setState(() => _selectedDept = selected ? null : id);
            _fetchServerTags();
          },
        ),
      );

  Widget _statusChip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _status == value,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: _status == value ? AppColors.white : AppColors.gray900,
          ),
          onSelected: (_) {
            setState(() => _status = value);
            _fetchServerTags();
          },
        ),
      );

  Widget _buildCard(PriceTag tag) => Dismissible(
        key: ValueKey(tag.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: AppColors.primary,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.delete, color: AppColors.white),
        ),
        onDismissed: (_) => _deleteTag(tag),
        child: Card(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tag.description,
                        style: AppTextStyles.title.copyWith(fontSize: 16),
                      ),
                    ),
                    Checkbox(
                      value: tag.checkbox,
                      activeColor: AppColors.primary,
                      onChanged: (v) => _toggleCheckbox(tag, v ?? false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Departamento: ${tag.department}'),
                Text('EAN: ${tag.ean}'),
                Text('Preço: ${tag.price}'),
                Text('Movimento: ${tag.movement}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Qtd:'),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _changeQuantity(tag, -1),
                    ),
                    Text('${tag.quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _changeQuantity(tag, 1),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.primary),
                      onPressed: () => _deleteTag(tag),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loadingTags && _tags.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _tags.isEmpty
                      ? const Center(child: Text('Nenhuma etiqueta'))
                      : ListView.builder(
                          itemCount: _tags.length,
                          itemBuilder: (_, i) => _buildCard(_tags[i]),
                        ),
            ),
            Container(
              width: double.infinity,
              color: AppColors.primary,
              child: SafeArea(
                top: false,
                child: TextButton(
                  onPressed: _hasSelection && !_loading ? _sendToPrinter : null,
                  child: Text(
                    'ENVIAR PARA IMPRESSORA',
                    style: AppTextStyles.button.copyWith(
                      color: _hasSelection ? AppColors.white : AppColors.gray100,
                    ),
                  ),
                ),
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
          right: 16,
          bottom: 64,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () async {
              final choice = await showModalBottomSheet<int>(
                context: context,
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Escanear código'),
                      onTap: () => Navigator.pop(ctx, 1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.keyboard),
                      title: const Text('Digitar EAN'),
                      onTap: () => Navigator.pop(ctx, 2),
                    ),
                  ],
                ),
              );
              if (choice == 1) {
                await _addByScan();
              } else if (choice == 2) {
                await _showManualEanDialog();
              }
            },
            child: const Icon(Icons.add, color: AppColors.white),
          ),
        ),
      ],
    );
  }
}

class _PrinterChoice {
  final String printerId;
  final String tagId;
  _PrinterChoice({required this.printerId, required this.tagId});
}
