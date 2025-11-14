 import 'package:flutter/material.dart';
 import 'package:url_launcher/url_launcher.dart';
 import 'package:speech_to_text/speech_to_text.dart' as stt;
 import 'package:permission_handler/permission_handler.dart';
 import '../services/contact_overrides.dart';
 import 'conntact.dart';
 import 'record_page.dart';

 class HomePage extends StatefulWidget {
   const HomePage({super.key});

   @override
   State<HomePage> createState() => _HomePageState();
 }

 class _HomePageState extends State<HomePage> {
   int _index = 1;

   final _pages = const [
     ContactPage(),
     _CenterHome(),
     RecordPage(),
   ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdvayX'),
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFFF3E5F5), // faint purple
        selectedItemColor: const Color(0xFF7E57C2), // purple 400
        unselectedItemColor: const Color(0xFFB39DDB), // purple 200
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contact'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
        ],
      ),
    );
  }
}

class _CenterHome extends StatefulWidget {
  const _CenterHome();

  @override
  State<_CenterHome> createState() => _CenterHomeState();
}

class _CenterHomeState extends State<_CenterHome> {
  final TextEditingController _numberCtrl = TextEditingController();
  final ContactOverridesStore _store = ContactOverridesStore();
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCallAndCapture() async {
    final raw = _numberCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number')),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    // 1) Place the call (opens dialer)
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot launch dialer')),
      );
    }

    // 2) Ask mic permission and start listening for 20s
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final available = await _speech!.initialize(
      onStatus: (s) {},
      onError: (e) {},
    );
    if (!available) return;

    setState(() {
      _isListening = true;
      _transcript = '';
    });

    await _speech!.listen(
      listenFor: const Duration(seconds: 20),
      onResult: (r) {
        setState(() {
          _transcript = r.recognizedWords;
        });
      },
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );

    // Wait for the listening duration to elapse
    await Future.delayed(const Duration(seconds: 20));
    if (_speech!.isListening) {
      await _speech!.stop();
    }
    setState(() {
      _isListening = false;
    });

    final cleaned = _cleanName(_transcript);
    if (cleaned.isNotEmpty) {
      await _store.upsert(ContactOverride(id: digits, name: _titleCase(cleaned)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved name for $digits: ${_titleCase(cleaned)}')),
        );
      }
    }
  }

  String _cleanName(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    // Keep first few words only
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(4).toList();
    return words.join(' ');
  }

  String _titleCase(String s) {
    return s
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p.substring(0, 1).toUpperCase() + (p.length > 1 ? p.substring(1).toLowerCase() : ''))
        .join(' ');
  }

  void _onKeyPress(String key) {
    final text = _numberCtrl.text;
    setState(() {
      _numberCtrl.text = text + key;
    });
  }

  void _onBackspace() {
    final text = _numberCtrl.text;
    if (text.isEmpty) return;
    setState(() {
      _numberCtrl.text = text.substring(0, text.length - 1);
    });
  }

  void _onClearAll() {
    if (_numberCtrl.text.isEmpty) return;
    setState(() {
      _numberCtrl.text = '';
    });
  }

  Widget _keyButton(String label) {
    return SizedBox(
      height: 48,
      width: 48,
      child: ElevatedButton(
        onPressed: () => _onKeyPress(label),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(0),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _numberCtrl.text,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _keyButton('1'),
              _keyButton('2'),
              _keyButton('3'),
              _keyButton('4'),
              _keyButton('5'),
              _keyButton('6'),
              _keyButton('7'),
              _keyButton('8'),
              _keyButton('9'),
              _keyButton('*'),
              _keyButton('0'),
              SizedBox(
                height: 48,
                width: 48,
                child: GestureDetector(
                  onLongPress: _onClearAll,
                  child: ElevatedButton(
                    onPressed: _onBackspace,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(0),
                    ),
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _startCallAndCapture,
              icon: const Icon(Icons.call, size: 18),
              label: const Text('Call and capture name', style: TextStyle(fontSize: 14)),
            ),
          ),
          if (_isListening) ...[
            const SizedBox(height: 12),
            const Text('Listening for 20 seconds...'),
            const SizedBox(height: 6),
            Text(
              _transcript,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
