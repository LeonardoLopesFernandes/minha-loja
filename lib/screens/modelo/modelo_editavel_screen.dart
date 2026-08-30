import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/screens/modelo/composite_preview_screen.dart';
import 'package:minhaloja/utils/crash_logger.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// IP/porta da impressora (socket RAW, igual ao MLoja).
const String _kPrinterIp = '10.25.168.24';
const int _kPrinterPort = 9100;

/// Paleta fiel à ModeloEditavelActivity do MLoja (cores do app Android).
const Color _kRed = Color(0xFFC62828);
const Color _kDarkRed = Color(0xFF8E0000);
const Color _kBg = Color(0xFFF4F6F8);
const Color _kPreviewBg = Color(0xFFEEEEEE);

/// Espelha a ModeloEditavelActivity do MLoja: tela sem AppBar com título
/// centralizado, card de pré-visualização composta embutido, opção de
/// overlay promocional, quantidade de cópias, seção "EDITAR ITENS" (no modo
/// editável) e barra fixa com VOLTAR / IMPRIMIR / COMPARTILHAR PDF.
class ModeloEditavelScreen extends StatefulWidget {
  const ModeloEditavelScreen({super.key});

  @override
  State<ModeloEditavelScreen> createState() => _ModeloEditavelScreenState();
}

