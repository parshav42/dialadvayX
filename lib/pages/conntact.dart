// lib/pages/conntact.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Map<String, List<Contact>> _grouped = {};

  bool _loading = false;
  bool _blocked = true; // 🔥 default → blocked until permission granted
  String _query = "";

  final ContactOverridesStore _store = ContactOverridesStore();
  Map<String, ContactOverride> _overrides = {};

  final SpeakHistoryStore _history = SpeakHistoryStore();
  final Set<String> _expanded = {};

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _askPermissions(); // 🔥 ask EVERY TIME user opens tab
  }

  // -------------------------------------------------------------
  // TRUECALLER-STYLE PERMISSION HANDLER
  // -------------------------------------------------------------
  Future<void> _askPermissions() async {
    setState(() {
      _loading = true;
      _blocked = true;
    });

    final status = await [
      Permission.contacts,
      Permission.phone,
    ].request();

    final granted = status.values.every((e) => e.isGranted);

    if (!granted) {
      setState(() {
        _blocked = true;
        _loading = false;
        _contacts = [];
        _grouped = {};
      });

      _showPermissionPopup();
      return;
    }

    // Permissions granted
    setState(() => _blocked = false);

    await _loadOverrides();
    await _fetchContacts();
  }

  void _showPermissionPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permission Needed"),
        content: const Text(
            "Contacts & Phone permissions are needed to show your contacts."),
        actions: [
          TextButton(
            child: const Text("Not Now"),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _blocked = true;
                _contacts = [];
                _grouped = {};
              });
            },
          ),
          TextButton(
            child: const Text("Allow"),
            onPressed: () {
              Navigator.pop(context);
              _askPermissions(); // 🔥 ask again
            },
          )
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // LOAD OVERRIDES
  // -------------------------------------------------------------
  Future<void> _loadOverrides() async {
    _overrides = await _store.load();
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------
  // FETCH CONTACTS - Optimized for performance
  // -------------------------------------------------------------
  Future<void> _fetchContacts() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Load contacts without thumbnails first for faster loading
      final Iterable<Contact> contacts = await ContactsService.getContacts(
        withThumbnails: false,  // Don't load thumbnails initially
      );
      
      // Convert to list and filter out any null displayNames
      final allContacts = contacts.where((c) => c.displayName?.isNotEmpty ?? false).toList();
      
      if (mounted) {
        setState(() {
          _contacts = allContacts;
          _loading = false;
        });
        _sortGroupContacts();
      }
      
      stopwatch.stop();
      debugPrint('Contacts loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, stackTrace) {
      debugPrint('Error loading contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // -------------------------------------------------------------
  // GROUP CONTACTS A-Z
  // -------------------------------------------------------------
  void _sortGroupContacts() {
    List<Contact> sorted = [..._contacts];

    sorted.sort((a, b) =>
        (a.displayName ?? "").toLowerCase().compareTo(
          (b.displayName ?? "").toLowerCase(),
        ));

    final Map<String, List<Contact>> groups = {};

    for (var c in sorted) {
      final name = c.displayName ?? "";
      if (name.isEmpty) continue;

      final letter = name[0].toUpperCase();
      groups.putIfAbsent(letter, () => []).add(c);
    }

    final sortedKeys = groups.keys.toList()..sort();

    _grouped = {for (var k in sortedKeys) k: groups[k]!};
  }

  // -------------------------------------------------------------
  // CLEAN PHONE
  // -------------------------------------------------------------
  String _clean(String? p) =>
      p?.replaceAll(RegExp(r'[^0-9+]'), "") ?? "";

  // -------------------------------------------------------------
  // CALL
  // -------------------------------------------------------------
  Future<void> _call(String number) async {
    String n = _clean(number);
    if (n.length == 10) n = "+91$n";

    bool ok = await FlutterPhoneDirectCaller.callNumber(n) ?? false;

    if (!ok) {
      final uri = Uri(scheme: "tel", path: n);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // -------------------------------------------------------------
  // MAIN UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_blocked) {
      return _blockedUI();
    }

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Search…",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) {
              _query = v;
              _filterSearch();
            },
          ),
        ),

        Expanded(
          child: ListView(
            children: _grouped.entries.map((entry) {
              final letter = entry.key;
              final contacts = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    color: Colors.grey.shade200,
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),

                  ...contacts.map((c) => _buildContact(c)).toList(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // BLOCKED UI (PERMISSION DENIED)
  // -------------------------------------------------------------
  Widget _blockedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            "Permission Needed",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Enable permissions to load contacts."),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _askPermissions,
            child: const Text("Allow Permissions"),
          ),
        ],
      ),
    );
  }


  // -------------------------------------------------------------
  // SEARCH
  // -------------------------------------------------------------
  void _filterSearch() {
    setState(() {
      if (_query.isEmpty) {
        _fetchContacts(); // Reload all contacts when search is cleared
        return;
      }

      final q = _query.toLowerCase();
      final filtered = _contacts.where((c) {
        final name = (c.displayName ?? "").toLowerCase();
        final ph = c.phones?.isNotEmpty == true
            ? c.phones!.first.value?.toLowerCase() ?? ""
            : "";
        return name.contains(q) || ph.contains(q);
      }).toList();

      _contacts = filtered;
      _sortGroupContacts();
    });
  }

  // Cache for contact avatars to avoid reloading
  final Map<String, Uint8List?> _avatarCache = {};
  
  // -------------------------------------------------------------
  // CONTACT CARD - Optimized with lazy loading
  // -------------------------------------------------------------
  Widget _buildContact(Contact c) {
    final ph = (c.phones != null && c.phones!.isNotEmpty) 
        ? (c.phones!.first.value ?? '') 
        : '';
    final id = _clean(ph);

    final override = _overrides[id];
    final name = override?.name?.isNotEmpty == true
        ? override!.name!
        : c.displayName ?? "Unknown";

    final expanded = _expanded.contains(id);

    return Column(
      children: [
        ListTile(
          leading: _buildContactAvatar(c, id, override),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(ph, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.call, color: Colors.blue),
            onPressed: ph.isNotEmpty ? () => _call(ph) : null,
          ),
          onTap: () => setState(() => 
              expanded ? _expanded.remove(id) : _expanded.add(id)),
          onLongPress: () => _onContactLongPress(id, name, ph, override),
        ),
        if (expanded) _buildHistory(id),
        const Divider(height: 1),
      ],
    );
  }
  
  Widget _buildContactAvatar(Contact c, String id, ContactOverride? override) {
    return GestureDetector(
      onTap: () {
        final name = override?.name?.isNotEmpty == true
            ? override!.name!
            : c.displayName ?? "Unknown";
        final phone = (c.phones != null && c.phones!.isNotEmpty) 
            ? _clean(c.phones!.first.value ?? '') 
            : '';
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditContactPage(
              contactId: id,
              initialName: name,
              initialPhone: phone,
              initialPhotoPath: override?.photoPath,
            ),
          ),
        );
      },
      child: FutureBuilder<Uint8List?>(
        future: _getContactAvatar(c, id),
        builder: (context, snapshot) {
          final avatar = snapshot.data;
          return CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: ClipOval(
              child: override?.photoPath != null
                  ? Image.file(
                      File(override!.photoPath!), 
                      fit: BoxFit.cover, 
                      width: 40, 
                      height: 40,
                      errorBuilder: (_, __, ___) => _defaultAvatarIcon(),
                    )
                  : (avatar != null && avatar.isNotEmpty
                      ? Image.memory(
                          avatar, 
                          fit: BoxFit.cover, 
                          width: 40, 
                          height: 40,
                          errorBuilder: (_, __, ___) => _defaultAvatarIcon(),
                        )
                      : _defaultAvatarIcon()),
            ),
          );
        },
      ),
    );
  }
  
  Widget _defaultAvatarIcon() {
    return Icon(Icons.person, color: Colors.blue.shade700);
  }
  
  Future<Uint8List?> _getContactAvatar(Contact c, String id) async {
    // Return from cache if available
    if (_avatarCache.containsKey(id)) {
      return _avatarCache[id];
    }
    
    // If no avatar data, return null
    if (c.avatar == null || c.avatar!.isEmpty) {
      return null;
    }
    
    try {
      // Load and cache the avatar
      final avatar = c.avatar;
      if (avatar != null && avatar.isNotEmpty) {
        _avatarCache[id] = avatar;
        return avatar;
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
    
    return null;
  }
  
  Future<void> _onContactLongPress(String id, String name, String phone, ContactOverride? override) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditContactPage(
          contactId: id,
          initialName: name,
          initialPhone: phone,
          initialPhotoPath: override?.photoPath,
        ),
      ),
    );
    
    if (saved == true && mounted) {
      await _loadOverrides();
      setState(() {});
    }
  }

  // -------------------------------------------------------------
  // HISTORY VIEW
  // -------------------------------------------------------------
  Widget _buildHistory(String id) {
    return FutureBuilder(
      future: _history.loadEntries(id),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(left: 70),
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final list = snap.data!;
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 70, bottom: 6),
            child: Text("No history",
                style: TextStyle(color: Colors.grey)),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 70, bottom: 6, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: list.take(3).map((e) {
              return Text("${e.when} - ${e.note ?? ''}",
                  style: const TextStyle(fontSize: 12));
            }).toList(),
          ),
        );
      },
    );
  }
}
