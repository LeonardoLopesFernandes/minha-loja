import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/models/models.dart';

const Color _greenCheckbox = Color(0xFF1B5E20);
const Color _red = Color(0xFFD32F2F);
const Color _redBrand = Color(0xFFD81B3A);
const Color _primary = Color(0xFFD7193F);
const Color _cardBorder = Color(0xFFCCCCCC);
const Color _qtyGray = Color(0xFFEDEFF2);
const Color _descDark = Color(0xFF1A1A1A);
const Color _descDark2 = Color(0xFF212121);
const Color _eanGray = Color(0xFF666666);
const Color _eanGray2 = Color(0xFF757575);
const Color _green = Color(0xFF4CAF50);
const Color _greenDark = Color(0xFF2E7D32);
const Color _orange = Color(0xFFFF9800);
const Color _grayBadge = Color(0xFF9E9E9E);

String _brl(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final dec = parts[1];
  final grouped = intPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return 'R\$ $grouped,$dec';
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

/// Card da home (EtiquetasFragment) -> item_etiqueta.xml
class EtiquetaCard extends StatefulWidget {
  final PriceTag tag;
  final ValueChanged<int> onImprimir;
  final VoidCallback onRemover;
  final ValueChanged<int> onChangedQuantity;
  const EtiquetaCard({
    super.key,
    required this.tag,
    required this.onImprimir,
    required this.onRemover,
    required this.onChangedQuantity,
  });

  @override
  State<EtiquetaCard> createState() => _EtiquetaCardState();
}

class _EtiquetaCardState extends State<EtiquetaCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.tag.quantity.toString());
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leveGanhe, String? deporValor, String? deporBadge}) _price() {
    final pd = widget.tag.printingData;
    final precoNormal = pd?.price?.value ?? 0.0;
    final precoPromo = pd?.promotionalPrice?.value;
    final take = pd?.takeAndWin;
    if (take != null && take.qty > 0 && take.totalValue > 0) {
      final totalLeve = (pd?.template == Constants.signTemplateLeveGanheCada &&
                  precoPromo != null && precoPromo > 0)
              ? precoPromo
              : take.totalValue;
      return (leveGanhe: 'Leve ${take.qty} por ${_brl(totalLeve)}', deporValor: null, deporBadge: null);
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        deporBadge: 'de por'
      );
    }
    final valor = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
    return (leveGanhe: null, deporValor: valor, deporBadge: 'normal');
  }

  @override
  Widget build(BuildContext context) {
    final p = _price();
    final deptNum = widget.tag.department.split(' -').first.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, (v) => widget.onChangedQuantity(v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.tag.description,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: _descDark2)),
                ),
                IconButton(
                  onPressed: () => widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: Image.asset('assets/icons/printer.png',
                      width: 22, height: 22, color: _green),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEP: $deptNum | EAN: ${widget.tag.ean} / SAP: ${widget.tag.sap}',
                        style: const TextStyle(fontSize: 10, color: _eanGray2),
                      ),
                      if (p.leveGanhe != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.leveGanhe!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text('leve e ganhe',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _greenDark)),
                              ),
                            ],
                          ),
                        ),
                      ] else if (p.deporValor != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.deporValor!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(p.deporBadge!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: p.deporBadge == 'de por'
                                            ? _orange
                                            : _grayBadge)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemover,
                  icon: Image.asset('assets/icons/remove.png',
                      width: 22, height: 22, color: _redBrand),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card da home (PapeletasFragment) -> item_papeleta.xml
class PapeletaCard extends StatefulWidget {
  final PriceSign item;
  final ValueChanged<int> onImprimir;
  final VoidCallback onRemover;
  final ValueChanged<int> onChangedQuantity;
  const PapeletaCard({
    super.key,
    required this.item,
    required this.onImprimir,
    required this.onRemover,
    required this.onChangedQuantity,
  });

  @override
  State<PapeletaCard> createState() => _PapeletaCardState();
}

class _PapeletaCardState extends State<PapeletaCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String? leveGanhe, String? deporValor, String? deporBadge}) _price() {
    final pd = widget.item.printingData;
    final precoNormal = pd?.price ?? 0.0;
    final precoPromo = pd?.promotionPrice;
    final takeQty = (pd?.takeAndWinQuantity != null && pd!.takeAndWinQuantity! > 0)
        ? pd!.takeAndWinQuantity!
        : null;
    final takePrice = (pd?.takeAndWinPrice != null && pd!.takeAndWinPrice! > 0)
        ? pd!.takeAndWinPrice!
        : null;
    if (takeQty != null && takePrice != null) {
      final totalLeve = Constants.totalLeveGanhePorTemplate(
          pd?.template, precoPromo, takePrice, takeQty);
      return (
        leveGanhe: 'Leve $takeQty por ${_brl(totalLeve)}',
        deporValor: null,
        deporBadge: null
      );
    }
    if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
      return (
        leveGanhe: null,
        deporValor: 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}',
        deporBadge: 'de por'
      );
    }
    final valor = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
    return (leveGanhe: null, deporValor: valor, deporBadge: 'normal');
  }

  @override
  Widget build(BuildContext context) {
    final p = _price();
    final deptNum = widget.item.department.split(' -').first.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          children: [
            Row(
              children: [
                _qtyBox(_qty, (v) => widget.onChangedQuantity(v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item.description,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black)),
                ),
                IconButton(
                  onPressed: () => widget.onImprimir(int.tryParse(_qty.text) ?? 1),
                  icon: Image.asset('assets/icons/printer.png',
                      width: 22, height: 22, color: _green),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEP: $deptNum | EAN: ${widget.item.ean} / SAP: ${widget.item.sap}',
                        style: const TextStyle(fontSize: 10, color: _eanGray2),
                      ),
                      if (p.leveGanhe != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.leveGanhe!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text('leve e ganhe',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _greenDark)),
                              ),
                            ],
                          ),
                        ),
                      ] else if (p.deporValor != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.deporValor!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(p.deporBadge!,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: p.deporBadge == 'de por'
                                            ? _orange
                                            : _grayBadge)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemover,
                  icon: Image.asset('assets/icons/remove.png',
                      width: 22, height: 22, color: _redBrand),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _qtyBox(TextEditingController c, ValueChanged<int> onChange) {
  return SizedBox(
    width: 32,
    height: 32,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _red, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => onChange(int.tryParse(v) ?? 1),
      ),
    ),
  );
}

