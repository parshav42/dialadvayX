import 'package:flutter/material.dart';
import '../services/speak_history.dart';

class SpeakHistoryPage extends StatefulWidget {
  final String contactId;
  final String displayName;

  const SpeakHistoryPage({
    super.key,
    required this.contactId,
    required this.displayName,
  });

  @override
  State<SpeakHistoryPage> createState() => _SpeakHistoryPageState();
}

class _SpeakHistoryPageState extends State<SpeakHistoryPage> {
  final SpeakHistoryStore _store = SpeakHistoryStore();

  List<SpeakEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await _store.loadEntries(widget.contactId);

    if (!mounted) return;

    setState(() {
      _items = list.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _logNow() async {
    await _store.add(
      widget.contactId,
      SpeakEntry(
        when: DateTime.now(),
        note: "Manual log",
      ),
    );

    _loadHistory();
  }

  Future<void> _clear() async {
    await _store.clearEntries(widget.contactId);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("History • ${widget.displayName}"),
        actions: [
          IconButton(
            onPressed: _items.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text("No history yet"))
          : ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final e = _items[index];
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(_format(e.when)),
            subtitle: Text(e.note ?? ""),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logNow,
        icon: const Icon(Icons.add),
        label: const Text("Add Log"),
      ),
    );
  }

  String _format(DateTime dt) {
    return "${dt.year}-${dt.month}-${dt.day} "
        "${dt.hour}:${dt.minute}:${dt.second}";
  }
}
