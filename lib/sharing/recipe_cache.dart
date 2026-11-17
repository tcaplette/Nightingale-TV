import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/app_storage.dart';
import 'channel_recipe.dart';

/// The receiver's last recipe of each shared copy (channel-sharing D5), as
/// `share_recipes/<id>.json.gz` in the profile's folder, for re-matching
/// after library scans.
///
/// Backups read only the files they name, so it is never in one; after a
/// restore it's fetched again on the next connect.
class RecipeCache {
  RecipeCache(this._storage);

  static const folder = 'share_recipes';

  final AppStorage _storage;

  File _file(String id) => File(_storage.pathOf('$folder/${_safe(id)}.json.gz'));

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<void> put(String id, Map<String, Object?> recipe) async {
    final f = _file(id);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(gzip.encode(utf8.encode(jsonEncode(recipe))), flush: true);
    await tmp.rename(f.path);
  }

  /// The cached recipe; null when there's none, it can't be read, or it is
  /// from a newer app.
  Future<ChannelRecipe?> get(String id) async {
    final f = _file(id);
    try {
      if (!await f.exists()) return null;
      return ChannelRecipe.fromJson(jsonDecode(utf8.decode(gzip.decode(await f.readAsBytes()))));
    } on Object catch (e) {
      debugPrint('Unreadable shared recipe $id: $e');
      return null;
    }
  }

  Future<bool> has(String id) => _file(id).exists();

  Future<void> remove(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}
