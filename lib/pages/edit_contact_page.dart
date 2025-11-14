import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../services/contact_overrides.dart';

class EditContactPage extends StatefulWidget {
  final String contactId; // key used for overrides (e.g., primary phone)
  final String initialName;
  final String? initialPhotoPath;

  const EditContactPage({
    super.key,
    required this.contactId,
    required this.initialName,
    this.initialPhotoPath,
  });

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  File? _photoFile;
  bool _saving = false;

  final _store = ContactOverridesStore();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    if (widget.initialPhotoPath != null && widget.initialPhotoPath!.isNotEmpty) {
      _photoFile = File(widget.initialPhotoPath!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Request photos permission on iOS 14+ if needed; on Android, image_picker will handle intents.
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photos permission denied.')),
          );
        }
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null) return;

    // Copy to app documents so the file persists
    final imagesDir = await _store.getAppImagesDir();
    final String filename = '${widget.contactId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final File target = File(p.join(imagesDir.path, filename));
    await File(picked.path).copy(target.path);

    setState(() {
      _photoFile = target;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ov = ContactOverride(
        id: widget.contactId,
        name: _nameCtrl.text.trim(),
        photoPath: _photoFile?.path,
      );
      await _store.upsert(ov);
      if (!mounted) return;
      Navigator.of(context).pop(true); // signal changes saved
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Contact'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                        child: _photoFile == null ? const Icon(Icons.person, size: 48) : null,
                      ),
                      IconButton(
                        onPressed: _saving ? null : _pickImage,
                        icon: const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.edit, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
