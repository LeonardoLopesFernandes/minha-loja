import 'dart:convert';
import 'dart:io';
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
import 'package:minhaloja/utils/crash_logger.dart';
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
        previewScale: 1.0,
        jpegPreview: true,
        displayMaxDim: 1280,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      await CrashLogger
          .step('exibindo ${_pages.length} pagina(s)');
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
      onPageChanged: (i) {
        CrashLogger.step('swipe preview pagina $i');
        setState(() => _page = i);
      },
      itemBuilder: (_, i) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final cw =
            (MediaQuery.of(context).size.width * dpr).round().clamp(720, 2160);
        return Image.memory(
          _pages[i],
          fit: BoxFit.contain,
          cacheWidth: cw,
          gaplessPlayback: true,
          errorBuilder: (_, e, __) {
            CrashLogger.write('ImageDecode', 'pagina $i: $e');
            return const Icon(Icons.broken_image, size: 64);
          },
        );
      },
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
  double previewScale = 1.0,
  bool jpegPreview = false,
  int displayMaxDim = 0,
  int? targetCanvasW,
  int? targetCanvasH,
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
  final overlayRaw = img.decodeImage(overlayData.buffer.asUint8List());
  final overlay = overlayRaw != null
      ? img.copyResize(overlayRaw, width: halfW * cols, height: halfH * rows,
          interpolation: img.Interpolation.cubic)
      : null;

  // Misto: overlay 1x1 para desenhar por célula (promo recebe, comum não).
  img.Image? overlay1x1;
  if (s != '1X1') {
    final ov1x1Data = await rootBundle.load('assets/overlays/1x1.png');
    final ov1x1Raw = img.decodeImage(ov1x1Data.buffer.asUint8List());
    overlay1x1 = ov1x1Raw != null
        ? img.copyResize(ov1x1Raw, width: halfW, height: halfH,
            interpolation: img.Interpolation.cubic)
        : null;
  }

  final gridCap = cols * rows;
  final total = items.length;
  final pageCount = total == 0 ? 1 : (total / gridCap).ceil();
  final out = <Uint8List>[];

  for (int p = 0; p < pageCount; p++) {
    // Detecta Misto: página contém comum + promo mixados.
    final pageStart = p * gridCap;
    final pageEnd = (pageStart + gridCap).clamp(0, total);
    var hasComumPage = false;
    var hasPromoPage = false;
    for (var pi = pageStart; pi < pageEnd; pi++) {
      if (_ehComum(items[pi])) {
        hasComumPage = true;
      } else {
        hasPromoPage = true;
      }
      if (hasComumPage && hasPromoPage) break;
    }
    final isMisto = !modoVencimentos && hasComumPage && hasPromoPage;

    final ovW0 = targetCanvasW ?? overlay?.width ?? (cols > rows ? 1200 : 850);
    final ovH0 = targetCanvasH ?? overlay?.height ?? (cols > rows ? 850 : 1200);
    // previewScale < 1 deixa o preview mais rápido (menor resolução).
    // Quando targetCanvasW/H são fornecidos (A4 1200 DPI), previewScale é ignorado.
    final scale = (targetCanvasW != null || targetCanvasH != null)
        ? 1.0
        : (previewScale > 0 ? previewScale.clamp(0.1, 4.0) : 1.0);
    final ovW = (ovW0 * scale).round().clamp(1, 100000);
    final ovH = (ovH0 * scale).round().clamp(1, 100000);
    final base = img.Image(width: ovW, height: ovH,
        numChannels: 4, format: img.Format.uint8);
    // Misto: fundo branco + overlay 1x1 individual por célula (não full-page).
    if (!isMisto && !semOverlay && overlay != null) {
      img.compositeImage(base, overlay, dstW: ovW, dstH: ovH);
    } else {
      img.fill(base, color: img.ColorRgb8(255, 255, 255));
    }
    final halfW = (ovW / cols).floor();
    final halfH = (ovH / rows).floor();

    final isLandscape = cols > rows;
    // MLoja (ModeloEditavelActivity): deslocamento vertical por tamanho.
    // Vencimentos: landscape 0,015 / 2x2 0,01 / outro 0,03.
    // Multi: landscape 0,015 / outro 0,03.
    final shiftYVenc =
        isLandscape ? 0.015 : (cols == 2 && rows == 2 ? 0.01 : 0.03);
    final shiftYMulti = isLandscape ? 0.015 : 0.03;

    // ---- Caminho NATIVO (rápido, igual ao MLoja): envia os PDFs da API
    // (payload pequeno) ao Kotlin, que renderiza cada célula via PdfRenderer,
    // compõe a página num único Canvas e grava o PNG em cache. O canal só
    // trafega o caminho do arquivo — sem pixels grandes em nenhuma direção.
    // Se falhar, cai no pipeline legado em Dart logo abaixo.
    try {
      final idxN = <int>[];
      for (int idx = p * gridCap; idx < total && idx < (p + 1) * gridCap; idx++) {
        idxN.add(idx);
      }
      final pdfBytes = List<Uint8List?>.filled(idxN.length, null);
      var nx = 0;
      Future<void> wk() async {
        while (true) {
          final i = nx++;
          if (i >= idxN.length) return;
          final idx = idxN[i];
          try {
            final key = _pdfCacheKey(items[idx]);
            final cached = key == null ? null : _pdfApiCache[key];
            if (cached != null) {
              pdfBytes[i] = cached;
            } else {
              final b = await api.previewPriceSign(
                  items[idx].copyWith(size: Constants.signSize1x1));
              pdfBytes[i] = b;
              if (key != null) {
                if (_pdfApiCache.length > 60) {
                  _pdfApiCache.remove(_pdfApiCache.keys.first);
                }
                _pdfApiCache[key] = b;
              }
            }
          } catch (e) {
            LogHelper.e('Composite: erro item $idx', e);
          }
        }
      }

      await Future.wait(List.generate(2, (_) => wk()));
      final multiCellN = cols * rows > 1;
      final comums = <int>[];
      final tops = <double>[];
      final vds = <String>[];
      final payload = <Uint8List>[];
      for (var i = 0; i < idxN.length; i++) {
        final idx = idxN[i];
        final comum = _ehComum(items[idx]);
        comums.add(comum ? 1 : 0);
        tops.add(
            comum ? 0.25 : (multiCellN ? 0.28 : 0.25));
        vds.add(validades.length > idx ? validades[idx] : '');
        payload.add(pdfBytes[i] ?? Uint8List(0));
      }
      final overlayName = isMisto
          ? 'assets/overlays/1x1.png'
          : 'assets/overlays/${s.toLowerCase()}.png';
      final res = await _pdfChannel.invokeMethod<Map<dynamic, dynamic>>(
          'composePage', {
        'pdfs': payload,
        'cols': cols,
        'rows': rows,
        'cellW': halfW,
        'cellH': halfH,
        'overlay': overlayName,
        'semOverlay': semOverlay,
        'vencimentos': modoVencimentos,
        'misto': isMisto,
        'comums': comums,
        'topFracs': tops,
        'validades': vds,
        'shiftVenc': shiftYVenc,
        'shiftMulti': shiftYMulti,
        'format': jpegPreview ? 'jpeg' : 'png',
        'maxDim': displayMaxDim,
      });
      await CrashLogger.step('composePage ok pagina $p');
      final path = res?['path'] as String?;
      await CrashLogger.step('path recebido pagina $p: ${path == null}');
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        await CrashLogger.step('lendo arquivo pagina $p');
        out.add(await f.readAsBytes());
        try {
          await f.delete();
        } catch (_) {
          await CrashLogger.step('delete falhou pagina $p (seguindo)');
        }
        continue;
      }
    } catch (e) {
      await CrashLogger.write(
          'ComposeFallback', 'pagina $p: $e');
      LogHelper.e(
          'Composite: composePage nativo falhou; usando pipeline Dart',
          e.toString());
    }

    // Pipeline anti-OOM: busca+render em PARALELO com concorrência 2 (mesma
    // estratégia das coroutines do MLoja), mas a COMPOSIÇÃO de cada célula é
    // encadeada de forma SERIAL à medida que os rasters ficam prontos. Assim
    // nunca há todos os bitmaps da página vivos ao mesmo tempo — o pico fica
    // em ~2 rasters + a página. Era isso que estourava memória e crashava,
    // sobretudo no Vencimentos (que ainda adiciona a camada de texto/célula).
    final pageIdx = <int>[];
    for (int idx = p * gridCap; idx < total && idx < (p + 1) * gridCap; idx++) {
      pageIdx.add(idx);
    }

    Future<void> compor(img.Image raster, int idx) async {
      final item = items[idx];
      final local = idx % gridCap;
      final col = local % cols;
      final row = local ~/ cols;
      final left = col * halfW;
      final top = row * halfH;
      final ehComum = _ehComum(item);

      if (modoVencimentos) {
        // Overlay nativo da página; comum recebe fundo branco por célula.
        if (ehComum && !semOverlay && overlay != null) {
          _fillCell(base, left, top, halfW, halfH);
        }
        final ignorar = ehComum ? 0.03 : 0.0;
        final maxShift = ehComum ? 1.0 : 0.35;
        final shiftY = ehComum ? 0.0 : shiftYVenc;
        _centralizarConteudo(base, raster, halfW, halfH, left, top, maxShift,
            ignorar, shiftY);
        // Validade/rodapé por cima, centrados na célula.
        // Comum: conteúdo mais baixo, sobe para 0.20.
        // Promocional: mantém 0.28 multi-célula / 0.25 single.
        final multiCell = cols * rows > 1;
        final vTxt = validades.length > idx ? validades[idx] : '';
        if (vTxt.trim().isNotEmpty) {
          try {
            final layer = await _camadaTextosVencimento(
                halfW, halfH, vTxt.trim(),
                topFrac: ehComum ? 0.25 : (multiCell ? 0.28 : 0.25));
            img.compositeImage(base, layer,
                dstX: left, dstY: top, dstW: halfW, dstH: halfH);
          } catch (e) {
            LogHelper.e('Composite: erro camada validade item $idx', e);
          }
        }
      } else {
        // Multi/Misto: overlay por célula.
        if (isMisto && !ehComum && !semOverlay && overlay1x1 != null) {
          img.compositeImage(base, overlay1x1, dstX: left, dstY: top, dstW: halfW, dstH: halfH);
        } else if (!isMisto && ehComum && !semOverlay && overlay != null) {
          _fillCell(base, left, top, halfW, halfH);
        }
        final ignorar = ehComum ? 0.03 : 0.0;
        _centralizarConteudo(base, raster, halfW, halfH, left, top, 1.0,
            ignorar, ehComum ? 0.0 : shiftYMulti);
      }
    }

    Future<void> composeChain = Future.value();
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= pageIdx.length) return;
        final idx = pageIdx[i];
        img.Image? r;
        try {
          r = await _rasterizeCard(api, items[idx], halfW, halfH);
        } catch (e) {
          LogHelper.e('Composite: erro item $idx', e);
        }
        if (r == null) continue;
        final raster = r;
        composeChain = composeChain.then((_) => compor(raster, idx));
      }
    }

    await Future.wait(List.generate(2, (_) => worker()));
    await composeChain;
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
/// Espelha fielmente o centralizarConteudo do MLoja (ModeloEditavelActivity.kt):
/// o bitmap é ESTICADO para preencher a célula (cellW x cellH) e deslocado para
/// cima por shiftYFrac. Apenas a horizontal é centralizada conforme a área não
/// branca do conteúdo (dx, limitado por maxShiftFrac). Não há centralização
/// vertical por conteúdo (dy) — diferentemente do desenharComProporcao, que era
/// o que causava o conteúdo ficar em posição diversa da do MLoja.
void _centralizarConteudo(img.Image base, img.Image bmp, int cellW, int cellH,
    int left, int top, double maxShiftFrac, double ignorarBordasFrac, double shiftYFrac) {
  final w = bmp.width;
  final h = bmp.height;
  final targetW = w < 1200 ? w : 1200;
  final targetH = (h * targetW / w).round().clamp(1, 100000);
  final small = (targetW < w) ? img.copyResize(bmp, width: targetW, height: targetH) : bmp;
  final sw = small.width;
  final sh = small.height;
  final bx0 = (sw * ignorarBordasFrac).round();
  final bx1 = (sw * (1 - ignorarBordasFrac)).round();
  final by0 = (sh * ignorarBordasFrac).round();
  final by1 = (sh * (1 - ignorarBordasFrac)).round();
  // Apenas a horizontal é medida (igual ao MLoja): não há dy vertical.
  int minX = sw;
  int maxX = -1;
  for (int y = by0; y < by1; y += 4) {
    for (int x = bx0; x < bx1; x += 4) {
      final p = small.getPixel(x, y);
      if (p.a > 8 && (p.r < 250 || p.g < 250 || p.b < 250)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
  }

  final dstY = (top - cellH * shiftYFrac).round();
  if (maxX <= minX) {
    img.compositeImage(base, bmp,
        dstX: left, dstY: dstY, dstW: cellW, dstH: cellH);
    return;
  }
  final scaleX = cellW / sw;
  final contentDrawW = (maxX - minX + 1) * scaleX;
  final dx = (((cellW - contentDrawW) / 2) - minX * scaleX)
      .clamp(-cellW * maxShiftFrac, cellW * maxShiftFrac);
  img.compositeImage(base, bmp,
      dstX: (left + dx).round(), dstY: dstY, dstW: cellW, dstH: cellH);
}

/// Camada transparente (tamanho da célula) com "VAL.: <data>" e o rodapé
/// fixo, ambos centralizados na PRÓPRIA célula. É composta POR CIMA da página
/// já montada, então não interfere no posicionamento do conteúdo da API.
Future<img.Image> _camadaTextosVencimento(int w, int h, String validade,
    {double topFrac = 0.25}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
      recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  final txt = validade.length == 8
      ? '${validade.substring(0, 2)}/${validade.substring(2, 4)}/${validade.substring(4)}'
      : validade.trim();
  void draw(String s, double y, double fs) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: const ui.Color(0xFFD32F2F),
          fontSize: fs,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: w.toDouble());
    final drawY = y < tp.height ? 0.0 : y - tp.height / 2;
    tp.paint(canvas, Offset((w - tp.width) / 2, drawY));
  }

  // Comum: sobe para 0.20 (conteúdo da API é mais baixo no card).
  // Promocional: 0.28 multi-célula / 0.25 single (posição validada).
  draw('VAL.: ${txt.toUpperCase()}', h * topFrac, w / 18);
  draw('PRÓXIMO DA VALIDADE. CONSUMO RÁPIDO', h * 0.88,
      (w / 32).clamp(8, 26).toDouble());
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  final png = (await out.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  out.dispose();
  return img.decodeImage(png)!;
}

/// Rasteriza os itens da página em paralelo com concorrência limitada
/// (busca na API + render nativo, como as coroutines do MLoja) e depois
/// desenha a validade em sequência (picture.toImage não deve ser concorrente).
Future<List<img.Image?>> _rasterizarPagina(
    ApiService api,
    List<PapeletaPrintingData> items,
    List<String> validades,
    List<int> pageIdx,
    int halfW,
    int halfH) async {
  final results = List<img.Image?>.filled(pageIdx.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= pageIdx.length) return;
      final idx = pageIdx[i];
      try {
        results[i] = await _rasterizeCard(api, items[idx], halfW, halfH);
      } catch (e) {
        LogHelper.e('Composite: erro item $idx', e);
        results[i] = null;
      }
    }
  }

  final nWorkers = pageIdx.length < 2 ? pageIdx.length : 2;
  await Future.wait(List.generate(nWorkers, (_) => worker()));

  return results;
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
    if (scale > 7) scale = 7;
    if (scale < 1) scale = 1;
    int renderWidth = (pw * scale).round();
    if (renderWidth > 11000) renderWidth = 11000;
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

