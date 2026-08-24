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

class PapeletasFragment extends StatefulWidget {
  const PapeletasFragment({super.key});

  @override
  State<PapeletasFragment> createState() => _PapeletasFragmentState();
}

class _PapeletasFragmentState extends State<PapeletasFragment> {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager _session = SessionManager._instance!;

  late String _store;
  late String _startDate;

  bool _loading = false;
  List<PriceSign> _items = [];

  // Filtros
  List<SupplyType> _supplyTypes = [];
  List<String> _sizes = [];

  String _type = Constants.tipoComum;
  String? _department;
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
    setState(() {
      _items = List<PriceSign>.from(saved);
    });
    await _loadSigns();
  }

  Future<void> _loadSigns() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final resp = await _api.getPriceSigns(
        _store,
        _type,
        department: _department,
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
      ToastUtils.show(context, 'Informe um EAN');
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await _api.getPriceSignStandalone(
        _store,
        _type,
        ean: ean,
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
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
    });
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

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                value: _type,
                hint: 'Tipo',
                items: const [
                  DropdownMenuItem(
                      value: Constants.tipoComum, child: Text('Comum')),
                  DropdownMenuItem(
                      value: Constants.tipoPromocional,
                      child: Text('Promocional')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _type = v);
                  _loadSigns();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown<String>(
                value: _department,
                hint: 'Departamento',
                items: _supplyTypes
                    .map((s) => DropdownMenuItem(
                        value: s.id, child: Text(s.label)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _department = v);
                  _loadSigns();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                value: _size,
                hint: 'Tamanho',
                items: _sizes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _size = v);
                  _loadSigns();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown<String>(
                value: _status,
                hint: 'Status',
                items: const [
                  DropdownMenuItem(
                      value: Constants.statusImpressas,
                      child: Text('IMPRESSAS')),
                  DropdownMenuItem(
                      value: Constants.statusNaoImpressas,
                      child: Text('NAO IMPRESSAS')),
                  DropdownMenuItem(
                      value: Constants.statusAll, child: Text('TODAS')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _status = v);
                  _loadSigns();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _eanController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por EAN',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addStandalone,
              child: const Text('Buscar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      hint: Text(hint),
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _buildFilterBar(),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('Nenhuma papeleta encontrada'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _PapeletaCard(
                          key: ValueKey(item.id),
                          item: item,
                          onChangedCheckbox: (v) {
                            setState(() => item.checkbox = v ?? false);
                            _persist();
                          },
                          onChangedQuantity: (v) {
                            setState(() => item.quantity = v);
                            _persist();
                          },
                          onEdit: () => _editModelo(item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _send,
        child: const Text('ENVIAR PARA IMPRESSORA'),
      ),
    );
  }
}

class _PapeletaCard extends StatelessWidget {
  final PriceSign item;
  final ValueChanged<bool?> onChangedCheckbox;
  final ValueChanged<int> onChangedQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PapeletaCard({
    super.key,
    required this.item,
    required this.onChangedCheckbox,
    required this.onChangedQuantity,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('papeleta_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.primary,
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: item.checkbox,
                    activeColor: AppColors.primary,
                    onChanged: onChangedCheckbox,
                  ),
                  Expanded(
                    child: Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'Sem descrição',
                      style: AppTextStyles.title,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    onPressed: onEdit,
                    tooltip: 'Editar modelo',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Departamento: ${item.department}',
                  style: AppTextStyles.subtitle),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Preço: ${item.price}',
                      style: AppTextStyles.body),
                  const SizedBox(width: 12),
                  if (item.printingData?.promotionPrice != null)
                    Text(
                        'Promo: ${item.printingData!.promotionPrice}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold)),
                ],
              ),
              if (item.movement.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Movimento: ${item.movement}',
                    style: AppTextStyles.subtitle),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      if (item.quantity > 1) {
                        onChangedQuantity(item.quantity - 1);
                      }
                    },
                  ),
                  Text('${item.quantity}', style: AppTextStyles.body),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () =>
                        onChangedQuantity(item.quantity + 1),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('EDITAR MODELO'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
