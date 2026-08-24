import '../models/models.dart';
import '../database/app_database.dart';

class ListaStore {
  static final ListaStore instance = ListaStore._();
  ListaStore._();

  // ========== ETIQUETAS ==========
  Future<List<PriceTag>> getEtiquetas() async {
    try {
      return await AppDatabase.recuperarEtiquetas();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveEtiquetas(List<PriceTag> list) async {
    try {
      await AppDatabase.salvarEtiquetas(list);
    } catch (e) {}
  }

  Future<void> addEtiqueta(PriceTag item) async {
    final current = await getEtiquetas();
    current.add(item);
    await saveEtiquetas(current);
  }

  Future<void> addEtiquetas(List<PriceTag> items) async {
    final current = await getEtiquetas();
    current.addAll(items);
    await saveEtiquetas(current);
  }

  Future<void> removeEtiqueta(PriceTag item) async {
    final current = await getEtiquetas();
    current.removeWhere((e) => e.id == item.id);
    await saveEtiquetas(current);
  }

  Future<void> clearEtiquetas() async => saveEtiquetas([]);

  // ========== PAPELETAS ==========
  Future<List<PriceSign>> getPapeletas() async {
    try {
      return await AppDatabase.recuperarPapeletas();
    } catch (e) {
      return [];
    }
  }

  Future<void> savePapeletas(List<PriceSign> list) async {
    try {
      await AppDatabase.salvarPapeletas(list);
    } catch (e) {}
  }

  Future<void> addPapeleta(PriceSign item) async {
    final current = await getPapeletas();
    current.add(item);
    await savePapeletas(current);
  }

  Future<void> addPapeletas(List<PriceSign> items) async {
    final current = await getPapeletas();
    current.addAll(items);
    await savePapeletas(current);
  }

  Future<void> removePapeleta(PriceSign item) async {
    final current = await getPapeletas();
    current.removeWhere((e) => e.id == item.id);
    await savePapeletas(current);
  }

  Future<void> clearPapeletas() async => savePapeletas([]);

  // ========== ÁREA DE COLAGEM ==========
  Future<String> getColagem() async {
    try {
      return await AppDatabase.recuperarColagem();
    } catch (e) {
      return "";
    }
  }

  Future<void> setColagem(String code) async {
    try {
      await AppDatabase.salvarColagem(code);
    } catch (e) {}
  }
}