/// Cache em memória dos PDFs da API por conteúdo do item: alternar overlay,
/// quantidade ou regerar os mesmos itens NÃO refaz rede — fluidez igual ao
/// MLoja (que se beneficia do cache HTTP do OkHttp).
final Map<String, Uint8List> _pdfApiCache = <String, Uint8List>{};

String? _pdfCacheKey(PapeletaPrintingData d) {
  try {
    final j = d.copyWith(size: Constants.signSize1x1).toJson();
    j.remove('quantity');
    j.remove('_quantity');
    return json.encode(j);
  } catch (_) {
    return null;
  }
}

/// Renderiza o PDF da API via canal nativo e devolve o PNG cru (sem
/// decodificar em Dart) — usado pela composição nativa da página.
Future<Uint8List?> _renderPdfPng(
    ApiService api, PapeletaPrintingData data, int w, int h) async {
  final bytes =
      await api.previewPriceSign(data.copyWith(size: Constants.signSize1x1));
  final res = await _pdfChannel.invokeMethod<Map<dynamic, dynamic>>(
      'renderPdfToRgba', {'bytes': bytes, 'w': w, 'h': h});
  if (res == null) return null;
  final rw = res['width'] as int? ?? 0;
  final b = res['bytes'] as Uint8List?;
  if (rw <= 0 || b == null || b.isEmpty) return null;
  return b;
}

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
  // Formata a validade: se tiver 8 dígitos, forma DD/MM/YYYY, caso contrário, trimado
  final validaTexto = validade.length == 8 
      ? '${validade.substring(0, 2)}/${validade.substring(2, 4)}/${validade.substring(4)}' 
      : validade.trim();
  // Centro X do conteúdo (equivalente ao centroXConteudo do MLoja): o texto
  // acompanha o eixo do conteúdo do card, ficando centralizado sobre ele
  // após o deslocamento do centralizarConteudo.
  int cxMin = raster.width;
  int cxMax = -1;
  for (int yy = 0; yy < raster.height; yy += 6) {
    for (int xx = 0; xx < raster.width; xx += 3) {
      final p = raster.getPixel(xx, yy);
      if (p.a > 8 && (p.r < 250 || p.g < 250 || p.b < 250)) {
        if (xx < cxMin) cxMin = xx;
        if (xx > cxMax) cxMax = xx;
      }
    }
  }
  final double centroX = (cxMax <= cxMin)
      ? w / 2
      : ((cxMin + cxMax + 1) / 2) * (w / raster.width);
  // Posicionamento da validade: mesma lógica do MLoja (localizar primeira banda + 
  // deslocamento + coerção para faixa h*0.28 até h*0.45).
  // Aqui usamos o centro da célula (w/2) e deslocamento 0.28h — mais acima,
  // dentro da faixa do MLoja (h*0.28 a h*0.45).
  // Fonte maior: w / 18 (antes w / 20).
  final yVal = h * 0.28;
  // Rodapé: um pouco mais pra cima (0.88h) e fonte maior (w / 32).
  final yFooter = h * 0.88;
  _drawCentered(canvas, w, yVal, 'VAL.: $validaTexto'.toUpperCase(),
      fontSize: w / 18, bold: true, centerX: centroX);
  _drawCentered(canvas, w, yFooter, 'PRÓXIMO DA VALIDADE. CONSUMO RÁPIDO',
      fontSize: (w / 32).clamp(8, 26).toDouble(), bold: true, centerX: centroX);
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  final pngOut = (await out.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  uiImg.dispose();
  return img.decodeImage(pngOut)!;
}

void _drawCentered(ui.Canvas canvas, int w, double y, String text,
    {required double fontSize, required bool bold, double? centerX}) {
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
  tp.paint(canvas, Offset(centerX ?? (w - tp.width) / 2, y - tp.height / 2));
}

String _formatValidade(String v) {
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 8) {
    return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
  }
  return v;
}