/// Card (EtiquetasActivity) -> item_price_tag.xml
class PriceTagCard extends StatefulWidget {
  final PriceTag tag;
  final ValueChanged<bool> onChangedCheckbox;
  final ValueChanged<int> onChangedQuantity;
  const PriceTagCard({
    super.key,
    required this.tag,
    required this.onChangedCheckbox,
    required this.onChangedQuantity,
  });

  @override
  State<PriceTagCard> createState() => _PriceTagCardState();
}

class _PriceTagCardState extends State<PriceTagCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.tag.quantity.toString());
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String badge, Color badgeColor, String? promo, String? price}) _badge() {
    final pd = widget.tag.printingData;
    final precoNormal = pd?.price?.value ?? 0.0;
    final precoPromo = pd?.promotionalPrice?.value;
    final take = pd?.takeAndWin;
    final movement = widget.tag.movement.toUpperCase();
    if (movement.contains('LEVE') || movement.contains('GANHE')) {
      String? promo;
      if (take != null && take.qty > 0 && take.totalValue > 0) {
        final totalLeve = (pd?.template == Constants.signTemplateLeveGanheCada &&
                    precoPromo != null && precoPromo > 0)
                ? precoPromo
                : take.totalValue;
        promo = 'Leve ${take.qty} por ${_brl(totalLeve)}';
      }
      final price = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
      return (badge: 'LEVE E GANHE', badgeColor: _green, promo: promo, price: price);
    }
    if (movement.contains('DE') ||
        movement.contains('POR') ||
        movement.contains('PROMOCIONAL')) {
      String? promo;
      if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
        promo = 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}';
      }
      return (badge: 'DE/POR', badgeColor: _orange, promo: promo, price: null);
    }
    final price = precoNormal > 0 ? _brl(precoNormal) : widget.tag.price;
    return (badge: 'NORMAL', badgeColor: _grayBadge, promo: null, price: price);
  }

  Widget _statusBadge() {
    final s = widget.tag.status.toUpperCase();
    if (s == 'IMPRESSA') return _Badge('IMPRESSA', _green);
    if (s == 'NÃO IMPRESSA' || s == 'NAO IMPRESSA')
      return _Badge('NÃO IMPRESSA', _redBrand);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final b = _badge();
    final showPrice = b.price != null;
    final showPromo = b.promo != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.tag.checkbox,
                  activeColor: _greenCheckbox,
                  onChanged: (v) => widget.onChangedCheckbox(v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.tag.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _descDark)),
                ),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _qtyGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _qty,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: _descDark),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => widget.onChangedQuantity(int.tryParse(v) ?? 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EAN: ${widget.tag.ean} • Dep: ${widget.tag.department}',
                    style: const TextStyle(fontSize: 10, color: _eanGray),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(),
              ],
            ),
            if (showPromo || showPrice) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(showPromo ? b.promo! : b.price!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(b.badge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.badgeColor)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.badge,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card (PapeletasDiariasActivity) -> item_papeleta_diaria.xml
class PapeletaDiariaCard extends StatefulWidget {
  final PriceSign item;
  final ValueChanged<bool> onChangedCheckbox;
  final ValueChanged<int> onChangedQuantity;
  const PapeletaDiariaCard({
    super.key,
    required this.item,
    required this.onChangedCheckbox,
    required this.onChangedQuantity,
  });

  @override
  State<PapeletaDiariaCard> createState() => _PapeletaDiariaCardState();
}

class _PapeletaDiariaCardState extends State<PapeletaDiariaCard> {
  late TextEditingController _qty;
  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  ({String badge, Color badgeColor, String? promo, String? price}) _badge() {
    final pd = widget.item.printingData;
    final precoNormal = pd?.price ?? 0.0;
    final precoPromo = pd?.promotionPrice;
    final takeQty = (pd?.takeAndWinQuantity != null && pd!.takeAndWinQuantity! > 0)
        ? pd!.takeAndWinQuantity!
        : null;
    final takePrice = (pd?.takeAndWinPrice != null && pd!.takeAndWinPrice! > 0)
        ? pd!.takeAndWinPrice!
        : null;
    final movement = widget.item.movement.toUpperCase();
    if (movement.contains('LEVE') || movement.contains('GANHE')) {
      String? promo;
      if (takeQty != null && takePrice != null) {
        final totalLeve = Constants.totalLeveGanhePorTemplate(
            pd?.template, precoPromo, takePrice, takeQty);
        promo = 'Leve $takeQty por ${_brl(totalLeve)}';
      }
      final price = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
      return (badge: 'LEVE E GANHE', badgeColor: _green, promo: promo, price: price);
    }
    if (movement.contains('DE') ||
        movement.contains('POR') ||
        movement.contains('PROMOCIONAL')) {
      String? promo;
      if (precoPromo != null && precoPromo > 0 && precoPromo < precoNormal) {
        promo = 'De ${_brl(precoNormal)} | Por ${_brl(precoPromo)}';
      }
      return (badge: 'DE/POR', badgeColor: _orange, promo: promo, price: null);
    }
    final price = precoNormal > 0 ? _brl(precoNormal) : widget.item.price;
    return (badge: 'COMUM', badgeColor: _grayBadge, promo: null, price: price);
  }

  Widget _statusBadge() {
    final s = widget.item.status.toUpperCase();
    if (s == 'IMPRESSA') return _Badge('IMPRESSA', _green);
    if (s == 'NÃO IMPRESSA' || s == 'NAO IMPRESSA')
      return _Badge('NÃO IMPRESSA', _redBrand);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final b = _badge();
    final showPrice = b.price != null;
    final showPromo = b.promo != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.item.checkbox,
                  activeColor: _greenCheckbox,
                  onChanged: (v) => widget.onChangedCheckbox(v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.item.description,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _descDark)),
                ),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _qtyGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _qty,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: _descDark),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => widget.onChangedQuantity(int.tryParse(v) ?? 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EAN: ${widget.item.ean} • Dep: ${widget.item.department}',
                    style: const TextStyle(fontSize: 10, color: _eanGray),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(),
              ],
            ),
            if (showPromo || showPrice) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(showPromo ? b.promo! : b.price!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(b.badge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.badgeColor)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.badge,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
