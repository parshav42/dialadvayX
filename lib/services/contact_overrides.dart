import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactOverride {
  final String id; // stable key: prefer primary phone number
  final String? name;
  final String? photoPath; // absolute path to local image

  ContactOverride({required this.id, this.name, this.photoPath});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
      };

  factory ContactOverride.fromJson(Map<String, dynamic> json) => ContactOverride(
        id: json['id'] as String,
        name: json['name'] as String?,
        photoPath: json['photoPath'] as String?,
      );
}

class ContactOverridesStore {
  static const _prefsKey = 'contact_overrides_v1';

  Future<Map<String, ContactOverride>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, ContactOverride.fromJson(Map<String, dynamic>.from(v as Map))));
  }

  Future<void> saveAll(Map<String, ContactOverride> map) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = map.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_prefsKey, json.encode(jsonMap));
  }

  Future<void> upsert(ContactOverride ov) async {
    final map = await load();
    map[ov.id] = ov;
    await saveAll(map);
  }

  Future<void> remove(String id) async {
    final map = await load();
    map.remove(id);
    await saveAll(map);
  }

  // Optional helper: ensure directory exists for storing copied images if needed
  Future<Directory> getAppImagesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/contact_images');
    if (!(await imagesDir.exists())) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }
}
