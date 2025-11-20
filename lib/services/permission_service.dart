// lib/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  // --------------------------------------------------------
  // CHECK: Has user already pressed CONTINUE in the popup?
  // --------------------------------------------------------
  static Future<bool> hasUserAcceptedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("accepted_permissions") ?? false;
  }

  // --------------------------------------------------------
  // SAVE user pressed CONTINUE
  // --------------------------------------------------------
  static Future<void> saveUserAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("accepted_permissions", true);
  }

  // --------------------------------------------------------
  // REQUEST ALL PERMISSIONS
  // --------------------------------------------------------
  static Future<bool> requestAllPermissions() async {
    final status = await [
      Permission.contacts,
      Permission.phone,
      Permission.microphone,
      Permission.storage,
    ].request();

    return status.values.every((e) => e.isGranted);
  }

  // --------------------------------------------------------
  static Future<bool> hasAllPermissions() async {
    return await Permission.contacts.isGranted &&
        await Permission.phone.isGranted &&
        await Permission.microphone.isGranted &&
        await Permission.storage.isGranted;
  }
}
