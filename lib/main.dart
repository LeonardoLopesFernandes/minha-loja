import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/session_manager.dart';
import 'core/lista_store.dart';
import 'network/api_client.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/login_webview_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/etiquetas/etiquetas_screen.dart';
import 'screens/papeletas/papeletas_diarias_screen.dart';
import 'screens/pdf/pdf_viewer_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/modelo/modelo_editavel_screen.dart';
import 'screens/barcode/barcode_scanner_screen.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = await SessionManager.getInstance();
  await sessionManager.getToken();
  ApiClient.instance.init(sessionManager);

  runApp(
    MultiProvider(
      providers: [
        Provider<SessionManager>.value(value: sessionManager),
        Provider<ListaStore>.value(value: ListaStore.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha Loja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute:
          SessionManager.instance?.isLoggedIn() == true ? '/main' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/etiquetas': (context) => const EtiquetasScreen(),
        '/papeletas_diarias': (context) => const PapeletasDiariasScreen(),
        '/pdf_viewer': (context) => const PdfViewerScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/modelo_editavel': (context) => const ModeloEditavelScreen(),
        '/barcode': (context) => const BarcodeScannerScreen(),
      },
    );
  }
}
