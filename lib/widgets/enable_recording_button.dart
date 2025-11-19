// lib/widgets/enable_recording_button.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_recorder_controller.dart';

class EnableRecordingButton extends StatefulWidget {
  const EnableRecordingButton({super.key});

  @override
  State<EnableRecordingButton> createState() =>
      _EnableRecordingButtonState();
}

class _EnableRecordingButtonState extends State<EnableRecordingButton> {
  bool enabled = false;

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // User selected 'Don't ask again' or similar
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Permission Required'),
            content: const Text(
              'Storage permission is required to save call recordings.\n\nPlease enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: Icon(enabled ? Icons.check : Icons.mic),
          label: Text(
            enabled ? "Recording Enabled" : "Enable Call Recording",
          ),
          onPressed: () async {
            // First request call recording permissions
            final callPermsOk = await CallRecorderController.requestPermissions();
            if (!callPermsOk) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Call recording permissions not granted"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }

            // Then request storage permission
            final storagePermsOk = await _requestStoragePermission();
            if (!storagePermsOk) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Storage permission is required to save recordings"),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }

            await CallRecorderController.start();
            setState(() => enabled = true);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Call Recording Activated"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
        if (!enabled)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              "Requires call and storage permissions",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
