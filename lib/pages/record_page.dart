// lib/pages/record_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/call_log.dart';
import '../widgets/recording_item.dart';

class RecordPage extends StatefulWidget {
  final CallLogEntry? initialCall;
  
  const RecordPage({Key? key, this.initialCall}) : super(key: key);

  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage>
    with SingleTickerProviderStateMixin {
  final CallLogStore _store = CallLogStore();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _search = TextEditingController();

  List<CallLogEntry> _recordings = [];
  String? _playingId;

  int _tabIndex = 0;
  late TabController _tabs;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      setState(() => _tabIndex = _tabs.index);
    });

    _load().then((_) {
      // If we have an initial call, find and play it
      if (widget.initialCall != null) {
        // Find the call in our loaded recordings
        final call = _recordings.firstWhere(
          (entry) => entry.id == widget.initialCall!.id,
          orElse: () => widget.initialCall!,
        );
        
        // If the call has a recording, play it
        if (call.filePath != null && call.filePath!.isNotEmpty) {
          _play(call);
        }
      }
    });
    
    _player.onPlayerComplete.listen((_) {
      setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD HISTORY + RECORDINGS
  // ------------------------------------------------------------
  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final list = await _store.load(); // reads all logs
      list.sort((a, b) => b.when.compareTo(a.when));

      setState(() {
        _recordings = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading logs: $e");
      setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------
  // FILTER RECORDINGS
  // ------------------------------------------------------------
  List<CallLogEntry> get _filtered {
    final q = _search.text.toLowerCase();

    return _recordings.where((entry) {
      // Tabs filtering
      if (_tabIndex == 1 && !entry.isSaved) return false;
      if (_tabIndex == 2 && !entry.isDeleted) return false;

      // Search
      if (q.isNotEmpty) {
        final n = entry.name?.toLowerCase() ?? "";
        final ph = entry.number.toLowerCase();
        return n.contains(q) || ph.contains(q);
      }

      return true;
    }).toList();
  }

  // ------------------------------------------------------------
  // PLAY / STOP AUDIO
  // ------------------------------------------------------------
  Future<void> _play(CallLogEntry e) async {
    if (e.filePath == null || e.filePath!.isEmpty) {
      _error("Recording file missing.");
      return;
    }

    final file = File(e.filePath!);

    if (!file.existsSync()) {
      _error("Recording file not found.");
      return;
    }

    // Stop if already playing
    if (_playingId == e.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    try {
      await _player.stop();
      await _player.play(DeviceFileSource(e.filePath!));

      setState(() => _playingId = e.id);
    } catch (ex) {
      debugPrint("Audio error: $ex");
      _error("Unable to play this recording.");
    }
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Recordings'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Saved'),
            Tab(text: 'Deleted'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search recordings...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    
    if (filtered.isEmpty) {
      return _empty();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final entry = filtered[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: IconButton(
                icon: Icon(
                  _playingId == entry.id ? Icons.pause : Icons.play_arrow,
                  color: Colors.blue,
                  size: 32,
                ),
                onPressed: () => _play(entry),
              ),
              title: Text(
                entry.name ?? entry.number,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.number),
                  Text(
                    '${_formatDate(entry.when)} • ${_formatDuration(entry.duration)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'save':
                      _toggleSave(entry);
                      break;
                    case 'share':
                      _share(entry);
                      break;
                    case 'delete':
                      _delete(entry);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(entry.isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
                        const SizedBox(width: 8),
                        Text(entry.isSaved ? 'Unsave' : 'Save'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY UI
  // ------------------------------------------------------------
  Widget _empty() {
    IconData icon;
    String msg;
    String? subMsg;

    if (_search.text.isNotEmpty) {
      icon = Icons.search_off;
      msg = "No matching results";
    } else if (_tabIndex == 1) {
      icon = Icons.bookmark_border;
      msg = "No saved recordings";
    } else if (_tabIndex == 2) {
      icon = Icons.delete_outline;
      msg = "Trash is empty";
    } else {
      icon = Icons.mic_none;
      msg = "No recordings yet";
      subMsg = "Your call recordings will appear here";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey),
          const SizedBox(height: 15),
          Text(msg, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          if (subMsg != null) ...[
            const SizedBox(height: 8),
            Text(subMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  Future<void> _toggleSave(CallLogEntry entry) async {
    await _store.toggleSave(entry.id);
    await _load();
  }

  Future<void> _share(CallLogEntry entry) async {
    if (entry.filePath == null || entry.filePath!.isEmpty) {
      _error('No recording file available to share');
      return;
    }

    try {
      await Share.shareFiles(
        [entry.filePath!],
        text: 'Call recording with ${entry.name ?? entry.number}',
      );
    } catch (e) {
      _error('Failed to share recording');
    }
  }

  Future<void> _delete(CallLogEntry entry) async {
    if (entry.isDeleted) {
      await _store.deletePermanently(entry.id);
    } else {
      await _store.moveToTrash(entry.id);
    }
    await _load();
  }
}
