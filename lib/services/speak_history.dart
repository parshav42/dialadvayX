// lib/services/speak_history.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SpeakEntry {
  final DateTime when;
  final String? note;

  SpeakEntry({required this.when, this.note});

  Map<String, dynamic> toJson() => {
    "when": when.toIso8601String(),
    "note": note,
  };

  static SpeakEntry fromJson(Map<String, dynamic> map) => SpeakEntry(
    when: DateTime.parse(map["when"]),
    note: map["note"],
  );
}

class SpeakHistoryStore {
  static const _key = "speak_history";

  Future<Map<String, List<SpeakEntry>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);
    if (raw == null) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final map = <String, List<SpeakEntry>>{};

    decoded.forEach((id, list) {
      map[id] = (list as List)
          .map((e) => SpeakEntry.fromJson(e))
          .toList();
    });

    return map;
  }

  Future<List<SpeakEntry>> loadEntries(String id) async {
    final all = await _loadAll();
    return all[id] ?? [];
  }

  Future<void> add(String id, SpeakEntry entry) async {
    final all = await _loadAll();

    final list = all[id] ?? [];
    list.insert(0, entry);

    all[id] = list;

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      all.map((key, value) =>
          MapEntry(key, value.map((e) => e.toJson()).toList())),
    );

    await prefs.setString(_key, encoded);
  }
}
