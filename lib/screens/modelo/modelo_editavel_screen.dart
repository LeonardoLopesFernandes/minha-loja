import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:minhaloja/core/constants.dart';
import 'package:minhaloja/core/session_manager.dart';
import 'package:minhaloja/models/models.dart';
import 'package:minhaloja/network/api_client.dart';
import 'package:minhaloja/network/api_service.dart';
import 'package:minhaloja/utils/log_helper.dart';
import 'package:minhaloja/utils/session_expired_handler.dart';
import 'package:minhaloja/utils/toast_utils.dart';

class ModeloEditavelScreen extends StatefulWidget {
  const ModeloEditavelScreen({super.key});

  @override
  State<ModeloEditavelScreen> createState() => _ModeloEditavelScreenState();
}

class _ModeloEditavelScreenState extends State<ModeloEditavelScreen> {
  final ApiService api = ApiService(ApiClient.instance.getSlApiService());
  final SessionManager session = SessionManager._instance!;

  PapeletaPrintingData? _data;
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _previewing = false;
  Uint8List? _previewBytes;

  late String _template;

  final TextEditingController _cProductName = TextEditingController();
  final TextEditingController _cPrice = TextEditingController();
  final TextEditingController _cPromotionPrice = TextEditingController();
  final TextEditingController _cTakeWinQty = TextEditingController();
  final TextEditingController _cTakeWinPrice = TextEditingController();
  final TextEditingController _cTakeWinPercent = TextEditingController();
  final TextEditingController _cInstallmentPrice = TextEditingController();
  final TextEditingController _cInstallmentQty = TextEditingController();
  final TextEditingController _cSize = TextEditingController();
  final TextEditingController _cQuantity = TextEditingController();
  final TextEditingController _cUnit = TextEditingController();

  static const List<String> _templates = [
    Constants.signTemplateModeloEditavel,
    Constants.signTemplateDepor,
    Constants.signTemplateDeporParcelado,
    Constants.signTemplateLeveGanheCada,
    Constants.signTemplateLeveGanheTotal,
  ];

  @override
  void initState() {
    super.initState();
    _resolveArgs();
  }

  Future<void> _resolveArgs() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final startDate =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      PapeletaPrintingData? resolved;

      if (args is PapeletaPrintingData) {
        resolved = args;
      } else if (args is PriceSign) {
        resolved = args.printingData;
      } else if (args is Map) {
        final pd = args['printingData'];
        if (pd is PapeletaPrintingData) {
          resolved = pd;
        } else if (pd is PriceSign) {
          resolved = pd.printingData;
        } else if (args['ean'] != null ||
            args['sap'] != null ||
            args['description'] != null) {
          final storeId = session.getUserStore();
          final resp = await api.getPriceSignStandalone(
            storeId,
            Constants.signTypePapeletaPromocionalModelo,
            ean: args['ean'] as String?,
            sapId: args['sap'] as String?,
            description: args['description'] as String?,
            startDate: startDate,
          );
          if (resp.items.isNotEmpty) resolved = resp.items.first.printingData;
        }
      }

