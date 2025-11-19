// lib/services/permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// For opening app settings
import 'package:permission_handler/permission_handler.dart' as permission_handler;

class PermissionService {
  // ----------------------------------------------------
  // BASIC CHECKERS
  // ----------------------------------------------------
  static Future<bool> hasMicrophonePermission() async =>
      await Permission.microphone.isGranted;

  static Future<bool> hasStoragePermission() async =>
      await Permission.storage.isGranted;

  static Future<bool> hasPhonePermission() async =>
      await Permission.phone.isGranted;

  static Future<bool> hasContactsPermission() async =>
      await Permission.contacts.isGranted;

  static Future<bool> hasAllPermissions() async {
    return await Permission.microphone.isGranted &&
        await Permission.storage.isGranted &&
        await Permission.phone.isGranted &&
        await Permission.contacts.isGranted;
  }

  // ----------------------------------------------------
  // REQUEST SINGLE
  // ----------------------------------------------------
  static Future<bool> requestMicrophonePermission() async =>
      await Permission.microphone.request().isGranted;

  static Future<bool> requestStoragePermission() async =>
      await Permission.storage.request().isGranted;

  static Future<bool> requestPhonePermission() async =>
      await Permission.phone.request().isGranted;

  static Future<bool> requestContactsPermission() async =>
      await Permission.contacts.request().isGranted;

  // ----------------------------------------------------
  // REQUEST MULTIPLE (USED BY PAGES)
  // ----------------------------------------------------
  static Future<bool> requestAllPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.storage,
      Permission.phone,
      Permission.contacts,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // ----------------------------------------------------
  // REQUEST PER PAGE
  // ----------------------------------------------------
  static Future<bool> requestAllForPage(
      BuildContext context, {
        required List<Permission> permissions,
        required String message,
      }) async {
    bool granted = true;

    for (final p in permissions) {
      final result = await p.request();

      if (!result.isGranted) {
        granted = false;
      }
    }

    if (!granted && context.mounted) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Permission Required"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                permission_handler.openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    }

    return granted;
  }
}
