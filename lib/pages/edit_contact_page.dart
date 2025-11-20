import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name')),
        );
        return;
      }

      // Save the contact override
      await ContactOverridesStore().upsert(
        ContactOverride(
          id: widget.contactId,
          name: name,
          photoPath: _photoPath,
        ),
      );

      // Also save to device contacts if permission is granted
      if (await Permission.contacts.request().isGranted) {
        try {
          // Create a new contact
          final contact = Contact(
            givenName: name,
            phones: [Item(value: widget.initialPhone)],
            avatar: _photoPath != null ? File(_photoPath!).readAsBytesSync() : null,
          );
          
          // Add or update the contact in the device's contact list
          await ContactsService.addContact(contact);
        } catch (e) {
          debugPrint('Error saving to device contacts: $e');
          // Continue even if device contact save fails
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving contact: $e');
      if (!mounted) return;
      
      // Show error message
      String errorMessage = 'Error saving contact';
      if (e is PlatformException) {
        errorMessage = e.message ?? errorMessage;
      } else if (e is String) {
        errorMessage = e;
      } else if (e is FormatException) {
        errorMessage = 'Invalid contact format. Please check the details and try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
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
