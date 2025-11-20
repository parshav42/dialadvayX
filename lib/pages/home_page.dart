// lib/pages/home_page.dart
// FINAL STABLE VERSION – USES ONLY YOUR CUSTOM CALL LOG MODEL (NO PLUGIN CONFLICT)

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

import '../services/call_log.dart';          // ✔ your CallLogEntry + CallLogStore
import '../services/call_recorder_service.dart'; // For call recording functionality
import '../services/permission_service.dart';
import 'conntact.dart';
import 'record_page.dart';
import 'edit_contact_page.dart';

// ===============================================================
// HOME PAGE
// ===============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 1;

  final List<Widget> _pages = const [
    ContactPage(),
    DialPadPage(),
    RecordPage(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request all required permissions directly
    await PermissionService.requestAllPermissions();
  }

  void _showSettingsPopup() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("Please enable required permissions in settings."),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(c),
          ),
          TextButton(
            child: const Text("Open Settings"),
            onPressed: () {
              Navigator.pop(c);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AdvayX",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),

      body: _pages[_index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Contacts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: "Dialpad",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: "Recordings",
          ),
        ],
      ),
    );
  }

  Widget _blockedUI() {
    // Return the main content directly
    return _pages[_index];
  }
}

// ===============================================================
// DIAL PAD PAGE
// ===============================================================

class DialPadPage extends StatefulWidget {
  const DialPadPage({super.key});

  @override
  State<DialPadPage> createState() => _DialPadPageState();
}

class _DialPadPageState extends State<DialPadPage> {
  final TextEditingController _numberCtrl = TextEditingController();
  final CallRecorderService _recorder = CallRecorderService();
  final CallLogStore _store = CallLogStore();
  final ContactsService _contactsService = ContactsService();
  final AudioPlayer _player = AudioPlayer();
  List<CallLogEntry> _recentCalls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player.setVolume(1.0);
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await _store.load(includeDeleted: false);

    setState(() {
      _recentCalls = list.take(10).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    try {
      await _player.play(AssetSource("sounds/tap.mp3"));
    } catch (_) {}
  }

  String? _currentCallId;

  Future<void> _callNow() async {
    String num = _numberCtrl.text.trim();
    if (num.isEmpty) return;

    if (num.length == 10) num = "+91$num";

    // Start call recording
    _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
    final isRecording = await _recorder.startRecording(_currentCallId!, num);
    
    if (!isRecording) {
      // Show error if recording couldn't start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start call recording')),
        );
      }
    }

    // Make the call
    await FlutterPhoneDirectCaller.callNumber(num).then((_) async {
      // Call ended, stop recording
      if (_recorder.isRecording) {
        final recordingInfo = await _recorder.stopRecording();
        if (recordingInfo != null) {
          final parts = recordingInfo.split(':');
          if (parts.length == 2) {
            final callId = parts[0];
            final filePath = parts[1];
            
            // Save call log with recording info
            final entry = CallLogEntry(
              id: callId,
              number: num,
              name: null, // You can get the contact name if available
              when: DateTime.now(),
              duration: const Duration(seconds: 0), // Calculate actual duration if needed
              filePath: filePath,
              isSaved: false,
            );
            
            await _store.add(entry);
            await _loadRecent(); // Refresh the recent calls list
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height for the dial pad
        final availableHeight = constraints.maxHeight;
        final recentSectionHeight = 82.0;
        final numberDisplayHeight = 80.0;
        final callButtonHeight = 102.0; // 70 + 16*2 (height + vertical padding)
        final dialPadHeight = availableHeight - recentSectionHeight - numberDisplayHeight - callButtonHeight - 2; // 2 for divider

        return Column(
          children: [
            SizedBox(
              height: recentSectionHeight,
              child: _buildRecentSection(),
            ),
            const Divider(height: 1, thickness: 1),
            SizedBox(
              height: numberDisplayHeight,
              child: _buildNumberDisplay(),
            ),
            SizedBox(
              height: dialPadHeight,
              child: _buildDialPad(),
            ),
            _buildCallBtn(),
          ],
        );
      },
    );
  }

  Widget _buildRecentSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_recentCalls.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("No recent calls", style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentCalls.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final c = _recentCalls[i];

          return GestureDetector(
            onTap: () => _onRecentTap(c.number),
            onLongPress: () => _showCallOptions(c),
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name ?? "Unknown",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.number ?? "",
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(c.when),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _numberCtrl.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_numberCtrl.text.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Colors.blue, size: 28),
              onPressed: _saveToContacts,
            ),
            IconButton(
              icon: const Icon(Icons.backspace, color: Colors.blue, size: 28),
              onPressed: _backspace,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveToContacts() async {
    final number = _numberCtrl.text.trim();
    if (number.isEmpty) return;

    // Navigate to the edit contact page with the number pre-filled
    if (!mounted) return;
    
    // Generate a unique ID for the new contact
    final newContactId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Navigate to the edit contact page
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditContactPage(
          contactId: newContactId,
          initialName: '',
          initialPhone: number,
        ),
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact saved successfully')),
      );
    }
  }

  Widget _buildDialPad() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.15,
      padding: const EdgeInsets.all(10),
      children: buttons.map((b) => _dialButton(b['t']!, b['s']!)).toList(),
    );
  }

  Widget _buildCallBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19.0, vertical: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _callNow,
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              gradient: const LinearGradient(
                colors: const [Color(0xFF0DDCD5), Color(0xFF0CA5D3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.call,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "CALL",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // BUTTON ACTIONS
  // ===============================================================

  void _backspace() {
    _playSound();
    if (_numberCtrl.text.isNotEmpty) {
      setState(() {
        _numberCtrl.text =
            _numberCtrl.text.substring(0, _numberCtrl.text.length - 1);
      });
    }
  }

  void _press(String v) {
    _playSound();
    if (_numberCtrl.text.length < 10) {
      setState(() => _numberCtrl.text += v);
    }
  }

  Widget _dialButton(String t, String s) {
    return InkWell(
      onTap: () => _press(t),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.grey.shade200),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t, style: const TextStyle(fontSize: 32)),
              if (s.isNotEmpty)
                Text(s, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // RECENT CALL OPTIONS
  // ===============================================================

  void _onRecentTap(String? number) {
    if (number == null || number.isEmpty) return;
    _numberCtrl.text = number;
  }

  void _showCallOptions(CallLogEntry call) async {
    final res = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text("Call"),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete", style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    );

    if (res == 1) {
      _numberCtrl.text = call.number ?? "";
      _callNow();
    } else if (res == 2) {
      _deleteCall(call);
    }
  }

  void _deleteCall(CallLogEntry call) async {
    await _store.deletePermanently(call.id);
    await _loadRecent();
  }

  // ===============================================================
  // TIME AGO
  // ===============================================================

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}

// ===============================================================
// DIAL PAD BUTTONS
// ===============================================================

final List<Map<String, String>> buttons = [
  {"t": "1", "s": ""},
  {"t": "2", "s": "ABC"},
  {"t": "3", "s": "DEF"},
  {"t": "4", "s": "GHI"},
  {"t": "5", "s": "JKL"},
  {"t": "6", "s": "MNO"},
  {"t": "7", "s": "PQRS"},
  {"t": "8", "s": "TUV"},
  {"t": "9", "s": "WXYZ"},
  {"t": "*", "s": ""},
  {"t": "0", "s": "+"},
  {"t": "#", "s": ""},
];
