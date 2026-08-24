class Constants {
  static const String defaultStore = "L291";

  // Recebimento
  static const String recebimentoPendente = "pendente";
  static const String recebimentoRecebido = "recebido";
  static const String recebimentoAnomalia = "anomalia";
  static const String recebimentoErro = "erro";

  // Status etiquetas
  static const String statusImpressas = "IMPRESSAS";
  static const String statusNaoImpressas = "NAO_IMPRESSAS";
  static const String statusAll = "IMPRESSAS,NAO_IMPRESSAS";

  // Impressoras
  static const String printerLaser1 = "LASER_1";
  static const String printerZebra1 = "ZEBRA_1";
  static const String printerZebra2 = "ZEBRA_2";

  // Tags
  static const String tagGondola = "GONDOLA";
  static const String tagAdesiva = "ADESIVA";
  static const String tagCartao = "CARTAO";

  // Tipos de papeleta
  static const String signTypePapeletaComum = "PAPELETA_COMUM";
  static const String signTypePapeletaPromocional = "PAPELETA_PROMOCIONAL";
  static const String tipoComum = "PAPELETA_COMUM";
  static const String tipoPromocional = "PAPELETA_PROMOCIONAL";
  static const String signTypePapeletaPromocionalModelo =
      "PAPELETA_PROMOCIONAL_MODELO";
  static const String signTemplateModelo = "leve_ganhe_total";
  static const String signTemplateModeloEditavel = "Modelo Editável";
  static const String signTemplateDepor = "De/Por";
  static const String signTemplateDeporParcelado = "Parcelado";
  static const String signTemplateLeveGanheCada = "leve_ganhe_cada";
  static const String signTemplateLeveGanheTotal = "leve_ganhe_total";

  static String? templateNormalizado(String? template) {
    if (template == signTemplateLeveGanheCada) return signTemplateModelo;
    return template;
  }

  static double totalLeveGanhe(
      double? promotionPrice, double? takeAndWinPrice, int? takeAndWinQuantity) {
    if (promotionPrice != null && promotionPrice > 0) return promotionPrice;
    final preco = takeAndWinPrice ?? 0;
    final qtd = takeAndWinQuantity ?? 1;
    return preco * qtd;
  }

  static double totalLeveGanhePorTemplate(String? template, double? promotionPrice,
      double? takeAndWinPrice, int? takeAndWinQuantity) {
    if (template == signTemplateModelo) return takeAndWinPrice ?? 0.0;
    return totalLeveGanhe(promotionPrice, takeAndWinPrice, takeAndWinQuantity);
  }

  // Movimento
  static const String movementAll = "";
  static const String movementDepor = "De/Por";
  static const String movementLeve = "Leve e Ganhe";
  static const String movementComum = "Comum";
  static const String movementNormal = "Normal";

  // Tamanhos
  static const String signSize1x1 = "1X1";
  static const String signSize2x1 = "2X1";
  static const String signSize4x1 = "4X1";
  static const String signSize6x1 = "6X1";

  static const String dateFormatApi = "2026-06-20";

  static const String baseUrlSl = "https://sl-bff.americanas.io/";
  static const String baseUrlMinhaloja = "https://minhaloja-bff.americanas.io/";
  static const String baseUrlMinhalojaWeb = "https://minhaloja.americanas.io/";
}

class ApiUrls {
  static const String baseUrlSl = "https://sl-bff.americanas.io/";
  static const String baseUrlMinhaloja = "https://minhaloja-bff.americanas.io/";
  static const String baseUrlMinhalojaWeb = "https://minhaloja.americanas.io/";
}

class MicrosoftOAuthConfig {
  static const String tenant = "e316d1ac-42c8-4d30-817c-12c7a71f8ab2";
  static const String clientId = "16021f31-43f8-4f7a-8af4-5e47efe7db8a";
  // ATENÇÃO: não versionar segredos. Preencha em runtime via variável de
  // ambiente / secrets do build (ex.: dart-define CLIENT_SECRET=...).
  static String clientSecret = const String.fromEnvironment(
    'CLIENT_SECRET',
    defaultValue: '',
  );
  static const String scopes = "openid profile offline_access";
  static const String redirectUri =
      "https://apimobile.brasilrisk.com.br/Validar/SamlResponseConsumer";

  static const String authorizeUrl =
      "https://login.microsoftonline.com/$tenant/oauth2/v2.0/authorize";
  static const String tokenUrl =
      "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token";
  static const String deviceCodeUrl =
      "https://login.microsoftonline.com/$tenant/oauth2/v2.0/devicecode";
  static const String validarUrl =
      "https://apimobile.brasilrisk.com.br/validar/LoginMobileDeliveryClientMicrosoft";

  static String getAuthorizeUrl({String state = "mloja"}) {
    return "$authorizeUrl?"
        "client_id=$clientId"
        "&response_type=code"
        "&redirect_uri=${Uri.encodeComponent(redirectUri)}"
        "&scope=${Uri.encodeComponent(scopes)}"
        "&response_mode=query"
        "&state=$state"
        "&nonce=mloja$state";
  }

  static const String loginUrl =
      "https://login.microsoftonline.com/e316d1ac-42c8-4d30-817c-12c7a71f8ab2/saml2?SAMLRequest=nVPLjhoxEPyVke%2Beh4fdYS1gRUBRkDYJApJDLlGPp2dx4gdxezYkXx8xQMIhy4Gru1RVXdUePe6tSV4wkPZuzIo0Z4%2BTEYE1Oznt4tat8EeHFJO9NY5kPxizLjjpgTRJBxZJRiXX0%2FdPUqS53AUfvfKGJYv5mH29K%2B%2BwflDQVrlohVICy5Yln8%2BCIs1ZsiDqcOEogotjJnJxz%2FN7LgYbUcqikqJMi7z4wpLlifqNdo12z9d91EcQyXebzZIvP643LJkjRe0g9tLbGHcks8z4Z%2B1Sq1Xw5NvondEOU%2BVthmVx3xSg%2BECoIR80Zc6HRaV4IVQFVdEOoRbZIRLBkikRhgPxzDvqLIY1hhet8NPq6Z8UGQ5d3Pqgf%2FcmUrAYtAIHlGqfWe22wI3%2FBpkCY2pQ39mxDNlHFC5auL48nN2wCcKwaaui4YhNyQfDhwEHqEtegWhzUau6yttRdiFyrv8DWFzMl95o9euW%2Bt%2F6YCG%2Bji7Son%2FRDW97qEQL2kybJiARS6bG%2BJ%2BzgBBxzGLokGVna6ejxKY%2F0Zl3Efc3nejM2x0ETYd7wD2oeM77knhmgGiF7S3pX4UpqQ7USLJztEOlW43NqYv%2FGZgcZ6%2Fs%2F3d6%2BW8nfwA%3D&sso_reload=true";
}
