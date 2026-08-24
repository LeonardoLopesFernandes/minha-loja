import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/toast_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager session = SessionManager._instance!;

  String _title = 'PDF';
  Uint8List? _bytes;
  bool _loading = true;
  bool _generating = false;
  String? _error;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _resolveArgs();
  }

  Future<void> _resolveArgs() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map) {
        _title = args['title']?.toString() ?? _title;
        final b = args['bytes'];
        if (b is Uint8List) {
          _bytes = b;
        } else if (args['printingData'] is PapeletaPrintingData) {
          _bytes = await _generatePreview(args['printingData'] as PapeletaPrintingData);
        } else if (args['printingData'] is PriceSign) {
          final pd = (args['printingData'] as PriceSign).printingData;
          if (pd != null) _bytes = await _generatePreview(pd);
        } else if (args['ean'] != null ||
            args['sap'] != null ||
            args['description'] != null) {
          _bytes = null;
        }
      } else if (args is PapeletaPrintingData) {
        _title = args.productName;
        _bytes = await _generatePreview(args);
      } else if (args is PriceSign) {
        _title = args.description;
        final pd = args.printingData;
        if (pd != null) _bytes = await _generatePreview(pd);
      }

      if (_bytes != null) {
        _loadPdf(_bytes!);
      }
    } catch (e) {
      LogHelper.e('PdfViewerScreen: erro ao resolver argumentos', e);
      _error = 'Erro ao carregar o PDF.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List?> _generatePreview(PapeletaPrintingData data) async {
    setState(() => _generating = true);
    try {
      return await api.previewPriceSign(data);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
      return null;
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao gerar PDF.');
      return null;
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _loadPdf(Uint8List bytes) {
    final dataUrl =
        'data:application/pdf;base64,${base64Encode(bytes)}';
    _controller.loadRequest(Uri.parse(dataUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading || _generating) {
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
    if (_bytes == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum PDF disponível para exibição.',
              style: AppTextStyles.body, textAlign: TextAlign.center),
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }
}