class _ModeloEditavelScreenState extends State<ModeloEditavelScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager session = SessionManager.instance!;

  List<PapeletaPrintingData> _items = [];
  late String _size;
  bool _semOverlay = false;
  bool _modoEditavel = false;
  bool _modoVencimentos = false;
  bool _mostrarOverlay = true;

  bool _sending = false;
  bool _gerando = false;
  bool _loadingPreview = false;
  String? _errorPreview;
  Timer? _hb;

  /// Comum pura (não Vencimentos) → envio via API; demais → PDF via socket.
  late bool _enviarApi;

  List<_ItemCtrls> _ctrls = [];
  List<Uint8List> _pages = [];
  int _page = 0;
  final TextEditingController _copiaCtrl = TextEditingController(text: '1');
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _resolveArgs();
  }

  @override
  void dispose() {
    _hb?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    _copiaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
      _size = (args['size'] ?? Constants.signSize4x1).toString();
      _size = _size.replaceAll('×', 'X').toUpperCase();
      _semOverlay = args['semOverlay'] ?? false;
      _modoEditavel = args['modoEditavel'] ?? false;
      _modoVencimentos = args['modoVencimentos'] ?? false;
      _mostrarOverlay = args['mostrarCheckboxOverlay'] ?? true;
    }
    if (_items.isEmpty) {
      _items = [];
    }
    _ctrls = _items.map((d) => _ItemCtrls(d)).toList();
    _enviarApi = !_modoVencimentos && _items.every(_isComum);
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

  int get _copias {
    final v = int.tryParse(_copiaCtrl.text);
    return (v == null || v < 1) ? 1 : v;
  }

  List<PapeletaPrintingData> _selecionados() {
    final out = <PapeletaPrintingData>[];
    for (int i = 0; i < _items.length; i++) {
      out.add(_currentData(i).copyWith(size: _size, quantity: _copias));
    }
    return out;
  }

  List<String> _validades() =>
      [for (int i = 0; i < _items.length; i++) _ctrls[i].validade.text];

  List<Uint8List> _comCopias(List<Uint8List> pages) {
    if (_copias <= 1) return pages;
    final out = <Uint8List>[];
    for (var i = 0; i < _copias; i++) {
      out.addAll(pages);
    }
    return out;
  }

  Future<void> _gerarPreview() async {
    // Trava de reentrada: toques repetidos não disparam gerações concorrentes
    // (threads nativas simultâneas derrubavam o app por memória/ANR).
    if (_loadingPreview || _items.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingPreview = true;
      _errorPreview = null;
    });
    try {
      final list = _selecionados();
      await CrashLogger
          .step('modelo: iniciando geracao itens=${list.length} $_size');
      // Heartbeat de 1s por 90s: se os hb pararem no log, a main thread
      // congelou (ANR); se continuarem, o travamento está fora do Dart.
      _hb?.cancel();
      var n = 0;
      _hb = Timer.periodic(const Duration(seconds: 1), (t) {
        CrashLogger.step('hb ${++n}');
        if (n >= 90) t.cancel();
      });
      _pages = await buildCompositePages(
        api: api,
        items: list,
        size: _size,
        modoVencimentos: _modoVencimentos,
        validades: _validades(),
        semOverlay: _semOverlay,
        previewScale: 1.0,
        // Diagnóstico concluído: crash era na textura de exibição; preview
        // sai em ≤1536px (JPEG) e impressão/compartilhamento seguem full-res.
        jpegPreview: true,
        displayMaxDim: 1280,
      );
      _page = 0;
      if (mounted) setState(() => _loadingPreview = false);
      await CrashLogger.step(
          'modelo: exibindo ${_pages.length} pagina(s)');
    } catch (e) {
      await CrashLogger.write('ModeloPreview', '$e');
      LogHelper.e('ModeloEditavel: erro preview', e);
      if (mounted) {
        setState(() {
          _errorPreview = 'Erro ao gerar pré-visualização';
          _loadingPreview = false;
        });
      }
    }
  }

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
      // Demais tipos → gera PDF e envia via socket RAW (igual ao MLoja).
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
        validades: _validades(),
        semOverlay: _semOverlay,
      );
      final pdfBytes = await _gerarPdfBytes(_comCopias(pages));
      final socket = await Socket.connect(_kPrinterIp, _kPrinterPort,
          timeout: const Duration(seconds: 5));
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
        validades: _validades(),
        semOverlay: _semOverlay,
      );
      final pdfBytes = await _gerarPdfBytes(_comCopias(pages));
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
          margin: const pw.EdgeInsets.all(14.0),
          build: (context) => pw.Center(
            child: pw.Image(pw.MemoryImage(png)),
          ),
        ),
      );
    }
    return await doc.save();
  }

  String get _titulo => _modoVencimentos
      ? 'PAPELETA DE VENCIMENTOS'
      : 'PAPELETA ${_size.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final previewH = (h * 0.55).clamp(280.0, 620.0);
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _kRed,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    _buildPreviewCard(previewH),
                    if (_modoEditavel) _buildEditarItens(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(double previewH) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'PRÉ-VISUALIZAÇÃO',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _kRed,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: previewH,
            color: _kPreviewBg,
            child: _buildPreviewArea(),
          ),
          if (_mostrarOverlay) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                setState(() => _semOverlay = !_semOverlay);
                _gerarPreview();
              },
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: !_semOverlay,
                      activeColor: _kRed,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        setState(() => _semOverlay = !(v ?? false));
                        _gerarPreview();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Usar overlay promocional',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Qtd. Cópias:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                height: 36,
                child: TextField(
                  controller: _copiaCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: const InputDecoration(
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _loadingPreview ? null : _gerarPreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'GERAR PRÉ-VISUALIZAÇÃO ${_size.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_loadingPreview) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Compondo pré-visualização...'),
          ],
        ),
      );
    }
    if (_errorPreview != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_errorPreview!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_pages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Clique em GERAR PRÉ-VISUALIZAÇÃO para visualizar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => CrashLogger.step('modelo: touch'),
          child: PageView.builder(
          itemCount: _pages.length,
          onPageChanged: (i) {
            CrashLogger.step('modelo: swipe pagina $i');
            setState(() => _page = i);
          },
          itemBuilder: (_, i) {
            // TESTE BINÁRIO: oculta a imagem para provar se o crash está na
            // exibição ou alhures. _kPreviewMostraImagem = false -> placeholder.
            const _kPreviewMostraImagem = true;
            CrashLogger.step('modelo: montando pagina $i (img=$_kPreviewMostraImagem)');
            final img = _kPreviewMostraImagem
                ? Image.memory(
                    _pages[i],
                    fit: BoxFit.contain,
                    cacheWidth: (MediaQuery.of(context).size.width *
                            MediaQuery.of(context).devicePixelRatio)
                        .round()
                        .clamp(720, 2160),
                    gaplessPlayback: true,
                    errorBuilder: (_, e, __) {
                      CrashLogger.write('ImageDecodeModelo', 'pagina $i: $e');
                      return const Icon(Icons.broken_image, size: 64);
                    },
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported, size: 64),
                      const SizedBox(height: 8),
                      Text('Preview oculto (teste) — página ${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  );
            return InteractiveViewer(maxScale: 4, child: img);
          },
        ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_page + 1} / ${_pages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditarItens() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'EDITAR ITENS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kRed,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._items.asMap().entries.map((e) => _buildItemFormCard(e.key)),
      ],
    );
  }

  Widget _buildItemFormCard(int i) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  color: _kRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'ITEM ${i + 1}',
                  style: const TextStyle(
                    color: _kRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildEditableForm(i),
          ],
        ),
      ),
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
                    borderSide: const BorderSide(color: AppColors.cardBorder)),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: field('Preço', c.price,
                  kb: const TextInputType.numberWithOptions(decimal: true)),
            ),
            if (!ehComum) const SizedBox(width: 8),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: const BorderSide(color: _kRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('VOLTAR',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _sending ? null : _imprimir,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_sending ? 'ENVIANDO...' : 'IMPRIMIR',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _gerando ? null : _compartilharPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDarkRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(_gerando ? 'GERANDO...' : 'COMPARTILHAR PDF',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
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
