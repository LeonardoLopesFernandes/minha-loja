import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;
import 'package:image/image.dart' as img;
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:pdf_render/pdf_render.dart';

/// Pré-visualização composta espelhando fielmente a ModeloEditavelActivity do
/// MLoja: o PDF de cada item é renderizado pela API, o branco é removido
/// (removerBrancoSuave) e o conteúdo é centralizado (centralizarConteudo) sobre
/// o overlay, exatamente como o Kotlin faz com canvas.
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
    final ovW = overlay?.width ?? (cols > rows ? 1200 : 850);
    final ovH = overlay?.height ?? (cols > rows ? 850 : 1200);
    final base = img.Image(width: ovW, height: ovH,
        numChannels: 4, format: img.Format.uint8);
    if (!semOverlay && overlay != null) {
      img.compositeImage(base, overlay);
    } else {
      img.fill(base, color: img.ColorRgb8(255, 255, 255));
    }
    final halfW = (ovW / cols).floor();
    final halfH = (ovH / rows).floor();

    final shiftYVenc =
        cols > rows ? 0.015 : (cols == 2 && rows == 2 ? 0.01 : 0.03);

    for (int idx = p * gridCap; idx < total && idx < (p + 1) * gridCap; idx++) {
      final item = items[idx];
      final local = idx % gridCap;
      final col = local % cols;
      final row = local ~/ cols;
      final left = col * halfW;
      final top = row * halfH;
      final ehComum = _ehComum(item);
      final validade = validades.length > idx ? validades[idx] : null;

      img.Image? raster;
      try {
        raster = await _rasterizeCard(api, item, halfW, halfH);
      } catch (e) {
        LogHelper.e('Composite: erro item $idx', e);
      }
      if (raster == null) continue;

      if (modoVencimentos &&
          validade != null &&
          validade.trim().isNotEmpty) {
        raster = await _drawVencimento(raster, validade.trim(), halfW, halfH);
      }

      if (modoVencimentos) {
        // Vencimentos: overlay é desenhado por célula (apenas não-comum).
        if (!semOverlay && overlay != null && !ehComum) {
          img.compositeImage(base, overlay,
              dstX: left, dstY: top, dstW: halfW, dstH: halfH);
          _centralizarConteudo(
              base, raster, halfW, halfH, left, top, 0.35, 0.0, shiftYVenc);
        } else {
          if (!semOverlay && overlay != null) {
            _fillCell(base, left, top, halfW, halfH);
          }
          _centralizarConteudo(
              base, raster, halfW, halfH, left, top, 1.0, 0.03, 0.0);
        }
      } else {
        // Multi: overlay cobre a página toda; comum recebe fundo branco.
        if (ehComum && !semOverlay && overlay != null) {
          _fillCell(base, left, top, halfW, halfH);
        }
        final ignorar = ehComum ? 0.03 : 0.0;
        final shiftY = ehComum ? 0.0 : (cols > rows ? 0.015 : 0.03);
        _centralizarConteudo(
            base, raster, halfW, halfH, left, top, 1.0, ignorar, shiftY);
      }
    }
    out.add(img.encodePng(base));
  }
  return out;
}

/// Pinta um retângulo branco na célula (esconde o overlay, p/ itens comuns).
void _fillCell(img.Image base, int left, int top, int w, int h) {
  final white = img.Image(width: w, height: h, numChannels: 4, format: img.Format.uint8);
  img.fill(white, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(base, white, dstX: left, dstY: top, dstW: w, dstH: h);
}

/// Equivalente ao removerBrancoSuave do Kotlin: torna o branco suave
/// transparente para que o overlay apareça através do conteúdo.
void _removerBrancoSuave(img.Image src) {
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final a = p.a;
      if (a < 200) continue;
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final minRGB = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (minRGB >= 200) {
        final t = ((minRGB - 200) / 55).clamp(0.0, 1.0);
        final newA = (a * (1 - t * 0.95)).round().clamp(0, 255);
        if (newA < 4) {
          src.setPixelRgba(x, y, r, g, b, 0);
        } else {
          src.setPixelRgba(x, y, r, g, b, newA);
        }
      }
    }
  }
}