      if (resolved != null) {
        _data = resolved;
        _template = Constants.templateNormalizado(resolved.template) ??
            Constants.signTemplateModeloEditavel;
        _populateControllers(resolved);
      } else {
        _error = 'Nenhum dado de papeleta disponível.';
      }
    } catch (e) {
      LogHelper.e('ModeloEditavelScreen: erro ao resolver argumentos', e);
      _error = 'Erro ao carregar dados.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _populateControllers(PapeletaPrintingData d) {
    _cProductName.text = d.productName;
    _cPrice.text = d.price.toString();
    _cPromotionPrice.text = d.promotionPrice?.toString() ?? '';
    _cTakeWinQty.text = d.takeAndWinQuantity?.toString() ?? '';
    _cTakeWinPrice.text = d.takeAndWinPrice?.toString() ?? '';
    _cTakeWinPercent.text = d.takeAndWinPercent?.toString() ?? '';
    _cInstallmentPrice.text = d.installmentPrice?.toString() ?? '';
    _cInstallmentQty.text = d.installmentQuantity?.toString() ?? '';
    _cSize.text = d.size ?? '';
    _cQuantity.text = d.quantity?.toString() ?? '';
    _cUnit.text = d.unit;
  }

  PapeletaPrintingData _buildData() {
    final d = _data!;
    return PapeletaPrintingData(
      template: _template,
      productName: _cProductName.text,
      price: _parseDouble(_cPrice.text, d.price),
      promotionPrice: _parseDoubleOrNull(_cPromotionPrice.text),
      takeAndWinQuantity: _parseIntOrNull(_cTakeWinQty.text),
      takeAndWinPrice: _parseDoubleOrNull(_cTakeWinPrice.text),
      takeAndWinPercent: _parseIntOrNull(_cTakeWinPercent.text),
      installmentPrice: _parseDoubleOrNull(_cInstallmentPrice.text),
      installmentQuantity: _parseIntOrNull(_cInstallmentQty.text),
      codSap: d.codSap,
      ean: d.ean,
      referenceDate: d.referenceDate,
      size: _cSize.text.isEmpty ? d.size : _cSize.text,
      quantity: _parseIntOrNull(_cQuantity.text) ?? d.quantity,
      unit: _cUnit.text.isEmpty ? d.unit : _cUnit.text,
    );
  }

  double _parseDouble(String v, double fallback) =>
      double.tryParse(v.replaceAll(',', '.')) ?? fallback;
  double? _parseDoubleOrNull(String v) {
    if (v.isEmpty) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }

  int? _parseIntOrNull(String v) {
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  String _computedDisplay() {
    final price = _parseDouble(_cPrice.text, 0);
    final promo = _parseDoubleOrNull(_cPromotionPrice.text);
    final twQty = _parseIntOrNull(_cTakeWinQty.text);
    final twPrice = _parseDoubleOrNull(_cTakeWinPrice.text);
    final instPrice = _parseDoubleOrNull(_cInstallmentPrice.text);
    final instQty = _parseIntOrNull(_cInstallmentQty.text);

    switch (_template) {
      case Constants.signTemplateDepor:
        return 'De: R\$ ${price.toStringAsFixed(2)}  Por: R\$ ${(promo ?? price).toStringAsFixed(2)}';
      case Constants.signTemplateDeporParcelado:
        if (instQty != null && instQty > 0 && instPrice != null) {
          return 'Parcelado: ${instQty}x de R\$ ${instPrice.toStringAsFixed(2)}';
        }
        return 'Parcelado';
      case Constants.signTemplateLeveGanheCada:
      case Constants.signTemplateLeveGanheTotal:
        final total = Constants.totalLeveGanhePorTemplate(
            _template, promo, twPrice, twQty);
        final qty = twQty ?? 1;
        return 'Leve $qty por R\$ ${total.toStringAsFixed(2)}';
      case Constants.signTemplateModeloEditavel:
      default:
        return _cProductName.text.isNotEmpty
            ? _cProductName.text
            : 'Modelo Editável';
    }
  }

  Future<void> _doPreview() async {
    if (_data == null) return;
    setState(() => _previewing = true);
    try {
      final bytes = await api.previewPriceSign(_buildData());
      if (!mounted) return;
      setState(() => _previewBytes = bytes);
      await Navigator.pushNamed(context, '/pdf_viewer', arguments: {
        'title': _cProductName.text,
        'bytes': bytes,
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao gerar pré-visualização.');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _doSend() async {
    if (_data == null) return;
    setState(() => _sending = true);
    final storeId = session.getUserStore();
    try {
      await api.sendPriceSigns(
        storeId,
        SendPriceSignRequest(products: [_buildData()]),
      );
      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Papeleta enviada com sucesso.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        SessionExpiredHandler.handleSessionExpired(context);
      } else {
        ToastUtils.showError(context, e.message);
      }
    } catch (e) {
      ToastUtils.showError(context, 'Erro ao enviar papeleta.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelo Editável'),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error ?? 'Dados indisponíveis.',
              style: AppTextStyles.body),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Dados do Produto'),
          _textField('Nome do produto', _cProductName),
          _textField('Preço', _cPrice, keyboard: TextInputType.number),
          _textField('Preço promocional',
              _cPromotionPrice,
              keyboard: TextInputType.number),
          Row(
            children: [
              Expanded(
                  child: _textField('Tamanho', _cSize)),
              const SizedBox(width: 12),
              Expanded(
                  child: _textField('Quantidade', _cQuantity,
                      keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _textField('Unidade', _cUnit)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Modelo do Cartaz'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _template,
                items: _templates
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _template = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_template == Constants.signTemplateModeloEditavel) ...[
            _sectionTitle('Campos Editáveis'),
            _textField('Texto/Preço extra', _cPromotionPrice,
                keyboard: TextInputType.number),
            _textField('Preço extra 2', _cTakeWinPrice,
                keyboard: TextInputType.number),
          ],
          if (_template == Constants.signTemplateDepor) ...[
            _sectionTitle('De / Por'),
            _textField('Preço De', _cPrice,
                keyboard: TextInputType.number),
            _textField('Preço Por', _cPromotionPrice,
                keyboard: TextInputType.number),
          ],
          if (_template == Constants.signTemplateDeporParcelado) ...[
            _sectionTitle('Parcelado'),
            Row(
              children: [
                Expanded(
                    child: _textField('Qtde parcelas', _cInstallmentQty,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: _textField('Valor parcela', _cInstallmentPrice,
                        keyboard: TextInputType.number)),
              ],
            ),
          ],
          if (_template == Constants.signTemplateLeveGanheCada ||
              _template == Constants.signTemplateLeveGanheTotal) ...[
            _sectionTitle('Leve e Ganhe'),
            Row(
              children: [
                Expanded(
                    child: _textField('Leve (qtd)', _cTakeWinQty,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: _textField('Preço total', _cTakeWinPrice,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: _textField('% desc.', _cTakeWinPercent,
                        keyboard: TextInputType.number)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Pré-visualização'),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: _previewBytes != null
                ? const Text('Pré-visualização gerada. Toque em "Visualizar".',
                    style: AppTextStyles.subtitle)
                : Text(
                    _computedDisplay(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray900),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _previewing ? null : _doPreview,
            icon: const Icon(Icons.visibility),
            label: Text(_previewing ? 'Gerando...' : 'Visualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sending ? null : _doSend,
            icon: const Icon(Icons.send),
            label: Text(_sending ? 'Enviando...' : 'Salvar / Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
      );

  Widget _textField(String label, TextEditingController controller,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
      ),
    );
  }
}
