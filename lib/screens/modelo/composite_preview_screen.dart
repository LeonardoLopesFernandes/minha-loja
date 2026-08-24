import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:pdf_render/pdf_render.dart';

/// Pré-visualização composta (grade) espelhando a ModeloEditavelActivity do
/// MLoja: rasteriza o PDF de cada item via API e o sobrepõe sobre o overlay
/// PNG correspondente ao tamanho, exatamente como o Kotlin faz com canvas.
class CompositePreviewScreen extends StatefulWidget {
  final List<PapeletaPrintingData> items;
  final String size;
  final bool modoVencimentos;
  final List<String> validades;
  const CompositePreviewScreen({
    super.key,
    required this.items,
    required this.size,
    this.modoVencimentos = false,
    this.validades = const [],
  });

  @override
  State<CompositePreviewScreen> createState() => _CompositePreviewScreenState();
}

class _CompositePreviewScreenState extends State<CompositePreviewScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  int _cols = 2;
  int _rows = 2;
  int _page = 0;
  List<Uint8List> _pages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _configureGrid() {
    final s = widget.size.toUpperCase().replaceAll('×', 'X');
    switch (s) {
      case '1X1':
        _cols = 1;
        _rows = 1;
        break;
      case '2X1':
        _cols = 2;
        _rows = 1;
        break;
      case '6X1':
        _cols = 3;
        _rows = 2;
        break;
      case '4X1':
      default:
        _cols = 2;
        _rows = 2;
        break;
    }
  }

  Future<void> _generate() async {
    try {
      _configureGrid();
      _pages = await buildCompositePages(
        api: api,
        items: widget.items,
        size: widget.size,
        modoVencimentos: widget.modoVencimentos,
        validades: widget.validades,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      LogHelper.e('Composite: erro geral', e);
      if (mounted) {
        setState(() {
          _error = 'Erro ao gerar pré-visualização composta.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pré-visualização (${_page + 1}/${_pages.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
    if (_error != null || _pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error ?? 'Nada para exibir',
              style: AppTextStyles.body, textAlign: TextAlign.center),
        ),
      );
    }
    return PageView.builder(
      itemCount: _pages.length,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (_, i) => InteractiveViewer(
        child: Image.memory(_pages[i], fit: BoxFit.contain),
      ),
    );
  }
}

bool _ehComum(PapeletaPrintingData d) {
  if (d.template == Constants.signTemplateDeporParcelado) return true;
  final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
  final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
  if (hasPromo || hasTW) return false;
  return true;
}

/// Gera as páginas compostas (grade sobre overlay) como imagens, fiel ao
/// gerarPreviewMulti / gerarPreviewVencimentos do Kotlin.
Future<List<Uint8List>> buildCompositePages({
  required ApiService api,
  required List<PapeletaPrintingData> items,
  required String size,
  required bool modoVencimentos,
  required List<String> validades,
  bool semOverlay = false,
}) async {
  final s = size.toUpperCase().replaceAll('×', 'X');
  int cols = 2;
  int rows = 2;
  switch (s) {
    case '1X1':
      cols = 1;
      rows = 1;
      break;
    case '2X1':
      cols = 2;
      rows = 1;
      break;
    case '6X1':
      cols = 3;
      rows = 2;
      break;
    case '4X1':
    default:
      cols = 2;
      rows = 2;
      break;
  }

  final overlayData =
      await rootBundle.load('assets/overlays/${s.toLowerCase()}.png');
  final overlay = img.decodeImage(overlayData.buffer.asUint8List());

  final gridCap = cols * rows;
  final total = items.length;
  final pageCount = total == 0 ? 1 : (total / gridCap).ceil();
  final out = <Uint8List>[];

  for (int p = 0; p < pageCount; p++) {
    final ovW = overlay?.width ?? 850;
    final ovH = overlay?.height ?? 1200;
    final base = img.Image(width: ovW, height: ovH,
        numChannels: 4, format: img.Format.uint8);
    if (overlay != null && !semOverlay) {
      img.compositeImage(base, overlay);
    } else {
      img.fill(base, color: img.ColorRgb8(255, 255, 255));
    }
    final halfW = (ovW / cols).floor();
    final halfH = (ovH / rows).floor();

    for (int idx = p * gridCap; idx < total && idx < (p + 1) * gridCap; idx++) {
      final item = items[idx];
      final local = idx % gridCap;
      final col = local % cols;
      final row = local ~/ cols;
      final left = col * halfW;
      final top = row * halfH;
      final validade = validades.length > idx ? validades[idx] : null;
      try {
        final raster = await _rasterizeCard(
            api, item, halfW, halfH, validade, modoVencimentos);
        if (raster != null) {
          img.compositeImage(base, raster, dstX: left, dstY: top);
        }
      } catch (e) {
        LogHelper.e('Composite: erro item $idx', e);
      }
    }
    out.add(img.encodePng(base));
  }
  return out;
}

Future<img.Image?> _rasterizeCard(ApiService api, PapeletaPrintingData data,
    int w, int h, String? validade, bool modoVencimentos) async {
  // O Kotlin sempre gera o PDF de cada célula em 1X1 e compõe a grade
  // conforme o tamanho selecionado (ex.: 3x2 para 6X1, já que a API não
  // possui 6X1).
  final bytes =
      await api.previewPriceSign(data.copyWith(size: Constants.signSize1x1));
  final doc = await PdfDocument.openData(bytes);
  try {
    if (doc.pageCount < 1) return null;
    final page = await doc.getPage(1);
    final pi = await page.render(width: w, height: h);
    final raster = img.Image.fromBytes(
        width: pi.width, height: pi.height, bytes: pi.pixels.buffer, format: img.Format.uint8);
    if (modoVencimentos &&
        validade != null &&
        validade.trim().isNotEmpty) {
      return await _drawVencimento(raster, validade.trim(), w, h);
    }
    return raster;
  } finally {
    doc.dispose();
  }
}

/// Desenha "VAL.: <data>" e o rodapé fixo "PRÓXIMO DA VALIDADE. CONSUMO
/// RÁPIDO" sobre a papeleta, espelhando o desenharValidadeCard do Kotlin.
Future<img.Image> _drawVencimento(
    img.Image raster, String validade, int w, int h) async {
  final uiImg = await decodeImageFromList(img.encodePng(raster));
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
      recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.srcOver);
  canvas.drawImageRect(
    uiImg,
    Rect.fromLTWH(0, 0, uiImg.width.toDouble(), uiImg.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint(),
  );
  final valText = 'VAL.: ${_formatValidade(validade)}'.toUpperCase();
  _drawCentered(canvas, w, h * 0.34, valText,
      fontSize: (w * 0.05).clamp(14, 48).toDouble(), bold: true);
  _drawCentered(canvas, w, h * 0.93, 'PRÓXIMO DA VALIDADE. CONSUMO RÁPIDO',
      fontSize: (w * 0.028).clamp(8, 26).toDouble(), bold: true);
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  final pngOut = (await out.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  uiImg.dispose();
  return img.decodeImage(pngOut)!;
}

void _drawCentered(ui.Canvas canvas, int w, double y, String text,
    {required double fontSize, required bool bold}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const ui.Color(0xFFD32F2F),
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: 0, maxWidth: w.toDouble());
  tp.paint(canvas, Offset((w - tp.width) / 2, y - tp.height / 2));
}

String _formatValidade(String v) {
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 8) {
    return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
  }
  return v;
}
