import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captura erros não tratados (Dart) em arquivo para diagnóstico de crashes
/// em produção. No próximo abrir do app, [promptIfCrashed] oferece o
/// compartilhamento do log.
class CrashLogger {
  static const _name = 'ultimo_crash.txt';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_name');
  }

  static Future<void> write(String source, String detail) async {
    try {
      final f = await _file();
      final ts = DateTime.now().toIso8601String();
      await f.writeAsString('[$ts] [$source]\n$detail\n\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // Nunca lançar ao tentar registrar um crash.
    }
  }

  static Future<String?> readLast() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final t = await f.readAsString();
      return t.trim().isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.writeAsString('', flush: true);
    } catch (_) {}
  }

  /// Instala os hooks globais. Chamar ANTES do runApp.
  static void install() {
    FlutterError.onError = (details) {
      write('FlutterError', '${details.exception}\n${details.stack}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      write('UncaughtDart', '$e\n$st');
      return true; // consome o erro (evita crash seco); app segue onde der.
    };
  }

  /// Se existe log de crash, mostra diálogo para compartilhar/limpar.
  static Future<void> promptIfCrashed(BuildContext context) async {
    final content = await readLast();
    if (content == null || !context.mounted) return;
    final res = await showDialog<_CrashAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Último crash registrado'),
        content: const Text(
            'Encontramos o registro do último travamento.\n'
            'Compartilhe o arquivo com o suporte para correção exata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _CrashAction.ignore),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _CrashAction.clear),
            child: const Text('Limpar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _CrashAction.share),
            child: const Text('Compartilhar'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (res) {
      case _CrashAction.share:
        final dir = await getApplicationSupportDirectory();
        await Share.shareXFiles(
          [XFile('${dir.path}/$_name', mimeType: 'text/plain')],
          text: 'Log de crash minhaloja',
        );
        break;
      case _CrashAction.clear:
        await clear();
        break;
      default:
        break;
    }
  }
}

enum _CrashAction { share, clear, ignore }
