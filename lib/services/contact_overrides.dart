// lib/services/contact_overrides.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContactOverride {
  final String id;
  final String? name;
  final String? photoPath;

  ContactOverride({
    required this.id,
    this.name,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "photoPath": photoPath,
  };

  static ContactOverride fromJson(Map<String, dynamic> map) =>
      ContactOverride(
        id: map["id"],
        name: map["name"],
        photoPath: map["photoPath"],
      );
}

class ContactOverridesStore {
  static const _key = "contact_overrides";

  Future<Map<String, ContactOverride>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);
    if (raw == null) return {};

    final decoded = jsonDecode(raw) as List;

    final map = <String, ContactOverride>{};
    for (var item in decoded) {
      final co = ContactOverride.fromJson(item);
      map[co.id] = co;
    }

    return map;
  }

  Future<void> _save(Map<String, ContactOverride> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
    jsonEncode(all.values.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> upsert(ContactOverride item) async {
    final all = await load();
    all[item.id] = item;
    await _save(all);
  }
}
