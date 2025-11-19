// lib/pages/conntact.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

import '../services/permission_service.dart';
import '../services/contact_overrides.dart';
import '../services/speak_history.dart';

import 'edit_contact_page.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<Contact> _contacts = [];
  bool _loading = true;
  String _query = "";

  String _error = "";

  final ContactOverridesStore _store = ContactOverridesStore();
  Map<String, ContactOverride> _overrides = {};

  final SpeakHistoryStore _history = SpeakHistoryStore();
  final Set<String> _expanded = {};

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasPermissions = await _checkPermissions();
      if (hasPermissions) {
        await _loadOverrides();
        await _fetchContacts();
      } else {
        setState(() {
          _error = "Permissions not granted. Please enable them in app settings.";
          _loading = false;
        });
      }
    });
  }

  // -----------------------------------------------------
  // PERMISSION CHECK
  // -----------------------------------------------------
  Future<bool> _checkPermissions() async {
    // Check if we already have the necessary permissions
    final contactsGranted = await Permission.contacts.isGranted;
    final phoneGranted = await Permission.phone.isGranted;
    
    if (contactsGranted && phoneGranted) {
      return true;
    }

    // If not, request them
    final statuses = await [
      Permission.contacts,
      Permission.phone,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    
    if (!allGranted && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Permissions Required"),
          content: const Text(
              "This app needs Contacts and Phone permissions to function properly.\n\n"
              "Please enable them in app settings."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("Open Settings"),
            ),
          ],
        ),
      ) ?? false;

      if (shouldOpenSettings) {
        await permission_handler.openAppSettings();
      }
      return false;
    }
    
    return allGranted;
  }

  // -----------------------------------------------------
  // LOAD OVERRIDES
  // -----------------------------------------------------
  Future<void> _loadOverrides() async {
    _overrides = await _store.load();
    if (mounted) setState(() {});
  }

  // -----------------------------------------------------
  // FETCH CONTACTS (FAST → then thumbnails)
  // -----------------------------------------------------
  Future<void> _fetchContacts() async {
    setState(() => _loading = true);

    try {
      final basic = await ContactsService.getContacts(withThumbnails: false);

      if (!mounted) return;

      setState(() {
        _contacts = basic.toList();
        _loading = false;
      });

      // Load thumbnails separately
      _loadThumbnails();
    } catch (e) {
      setState(() {
        _error = "Failed to load contacts: $e";
        _loading = false;
      });
    }
  }

  Future<void> _loadThumbnails() async {
    try {
      final full = await ContactsService.getContacts(withThumbnails: true);

      if (mounted) {
        setState(() => _contacts = full.toList());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------
  // UTIL: CLEAN PHONE
  // -----------------------------------------------------
  String _cleanPhone(String? p) {
    if (p == null) return "";
    return p.replaceAll(RegExp(r'[^0-9+]'), "");
  }

  // -----------------------------------------------------
  // CALL CONTACT
  // -----------------------------------------------------
  Future<void> _call(String raw) async {
    String number = _cleanPhone(raw);

    if (number.length == 10) number = "+91$number";

    bool placed = false;

    try {
      placed = await FlutterPhoneDirectCaller.callNumber(number) ?? false;
    } catch (_) {}

    // fallback
    if (!placed) {
      final uri = Uri(scheme: "tel", path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _fmt(DateTime dt) {
    return "${dt.year}-${dt.month}-${dt.day}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // -----------------------------------------------------
  // UI
  // -----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text(_error));

    final filtered = _contacts.where((c) {
      final q = _query.toLowerCase();
      if (q.isEmpty) return true;

      final name = (c.displayName ?? "").toLowerCase();
      final phone = c.phones?.isNotEmpty == true
          ? c.phones!.first.value!.toLowerCase()
          : "";

      return name.contains(q) || phone.contains(q);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search contacts",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          );
        }

        final c = filtered[index - 1];
        final phoneNumber = c.phones?.isNotEmpty == true ? c.phones!.first.value : null;
        final id = _cleanPhone(phoneNumber);

        final override = id != null ? _overrides[id] : null;

        final String displayName = (override?.name?.isNotEmpty ?? false)
            ? override!.name!
            : c.displayName ?? "Unknown";

        final phone = phoneNumber ?? "";

        final expanded = _expanded.contains(id);

        return Column(
          children: [
            ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

              leading: GestureDetector(
                onTap: () async {
                  final saved = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditContactPage(
                        contactId: id,
                        initialName: displayName,
                        initialPhone: phone,
                        initialPhotoPath: override?.photoPath,
                      ),
                    ),
                  );

                  if (saved == true) {
                    await _loadOverrides();
                    setState(() {});
                  }
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade100,
                  child: ClipOval(
                    child: override?.photoPath != null
                        ? Image.file(
                      File(override!.photoPath!),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                        : (c.avatar != null && c.avatar!.isNotEmpty
                        ? Image.memory(
                      c.avatar!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                        : Icon(Icons.person,
                        size: 30, color: Colors.blue.shade700)),
                  ),
                ),
              ),

              title: GestureDetector(
                onTap: () {
                  setState(() {
                    expanded ? _expanded.remove(id) : _expanded.add(id);
                  });
                },
                child: Text(
                  displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),

              subtitle: GestureDetector(
                onTap: () => _call(phone),
                child: Text(
                  phone,
                  style: const TextStyle(color: Colors.blue),
                ),
              ),

              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.blue),
                onPressed: () => _call(phone),
              ),
            ),

            if (expanded)
              _buildHistory(id),

            const Divider(height: 1),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------
  // LAST 3 SPEAK HISTORY LOGS
  // -----------------------------------------------------
  Widget _buildHistory(String id) {
    return FutureBuilder<List<SpeakEntry>>(
      future: _history.loadEntries(id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(left: 70, top: 8, bottom: 8),
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final items = snap.data!;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 70, bottom: 8),
            child: Text("No history yet",
                style: TextStyle(color: Colors.grey)),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 70, bottom: 8, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final h in items.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    "${_fmt(h.when)} — ${h.note ?? ""}",
                    style: const TextStyle(fontSize: 12),
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}
