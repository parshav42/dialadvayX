import 'package:flutter/material.dart';
import '../services/speak_history.dart';

class SpeakHistoryPage extends StatefulWidget {
  final String contactId;
  final String displayName;

  const SpeakHistoryPage({super.key, required this.contactId, required this.displayName});

  @override
  State<SpeakHistoryPage> createState() => _SpeakHistoryPageState();
}

class _SpeakHistoryPageState extends State<SpeakHistoryPage> {
  final _store = SpeakHistoryStore();
  List<DateTime> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _store.loadHistory(widget.contactId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _logNow() async {
    await _store.logSpeak(widget.contactId, DateTime.now());
    await _load();
  }

  Future<void> _clear() async {
    await _store.clearHistory(widget.contactId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History • ' + widget.displayName),
        actions: [
          IconButton(
            onPressed: _items.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No history yet'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final dt = _items[index];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(_format(dt)),
                      subtitle: Text(dt.toIso8601String()),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logNow,
        icon: const Icon(Icons.mic),
        label: const Text('Log now'),
      ),
    );
  }

  String _format(DateTime dt) {
    final d = dt;
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    
  }
}
