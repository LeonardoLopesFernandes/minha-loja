import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../network/api_service.dart';
import '../../network/api_client.dart';
import '../../widgets/cards.dart';
import '../../core/session_manager.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../utils/toast_utils.dart';
import '../../utils/log_helper.dart';
import '../../utils/session_expired_handler.dart';

class EtiquetasScreen extends StatefulWidget {
  const EtiquetasScreen({super.key});

  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final ScrollController _scrollController = ScrollController();

  String _storeId = Constants.defaultStore;

  bool _isLoading = false;
  List<PriceTag> _items = [];

  String _currentDate = '';
  String _today = '';

  int _naoImpressas = 0;
  int _impressas = 0;
  int _total = 0;

  List<TagFilter> _printers = [];
  String _selectedPrinterId = '';
  String _selectedTagId = '';

  List<Department> _departments = [];
  final Set<String> _selectedDepartments = {};

  String _selectedStatus = Constants.statusAll;
  static const List<String> _statusLabels = [
    'Todas',
    'Impressas',
    'Não impressas'
  ];
  int _statusPos = 0;

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    final now = DateTime.now();
    _today = _toApi(now);
    _currentDate = _today;
    _loadInit();
  }

  String _toApi(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  String _toDisplay(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[2]}/${parts[1]}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  DateTime _fromApi(String ymd) {
    final parts = ymd.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Future<void> _loadInit() async {
    setState(() => _isLoading = true);
    try {
      final menu = await _api.getPriceTags(_storeId, _currentDate);
      final info = menu.page.infoTag;
      _naoImpressas = info.unprintedTags;
      _impressas = info.printedTags;
      _total = info.totalTags;
      final filters = await _api.getPriceTagFilters(_storeId, _currentDate);
      _printers = (filters.tags)
          .where((t) => (t.printerId).toUpperCase().contains('ZEBRA'))
          .toList();
      _departments = filters.departments;
      if (_printers.isNotEmpty) {
        _selectedPrinterId = _printers.first.printerId;
        _selectedTagId = _printers.first.tagId;
      }
      await _loadTags();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao carregar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar etiquetas');
      LogHelper.e('EtiquetasScreen: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _api.getPriceTagsByStatus(_storeId, _selectedStatus,
          startDate: _currentDate);
      List<PriceTag> list = resp.priceTags;
      if (_selectedDepartments.isNotEmpty) {
        list = list.where((it) {
          final num = _deptNumber(it.department);
          return num != null && _selectedDepartments.contains(num);
        }).toList();
      }
      list.sort((a, b) => _deptNumber(a.department)
          .toString()
          .compareTo(_deptNumber(b.department).toString()));
      setState(() => _items = list);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao buscar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao buscar etiquetas');
      LogHelper.e('EtiquetasScreen: erro ao buscar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? _deptNumber(String department) {
    final num = department.split(' -').first.trim();
    return int.tryParse(num);
  }

  String _printerLabel(String label) {
    final match =
        RegExp(r'Zebra\s*\d+', caseSensitive: false).firstMatch(label);
    if (match != null) {
      final raw = match.group(0)!;
      return 'Zebra ${raw.replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return label;
  }

  bool get _allDepartmentsSelected =>
      _departments.isNotEmpty &&
      _selectedDepartments.length == _departments.length;

  void _onNextDay() {
    final next = _fromApi(_currentDate).add(const Duration(days: 1));
    _currentDate = _toApi(next);
    _loadInit();
  }

  void _onSelectAll(bool? value) {
    setState(() {
      for (var it in _items) {
        it.checkbox = value ?? false;
      }
    });
  }

  void _onItemCheck(PriceTag item, bool? value) {
    setState(() => item.checkbox = value ?? false);
  }

  void _onItemQty(PriceTag item, int qty) {
    setState(() => item.quantity = qty);
  }

  Future<void> _onPrint() async {
    if (_selectedPrinterId.isEmpty) {
      ToastUtils.show(context, 'Selecione uma impressora');
      return;
    }
    final selected = _items.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos um item');
      return;
    }
    final data = selected.map((e) {
      final pd = e.printingData;
      if (pd == null) {
        return PrintingData(
          ean: e.ean,
          description: e.description,
          department: e.department,
          displayPrice: double.tryParse(e.price) ?? 0,
          quantity: e.quantity,
          movementType: e.movement,
          unit: '',
          unitQty: 0,
          unitValue: 0,
          printUnitValue: false,
          codSap: e.sap,
          referenceDate: _currentDate,
        );
      }
      return pd.copyWith(quantity: e.quantity, referenceDate: _currentDate);
    }).toList();

    setState(() => _isLoading = true);
    try {
      await _api.sendPriceTagsToPrinter(
        _storeId,
        _selectedPrinterId,
        _selectedTagId,
        SendPriceTagsRequest(products: data),
      );
      ToastUtils.showSuccess(context, 'Enviado para impressão');
      await _loadInit();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('EtiquetasScreen: erro ao enviar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao enviar para impressora');
      LogHelper.e('EtiquetasScreen: erro ao enviar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onReport() {
    ToastUtils.show(context, 'Relatório indisponível no momento');
  }

  void _openDepartmentDialog() async {
    final temp = <String>{..._selectedDepartments};
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecione os departamentos'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              StatefulBuilder(
                builder: (c, setInner) => CheckboxListTile(
                  title: const Text('Todos os departamentos'),
                  value: temp.length == _departments.length,
                  onChanged: (v) {
                    setInner(() {
                      if (v == true) {
                        temp.addAll(_departments.map((d) => d.id));
                      } else {
                        temp.clear();
                      }
                    });
                  },
                ),
              ),
              const Divider(),
              ..._departments.map((d) {
                final id = d.id;
                return StatefulBuilder(
                  builder: (c, setInner) => CheckboxListTile(
                    title: Text('$id - ${d.label}'),
                    value: temp.contains(id),
                    onChanged: (v) {
                      setInner(() {
                        if (v == true) temp.add(id); else temp.remove(id);
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedDepartments
                ..clear()
                ..addAll(temp));
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int get _selectedCount => _items.where((e) => e.checkbox).length;

  @override
  Widget build(BuildContext context) {
    final isTomorrow = _currentDate != _today;
    final nextDay = _fromApi(_currentDate).add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFF2),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(isTomorrow, nextDay),
            Expanded(
              child: _isLoading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTomorrow, DateTime nextDay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'ETIQUETAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isTomorrow) {
                      _currentDate = _today;
                      _loadInit();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isTomorrow ? Colors.white : AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'Hoje ${_toDisplay(_today)}',
                        style: TextStyle(
                          color: isTomorrow ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _onNextDay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isTomorrow ? AppColors.accent : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'Amanhã ${_toDisplay(_toApi(nextDay))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _statCell('NÃO IMPRESSA', _naoImpressas, AppColors.red),
                _divider(),
                _statCell('IMPRESSA', _impressas, AppColors.green),
                _divider(),
                _statCell('TOTAL', _total, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.grey[300]);

  Widget _buildBody() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilters(),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _items.isNotEmpty &&
                  _items.every((e) => e.checkbox),
              onChanged: _onSelectAll,
            ),
            const Text('Selecionar todos'),
            const Spacer(),
            Text('($_selectedCount) selecionados'),
          ],
        ),
        if (_currentDate != _today)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text(
              'Atenção: A impressão será efetuada para o dia seguinte.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Nenhuma etiqueta encontrada')),
          )
        else
          ..._items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PriceTagCard(
                  tag: it,
                  onChangedCheckbox: (v) => _onItemCheck(it, v),
                  onChangedQuantity: (q) => _onItemQty(it, q),
                ),
              )),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  value: _selectedPrinterId.isEmpty ? null : _selectedPrinterId,
                  hint: 'Impressora',
                  items: _printers
                      .map((p) => DropdownMenuItem(
                            value: p.printerId,
                            child: Text(_printerLabel(p.label)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final p = _printers.firstWhere((e) => e.printerId == v);
                    setState(() {
                      _selectedPrinterId = p.printerId;
                      _selectedTagId = p.tagId;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  value: _statusPos,
                  items: _statusLabels
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _statusPos = v ?? 0);
                    _selectedStatus = [
                      Constants.statusAll,
                      Constants.statusImpressas,
                      Constants.statusNaoImpressas
                    ][_statusPos];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openDepartmentDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedDepartments.isEmpty
                          ? 'Departamentos'
                          : _allDepartmentsSelected
                              ? 'Todos'
                              : '${_selectedDepartments.length} selecionado(s)',
                      style: TextStyle(
                        color: _selectedDepartments.isEmpty
                            ? Colors.grey[600]
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loadTags,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('BUSCAR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
      {dynamic value,
      String? hint,
      required List<DropdownMenuItem<dynamic>> items,
      required void Function(dynamic) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          value: value,
          hint: hint != null ? Text(hint) : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _onReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('RELATÓRIO'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _onPrint,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('IMPRIMIR'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
