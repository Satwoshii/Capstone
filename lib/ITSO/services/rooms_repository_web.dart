// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'rooms_repository.dart';

class WebLocalRoomsRepository implements RoomsRepository {
  static const _key = 'itso_labs_v1';

  @override
  Future<List<String>> loadLabs() async {
    final s = html.window.localStorage[_key];
    if (s == null || s.isEmpty) {
      return ['706', '707', '708', '709', '710', '722']; // defaults
    }
    try {
      final list = (jsonDecode(s) as List).map((e) => e.toString()).toList();
      return list;
    } catch (_) {
      return ['706', '707', '708', '709', '710', '722'];
    }
  }

  @override
  Future<void> saveLabs(List<String> labs) async {
    html.window.localStorage[_key] = jsonEncode(labs);
  }
}
