class MenuResponse {
  final Menu menu;
  final Page page;
  MenuResponse({required this.menu, required this.page});
  factory MenuResponse.fromJson(Map<String, dynamic> j) =>
      MenuResponse(menu: Menu.fromJson(j['menu']), page: Page.fromJson(j['page']));
}

class Menu {
  final int totalChanges;
  Menu({required this.totalChanges});
  factory Menu.fromJson(Map<String, dynamic> j) =>
      Menu(totalChanges: j['totalChanges'] ?? 0);
}

class Page {
  final InfoTag infoTag;
  final List<DepartmentItem> items;
  Page({required this.infoTag, required this.items});
  factory Page.fromJson(Map<String, dynamic> j) => Page(
        infoTag: InfoTag.fromJson(j['infoTag']),
        items: (j['items'] as List? ?? [])
            .map((e) => DepartmentItem.fromJson(e))
            .toList(),
      );
}

class InfoTag {
  final DateInfo date;
  final int printedTags;
  final int unprintedTags;
  final int totalTags;
  final bool nextDayPricingEnabled;
  InfoTag(
      {required this.date,
      required this.printedTags,
      required this.unprintedTags,
      required this.totalTags,
      required this.nextDayPricingEnabled});
  factory InfoTag.fromJson(Map<String, dynamic> j) => InfoTag(
        date: DateInfo.fromJson(j['date']),
        printedTags: j['printedTags'] ?? 0,
        unprintedTags: j['unprintedTags'] ?? 0,
        totalTags: j['totalTags'] ?? 0,
        nextDayPricingEnabled: j['nextDayPricingEnabled'] ?? false,
      );
}

class DateInfo {
  final String day;
  final String weekday;
  DateInfo({required this.day, required this.weekday});
  factory DateInfo.fromJson(Map<String, dynamic> j) =>
      DateInfo(day: j['day'] ?? '', weekday: j['weekday'] ?? '');
}

class DepartmentItem {
  final String department;
  final int printed;
  final int unprinted;
  DepartmentItem(
      {required this.department, required this.printed, required this.unprinted});
  factory DepartmentItem.fromJson(Map<String, dynamic> j) => DepartmentItem(
        department: j['department'] ?? '',
        printed: j['printed'] ?? 0,
        unprinted: j['unprinted'] ?? 0,
      );
}

class FilterResponse {
  final List<TagFilter> tags;
  final List<Department> departments;
  final List<Status> status;
  final int printedTags;
  final int unprintedTags;
  FilterResponse(
      {required this.tags,
      required this.departments,
      required this.status,
      required this.printedTags,
      required this.unprintedTags});
  factory FilterResponse.fromJson(Map<String, dynamic> j) => FilterResponse(
        tags: (j['tags'] as List? ?? []).map((e) => TagFilter.fromJson(e)).toList(),
        departments: (j['departments'] as List? ?? [])
            .map((e) => Department.fromJson(e))
            .toList(),
        status: (j['status'] as List? ?? [])
            .map((e) => Status.fromJson(e))
            .toList(),
        printedTags: j['printedTags'] ?? 0,
        unprintedTags: j['unprintedTags'] ?? 0,
      );
}

class TagFilter {
  final String printerId;
  final String tagId;
  final String label;
  TagFilter({required this.printerId, required this.tagId, required this.label});
  factory TagFilter.fromJson(Map<String, dynamic> j) => TagFilter(
        printerId: j['printerId'] ?? '',
        tagId: j['tagId'] ?? '',
        label: j['label'] ?? '',
      );
}

class Department {
  final String id;
  final String label;
  Department({required this.id, required this.label});
  factory Department.fromJson(Map<String, dynamic> j) =>
      Department(id: j['id'] ?? '', label: j['label'] ?? '');
}

class Status {
  final String id;
  final String label;
  Status({required this.id, required this.label});
  factory Status.fromJson(Map<String, dynamic> j) =>
      Status(id: j['id'] ?? '', label: j['label'] ?? '');
}

class PriceTag {
  final String id;
  final String sap;
  final String department;
  final String ean;
  final String description;
  final String startDate;
  final String endDate;
  final String duration;
  final String price;
  final String movement;
  final String status;
  bool checkbox;
  int quantity;
  final PrintingData? printingData;

