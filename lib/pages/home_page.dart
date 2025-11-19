// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

import 'conntact.dart';
import 'record_page.dart';
import '../services/permission_service.dart';
import '../services/contact_overrides.dart';
import '../services/call_log.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 1;

  final List<Widget> _pages = const [
    ContactPage(), // Contacts tab
    _CenterHome(), // Dialpad
    RecordPage(),  // Recordings tab
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialPermissionPopup();
    });
  }

  // ---------------------------------------------------------
  // FIRST TIME POPUP (Truecaller style)
  // ---------------------------------------------------------
  Future<void> _showInitialPermissionPopup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
          "To use AdvayX properly we need:\n\n"
              "• Contacts – show contact names\n"
              "• Phone – calling & call detection\n"
              "• Microphone – call recording\n"
              "• Storage – save call recordings\n\n"
              "Tap Continue to allow permissions.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Not Now"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final granted = await PermissionService.requestAllPermissions();

              if (!granted && mounted) {
                _showSettingsDialog();
              }
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // USER DENIED → Show "Open Settings"
  // ---------------------------------------------------------
  Future<void> _showSettingsDialog() async {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Permission Needed"),
        content: const Text(
          "Some permissions were denied.\n"
              "You must enable them from settings.",
        ),
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

  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AdvayX",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),

      body: _pages[_index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: "Recents"),
          BottomNavigationBarItem(
              icon: Icon(Icons.dialpad), label: "Dialpad"),
          BottomNavigationBarItem(
              icon: Icon(Icons.audio_file), label: "Recordings"),
        ],
      ),
    );
  }
}

// ===================================================================
// DIALPAD PAGE
// ===================================================================

class _CenterHome extends StatefulWidget {
  const _CenterHome({super.key});

  @override
  State<_CenterHome> createState() => _CenterHomeState();
}

class _CenterHomeState extends State<_CenterHome> {
  final TextEditingController _numberCtrl = TextEditingController();
  final ContactOverridesStore _store = ContactOverridesStore();
  stt.SpeechToText? _speech;

  bool _isListening = false;
  String _transcript = '';
  String _recentNumber = '';
  String? _recentName;

  final List<Map<String, dynamic>> _dialPadItems = [
    {'text': '1', 'sub': ''},
    {'text': '2', 'sub': 'ABC'},
    {'text': '3', 'sub': 'DEF'},
    {'text': '4', 'sub': 'GHI'},
    {'text': '5', 'sub': 'JKL'},
    {'text': '6', 'sub': 'MNO'},
    {'text': '7', 'sub': 'PQRS'},
    {'text': '8', 'sub': 'TUV'},
    {'text': '9', 'sub': 'WXYZ'},
    {'text': '*', 'sub': ''},
    {'text': '0', 'sub': '+'},
    {'text': '#', 'sub': ''},
    {'text': '', 'sub': '', 'isBackspace': true},
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentNumber = prefs.getString("recent_number") ?? "";
      _recentName = prefs.getString("recent_name");
    });
  }

  Future<void> _saveRecent(String num, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("recent_number", num);

    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString("recent_name", name.trim());
    }
  }

  // ---------------------------------------------------------
  void _onDialPress(String d) {
    if (_numberCtrl.text.length >= 10) return;
    setState(() => _numberCtrl.text += d);
  }

  void _onBackspace() {
    if (_numberCtrl.text.isEmpty) return;
    setState(() =>
    _numberCtrl.text = _numberCtrl.text.substring(0, _numberCtrl.text.length - 1)
    );
  }

  // ---------------------------------------------------------
  Future<void> _startCallAndCapture() async {
    String num = _numberCtrl.text;

    if (num.isEmpty) return;
    if (num.length == 10) num = "+91$num";

    await _saveRecent(num);

    bool placed = false;

    if (Platform.isAndroid) {
      final p = await Permission.phone.request();
      if (p.isGranted) {
        placed = await FlutterPhoneDirectCaller.callNumber(num) ?? false;
      }
    }

    if (!placed) {
      final uri = Uri(scheme: "tel", path: num);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    // mic permission
    if (!await Permission.microphone.request().isGranted) return;

    final ok = await _speech!.initialize();
    if (!ok) return;

    setState(() {
      _isListening = true;
      _transcript = "";
    });

    await _speech!.listen(
      listenFor: const Duration(seconds: 20),
      partialResults: true,
      onResult: (r) {
        setState(() => _transcript = r.recognizedWords);
      },
    );

    await Future.delayed(const Duration(seconds: 20));
    if (_speech!.isListening) await _speech!.stop();

    setState(() => _isListening = false);

    final cleaned = _cleanName(_transcript);
    if (cleaned.isNotEmpty) {
      final name = _titleCase(cleaned);
      await _store.upsert(ContactOverride(id: num, name: name));
      await _saveRecent(num, name: name);
    }

    await CallLogStore().add(
      CallLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        number: num,
        name: _recentName,
        when: DateTime.now(),
        duration: const Duration(seconds: 0),
        note: _transcript.isNotEmpty ? _transcript : null,
      ),
    );
  }

  String _cleanName(String s) {
    return s.trim().split(" ").take(3).join(" ");
  }

  String _titleCase(String s) {
    return s
        .split(" ")
        .map((w) =>
    w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(" ");
  }

  // ---------------------------------------------------------

  Widget _buildDialButton(String text, String sub, {bool isBackspace = false}) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: InkWell(
        onTap: isBackspace ? _onBackspace : () => _onDialPress(text),
        child: Container(
          width: 75,
          height: 75,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF1F4F8),
          ),
          child: isBackspace
              ? const Icon(Icons.backspace, size: 32, color: Colors.blue)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 32)),
                    if (sub.isNotEmpty)
                      Text(sub, style: const TextStyle(fontSize: 12)),
                  ],
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _numberCtrl.text,
              style: const TextStyle(fontSize: 40),
            ),
            if (_numberCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.backspace),
                onPressed: _onBackspace,
              ),
          ],
        ),

        if (_recentName != null)
          Text(_recentName!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),

        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            padding: const EdgeInsets.only(top: 24, left: 12, right: 12, bottom: 40),
            children:
            _dialPadItems.map((e) => _buildDialButton(e['text'], e['sub'])).toList(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed:
              _numberCtrl.text.isEmpty ? null : _startCallAndCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "CALL",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
