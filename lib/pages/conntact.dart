import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import '../services/contact_overrides.dart';
import 'edit_contact_page.dart';
import '../services/speak_history.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/call_log.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> with SingleTickerProviderStateMixin {
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final ContactOverridesStore _store = ContactOverridesStore();
  Map<String, ContactOverride> _overrides = {};
  final SpeakHistoryStore _historyStore = SpeakHistoryStore();
  final Set<String> _expanded = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  
  AnimationController? _appBarController;
  Animation<double>? _appBarSizeFactor;
  Animation<double>? _appBarOpacity;

  @override
  void initState() {
    super.initState();
    _init();
    _appBarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _appBarSizeFactor = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _appBarController!,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    ));
    _appBarOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _appBarController!,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));
    // Start hiding after first frame + 1.5 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) _appBarController?.forward();
      });
    });
  }

  @override
  void dispose() {
    _appBarController?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Contact> _sampleContacts() {
    return [
      Contact(
        displayName: 'Alice Johnson',
        givenName: 'Alice',
        familyName: 'Johnson',
        phones: [Item(label: 'mobile', value: '+15551230001')],
      ),
      Contact(
        displayName: 'Bob Smith',
        givenName: 'Bob',
        familyName: 'Smith',
        phones: [Item(label: 'mobile', value: '+15551230002')],
      ),
      Contact(
        displayName: 'Carol Lee',
        givenName: 'Carol',
        familyName: 'Lee',
        phones: [Item(label: 'mobile', value: '+15551230003')],
      ),
      Contact(
        displayName: 'David Kim',
        givenName: 'David',
        familyName: 'Kim',
        phones: [Item(label: 'mobile', value: '+15551230004')],
      ),
      Contact(
        displayName: 'Eva Martinez',
        givenName: 'Eva',
        familyName: 'Martinez',
        phones: [Item(label: 'mobile', value: '+15551230005')],
      ),
    ];
  }

  Future<void> _init() async {
    await Future.wait([
      _fetchContacts(),
      _loadOverrides(),
    ]);
  }

  Future<void> _loadOverrides() async {
    final data = await _store.load();
    if (!mounted) return;
    setState(() {
      _overrides = data;
    });
  }

  Future<void> _fetchContacts() async {
    // 1. Request contact permission
    PermissionStatus status = await Permission.contacts.request();

    // 2. Check if permission is granted
    if (status.isGranted) {
      // 3. If granted, fetch contacts
      try {
        final Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
        final list = contacts.toList();
        setState(() {
          _contacts = list.isEmpty ? _sampleContacts() : list;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to fetch contacts: $e';
          _isLoading = false;
        });
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      // 4. If denied, show an error or guide the user
      setState(() {
        _errorMessage = 'Contact permission is required to use this feature. Please enable it in your phone settings.';
        _isLoading = false;
      });

      // Optionally, open app settings so the user can grant permission
      // openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appBarController == null || _appBarSizeFactor == null || _appBarOpacity == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Contacts', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF4CAF50), // Soft green
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        body: _buildBody(),
      );
    }

    return AnimatedBuilder(
      animation: _appBarController!,
      builder: (context, _) {
        final h = (kToolbarHeight * _appBarSizeFactor!.value).clamp(0.0, kToolbarHeight);
        final PreferredSizeWidget? appBarWidget = (h <= 0.01)
            ? const PreferredSize(preferredSize: Size.fromHeight(0), child: SizedBox.shrink())
            : PreferredSize(
                preferredSize: Size.fromHeight(h),
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _appBarSizeFactor!.value,
                    child: FadeTransition(
                      opacity: _appBarOpacity!,
                      child: AppBar(
                        title: const Text('Contacts'),
                        backgroundColor: const Color(0xFFFFFFFF),
                        titleTextStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );

        return Scaffold(
          appBar: appBarWidget,
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return const Center(
        child: Text(
          'No contacts found.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final filtered = _contacts.where((c) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      final name = (c.displayName ?? '').toLowerCase();
      final phone = (c.phones?.isNotEmpty == true ? (c.phones!.first.value ?? '') : '').toLowerCase();
      final id = _contactIdFor(c).toLowerCase();
      final overrideName = (_overrides[_contactIdFor(c)]?.name ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || id.contains(q) || overrideName.contains(q);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          );
        }

        final contact = filtered[index - 1];
        final contactId = _contactIdFor(contact);
        final override = _overrides[contactId];
        final displayName = (override?.name?.isNotEmpty ?? false) ? override!.name! : contact.displayName ?? 'Unknown';
        
        // Safely get the first phone number or use a default
        final phoneNumber = (contact.phones?.isNotEmpty ?? false) 
            ? contact.phones!.first.value 
            : 'No number';
        final String? photoPath = override?.photoPath;
        
        // Skip this contact if there's no valid phone number
        if (phoneNumber == null || phoneNumber.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: GestureDetector(
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditContactPage(
                        contactId: contactId,
                        initialName: displayName,
                        initialPhone: phoneNumber,
                        initialPhotoPath: photoPath,
                      ),
                    ),
                  );
                  if (saved == true) {
                    await _loadOverrides();
                    if (mounted) setState(() {});
                  }
                },
                child: CircleAvatar(
                  child: (photoPath == null) ? const Icon(Icons.person) : null,
                  backgroundImage: (photoPath != null && File(photoPath).existsSync())
                      ? FileImage(File(photoPath))
                      : null,
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_expanded.contains(contactId)) {
                      _expanded.clear();
                    } else {
                      _expanded
                        ..clear()
                        ..add(contactId);
                    }
                  });
                },
                child: Text(displayName),
              ),
              subtitle: _expanded.contains(contactId)
                  ? null
                  : GestureDetector(
                      onTap: () => _callFromContact(phoneNumber, name: displayName),
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.call),
                onPressed: () => _callFromContact(phoneNumber, name: displayName),
                tooltip: 'Call',
              ),
              onTap: () {},
            ),
            if (_expanded.contains(contactId))
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: FutureBuilder<List<SpeakEntry>>(
                  future: _historyStore.loadEntries(contactId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final items = snapshot.data ?? const <SpeakEntry>[];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('No history yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      );
                    }
                    final limited = items.take(3).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          itemCount: limited.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, i) {
                            final e = limited[i];
                            final subtitle = (e.note != null && e.note!.trim().isNotEmpty)
                                ? ' • ' + e.note!.trim()
                                : '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(_format(e.when) + subtitle, style: const TextStyle(fontSize: 12)),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () async {
                              final suggestions = await _generateNameSuggestions(
                                contactId: contactId,
                                currentName: displayName,
                                phone: phoneNumber,
                              );
                              if (!mounted) return;
                              if (suggestions.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No suggestions available yet.')),
                                );
                                return;
                              }
                              final chosen = await showDialog<String>(
                                context: context,
                                builder: (context) {
                                  return SimpleDialog(
                                    title: const Text('Suggest a name'),
                                    children: [
                                      for (final s in suggestions)
                                        SimpleDialogOption(
                                          onPressed: () => Navigator.of(context).pop(s),
                                          child: Text(s),
                                        ),
                                    ],
                                  );
                                },
                              );
                              if (chosen != null && chosen.trim().isNotEmpty) {
                                await _store.upsert(ContactOverride(
                                  id: contactId,
                                  name: chosen.trim(),
                                  photoPath: photoPath,
                                ));
                                await _loadOverrides();
                                if (mounted) setState(() {});
                              }
                            },
                            child: const Text('Suggest name'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _callFromContact(String raw, {String? name}) async {
    if (raw.trim().isEmpty) return;
    String digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!digits.startsWith('+') && RegExp(r'^\d{10}$').hasMatch(digits)) {
      digits = '+91$digits';
    }

    bool placed = false;
    if (Platform.isAndroid) {
      final perm = await Permission.phone.request();
      if (perm.isGranted) {
        try {
          placed = await FlutterPhoneDirectCaller.callNumber(digits) ?? false;
        } catch (_) {
          placed = false;
        }
      }
    }

    if (!placed) {
      final uri = Uri(scheme: 'tel', path: digits);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot launch dialer')),
          );
        }
      }
    }

    try {
      await CallLogStore().add(
        CallLogEntry(
          number: digits,
          when: DateTime.now(),
          name: name,
          note: null,
        ),
      );
    } catch (_) {}
  }

  String _format(DateTime dt) {
    final d = dt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<List<String>> _generateNameSuggestions({
    required String contactId,
    required String currentName,
    required String phone,
  }) async {
    final entries = await _historyStore.loadEntries(contactId);
    final notes = entries
        .map((e) => e.note?.toLowerCase().trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    final Set<String> out = {};

    // 1) Heuristic roles from keywords
    final roleMap = <String, List<String>>{
      'Mom': ['mom', 'mother', 'amma', 'maa'],
      'Dad': ['dad', 'father', 'appa', 'papa'],
      'Office': ['office', 'work', 'colleague', 'boss'],
      'HR': ['hr', 'recruiter', 'hiring'],
      'Doctor': ['doctor', 'dr', 'clinic', 'hospital'],
      'Plumber': ['plumber'],
      'Electrician': ['electrician'],
      'Bank': ['bank'],
      'Delivery': ['delivery', 'courier'],
      'Support': ['support', 'helpdesk', 'service'],
      'Manager': ['manager', 'lead'],
      'Teacher': ['teacher', 'professor', 'sir', 'madam', 'mentor'],
      'Landlord': ['landlord', 'owner'],
      'Driver': ['driver', 'cab', 'taxi'],
    };
    for (final note in notes) {
      for (final entry in roleMap.entries) {
        if (entry.value.any((k) => RegExp('(^|\\b)'+RegExp.escape(k)+'(\\b|\$)').hasMatch(note))) {
          out.add(entry.key);
        }
      }
    }

    // 2) Cleaned variants of current name
    final cleaned = _cleanName(currentName);
    if (cleaned.isNotEmpty) out.add(_titleCase(cleaned));
    final first = cleaned.split(' ').where((s) => s.isNotEmpty).take(1).join(' ');
    if (first.isNotEmpty && first.toLowerCase() != cleaned.toLowerCase()) out.add(_titleCase(first));

    // 3) Very simple phone-based hint (country-like)
    if (phone.startsWith('+91')) out.add('India Contact');
    if (phone.startsWith('+1')) out.add('US Contact');

    // Remove the current name and near-duplicates
    out.removeWhere((s) => s.trim().toLowerCase() == cleaned.toLowerCase());

    // Return up to 5 unique suggestions
    return out.take(5).toList();
  }

  String _cleanName(String s) {
    // Remove emojis/specials and collapse spaces
    final noEmoji = s.replaceAll(RegExp(r'[\p{So}\p{Sk}]', unicode: true), '');
    final lettersDigits = noEmoji.replaceAll(RegExp(r'[^A-Za-z0-9 +._-]'), ' ');
    return lettersDigits.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _titleCase(String s) {
    return s
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p.substring(0, 1).toUpperCase() + (p.length > 1 ? p.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  String _contactIdFor(Contact c) {
    // Prefer first phone number as stable key
    final raw = c.phones?.isNotEmpty == true ? c.phones!.first.value ?? '' : '';
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isNotEmpty) return digits;
    // Fallback to display name if no phone
    return (c.displayName ?? '').trim();
  }
}