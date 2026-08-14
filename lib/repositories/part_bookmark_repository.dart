import '../database/database_helper.dart';

class PartBookmarkRepository {
  PartBookmarkRepository._();
  static final instance = PartBookmarkRepository._();
  final _db = DatabaseHelper.instance;

  Future<List<Map<String, Object?>>> getAll() => _db.getPartBookmarks();

  Future<int> save({
    int? id,
    required String name,
    String? brand,
    String? article,
    String? shop,
    double? price,
    String? url,
    String? note,
  }) {
    return _db.savePartBookmark({
      'name': name.trim(),
      'brand': _clean(brand),
      'article': _clean(article),
      'shop': _clean(shop),
      'price': price,
      'url': _clean(url),
      'note': _clean(note),
    }, id: id);
  }

  Future<void> delete(int id) => _db.deletePartBookmark(id);

  String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
