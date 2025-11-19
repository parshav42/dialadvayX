// lib/services/call_log.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CallLogEntry {
  final String id;
  final String number;
  final String? name;
  final DateTime when;
  final Duration duration;
  final String? filePath;
  final String? note;
  final bool isSaved;
  final bool isDeleted;

  CallLogEntry({
    required this.id,
    required this.number,
    required this.when,
    required this.duration,
    this.name,
    this.filePath,
    this.note,
    this.isSaved = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "number": number,
    "name": name,
    "when": when.toIso8601String(),
    "duration": duration.inSeconds,
    "filePath": filePath,
    "note": note,
    "isSaved": isSaved,
    "isDeleted": isDeleted,
  };

  static CallLogEntry fromJson(Map<String, dynamic> map) => CallLogEntry(
    id: map["id"],
    number: map["number"],
    name: map["name"],
    when: DateTime.parse(map["when"]),
    duration: Duration(seconds: map["duration"] ?? 0),
    filePath: map["filePath"],
    note: map["note"],
    isSaved: map["isSaved"] ?? false,
    isDeleted: map["isDeleted"] ?? false,
  );
}

class CallLogStore {
  static const _key = "call_logs";

  Future<List<CallLogEntry>> load({bool includeDeleted = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return [];

    final decoded = jsonDecode(raw) as List;
    final all = decoded.map((e) => CallLogEntry.fromJson(e)).toList();

    if (!includeDeleted) {
      return all.where((e) => !e.isDeleted).toList();
    }

    return all;
  }

  Future<void> _save(List<CallLogEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(all.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> add(CallLogEntry entry) async {
    final all = await load(includeDeleted: true);
    all.insert(0, entry);
    await _save(all);
  }

  Future<void> toggleSave(String id) async {
    final all = await load(includeDeleted: true);

    final updated = all.map((e) {
      if (e.id == id) {
        return CallLogEntry(
          id: e.id,
          number: e.number,
          name: e.name,
          when: e.when,
          duration: e.duration,
          filePath: e.filePath,
          note: e.note,
          isSaved: !e.isSaved,
          isDeleted: e.isDeleted,
        );
      }
      return e;
    }).toList();

    await _save(updated);
  }

  Future<void> moveToTrash(String id) async {
    final all = await load(includeDeleted: true);

    final updated = all.map((e) {
      if (e.id == id) {
        return CallLogEntry(
          id: e.id,
          number: e.number,
          name: e.name,
          when: e.when,
          duration: e.duration,
          filePath: e.filePath,
          note: e.note,
          isSaved: e.isSaved,
          isDeleted: true,
        );
      }
      return e;
    }).toList();

    await _save(updated);
  }

  Future<void> restoreFromTrash(String id) async {
    final all = await load(includeDeleted: true);

    final updated = all.map((e) {
      if (e.id == id) {
        return CallLogEntry(
          id: e.id,
          number: e.number,
          name: e.name,
          when: e.when,
          duration: e.duration,
          filePath: e.filePath,
          note: e.note,
          isSaved: e.isSaved,
          isDeleted: false,
        );
      }
      return e;
    }).toList();

    await _save(updated);
  }

  Future<void> deletePermanently(String id) async {
    final all = await load(includeDeleted: true);
    final left = all.where((e) => e.id != id).toList();
    await _save(left);
  }

  Future<void> clearTrash() async {
    final all = await load(includeDeleted: true);
    final left = all.where((e) => !e.isDeleted).toList();
    await _save(left);
  }
}