/// Equivalente ao desenharComProporcao/centralizarConteudo do Kotlin: aplica
/// escala UNIFORME (preserva proporção, igual ao min(cellW/w, cellH/h) do
/// Android) e centraliza o conteúdo não-branco dentro da célula. Evita a
/// distorção que ocorria ao esticar o bitmap para cellW x cellH.
void _centralizarConteudo(img.Image base, img.Image bmp, int cellW, int cellH,
    int left, int top, double maxShiftFrac, double ignorarBordasFrac, double shiftYFrac) {
  final w = bmp.width;
  final h = bmp.height;
  final targetW = w < 800 ? w : 800;
  final targetH = (h * targetW / w).round().clamp(1, 100000);
  final small = (targetW < w) ? img.copyResize(bmp, width: targetW, height: targetH) : bmp;
  final sw = small.width;
  final sh = small.height;
  final bx0 = (sw * ignorarBordasFrac).round();
  final bx1 = (sw * (1 - ignorarBordasFrac)).round();
  final by0 = (sh * ignorarBordasFrac).round();
  final by1 = (sh * (1 - ignorarBordasFrac)).round();
  int minX = sw;
  int maxX = -1;
  int minY = sh;
  int maxY = -1;
  for (int y = by0; y < by1; y += 2) {
    for (int x = bx0; x < bx1; x += 2) {
      final p = small.getPixel(x, y);
      if (p.a > 8 && (p.r < 250 || p.g < 250 || p.b < 250)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  // Escala uniforme (contain) — fiel ao desenharComProporcao do Kotlin.
  final scale = (cellW / w < cellH / h) ? (cellW / w) : (cellH / h);
  final dw = w * scale;
  final dh = h * scale;
  final dlBase = left + ((cellW - dw) / 2);
  final dtBase = top - cellH * shiftYFrac + ((cellH - dh) / 2);

  late int dstX;
  late int dstY;
  if (maxX <= minX || maxY <= minY) {
    dstX = dlBase.round();
    dstY = dtBase.round();
  } else {
    final scaleX = dw / sw;
    final scaleY = dh / sh;
    final contentW = (maxX - minX + 1) * scaleX;
    final contentH = (maxY - minY + 1) * scaleY;
    final dx = (((dw - contentW) / 2) - minX * scaleX)
        .clamp(-dw * maxShiftFrac, dw * maxShiftFrac);
    final dy = (((dh - contentH) / 2) - minY * scaleY)
        .clamp(-dh * maxShiftFrac, dh * maxShiftFrac);
    dstX = (dlBase + dx).round();
    dstY = (dtBase + dy).round();
  }

  img.compositeImage(base, bmp,
      dstX: dstX, dstY: dstY, dstW: dw.round(), dstH: dh.round());
}

Future<img.Image?> _rasterizeCard(
    ApiService api, PapeletaPrintingData data, int w, int h) async {
  // O Kotlin sempre gera o PDF de cada célula em 1X1 e compõe a grade
  // conforme o tamanho selecionado (ex.: 3x2 para 6X1, já que a API não
  // possui 6X1).
  final bytes =
      await api.previewPriceSign(data.copyWith(size: Constants.signSize1x1));

  // Renderiza via PdfRenderer do Android (canal de plataforma), fiel ao MLoja.
  // O pdf_render (Pdfium próprio) desenha a camada de widget de formulário por
  // cima do conteúdo estático, duplicando textos/preços; o PdfRenderer do
  // sistema com RENDER_MODE_FOR_PRINT não, igual ao app nativo.
  final platformRaster = await _renderViaPlatform(bytes, w, h);
  if (platformRaster != null) {
    _removerBrancoSuave(platformRaster);
    return platformRaster;
  }

  // Fallback: pdf_render.
  final doc = await PdfDocument.openData(bytes);
  try {
    if (doc.pageCount < 1) return null;
    final page = await doc.getPage(1);
    // Fiel ao renderPdfToBitmap do MLoja (ModeloEditavelActivity.kt:541): a
    // página é renderizada em sua PROPORÇÃO NATIVA (page.width*scale x
    // page.height*scale, scale = min(ceil(w/pageW), ceil(h/pageH), 8),
    // renderWidth<=7200). O bitmap resultante TEM a proporção do PDF; quem
    // estica para preencher a célula é o centralizarConteudo, exatamente como
    // no Android. Assim a visualização fica idêntica à do MLoja.
    final pw = page.width;
    final ph = page.height;
    if (pw <= 0 || ph <= 0) return null;
    int scale = (w / pw).ceil();
    final ch = (h / ph).ceil();
    if (ch < scale) scale = ch;
    if (scale > 8) scale = 8;
    if (scale < 1) scale = 1;
    int renderWidth = (pw * scale).round();
    if (renderWidth > 7200) renderWidth = 7200;
    final renderHeight = (ph * (renderWidth / pw)).round();
    final pi = await page.render(width: renderWidth, height: renderHeight);
    final raster = img.Image.fromBytes(
        width: pi.width,
        height: pi.height,
        bytes: pi.pixels.buffer,
        format: img.Format.uint8);
    _removerBrancoSuave(raster);
    return raster;
  } finally {
    doc.dispose();
  }
}

const _pdfChannel = MethodChannel('minhaloja/pdf');

/// Renderiza o PDF da API usando o PdfRenderer do Android (igual ao MLoja),
/// retornando o bitmap em PNG (compacto). Retorna null se o canal não
/// estiver disponível (ex.: fora do Android) para usar o fallback pdf_render.
/// Em caso de erro, registra o motivo (não silencia) para facilitar o diagnóstico.
Future<img.Image?> _renderViaPlatform(Uint8List bytes, int w, int h) async {
  try {
    final res = await _pdfChannel.invokeMethod<Map<dynamic, dynamic>>(
      'renderPdfToRgba',
      {'bytes': bytes, 'w': w, 'h': h},
    );
    if (res == null) {
      LogHelper.e('Composite: canal minhaloja/pdf retornou null');
      return null;
    }
    final rw = res['width'] as int? ?? 0;
    final rh = res['height'] as int? ?? 0;
    final data = res['bytes'] as Uint8List?;
    if (rw <= 0 || rh <= 0 || data == null || data.isEmpty) {
      LogHelper.e('Composite: dados da plataforma invalidos (rw=$rw rh=$rh)');
      return null;
    }
    final decoded = img.decodeImage(data);
    if (decoded == null) {
      LogHelper.e('Composite: falha ao decodificar PNG da plataforma');
      return null;
    }
    return decoded;
  } catch (e, st) {
    LogHelper.e('Composite: render via plataforma falhou', '$e\n$st');
    return null;
  }
}

/// Desenha "VAL.: <data>" e o rodapé fixo "PRÓXIMO DA VALIDADE. CONSUMO
/// RÁPIDO" sobre a papeleta, espelhando o desenharValidadeCard do Kotlin.
/// Fundo transparente (não pinta branco) para compor sobre o overlay.
Future<img.Image> _drawVencimento(
    img.Image raster, String validade, int w, int h) async {
  final uiImg = await decodeImageFromList(img.encodePng(raster));
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
      recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
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
