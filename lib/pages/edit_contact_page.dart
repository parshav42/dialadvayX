import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/contact_overrides.dart';

class EditContactPage extends StatefulWidget {
  final String contactId;
  final String initialName;
  final String initialPhone;
  final String? initialPhotoPath;

  const EditContactPage({
    super.key,
    required this.contactId,
    required this.initialName,
    required this.initialPhone,
    this.initialPhotoPath,
  });

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  final _nameCtrl = TextEditingController();
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _photoPath = widget.initialPhotoPath;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => _photoPath = picked.path);
    }
  }

  Future<void> _save() async {
    await ContactOverridesStore().upsert(
      ContactOverride(
        id: widget.contactId,
        name: _nameCtrl.text.trim(),
        photoPath: _photoPath,
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Contact"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // PHOTO PICKER
            GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.blue.shade100,
                child: ClipOval(
                  child: _photoPath != null
                      ? Image.file(
                    File(_photoPath!),
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  )
                      : const Icon(
                    Icons.person,
                    size: 55,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // NAME FIELD
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PHONE DISPLAY
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: widget.initialPhone,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
