import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'api_client.dart';

class ApiService {
  final Dio dio;

  ApiService(this.dio);

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic) parser,
  }) async {
    try {
      final resp = await dio.get(path, queryParameters: query);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return parser(resp.data);
      }
      throw ApiException(resp.statusCode, _extractMessage(resp.data));
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(
            e.response!.statusCode, _extractMessage(e.response!.data));
      }
      throw ApiException(null, e.message ?? 'Erro de rede');
    }
  }

  Future<T> _post<T>(
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    required T Function(dynamic) parser,
  }) async {
    try {
      final resp = await dio.post(path, queryParameters: query, data: body);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return parser(resp.data);
      }
      throw ApiException(resp.statusCode, _extractMessage(resp.data));
    } on DioException catch (e) {
      if (e.response != null) {
        throw ApiException(
            e.response!.statusCode, _extractMessage(e.response!.data));
      }
      throw ApiException(null, e.message ?? 'Erro de rede');
    }
  }

  String _extractMessage(dynamic data) {
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    return 'Erro na requisição';
  }

  // ========== PRICE TAGS ==========
  Future<MenuResponse> getPriceTags(String storeId, String startDate) =>
      _get('web/price-tag/store/$storeId', query: {'startDate': startDate},
          parser: (d) => MenuResponse.fromJson(d));

  Future<FilterResponse> getPriceTagFilters(String storeId, String startDate) =>
      _get('web/price-tag/store/$storeId/filter', query: {'startDate': startDate},
          parser: (d) => FilterResponse.fromJson(d));

  Future<PriceTagsResponse> getPriceTagsByStatus(String storeId, String status,
      {String? department, String? startDate}) async {
    final query = <String, dynamic>{'status': status};
    if (department != null) query['department'] = department;
    if (startDate != null) query['startDate'] = startDate;
    return _get('web/price-tag/store/$storeId/printing', query: query,
        parser: (d) => PriceTagsResponse.fromJson(d));
  }

  Future<SingleLabelResponse> getSingleLabelByEan(String storeId,
      {String? ean,
      String? description,
      String? sapId,
      required String startDate}) async {
    final query = <String, dynamic>{'startDate': startDate};
    if (ean != null) query['ean'] = ean;
    if (description != null) query['description'] = description;
    if (sapId != null) query['sapId'] = sapId;
    return _get('web/price-tag/store/$storeId/single-label-printing', query: query,
        parser: (d) => SingleLabelResponse.fromJson(d));
  }

  Future<void> sendPriceTagsToPrinter(String storeId, String printerId,
      String tagId, SendPriceTagsRequest request) async {
    await _post(
        'web/price-tag/store/$storeId/printer/$printerId/tag/$tagId/send',
        body: request.toJson(), parser: (d) => null);
  }

  // ========== PRICE SIGNS ==========
  Future<PriceSignFilterResponse> getPriceSignFilters(String storeId) =>
      _get('web/price-sign/store/$storeId/filter',
          parser: (d) => PriceSignFilterResponse.fromJson(d));

  Future<PriceSignResponse> getPriceSigns(String storeId, String type,
      {String? department,
      String? size,
      required String status,
      required String startDate}) async {
    final query = <String, dynamic>{
      'type': type,
      'status': status,
      'startDate': startDate,
    };
    if (department != null) query['department'] = department;
    if (size != null) query['size'] = size;
    return _get('web/price-sign/store/$storeId/printing', query: query,
        parser: (d) => PriceSignResponse.fromJson(d));
  }

  Future<Uint8List> getPriceSignDashboard(String storeId, String startDate) async {
    final resp = await dio.get('web/price-sign/store/$storeId/dashboard',
        queryParameters: {'startDate': startDate},
        options: Options(responseType: ResponseType.bytes));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return resp.data as Uint8List;
    }
    throw ApiException(resp.statusCode, 'Erro ao obter dashboard');
  }

  Future<PapeletaStandaloneResponse> getPriceSignStandalone(String storeId,
      String type,
      {String? ean,
      String? sapId,
      String? description,
      required String startDate}) async {
    final query = <String, dynamic>{'type': type, 'startDate': startDate};
    if (ean != null) query['ean'] = ean;
    if (sapId != null) query['sapId'] = sapId;
    if (description != null) query['description'] = description;
    return _get('web/price-sign/store/$storeId/standalone', query: query,
        parser: (d) => PapeletaStandaloneResponse.fromJson(d));
  }

  Future<void> sendPriceSigns(String storeId, SendPriceSignRequest request) async {
    await _post('web/price-sign/store/$storeId/send',
        body: request.toJson(), parser: (d) => null);
  }

  Future<Uint8List> previewPriceSign(PapeletaPrintingData request) async {
    final resp = await dio.post('web/price-sign/preview',
        data: request.toJson(), options: Options(responseType: ResponseType.bytes));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return resp.data as Uint8List;
    }
    throw ApiException(resp.statusCode, 'Erro ao gerar pré-visualização');
  }

  // ========== RECEBIMENTOS ==========
  Future<RecebimentoResponse> getRecebimentos(String storeId, String status,
      {String? search, String sort = 'asc', int page = 1}) async {
    final query = <String, dynamic>{
      'status': status,
      'sort': sort,
      'page': page,
    };
    if (search != null) query['search'] = search;
    return _get('web/recebimento/$storeId', query: query,
        parser: (d) => RecebimentoResponse.fromJson(d));
  }

  // ========== PRINTERS ==========
  Future<PrinterResponse> getPrinters(String storeId,
      {String orderBy = 'asc', String sortBy = 'name'}) async {
    final query = {'orderBy': orderBy, 'sortBy': sortBy};
    return _get('web/priceTag/store/$storeId/printer', query: query,
        parser: (d) => PrinterResponse.fromJson(d));
  }

  // ========== STORE ==========
  Future<BusinessHours> getBusinessHours(String storeId) =>
      _get('web/store/$storeId/business-hours',
          parser: (d) => BusinessHours.fromJson(d));

  Future<SpecialBusinessHours> getSpecialBusinessHours(
          String storeId, String date) =>
      _get('web/store/$storeId/special-business-hours', query: {'date': date},
          parser: (d) => SpecialBusinessHours.fromJson(d));

  // ========== LOGIN ==========
  Future<SessionLoginResponse> login(LoginRequest request) =>
      _post('auth/login', body: request.toJson(),
          parser: (d) => SessionLoginResponse.fromJson(d));

  Future<SessionLoginResponse> refreshToken(String token) =>
      _post('auth/refresh', query: {}, body: null,
          parser: (d) => SessionLoginResponse.fromJson(d));
}

class PriceTagsResponse {
  final List<PriceTag> priceTags;
  PriceTagsResponse({required this.priceTags});
  factory PriceTagsResponse.fromJson(Map<String, dynamic> j) => PriceTagsResponse(
        priceTags: (j['priceTags'] as List? ?? [])
            .map((e) => PriceTag.fromJson(e))
            .toList(),
      );
}
