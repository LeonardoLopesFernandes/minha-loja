import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, "MinhaLoja.db");
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute(
          "CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, json TEXT)");
    });
    return _db!;
  }

  static Future<void> salvarEtiquetas(List<PriceTag> list) async {
    final db = await database;
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await db.insert('cache', {'key': 'etiquetas', 'json': json},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<PriceTag>> recuperarEtiquetas() async {
    final db = await database;
    final cursor = await db.query('cache',
        columns: ['json'], where: 'key = ?', whereArgs: ['etiquetas']);
    if (cursor.isNotEmpty) {
      final json = cursor.first['json'] as String;
      try {
        final list = jsonDecode(json) as List;
        return list.map((e) => PriceTag.fromJson(e)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Future<void> salvarPapeletas(List<PriceSign> list) async {
    final db = await database;
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await db.insert('cache', {'key': 'papeletas', 'json': json},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<PriceSign>> recuperarPapeletas() async {
    final db = await database;
    final cursor = await db.query('cache',
        columns: ['json'], where: 'key = ?', whereArgs: ['papeletas']);
    if (cursor.isNotEmpty) {
      final json = cursor.first['json'] as String;
      try {
        final list = jsonDecode(json) as List;
        return list.map((e) => PriceSign.fromJson(e)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Future<void> salvarColagem(String code) async {
    final db = await database;
    await db.insert('cache', {'key': 'colagem', 'json': code},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String> recuperarColagem() async {
    final db = await database;
    final cursor = await db.query('cache',
        columns: ['json'], where: 'key = ?', whereArgs: ['colagem']);
    if (cursor.isNotEmpty) {
      return cursor.first['json'] as String;
    }
    return "";
  }

  static Future<void> limparCache() async {
    final db = await database;
    await db.delete('cache');
  }
}
