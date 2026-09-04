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
import '../../utils/buscar_anim.dart';

class PapeletasDiariasScreen extends StatefulWidget {
  const PapeletasDiariasScreen({super.key});

  @override
  State<PapeletasDiariasScreen> createState() => _PapeletasDiariasScreenState();
}

class _PapeletasDiariasScreenState extends State<PapeletasDiariasScreen>
    with BuscarAnimMixin {
  final ApiService _api = ApiService(ApiClient.instance.getSlApiService());
  final ScrollController _scrollController = ScrollController();

  String _storeId = Constants.defaultStore;

  bool _isLoading = false;
  List<PriceSign> _allItems = [];
  List<PriceSign> _items = [];

  String _currentDate = '';
  String _today = '';

  int _naoImpressas = 0;
  int _impressas = 0;
  int _total = 0;

  List<Department> _departments = [];
  final Set<String> _selectedDepartments = {};

  List<String> _sizes = [];
  String _selectedSize = '2X1';

  static const List<String> _movementOptions = [
    'Todos',
    'De/Por',
    'Leve e Ganhe',
    'Comum'
  ];
  int _movementPos = 0;
  String _selectedMovement = '';

  static const List<String> _typeOptions = [
    'Comum',
    'Promocional',
    'Promocional (Modelo)'
  ];
  int _typePos = 0;
  String _selectedType = Constants.signTypePapeletaComum;
  bool _usarModeloPersonalizado = false;

  static const List<String> _statusOptions = [
    'Todas',
    'Impressas',
    'Não impressas'
  ];
  int _statusPos = 0;
  String _selectedStatus = Constants.statusAll;
  int _selectedSpinnerIndex = -1; // Índice do spinner selecionado (-1 = nenhum)

  @override
  void initState() {
    super.initState();
    _storeId = SessionManager.instance?.getUserStore() ?? Constants.defaultStore;
    final now = DateTime.now();
    _today = _toApi(now);
    _currentDate = _today;
    _loadFilters();
  }

  String _toApi(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _pad(int n) => n.toString().padLeft(2, '0');
  DateTime _fromApi(String ymd) {
    final p = ymd.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _toDisplay(String ymd) {
    final p = ymd.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : ymd;
  }

  Future<void> _loadFilters() async {
    setState(() => _isLoading = true);
    try {
      final filters = await _api.getPriceSignFilters(_storeId);
      _sizes = [
        Constants.signSize1x1,
        Constants.signSize2x1,
        Constants.signSize4x1,
        Constants.signSize6x1,
      ];
      if (filters.size.isNotEmpty) {
        final merged = <String>{...filters.size, ..._sizes};
        _sizes = merged.toList();
      }
      _selectedSize = _sizes.first;

      final deptFilters = await _api.getPriceTagFilters(_storeId, _currentDate);
      _departments = deptFilters.departments.toList()
        ..removeWhere((d) {
          final id = int.tryParse(d.id) ?? 0;
          return id >= 68 && id <= 98;
        })
        ..sort((a, b) {
          final na = int.tryParse(a.id) ?? 0;
          final nb = int.tryParse(b.id) ?? 0;
          return na.compareTo(nb);
        });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('PapeletasDiarias: erro filtros', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar filtros');
      LogHelper.e('PapeletasDiarias: erro filtros', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSigns() async {
    setState(() => _isLoading = true);
    startBuscarAnim();
    try {
      final comum = await _api.getPriceSigns(_storeId, Constants.signTypePapeletaComum,
          status: _selectedStatus, startDate: _currentDate);
      final promo = await _api.getPriceSigns(
          _storeId, Constants.signTypePapeletaPromocional,
          status: _selectedStatus, startDate: _currentDate);
      List<PriceSign> all = [...comum.priceSigns, ...promo.priceSigns];

      if (_selectedMovement.isNotEmpty) {
        all = all.where((it) => it.movement == _selectedMovement).toList();
      }
      if (_selectedDepartments.isNotEmpty) {
        all = all.where((it) {
          final num = _deptNumber(it.department);
          return num != null && _selectedDepartments.contains(num);
        }).toList();
      }
      all.sort((a, b) => _deptNumber(a.department)
          .toString()
          .compareTo(_deptNumber(b.department).toString()));

      _allItems = all;
      _naoImpressas = all.where((e) => e.status == Constants.statusNaoImpressas).length;
      _impressas = all.where((e) => e.status == Constants.statusImpressas).length;
      _total = all.length;

      setState(() => _items = all);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      LogHelper.e('PapeletasDiarias: erro ao carregar', e);
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao carregar papeletas');
      LogHelper.e('PapeletasDiarias: erro ao carregar', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      stopBuscarAnim();
    }
  }

  String? _deptNumber(String department) {
    final num = department.split(' -').first.trim();
    return num.isNotEmpty ? num : null;
  }

  void _onNextDay() {
    if (_currentDate != _today) return;
    setState(() {
      final next = _fromApi(_currentDate).add(const Duration(days: 1));
      _currentDate = _toApi(next);
    });
    _loadSigns();
  }

  void _onSelectAll(bool? value) {
    setState(() {
      for (var it in _items) it.checkbox = value ?? false;
    });
  }

  void _onItemCheck(PriceSign item, bool? value) =>
      setState(() => item.checkbox = value ?? false);

  void _onItemQty(PriceSign item, int qty) =>
      setState(() => item.quantity = qty);

  Future<void> _onPrint() async {
    final selected = _items.where((e) => e.checkbox).toList();
    if (selected.isEmpty) {
      ToastUtils.show(context, 'Selecione ao menos uma papeleta');
      return;
    }
    final data = selected.map((e) {
      final pd = e.printingData;
      if (pd == null) {
        return PapeletaPrintingData(
          productName: e.description,
          price: double.tryParse(e.price) ?? 0,
          codSap: e.sap,
          ean: e.ean,
          referenceDate: _currentDate,
          size: _selectedSize,
          quantity: e.quantity,
          unit: '',
        );
      }
      return pd.copyWith(size: _selectedSize, quantity: e.quantity);
    }).toList();

    if (_usarModeloPersonalizado) {
      final first = data.first.copyWith(template: Constants.signTemplateModelo);
      final r = await Navigator.pushNamed(context, '/modelo_editavel',
          arguments: {
            'items': [first],
            'size': _selectedSize,
            'modoEditavel': true,
            'mostrarCheckbox': false,
            'hideGerarPreview': true,
          });
      if (r == true) await _loadSigns();
      return;
    }

    final r = await Navigator.pushNamed(context, '/modelo_editavel',
        arguments: {
          'items': data,
          'size': _selectedSize,
          'mostrarCheckbox': true,
        });
    if (r == true) await _loadSigns();
  }

  bool get _allDepartmentsSelected =>
      _departments.isNotEmpty &&
      _selectedDepartments.length == _departments.length;

  void _openDepartmentDialog() async {
    final temp = <String>{..._selectedDepartments};
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecione os departamentos'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (c, setInner) => ListView(
              shrinkWrap: true,
              children: [
                CheckboxListTile(
                  title: const Text('Todos os departamentos'),
                  value: temp.length == _departments.length,
                  onChanged: (v) => setInner(() {
                    if (v == true) {
                      temp.addAll(_departments.map((d) => d.id));
                    } else {
                      temp.clear();
                    }
                  }),
                ),
                const Divider(),
                ..._departments.map((d) {
                  return CheckboxListTile(
                    title: Text('${d.id} - ${d.label}'),
                    value: temp.contains(d.id),
                    onChanged: (v) => setInner(() {
                      if (v == true) temp.add(d.id); else temp.remove(d.id);
                    }),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
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
              child: _buildBody(),
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
            'PAPELETAS DIÁRIAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isTomorrow
                      ? () {
                          _currentDate = _today;
                          _loadSigns();
                        }
                      : null,
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
                  onTap: isTomorrow ? null : _onNextDay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isTomorrow ? Colors.grey.shade300 : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'Amanhã ${_toDisplay(_toApi(nextDay))}',
                        style: TextStyle(
                          color: isTomorrow ? Colors.grey.shade500 : Colors.white,
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

  Widget _statCell(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value.toString(),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.grey[300]);

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
              value: _items.isNotEmpty && _items.every((e) => e.checkbox),
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
            child: Center(child: Text('Nenhuma papeleta encontrada')),
          )
        else
          ..._items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: PapeletaDiariaCard(
                  item: it,
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
                  index: 0,
                  value: _movementPos,
                  items: _movementOptions
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _movementPos = v ?? 0;
                      _selectedMovement = _movementPos == 0
                          ? ''
                          : _movementOptions[_movementPos];
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  index: 1,
                  value: _typePos,
                  items: _typeOptions
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _typePos = v ?? 0;
                      _selectedType = _typePos == 0
                          ? Constants.signTypePapeletaComum
                          : Constants.signTypePapeletaPromocional;
                      _usarModeloPersonalizado = _typePos == 2;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  index: 2,
                  value: _sizes.contains(_selectedSize) ? _selectedSize : null,
                  hint: 'Tamanho',
                  items: _sizes
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedSize = v ?? '2X1'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  index: 3,
                  value: _statusPos,
                  items: _statusOptions
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
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
                onPressed: buscando ? null : _loadSigns,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: buscando ? Text(buscandoLabel) : const Text('BUSCAR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
      {required int index,
      dynamic value,
      String? hint,
      required List<DropdownMenuItem<dynamic>> items,
      required void Function(dynamic) onChanged}) {
    return _DropdownWidget(
      index: index,
      value: value,
      hint: hint,
      items: items,
      isSelected: _selectedSpinnerIndex == index,
      onSelected: (idx) => setState(() => _selectedSpinnerIndex = idx),
      onChanged: (v) {
        setState(() => _selectedSpinnerIndex = index);
        onChanged(v);
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onPrint,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('IMPRIMIR PAPELETAS'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _DropdownWidget extends StatefulWidget {
  final int index;
  final dynamic value;
  final String? hint;
  final List<DropdownMenuItem<dynamic>> items;
  final bool isSelected;
  final ValueChanged<int> onSelected;
  final void Function(dynamic) onChanged;
  const _DropdownWidget({
    required this.index,
    required this.value,
    this.hint,
    required this.items,
    required this.isSelected,
    required this.onSelected,
    required this.onChanged,
  });
  @override
  State<_DropdownWidget> createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<_DropdownWidget> {
  @override
  Widget build(BuildContext context) {
    final red = const Color(0xFFD32F2F);
    final isActive = widget.isSelected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? red : Colors.white,
        border: Border.all(color: isActive ? red : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          value: widget.value,
          hint: widget.hint != null
              ? Text(widget.hint!, style: const TextStyle(color: Colors.black))
              : null,
          dropdownColor: Colors.white,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          iconEnabledColor: isActive ? Colors.white : Colors.black,
          items: widget.items
              .map((e) => DropdownMenuItem(
                    value: e.value,
                    child: Text(e.child is Text ? (e.child as Text).data ?? '' : '',
                        style: const TextStyle(color: Colors.black)),
                  ))
              .toList(),
          onChanged: (v) {
            widget.onChanged(v);
          },
          onTap: () => widget.onSelected(widget.index),
        ),
      ),
    );
  }
}
