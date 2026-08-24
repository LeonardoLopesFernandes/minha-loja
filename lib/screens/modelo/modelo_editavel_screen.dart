import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:minhaloja/screens/modelo/composite_preview_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// IP/porta da impressora (socket RAW, igual ao MLoja).
const String _kPrinterIp = '10.25.168.24';
const int _kPrinterPort = 9100;

/// Espelha o fluxo multi-item da ModeloEditavelActivity do MLoja:
/// lista todos os itens com checkboxes, seletor de tamanho,
/// "GERAR PRÉ-VISUALIZAÇÃO" e "IMPRIMIR".
class ModeloEditavelScreen extends StatefulWidget {
  const ModeloEditavelScreen({super.key});

  @override
  State<ModeloEditavelScreen> createState() => _ModeloEditavelScreenState();
}

class _ModeloEditavelScreenState extends State<ModeloEditavelScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager session = SessionManager.instance!;

  List<PapeletaPrintingData> _items = [];
  List<bool> _selected = [];
  late String _size;
  bool _semOverlay = false;
  bool _modoEditavel = false;
  bool _modoVencimentos = false;
  bool _mostrarCheckbox = true;
  bool _hideGerarPreview = false;

  bool _sending = false;
  bool _gerando = false;

  /// Comum pura (não Vencimentos) → envio via API; demais → PDF via socket.
  bool _enviarApi = false;

  List<_ItemCtrls> _ctrls = [];

  static const List<String> _sizes = [
    Constants.signSize1x1,
    Constants.signSize2x1,
    Constants.signSize4x1,
    Constants.signSize6x1,
  ];

  @override
  void initState() {
    super.initState();
    _resolveArgs();
  }

  void _resolveArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final list = args['items'];
      if (list is List<PapeletaPrintingData>) {
        _items = List<PapeletaPrintingData>.from(list);
      } else if (args['printingData'] is PapeletaPrintingData) {
        _items = [args['printingData'] as PapeletaPrintingData];
      }
      _size = args['size'] ?? Constants.signSize4x1;
      if (!_sizes.contains(_size)) _size = Constants.signSize4x1;
      _semOverlay = args['semOverlay'] ?? false;
      _modoEditavel = args['modoEditavel'] ?? false;
      _modoVencimentos = args['modoVencimentos'] ?? false;
      _mostrarCheckbox = args['mostrarCheckbox'] ?? true;
      _hideGerarPreview = args['hideGerarPreview'] ?? false;
    }
    if (_items.isEmpty) {
      _items = [];
    }
    _selected = List.filled(_items.length, true);
    _ctrls = _items.map((d) => _ItemCtrls(d)).toList();
    _enviarApi = !_modoVencimentos && _items.every(_isComum);
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  PapeletaPrintingData _currentData(int i) {
    if (!_modoEditavel) return _items[i];
    final c = _ctrls[i];
    final d = _items[i];
    return d.copyWith(
      productName: c.name.text,
      price: _d(c.price.text, d.price),
      promotionPrice: _dOrNull(c.promo.text),
      takeAndWinQuantity: _iOrNull(c.twQty.text),
      takeAndWinPrice: _dOrNull(c.twPrice.text),
      installmentQuantity: _iOrNull(c.instQty.text),
      installmentPrice: _dOrNull(c.instPrice.text),
      ean: c.ean.text,
    );
  }

  double _d(String v, double fb) =>
      double.tryParse(v.replaceAll(',', '.')) ?? fb;
  double? _dOrNull(String v) =>
      v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.'));
  int? _iOrNull(String v) => v.trim().isEmpty ? null : int.tryParse(v);

  bool _isComum(PapeletaPrintingData d) {
    if (d.template == Constants.signTemplateDeporParcelado) return true;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasPromo || hasTW) return false;
    return true;
  }

  List<PapeletaPrintingData> _selecionados() {
    final sel = <PapeletaPrintingData>[];
    final val = <String>[];
    for (int i = 0; i < _items.length; i++) {
      if (!_mostrarCheckbox || _selected[i]) {
        sel.add(_currentData(i).copyWith(size: _size, quantity: 1));
        val.add(_ctrls[i].validade.text);
      }
    }
    _validadesSelecionadas = val;
    return sel;
  }

  List<String> _validadesSelecionadas = [];

  Future<void> _imprimir() async {
    final toSend = _selecionados();
    if (toSend.isEmpty) {
      ToastUtils.show(context, 'Nenhum item selecionado');
      return;
    }
    if (_enviarApi) {
      // Comum pura → envio via API (fiel ao MLoja).
      setState(() => _sending = true);
      try {
        await api.sendPriceSigns(
          session.getUserStore(),
          SendPriceSignRequest(products: toSend),
        );
        if (!mounted) return;
        ToastUtils.showSuccess(context, 'Papeletas enviadas para impressora');
        Navigator.pop(context, true);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          SessionExpiredHandler.handleSessionExpired(context);
        } else {
          ToastUtils.showError(context, e.message);
        }
      } catch (e) {
        ToastUtils.showError(context, 'Erro ao enviar papeletas');
        LogHelper.e('ModeloEditavel: erro ao enviar', e);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    } else {
      // Demais tipos (Promocional, Misto, Vencimentos) → gera PDF e envia
      // via socket RAW, igual ao MLoja.
      await _enviarViaSocket(toSend);
    }
  }

  Future<void> _enviarViaSocket(List<PapeletaPrintingData> toSend) async {
    setState(() => _sending = true);
    try {
      final pages = await buildCompositePages(
        api: api,
        items: toSend,
        size: _size,
        modoVencimentos: _modoVencimentos,
        validades: _validadesSelecionadas,
      );
      final pdfBytes = await _gerarPdfBytes(pages);
      final socket =
          await Socket.connect(_kPrinterIp, _kPrinterPort, timeout: const Duration(seconds: 5));
      socket.add(pdfBytes);
      await socket.flush();
      await socket.close();
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Papeletas enviadas para impressora');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao enviar via socket: ${e.toString()}');
      LogHelper.e('ModeloEditavel: erro socket', e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compartilharPdf() async {
    final toSend = _selecionados();
    if (toSend.isEmpty) {
      ToastUtils.show(context, 'Nenhum item selecionado');
      return;
    }
    setState(() => _gerando = true);
    try {
      final pages = await buildCompositePages(
        api: api,
        items: toSend,
        size: _size,
        modoVencimentos: _modoVencimentos,
        validades: _validadesSelecionadas,
      );
      final pdfBytes = await _gerarPdfBytes(pages);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/papeletas.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Papeletas',
      );
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError(context, 'Erro ao compartilhar PDF');
      LogHelper.e('ModeloEditavel: erro share', e);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<Uint8List> _gerarPdfBytes(List<Uint8List> pages) async {
    final doc = pw.Document();
    for (final png in pages) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(14),
          build: (context) => pw.Center(
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return await doc.save();
  }

  void _abrirPreviewItem(int i) {
    // A API não possui 6X1; usa 1X1 como base (mesmo do grid).
    final size = _size.toUpperCase() == Constants.signSize6x1
        ? Constants.signSize1x1
        : _size;
    Navigator.pushNamed(context, '/pdf_viewer', arguments: {
      'printingData': _currentData(i).copyWith(size: size),
    });
  }

  void _abrirPreviewTodos() {
    final sel = <PapeletaPrintingData>[];
    final valList = <String>[];
    for (int i = 0; i < _items.length; i++) {
      if (!_mostrarCheckbox || _selected[i]) {
        sel.add(_currentData(i).copyWith(size: _size));
        valList.add(_ctrls[i].validade.text);
      }
    }
    if (sel.isEmpty) {
      ToastUtils.show(context, 'Nenhum item selecionado');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompositePreviewScreen(
          items: sel,
          size: _size,
          modoVencimentos: _modoVencimentos,
          validades: valList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _modoVencimentos
        ? 'PAPELETA DE VENCIMENTOS'
        : 'PAPELETA ${_size.toUpperCase()}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Nenhum dado disponível'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildItemCard(i),
                  ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildItemCard(int i) {
    final d = _currentData(i);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  color: AppColors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ITEM ${i + 1}',
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_mostrarCheckbox)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Incluir'),
                      Checkbox(
                        value: _selected[i],
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => _selected[i] = v ?? false),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_modoEditavel) _buildEditableForm(i) else _buildSummary(d),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _abrirPreviewItem(i),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Ver pré-visualização'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(PapeletaPrintingData d) {
    final infos = <String>[
      d.productName,
      'Preço: R\$ ${d.price.toStringAsFixed(2)}',
      if (d.promotionPrice != null) 'Promo: R\$ ${d.promotionPrice!.toStringAsFixed(2)}',
      if (d.takeAndWinQuantity != null) 'Leve e Ganhe: ${d.takeAndWinQuantity}',
      'EAN: ${d.ean}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infos
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(t,
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ))
          .toList(),
    );
  }

  Widget _buildEditableForm(int i) {
    final c = _ctrls[i];
    final d = _items[i];
    final hasInst = d.installmentQuantity != null && d.installmentQuantity! > 0;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTake = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    final ehDePor = hasPromo && !hasTake && !hasInst;
    final ehComum = !hasPromo && !hasTake && !hasInst;

    Widget field(String label, TextEditingController ctrl,
        {TextInputType kb = TextInputType.text}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctrl,
          keyboardType: kb,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.cardBorder)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field('Nome do Produto', c.name),
        if (_modoVencimentos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: c.validade,
              keyboardType: TextInputType.number,
              inputFormatters: [_ValidadeMask()],
              decoration: InputDecoration(
                labelText: 'Validade (DD/MM/AAAA)',
                hintText: 'Ex: 10/08/2026',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder)),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: field('Preço', c.price,
                  kb: const TextInputType.numberWithOptions(decimal: true)),
            ),
            if (!ehComum)
              const SizedBox(width: 8),
            if (!ehComum)
              Expanded(
                child: field('Preço Promocional', c.promo,
                    kb: const TextInputType.numberWithOptions(decimal: true)),
              ),
          ],
        ),
        if (!ehDePor && !ehComum)
          Row(
            children: [
              Expanded(
                child: field(
                    hasInst ? 'Parcela (Qtd)' : 'Leve (Qtd)', c.twQty,
                    kb: TextInputType.number),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                    hasInst ? 'Valor da parcela' : 'Preço Leve e Ganhe',
                    c.twPrice,
                    kb: const TextInputType.numberWithOptions(decimal: true)),
              ),
            ],
          ),
        field('EAN', c.ean, kb: TextInputType.number),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: _sizes
                .map((s) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(s.replaceAll('X', '×'),
                              textAlign: TextAlign.center),
                          selected: _size == s,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _size == s ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _size = s),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!_hideGerarPreview)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _abrirPreviewTodos,
                    icon: const Icon(Icons.preview),
                    label:
                        Text('GERAR PRÉ-VISUALIZAÇÃO ${_size.toUpperCase()}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (!_hideGerarPreview) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _imprimir,
                  icon: const Icon(Icons.send),
                  label:
                      Text(_sending ? 'ENVIANDO...' : 'IMPRIMIR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gerando ? null : _compartilharPdf,
                  icon: const Icon(Icons.share),
                  label: Text(_gerando ? 'GERANDO...' : 'COMPARTILHAR PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemCtrls {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController promo = TextEditingController();
  final TextEditingController twQty = TextEditingController();
  final TextEditingController twPrice = TextEditingController();
  final TextEditingController instQty = TextEditingController();
  final TextEditingController instPrice = TextEditingController();
  final TextEditingController ean = TextEditingController();
  final TextEditingController validade = TextEditingController();

  _ItemCtrls(PapeletaPrintingData d) {
    name.text = d.productName;
    price.text = d.price.toString();
    promo.text = d.promotionPrice?.toString() ?? '';
    twQty.text = d.takeAndWinQuantity?.toString() ?? '';
    twPrice.text = d.takeAndWinPrice?.toString() ?? '';
    instQty.text = d.installmentQuantity?.toString() ?? '';
    instPrice.text = d.installmentPrice?.toString() ?? '';
    ean.text = d.ean;
  }

  void dispose() {
    name.dispose();
    price.dispose();
    promo.dispose();
    twQty.dispose();
    twPrice.dispose();
    instQty.dispose();
    instPrice.dispose();
    ean.dispose();
    validade.dispose();
  }
}

/// Pré-visualização paginada de todos os itens selecionados, gerando o PDF
/// de cada um via API (equivalente à grade composta no Kotlin).
class _PreviewAllScreen extends StatefulWidget {
  final List<PapeletaPrintingData> items;
  final String size;
  const _PreviewAllScreen({required this.items, required this.size});

  @override
  State<_PreviewAllScreen> createState() => _PreviewAllScreenState();
}

class _PreviewAllScreenState extends State<_PreviewAllScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Pré-visualização (${_page + 1}/${widget.items.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => _PreviewPage(
          key: ValueKey(i),
          api: api,
          data: widget.items[i],
        ),
      ),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  final ApiService api;
  final PapeletaPrintingData data;
  const _PreviewPage({super.key, required this.api, required this.data});

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await widget.api.previewPriceSign(widget.data);
      if (!mounted) return;
      final dataUrl =
          'data:application/pdf;base64,${base64Encode(bytes)}';
      await _controller.loadRequest(Uri.parse(dataUrl));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao gerar PDF');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: AppTextStyles.body),
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }
}

/// Máscara de validade DD/MM/AAAA (igual ao comportamento do MLoja).
class _ValidadeMask extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.length),
    );
  }
}
