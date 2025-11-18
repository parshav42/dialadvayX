import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'edit_contact_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/contact_overrides.dart';
import '../services/call_log.dart';
import 'conntact.dart';
import 'record_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 1;

  final List<Widget> _pages = [
    const ContactPage(),
    const _CenterHome(),
    const RecordPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "advayX",
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        elevation: 0,
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors .blue[900],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Recents"),
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: "Dialpad"),
          BottomNavigationBarItem(
              icon: Icon(Icons.audio_file), label: "Recordings"),
        ],
      ),
    );
  }
}

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

  Future<void> _saveRecent(String number, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("recent_number", number);
    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString("recent_name", name.trim());
    }
    _loadRecent();
  }

  void _onDialPress(String value) {
    if (_numberCtrl.text.length >= 10) return;

    setState(() {
      _numberCtrl.text += value;
    });
  }

  void _onBackspace() {
    if (_numberCtrl.text.isEmpty) return;

    setState(() {
      _numberCtrl.text =
          _numberCtrl.text.substring(0, _numberCtrl.text.length - 1);
    });
  }

  Future<void> _startCallAndCapture() async {
    String num = _numberCtrl.text;

    if (num.isEmpty) return;

    if (num.length == 10) {
      num = "+91$num";
    }

    await _saveRecent(num);

    bool placed = false;

    if (Platform.isAndroid) {
      final p = await Permission.phone.request();
      if (p.isGranted) {
        placed =
            await FlutterPhoneDirectCaller.callNumber(num.toString()) ?? false;
      }
    }

    if (!placed) {
      final uri = Uri(scheme: "tel", path: num.toString());
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
        setState(() {
          _transcript = r.recognizedWords;
        });
      },
    );

    await Future.delayed(const Duration(seconds: 20));
    if (_speech!.isListening) await _speech!.stop();

    setState(() => _isListening = false);

    final cleaned = _cleanName(_transcript);

    if (cleaned.isNotEmpty) {
      final name = _titleCase(cleaned);
      await _store.upsert(ContactOverride(id: num, name: name));
      _saveRecent(num, name: name);
    }

    await CallLogStore().add(
      CallLogEntry(
        number: num,
        name: _recentName,
        when: DateTime.now(),
        note: _transcript.isNotEmpty ? _transcript : null,
      ),
    );
  }

  String _cleanName(String s) {
    final parts = s.trim().split(" ");
    return parts.take(3).join(" ");
  }

  String _titleCase(String s) {
    return s
        .split(" ")
        .map((w) =>
    w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(" ");
  }

  Widget _buildDialButton(String text, String sub) {
    return InkWell(
      onTap: () => _onDialPress(text),
      borderRadius: BorderRadius.circular(48),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          shape: BoxShape.circle,
        ),
        width: 72,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w300,
                  ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: Colors.white, // Light grey background
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _numberCtrl.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_numberCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.backspace),
                    onPressed: _onBackspace,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  )
              ],
            ),
          ),
        ),

        ..._recentName != null
            ? [
                Container(
                  width: double.infinity,
                  color: Colors.grey[100], // Light grey background
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _recentName!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ]
            : [],

        const SizedBox(height: 10),

        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            padding: const EdgeInsets.all(8),
            children: _dialPadItems
                .map((e) => _buildDialButton(e['text'], e['sub']))
                .toList(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
              _numberCtrl.text.isEmpty ? null : _startCallAndCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                "CALL",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
