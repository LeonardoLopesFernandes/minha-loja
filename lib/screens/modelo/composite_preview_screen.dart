import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/theme.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:pdf_render/pdf_render.dart';

/// Pré-visualização composta (grade) espelhando a ModeloEditavelActivity do
/// MLoja: rasteriza o PDF de cada item via API e o sobrepõe sobre o overlay
/// PNG correspondente ao tamanho, exatamente como o Kotlin faz com canvas.
class CompositePreviewScreen extends StatefulWidget {
  final List<PapeletaPrintingData> items;
  final String size;
  const CompositePreviewScreen(
      {super.key, required this.items, required this.size});

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
    _configureGrid();
    _generate();
  }

  void _configureGrid() {
    switch (widget.size.toUpperCase()) {
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

  bool _ehComum(PapeletaPrintingData d) {
    if (d.template == Constants.signTemplateDeporParcelado) return true;
    final hasPromo = d.promotionPrice != null && d.promotionPrice! > 0;
    final hasTW = d.takeAndWinQuantity != null && d.takeAndWinQuantity! > 0;
    if (hasPromo || hasTW) return false;
    return true;
  }

  Future<img.Image?> _rasterize(PapeletaPrintingData data, int w, int h) async {
    // O Kotlin sempre gera o PDF de cada célula em 1X1 e compõe a grade
    // conforme o tamanho selecionado (ex.: 3x2 para 6X1, já que a API não
    // possui 6X1).
    final bytes = await api.previewPriceSign(
        data.copyWith(size: Constants.signSize1x1));
    final doc = await PdfDocument.openData(bytes);
    try {
      if (doc.pageCount < 1) return null;
      final page = await doc.loadPage(1);
      try {
        final pi = await page.render(width: w, height: h);
        final png = pi.bytes;
        return img.decodeImage(png);
      } finally {
        page.dispose();
      }
    } finally {
      doc.dispose();
    }
  }

  Future<void> _generate() async {
    try {
      final overlayData = await rootBundle
          .load('assets/overlays/${widget.size.toLowerCase()}.png');
      final overlay = img.decodeImage(overlayData.buffer.asUint8List());
      if (overlay == null) throw Exception('Overlay não encontrado');

      final gridCap = _cols * _rows;
      final total = widget.items.length;
      final pageCount = total == 0 ? 1 : (total / gridCap).ceil();
      final out = <Uint8List>[];

      for (int p = 0; p < pageCount; p++) {
        final base = img.Image(width: overlay.width, height: overlay.height);
        base.drawImage(overlay);
        final halfW = (overlay.width / _cols).floor();
        final halfH = (overlay.height / _rows).floor();

        for (int idx = p * gridCap; idx < total && idx < (p + 1) * gridCap; idx++) {
          final item = widget.items[idx];
          final local = idx % gridCap;
          final col = local % _cols;
          final row = local ~/ _cols;
          final left = col * halfW;
          final top = row * halfH;

          try {
            final raster = await _rasterize(item, halfW * 2, halfH * 2);
            if (raster != null) {
              final resized = img.copyResize(raster, width: halfW, height: halfH);
              if (_ehComum(item)) {
                img.fillRect(base,
                    x1: left, y1: top, x2: left + halfW, y2: top + halfH,
                    color: img.ColorRgba8(255, 255, 255, 255));
              }
              img.compositeImage(base, resized, dstX: left, dstY: top);
            }
          } catch (e) {
            LogHelper.e('Composite: erro item $idx', e);
          }
        }
        out.add(img.encodePng(base));
      }

      if (!mounted) return;
      setState(() {
        _pages = out;
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
