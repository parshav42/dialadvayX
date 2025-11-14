import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SpeakEntry {
  final DateTime when;
  final String? note;

  SpeakEntry({required this.when, this.note});

  Map<String, dynamic> toJson() => {
        'when': when.toUtc().toIso8601String(),
        if (note != null) 'note': note,
      };

  factory SpeakEntry.fromJson(Map<String, dynamic> json) => SpeakEntry(
        when: DateTime.parse(json['when'] as String).toLocal(),
        note: json['note'] as String?,
      );
}

class SpeakHistoryStore {
  String _key(String contactId) => 'speak_history_' + contactId;

  // Backward-compatible: returns dates only.
  Future<List<DateTime>> loadHistory(String contactId) async {
    final entries = await loadEntries(contactId);
    final dates = entries.map((e) => e.when).toList()
      ..sort((a, b) => b.compareTo(a));
    return dates;
  }

  // New: full entries with optional notes.
  Future<List<SpeakEntry>> loadEntries(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(contactId)) ?? <String>[];
    final entries = <SpeakEntry>[];
    for (final s in list) {
      if (s.trim().startsWith('{')) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          entries.add(SpeakEntry.fromJson(map));
          continue;
        } catch (_) {}
      }
      // Fallback legacy ISO timestamp without note
      try {
        entries.add(SpeakEntry(when: DateTime.parse(s).toLocal()));
      } catch (_) {}
    }
    entries.sort((a, b) => b.when.compareTo(a.when));
    return entries;
  }

  Future<void> logSpeak(String contactId, DateTime when, {String? note}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(contactId);
    final list = prefs.getStringList(key) ?? <String>[];
    final entry = SpeakEntry(when: when, note: note);
    list.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(key, list);
  }

  Future<void> clearHistory(String contactId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(contactId));
  }
}
