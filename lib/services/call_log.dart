// lib/services/call_log.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_storage_service.dart';

class CallLogEntry {
  final String id;
  final String number;
  final DateTime when;
  final String? name;
  final String? note;
  bool isSaved;
  bool isDeleted;
  final String? filePath;

  CallLogEntry({
    String? id,
    required this.number,
    required this.when,
    this.name,
    this.note,
    this.isSaved = false,
    this.isDeleted = false,
    this.filePath,
  }) : id = id ?? '${when.millisecondsSinceEpoch}_${number.hashCode}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'when': when.toUtc().toIso8601String(),
    if (name != null) 'name': name,
    if (note != null) 'note': note,
    'isSaved': isSaved,
    'isDeleted': isDeleted,
    if (filePath != null) 'filePath': filePath,
  };

  factory CallLogEntry.fromJson(Map<String, dynamic> json) => CallLogEntry(
    id: json['id'] as String?,
    number: json['number'] as String,
    when: DateTime.parse(json['when'] as String).toLocal(),
    name: json['name'] as String?,
    note: json['note'] as String?,
    isSaved: json['isSaved'] as bool? ?? false,
    isDeleted: json['isDeleted'] as bool? ?? false,
    filePath: json['filePath'] as String?,
  );

  CallLogEntry copyWith({
    String? number,
    DateTime? when,
    String? name,
    String? note,
    bool? isSaved,
    bool? isDeleted,
    String? filePath,
  }) {
    return CallLogEntry(
      id: id,
      number: number ?? this.number,
      when: when ?? this.when,
      name: name ?? this.name,
      note: note ?? this.note,
      isSaved: isSaved ?? this.isSaved,
      isDeleted: isDeleted ?? this.isDeleted,
      filePath: filePath ?? this.filePath,
    );
  }
}

class CallLogStore {
  static const _key = 'call_log_entries';

  Future<List<CallLogEntry>> load({bool includeDeleted = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    final entries = <CallLogEntry>[];
    for (final s in list) {
      try {
        final entry = CallLogEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map));
        if (includeDeleted || !entry.isDeleted) {
          entries.add(entry);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    return entries..sort((a, b) => b.when.compareTo(a.when));
  }

  Future<void> add(CallLogEntry entry) async {
    final entries = await load(includeDeleted: true);
    final existingIndex = entries.indexWhere((e) => e.id == entry.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }
    await _save(entries);
  }

  Future<void> updateEntry(
      String id, CallLogEntry Function(CallLogEntry) update) async {
    final entries = await load(includeDeleted: true);
    final index = entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      entries[index] = update(entries[index]);
      await _save(entries);
    }
  }

  Future<void> toggleSave(String id) async {
    await updateEntry(id, (entry) => entry.copyWith(isSaved: !entry.isSaved));
  }

  Future<void> moveToTrash(String id) async {
    await updateEntry(id, (entry) => entry.copyWith(isDeleted: true));
  }

  Future<void> restoreFromTrash(String id) async {
    await updateEntry(id, (entry) => entry.copyWith(isDeleted: false));
  }

  Future<void> deletePermanently(String id) async {
    final entries = await load(includeDeleted: true);
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  Future<void> clearTrash() async {
    final entries = await load(includeDeleted: true);
    final filtered = entries.where((e) => !e.isDeleted).toList();
    await _save(filtered);
  }

  Future<void> clear() async {
    try {
      final dataStorage = DataStorageService();
      await dataStorage.init();
      
      // Clear using DataStorageService
      await dataStorage.saveCallLogs([]);
      
      // Also clear any legacy data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (e) {
        print('Error clearing legacy data: $e');
      }
    } catch (e) {
      print('Error clearing call logs: $e');
      rethrow;
    }
  }

  Future<void> _save(List<CallLogEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, list);
  }
}