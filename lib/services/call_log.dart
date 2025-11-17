import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CallLogEntry {
  final String number;
  final DateTime when;
  final String? name;
  final String? note; // e.g., recognized speech

  CallLogEntry({
    required this.number,
    required this.when,
    this.name,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'when': when.toUtc().toIso8601String(),
        if (name != null) 'name': name,
        if (note != null) 'note': note,
      };

  factory CallLogEntry.fromJson(Map<String, dynamic> json) => CallLogEntry(
        number: json['number'] as String,
        when: DateTime.parse(json['when'] as String).toLocal(),
        name: json['name'] as String?,
        note: json['note'] as String?,
      );
}

class CallLogStore {
  static const _key = 'call_log_entries';

  Future<List<CallLogEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    final entries = <CallLogEntry>[];
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        entries.add(CallLogEntry.fromJson(map));
      } catch (_) {
        // ignore
      }
    }
    entries.sort((a, b) => b.when.compareTo(a.when));
    return entries;
  }

  Future<void> add(CallLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_key, list);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