  PriceTag(
      {required this.id,
      required this.sap,
      required this.department,
      required this.ean,
      required this.description,
      required this.startDate,
      required this.endDate,
      required this.duration,
      required this.price,
      required this.movement,
      required this.status,
      this.checkbox = false,
      this.quantity = 1,
      this.printingData});

  factory PriceTag.fromJson(Map<String, dynamic> j) => PriceTag(
        id: j['id'] ?? '',
        sap: j['sap'] ?? '',
        department: j['department'] ?? '',
        ean: j['ean'] ?? '',
        description: j['description'] ?? '',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        duration: j['duration'] ?? '',
        price: j['price'] ?? '',
        movement: j['movement'] ?? '',
        status: j['status'] ?? '',
        checkbox: j['checkbox'] ?? false,
        quantity: j['quantity'] ?? 1,
        printingData: j['_printingData'] != null
            ? PrintingData.fromJson(j['_printingData'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sap': sap,
        'department': department,
        'ean': ean,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'duration': duration,
        'price': price,
        'movement': movement,
        'status': status,
        'checkbox': checkbox,
        'quantity': quantity,
        '_printingData': printingData?.toJson(),
      };
}

class PrintingData {
  final String ean;
  final String description;
  final String department;
  final double displayPrice;
  final PriceInfo? price;
  final PromotionalPriceInfo? promotionalPrice;
  final int quantity;
  final String movementType;
  final String unit;
  final double unitQty;
  final double unitValue;
  final bool printUnitValue;
  final String codSap;
  final TakeAndWin? takeAndWin;
  final String referenceDate;
  final String? template;
  final String? productName;
  final double? promotionPrice;
  final int? takeAndWinQuantity;
  final double? takeAndWinPrice;
  final int? takeAndWinPercent;

  PrintingData(
      {required this.ean,
      required this.description,
      required this.department,
      required this.displayPrice,
      this.price,
      this.promotionalPrice,
      required this.quantity,
      required this.movementType,
      required this.unit,
      required this.unitQty,
      required this.unitValue,
      required this.printUnitValue,
      required this.codSap,
      this.takeAndWin,
      required this.referenceDate,
      this.template,
      this.productName,
      this.promotionPrice,
      this.takeAndWinQuantity,
      this.takeAndWinPrice,
      this.takeAndWinPercent});

  factory PrintingData.fromJson(Map<String, dynamic> j) => PrintingData(
        ean: j['ean'] ?? '',
        description: j['description'] ?? '',
        department: j['department'] ?? '',
        displayPrice: (j['displayPrice'] ?? 0).toDouble(),
        price: j['price'] != null ? PriceInfo.fromJson(j['price']) : null,
        promotionalPrice: j['promotionalPrice'] != null
            ? PromotionalPriceInfo.fromJson(j['promotionalPrice'])
            : null,
        quantity: j['quantity'] ?? 1,
        movementType: j['movementType'] ?? '',
        unit: j['unit'] ?? '',
        unitQty: (j['unitQty'] ?? 0).toDouble(),
        unitValue: (j['unitValue'] ?? 0).toDouble(),
        printUnitValue: j['printUnitValue'] ?? false,
        codSap: j['codSap'] ?? '',
        takeAndWin: j['takeAndWin'] != null
            ? TakeAndWin.fromJson(j['takeAndWin'])
            : null,
        referenceDate: j['referenceDate'] ?? '',
        template: j['template'],
        productName: j['productName'],
        promotionPrice: j['promotionPrice']?.toDouble(),
        takeAndWinQuantity: j['takeAndWinQuantity'],
        takeAndWinPrice: j['takeAndWinPrice']?.toDouble(),
        takeAndWinPercent: j['takeAndWinPercent'],
      );

  Map<String, dynamic> toJson() => {
        'ean': ean,
        'description': description,
        'department': department,
        'displayPrice': displayPrice,
        'price': price?.toJson(),
        'promotionalPrice': promotionalPrice?.toJson(),
        'quantity': quantity,
        'movementType': movementType,
        'unit': unit,
        'unitQty': unitQty,
        'unitValue': unitValue,
        'printUnitValue': printUnitValue,
        'codSap': codSap,
        'takeAndWin': takeAndWin?.toJson(),
        'referenceDate': referenceDate,
        'template': template,
        'productName': productName,
        'promotionPrice': promotionPrice,
        'takeAndWinQuantity': takeAndWinQuantity,
        'takeAndWinPrice': takeAndWinPrice,
        'takeAndWinPercent': takeAndWinPercent,
      };
}

class PriceInfo {
  final double value;
  final int discountPercent;
  final String startAt;
  final String endAt;
  PriceInfo(
      {required this.value,
      required this.discountPercent,
      required this.startAt,
      required this.endAt});
  factory PriceInfo.fromJson(Map<String, dynamic> j) => PriceInfo(
        value: (j['value'] ?? 0).toDouble(),
        discountPercent: j['discountPercent'] ?? 0,
        startAt: j['startAt'] ?? '',
        endAt: j['endAt'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        'value': value,
        'discountPercent': discountPercent,
        'startAt': startAt,
        'endAt': endAt,
      };
}

class PromotionalPriceInfo {
  final double value;
  final int discountPercent;
  final String startAt;
  final String endAt;
  PromotionalPriceInfo(
      {required this.value,
      required this.discountPercent,
      required this.startAt,
      required this.endAt});
  factory PromotionalPriceInfo.fromJson(Map<String, dynamic> j) =>
      PromotionalPriceInfo(
        value: (j['value'] ?? 0).toDouble(),
        discountPercent: j['discountPercent'] ?? 0,
        startAt: j['startAt'] ?? '',
        endAt: j['endAt'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        'value': value,
        'discountPercent': discountPercent,
        'startAt': startAt,
        'endAt': endAt,
      };
}

class TakeAndWin {
  final double discountValue;
  final int qty;
  final double totalValue;
  TakeAndWin(
      {required this.discountValue,
      required this.qty,
      required this.totalValue});
  factory TakeAndWin.fromJson(Map<String, dynamic> j) => TakeAndWin(
        discountValue: (j['discountValue'] ?? 0).toDouble(),
        qty: j['qty'] ?? 0,
        totalValue: (j['totalValue'] ?? 0).toDouble(),
      );
  Map<String, dynamic> toJson() => {
        'discountValue': discountValue,
        'qty': qty,
        'totalValue': totalValue,
      };
}

class SendPriceTagsRequest {
  final List<PrintingData> products;
  SendPriceTagsRequest({required this.products});
  Map<String, dynamic> toJson() => {'products': products.map((e) => e.toJson()).toList()};
}

class PriceSignFilterResponse {
  final List<String> size;
  final List<SupplyType> supplyTypes;
  final bool nextDayPricingEnabled;
  PriceSignFilterResponse(
      {required this.size,
      required this.supplyTypes,
      required this.nextDayPricingEnabled});
  factory PriceSignFilterResponse.fromJson(Map<String, dynamic> j) =>
      PriceSignFilterResponse(
        size: List<String>.from(j['size'] ?? []),
        supplyTypes: (j['supplyTypes'] as List? ?? [])
            .map((e) => SupplyType.fromJson(e))
            .toList(),
        nextDayPricingEnabled: j['nextDayPricingEnabled'] ?? false,
      );
}

class SupplyType {
  final String id;
  final String label;
  final List<SupplyModel> models;
  SupplyType({required this.id, required this.label, required this.models});
  factory SupplyType.fromJson(Map<String, dynamic> j) => SupplyType(
        id: j['id'] ?? '',
        label: j['label'] ?? '',
        models: (j['models'] as List? ?? [])
            .map((e) => SupplyModel.fromJson(e))
            .toList(),
      );
}

class SupplyModel {
  final String id;
  final String label;
  SupplyModel({required this.id, required this.label});
  factory SupplyModel.fromJson(Map<String, dynamic> j) =>
      SupplyModel(id: j['id'] ?? '', label: j['label'] ?? '');
}

class PriceSignResponse {
  final List<PriceSign> priceSigns;
  PriceSignResponse({required this.priceSigns});
  factory PriceSignResponse.fromJson(Map<String, dynamic> j) => PriceSignResponse(
        priceSigns: (j['priceSigns'] as List? ?? [])
            .map((e) => PriceSign.fromJson(e))
            .toList(),
      );
}

class PriceSign {
  final String id;
  final String sap;
  final String department;
  final String ean;
  final String description;
  final String startDate;
  final String endDate;
  final String duration;
  final String price;
  final String movement;
  final String status;
  bool checkbox;
  int quantity;
  final PapeletaPrintingData? printingData;

  PriceSign(
      {required this.id,
      required this.sap,
      required this.department,
      required this.ean,
      required this.description,
      required this.startDate,
      required this.endDate,
      required this.duration,
      required this.price,
      required this.movement,
      required this.status,
      this.checkbox = false,
      this.quantity = 1,
      this.printingData});

  factory PriceSign.fromJson(Map<String, dynamic> j) => PriceSign(
        id: j['id'] ?? '',
        sap: j['sap'] ?? '',
        department: j['department'] ?? '',
        ean: j['ean'] ?? '',
        description: j['description'] ?? '',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        duration: j['duration'] ?? '',
        price: j['price'] ?? '',
        movement: j['movement'] ?? '',
        status: j['status'] ?? '',
        checkbox: j['checkbox'] ?? false,
        quantity: j['quantity'] ?? 1,
        printingData: j['_printingData'] != null
            ? PapeletaPrintingData.fromJson(j['_printingData'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sap': sap,
        'department': department,
        'ean': ean,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'duration': duration,
        'price': price,
        'movement': movement,
        'status': status,
        'checkbox': checkbox,
        'quantity': quantity,
        '_printingData': printingData?.toJson(),
      };
}

class PapeletaPrintingData {
  final String? template;
  final String productName;
  final double price;
  final double? promotionPrice;
  final int? takeAndWinQuantity;
  final double? takeAndWinPrice;
  final int? takeAndWinPercent;
  final double? installmentPrice;
  final int? installmentQuantity;
  final String codSap;
  final String ean;
  final String referenceDate;
  final String? size;
  final int? quantity;
  final String unit;

  PapeletaPrintingData(
      {this.template,
      required this.productName,
      required this.price,
      this.promotionPrice,
      this.takeAndWinQuantity,
      this.takeAndWinPrice,
      this.takeAndWinPercent,
      this.installmentPrice,
      this.installmentQuantity,
      required this.codSap,
      required this.ean,
      required this.referenceDate,
      this.size,
      this.quantity,
      required this.unit});

  factory PapeletaPrintingData.fromJson(Map<String, dynamic> j) =>
      PapeletaPrintingData(
        template: j['template'],
        productName: j['productName'] ?? '',
        price: (j['price'] ?? 0).toDouble(),
        promotionPrice: j['promotionPrice']?.toDouble(),
        takeAndWinQuantity: j['takeAndWinQuantity'],
        takeAndWinPrice: j['takeAndWinPrice']?.toDouble(),
        takeAndWinPercent: j['takeAndWinPercent'],
        installmentPrice: j['installmentPrice']?.toDouble(),
        installmentQuantity: j['installmentQuantity'],
        codSap: j['codSap'] ?? '',
        ean: j['ean'] ?? '',
        referenceDate: j['referenceDate'] ?? '',
        size: j['size'],
        quantity: j['quantity'],
        unit: j['unit'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'template': template,
        'productName': productName,
        'price': price,
        'promotionPrice': promotionPrice,
        'takeAndWinQuantity': takeAndWinQuantity,
        'takeAndWinPrice': takeAndWinPrice,
        'takeAndWinPercent': takeAndWinPercent,
        'installmentPrice': installmentPrice,
        'installmentQuantity': installmentQuantity,
        'codSap': codSap,
        'ean': ean,
        'referenceDate': referenceDate,
        'size': size,
        'quantity': quantity,
        'unit': unit,
      };
}

class SendPriceSignRequest {
  final List<PapeletaPrintingData> products;
  SendPriceSignRequest({required this.products});
  Map<String, dynamic> toJson() =>
      {'products': products.map((e) => e.toJson()).toList()};
}

class PapeletaStandaloneResponse {
  final List<PriceSign> items;
  PapeletaStandaloneResponse({required this.items});
  factory PapeletaStandaloneResponse.fromJson(Map<String, dynamic> j) =>
      PapeletaStandaloneResponse(
        items: (j['items'] as List? ?? [])
            .map((e) => PriceSign.fromJson(e))
            .toList(),
      );
}

class RecebimentoResponse {
  final List<Recebimento> recebimentos;
  final String dateFromGet;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final int qtdRecebimentosTotal;
  final QtdRecebimentos qtdRecebimentos;
  RecebimentoResponse(
      {required this.recebimentos,
      required this.dateFromGet,
      required this.page,
      required this.pageSize,
      required this.totalItems,
      required this.totalPages,
      required this.qtdRecebimentosTotal,
      required this.qtdRecebimentos});
  factory RecebimentoResponse.fromJson(Map<String, dynamic> j) =>
      RecebimentoResponse(
        recebimentos: (j['recebimentos'] as List? ?? [])
            .map((e) => Recebimento.fromJson(e))
            .toList(),
        dateFromGet: j['dateFromGet'] ?? '',
        page: j['page'] ?? 1,
        pageSize: j['pageSize'] ?? 0,
        totalItems: j['totalItems'] ?? 0,
        totalPages: j['totalPages'] ?? 0,
        qtdRecebimentosTotal: j['qtdRecebimentosTotal'] ?? 0,
        qtdRecebimentos: QtdRecebimentos.fromJson(j['qtdRecebimentos']),
      );
}

class Recebimento {
  final String id;
  final String viagemData;
  final String codigoOrigem;
  final String origem;
  final String status;
  final String placaVeiculo;
  final String dataRecebimento;
  final int qtdRolls;
  final int qtdGuias;
  final String protocolo;
  Recebimento(
      {required this.id,
      required this.viagemData,
      required this.codigoOrigem,
      required this.origem,
      required this.status,
      required this.placaVeiculo,
      required this.dataRecebimento,
      required this.qtdRolls,
      required this.qtdGuias,
      required this.protocolo});
  factory Recebimento.fromJson(Map<String, dynamic> j) => Recebimento(
        id: j['_id'] ?? '',
        viagemData: j['viagem_data'] ?? '',
        codigoOrigem: j['codigo_origem'] ?? '',
        origem: j['origem'] ?? '',
        status: j['status'] ?? '',
        placaVeiculo: j['placa_veiculo'] ?? '',
        dataRecebimento: j['data_recebimento'] ?? '',
        qtdRolls: j['qtd_rolls'] ?? 0,
        qtdGuias: j['qtd_guias'] ?? 0,
        protocolo: j['protocolo'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        '_id': id,
        'viagem_data': viagemData,
        'codigo_origem': codigoOrigem,
        'origem': origem,
        'status': status,
        'placa_veiculo': placaVeiculo,
        'data_recebimento': dataRecebimento,
        'qtd_rolls': qtdRolls,
        'qtd_guias': qtdGuias,
        'protocolo': protocolo,
      };
}

class QtdRecebimentos {
  final int pendente;
  final int erro;
  QtdRecebimentos({required this.pendente, required this.erro});
  factory QtdRecebimentos.fromJson(Map<String, dynamic> j) => QtdRecebimentos(
        pendente: j['pendente'] ?? 0,
        erro: j['erro'] ?? 0,
      );
}

class PrinterResponse {
  final List<Printer> printers;
  final List<AvailablePrinter> availablePrinter;
  PrinterResponse({required this.printers, required this.availablePrinter});
  factory PrinterResponse.fromJson(Map<String, dynamic> j) => PrinterResponse(
        printers: (j['printers'] as List? ?? [])
            .map((e) => Printer.fromJson(e))
            .toList(),
        availablePrinter: (j['availablePrinter'] as List? ?? [])
            .map((e) => AvailablePrinter.fromJson(e))
            .toList(),
      );
}

class Printer {
  final String id;
  final String name;
  final String store;
  final List<PrinterTag> tags;
  Printer(
      {required this.id,
      required this.name,
      required this.store,
      required this.tags});
  factory Printer.fromJson(Map<String, dynamic> j) => Printer(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        store: j['store'] ?? '',
        tags: (j['tags'] as List? ?? [])
            .map((e) => PrinterTag.fromJson(e))
            .toList(),
      );
}

class PrinterTag {
  final String id;
  final String name;
  final String orientation;
  PrinterTag(
      {required this.id, required this.name, required this.orientation});
  factory PrinterTag.fromJson(Map<String, dynamic> j) => PrinterTag(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        orientation: j['orientation'] ?? '',
      );
}

class AvailablePrinter {
  final String id;
  final String name;
  final List<AvailableTag> tag;
  final List<Orientation> orientations;
  AvailablePrinter(
      {required this.id,
      required this.name,
      required this.tag,
      required this.orientations});
  factory AvailablePrinter.fromJson(Map<String, dynamic> j) => AvailablePrinter(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        tag: (j['tag'] as List? ?? [])
            .map((e) => AvailableTag.fromJson(e))
            .toList(),
        orientations: (j['orientations'] as List? ?? [])
            .map((e) => Orientation.fromJson(e))
            .toList(),
      );
}

class AvailableTag {
  final String id;
  final String name;
  final bool selected;
  AvailableTag({required this.id, required this.name, required this.selected});
  factory AvailableTag.fromJson(Map<String, dynamic> j) => AvailableTag(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        selected: j['selected'] ?? false,
      );
}

class Orientation {
  final String name;
  final bool selected;
  Orientation({required this.name, required this.selected});
  factory Orientation.fromJson(Map<String, dynamic> j) => Orientation(
        name: j['name'] ?? '',
        selected: j['selected'] ?? false,
      );
}

class SingleLabelResponse {
  final List<SingleLabelItem> items;
  SingleLabelResponse({required this.items});
  factory SingleLabelResponse.fromJson(Map<String, dynamic> j) =>
      SingleLabelResponse(
        items: (j['items'] as List? ?? [])
            .map((e) => SingleLabelItem.fromJson(e))
            .toList(),
      );
}

class SingleLabelItem {
  final String id;
  final String sap;
  final String department;
  final String ean;
  final String description;
  final String startDate;
  final String endDate;
  final String duration;
  final String price;
  final String movement;
  final String status;
  bool checkbox;
  int quantity;
  final SingleLabelPrintingData? printingData;
  SingleLabelItem(
      {required this.id,
      required this.sap,
      required this.department,
      required this.ean,
      required this.description,
      required this.startDate,
      required this.endDate,
      required this.duration,
      required this.price,
      required this.movement,
      required this.status,
      this.checkbox = false,
      this.quantity = 1,
      this.printingData});
  factory SingleLabelItem.fromJson(Map<String, dynamic> j) => SingleLabelItem(
        id: j['id'] ?? '',
        sap: j['sap'] ?? '',
        department: j['department'] ?? '',
        ean: j['ean'] ?? '',
        description: j['description'] ?? '',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        duration: j['duration'] ?? '',
        price: j['price'] ?? '',
        movement: j['movement'] ?? '',
        status: j['status'] ?? '',
        checkbox: j['checkbox'] ?? false,
        quantity: j['quantity'] ?? 1,
        printingData: j['_printingData'] != null
            ? SingleLabelPrintingData.fromJson(j['_printingData'])
            : null,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'sap': sap,
        'department': department,
        'ean': ean,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'duration': duration,
        'price': price,
        'movement': movement,
        'status': status,
        'checkbox': checkbox,
        'quantity': quantity,
        '_printingData': printingData?.toJson(),
      };
}

class SingleLabelPrintingData {
  final String? template;
  final String ean;
  final String description;
  final String department;
  final double displayPrice;
  final PriceInfo price;
  final PromotionalPriceInfo? promotionalPrice;
  final int quantity;
  final String movementType;
  final String unit;
  final double unitQty;
  final double unitValue;
  final bool printUnitValue;
  final String codSap;
  final TakeAndWin takeAndWin;
  final String referenceDate;
  SingleLabelPrintingData(
      {this.template,
      required this.ean,
      required this.description,
      required this.department,
      required this.displayPrice,
      required this.price,
      this.promotionalPrice,
      required this.quantity,
      required this.movementType,
      required this.unit,
      required this.unitQty,
      required this.unitValue,
      required this.printUnitValue,
      required this.codSap,
      required this.takeAndWin,
      required this.referenceDate});
  factory SingleLabelPrintingData.fromJson(Map<String, dynamic> j) =>
      SingleLabelPrintingData(
        template: j['template'],
        ean: j['ean'] ?? '',
        description: j['description'] ?? '',
        department: j['department'] ?? '',
        displayPrice: (j['displayPrice'] ?? 0).toDouble(),
        price: PriceInfo.fromJson(j['price']),
        promotionalPrice: j['promotionalPrice'] != null
            ? PromotionalPriceInfo.fromJson(j['promotionalPrice'])
            : null,
        quantity: j['quantity'] ?? 1,
        movementType: j['movementType'] ?? '',
        unit: j['unit'] ?? '',
        unitQty: (j['unitQty'] ?? 0).toDouble(),
        unitValue: (j['unitValue'] ?? 0).toDouble(),
        printUnitValue: j['printUnitValue'] ?? false,
        codSap: j['codSap'] ?? '',
        takeAndWin: TakeAndWin.fromJson(j['takeAndWin']),
        referenceDate: j['referenceDate'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        'template': template,
        'ean': ean,
        'description': description,
        'department': department,
        'displayPrice': displayPrice,
        'price': price.toJson(),
        'promotionalPrice': promotionalPrice?.toJson(),
        'quantity': quantity,
        'movementType': movementType,
        'unit': unit,
        'unitQty': unitQty,
        'unitValue': unitValue,
        'printUnitValue': printUnitValue,
        'codSap': codSap,
        'takeAndWin': takeAndWin.toJson(),
        'referenceDate': referenceDate,
      };
}

class BusinessHours {
  final DayHours sunday;
  final DayHours monday;
  final DayHours tuesday;
  final DayHours wednesday;
  final DayHours thursday;
  final DayHours friday;
  final DayHours saturday;
  BusinessHours(
      {required this.sunday,
      required this.monday,
      required this.tuesday,
      required this.wednesday,
      required this.thursday,
      required this.friday,
      required this.saturday});
  factory BusinessHours.fromJson(Map<String, dynamic> j) => BusinessHours(
        sunday: DayHours.fromJson(j['sunday']),
        monday: DayHours.fromJson(j['monday']),
        tuesday: DayHours.fromJson(j['tuesday']),
        wednesday: DayHours.fromJson(j['wednesday']),
        thursday: DayHours.fromJson(j['thursday']),
        friday: DayHours.fromJson(j['friday']),
        saturday: DayHours.fromJson(j['saturday']),
      );
}

class DayHours {
  final String opening;
  final String closing;
  final String open;
  DayHours({required this.opening, required this.closing, required this.open});
  factory DayHours.fromJson(Map<String, dynamic> j) => DayHours(
        opening: j['opening'] ?? '',
        closing: j['closing'] ?? '',
        open: j['open'] ?? '',
      );
}

class SpecialBusinessHours {
  final String date;
  final String? opening;
  final String? closing;
  final String? open;
  final bool special;
  SpecialBusinessHours(
      {required this.date,
      this.opening,
      this.closing,
      this.open,
      this.special = false});
  factory SpecialBusinessHours.fromJson(Map<String, dynamic> j) =>
      SpecialBusinessHours(
        date: j['date'] ?? '',
        opening: j['opening'],
        closing: j['closing'],
        open: j['open'],
        special: j['special'] ?? false,
      );
}

class LoginRequest {
  final String email;
  final String password;
  LoginRequest({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class SessionLoginResponse {
  final String? sessionToken;
  final String? token;
  final UserInfo? user;
  final String? message;
  final bool success;
  SessionLoginResponse(
      {this.sessionToken, this.token, this.user, this.message, this.success = false});
  factory SessionLoginResponse.fromJson(Map<String, dynamic> j) =>
      SessionLoginResponse(
        sessionToken: j['session_token'],
        token: j['token'],
        user: j['user'] != null ? UserInfo.fromJson(j['user']) : null,
        message: j['message'],
        success: j['success'] ?? false,
      );
}

class UserInfo {
  final String email;
  final String name;
  final List<String> stores;
  final List<String> roles;
  final List<String> grupo;
  final List<String> perfil;
  UserInfo(
      {required this.email,
      required this.name,
      required this.stores,
      required this.roles,
      required this.grupo,
      required this.perfil});
  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        stores: List<String>.from(j['stores'] ?? []),
        roles: List<String>.from(j['roles'] ?? []),
        grupo: List<String>.from(j['grupo'] ?? []),
        perfil: List<String>.from(j['perfil'] ?? []),
      );
}
