import 'package:flutter/material.dart';
import 'dart:io' show Platform;
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

  // Avoid forcing const here — safer if underlying pages aren't const
  final List<Widget> _pages = [
    ContactPage(),
    _CenterHome(),
    RecordPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdvayX'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF7E57C2), // purple 400
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: 'Dialpad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.audio_file),
            label: 'Recordings',
          ),
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
  String _recentNumber = '';
  String? _recentName;
  
  // Dialpad buttons data - simplified to match the screenshot
  final List<Map<String, dynamic>> _dialPadItems = [
    {'text': '1', 'subText': ''},
    {'text': '2', 'subText': 'ABC'},
    {'text': '3', 'subText': 'DEF'},
    {'text': '4', 'subText': 'GHI'},
    {'text': '5', 'subText': 'JKL'},
    {'text': '6', 'subText': 'MNO'},
    {'text': '7', 'subText': 'PQRS'},
    {'text': '8', 'subText': 'TUV'},
    {'text': '9', 'subText': 'WXYZ'},
    {'text': '*', 'subText': ''},
    {'text': '0', 'subText': '+'},
    {'text': '#', 'subText': ''},
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadRecent();
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

    String digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    // Default to India if user entered a 10-digit local number without country code
    if (!digits.startsWith('+') && RegExp(r'^\d{10}$').hasMatch(digits)) {
      digits = '+91$digits';
    }

    // Save recent
    await _saveRecent(digits);

    // 1) Place the call
    bool placed = false;
    if (Platform.isAndroid) {
      // Request phone permission for direct calling
      final phonePerm = await Permission.phone.request();
      if (phonePerm.isGranted) {
        try {
          placed = await FlutterPhoneDirectCaller.callNumber(digits) ?? false;
        } catch (_) {
          placed = false;
        }
      }
    }

    if (!placed) {
      // Fallback to opening dialer (iOS and if direct call not available)
      final uri = Uri(scheme: 'tel', path: digits);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot launch dialer')),
        );
      }
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
    String? savedName;
    if (cleaned.isNotEmpty) {
      savedName = _titleCase(cleaned);
      await _store.upsert(ContactOverride(id: digits, name: savedName));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved name for $digits: $savedName')),
        );
      }
    }

    // Log call locally
    try {
      await CallLogStore().add(
        CallLogEntry(
          number: digits,
          when: DateTime.now(),
          name: savedName ?? _recentName,
          note: _transcript.isNotEmpty ? _transcript : null,
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentNumber = prefs.getString('recent_number') ?? '';
      _recentName = prefs.getString('recent_name');
    });
  }

  Future<void> _saveRecent(String number, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_number', number);
    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString('recent_name', name.trim());
    }
    await _loadRecent();
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

  void _onDialpadPressed(String text) {
    // Skip if empty or not a digit
    if (text.isEmpty) return;
    
    // Handle * and # if needed
    if (text == '*' || text == '#') {
      // You can add specific handling for * and # here if needed
      return;
    }
    
    // Don't allow more than 10 digits
    if (_numberCtrl.text.length >= 10) return;
    
    setState(() {
      // Add the pressed digit to the current number
      _numberCtrl.text += text;
      
      // Auto-save after 10 digits
      if (_numberCtrl.text.length == 10) {
        _saveRecent(_numberCtrl.text);
        // Show a subtle feedback when number is complete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('10-digit number entered'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            backgroundColor: Colors.green[700],
          ),
        );
      }
      
      // Load recent contacts when first digit is entered
      if (_numberCtrl.text.length == 1) {
        _loadRecent();
      }
    });
    
    // Move cursor to end
    _numberCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _numberCtrl.text.length)
    );
  }

  void _onBackspace() {
    final text = _numberCtrl.text;
    if (text.isEmpty) return;
    
    setState(() {
      // Remove last character
      _numberCtrl.text = text.substring(0, text.length - 1);
      
      // Update cursor position
      _numberCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _numberCtrl.text.length)
      );
      
      // If we deleted the last character, clear recent contact info
      if (_numberCtrl.text.isEmpty) {
        _recentName = null;
        _recentNumber = '';
      }
    });
    
    // Haptic feedback for better UX
    // ignore: deprecated_member_use
    Feedback.forTap(context);
  }

  void _onClearAll() {
    if (_numberCtrl.text.isEmpty) return;
    setState(() {
      _numberCtrl.text = '';
    });
  }

  Widget _buildDialpadButton({required String text, String subText = '', required VoidCallback onPressed}) {
    // Define color scheme for all buttons
    final primaryColor = Colors.green[700]!;
    final textColor = Colors.green[900]!;
    final subTextColor = Colors.green[600]!;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 36.0,
                fontWeight: FontWeight.w400,
                color: textColor,
                height: 1.0,
              ),
            ),
            if (subText.isNotEmpty)
              Text(
                subText,
                style: TextStyle(
                  fontSize: 12.0,
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Contacts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save this number to your contacts?'),
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement contact creation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact creation will be implemented here')),
              );
            },
            child: const Text('CREATE CONTACT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White background
      child: Column(
        children: [
          // Number display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              children: [
                // Large number display
                TextField(
                  controller: _numberCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36.0, 
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter number',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w300,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  readOnly: true,
                  showCursor: false,
                ),
                const SizedBox(height: 8.0),
                // Recent number/name
                if (_recentName != null || _recentNumber.isNotEmpty)
                  Text(
                    _recentName ?? _recentNumber,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                // Number controls row (Backspace and Add Contact)
                if (_numberCtrl.text.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Backspace button
                      IconButton(
                        onPressed: _onBackspace,
                        icon: const Icon(Icons.backspace, size: 24),
                        color: Colors.green[700],
                        padding: const EdgeInsets.all(8),
                      ),
                      const SizedBox(width: 16),
                      // Add Contact button
                      TextButton.icon(
                        onPressed: () {
                          _showAddContactDialog(context, _numberCtrl.text);
                        },
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Add Contact'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.green[700]!),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Divider above dialpad
                const Divider(height: 1, thickness: 0.5),
                // Dialpad buttons
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    childAspectRatio: 1.2,
                    children: _dialPadItems.map((item) {
                      return _buildDialpadButton(
                        text: item['text'],
                        subText: item['subText'],
                        onPressed: () => _onDialpadPressed(item['text']),
                      );
                    }).toList(),
                  ),
                ),
                // Call button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _numberCtrl.text.isEmpty ? null : _startCallAndCapture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50), // Green color for call button
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'CALL',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
