import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CallRecorderController {
  static const _channel = MethodChannel("advayx.recorder");

  /// 🚀 Start service
  static Future<void> start() async {
    try {
      await _channel.invokeMethod("startService");
    } catch (e) {
      debugPrint("Start error: $e");
    }
  }

  /// 🛑 Stop service
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod("stopService");
    } catch (e) {
      debugPrint("Stop error: $e");
    }
  }

  /// 🔐 Ask all permissions
  static Future<bool> requestPermissions() async {
    final perms = [
      Permission.phone,
      Permission.microphone,
      Permission.contacts,
      Permission.storage,
    ];

    for (final p in perms) {
      if (!await p.isGranted) {
        final r = await p.request();
        if (!r.isGranted) return false;
      }
    }
    return true;
  }
}
