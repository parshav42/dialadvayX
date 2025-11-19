// Update the imports at the top of record_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/call_log.dart';
import '../services/permission_service.dart';
import '../widgets/recording_item.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({Key? key}) : super(key: key);

  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage>
    with SingleTickerProviderStateMixin {
  final CallLogStore _store = CallLogStore();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  List<CallLogEntry> _recordings = [];
  bool _isLoading = true;
  String? _currentlyPlayingId;
  int _currentTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecordings();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _currentlyPlayingId = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final logs = await _store.load();// Changed from getCallLogs to getAllLogs
      logs.sort((a, b) => b.when.compareTo(a.when));

      if (mounted) {
        setState(() {
          _recordings = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<CallLogEntry> get _filteredRecordings {
    return _recordings.where((recording) {
      if (_currentTabIndex == 1 && !recording.isSaved) return false;
      if (_currentTabIndex == 2 && !recording.isDeleted) return false;

      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) return true;

      return recording.number.toLowerCase().contains(query) ||
          (recording.name?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _playRecording(CallLogEntry entry) async {
    if (entry.filePath == null) {
      debugPrint('Error: No file path for recording');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No recording file found')),
        );
      }
      return;
    }

    if (_currentlyPlayingId == entry.id) {
      debugPrint('Stopping current playback');
      await _player.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    try {
      debugPrint('Attempting to play: ${entry.filePath}');
      await _player.stop();
      
      // Check if file exists and is accessible
      final file = File(entry.filePath!);
      if (!await file.exists()) {
        debugPrint('Error: File does not exist at path: ${entry.filePath}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Recording file not found')),
          );
        }
        return;
      }

      // Configure audio player
      _player.setReleaseMode(ReleaseMode.stop);
      
      // Try playing with file path directly first
      try {
        await _player.play(DeviceFileSource(entry.filePath!));
        debugPrint('Playback started successfully');
        setState(() => _currentlyPlayingId = entry.id);
      } catch (e) {
        debugPrint('Error with DeviceFileSource, trying with UrlSource: $e');
        // Fallback to UrlSource if DeviceFileSource fails
        await _player.play(UrlSource(entry.filePath!));
        debugPrint('Playback started with UrlSource');
        setState(() => _currentlyPlayingId = entry.id);
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing recording: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() => _currentTabIndex = index),
          tabs: const [
            Tab(icon: Icon(Icons.mic, color: Colors.blue)),
            Tab(icon: Icon(Icons.bookmark, color: Colors.blue)),
            Tab(icon: Icon(Icons.delete, color: Colors.blue)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recordings...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              itemCount: _filteredRecordings.length,
              itemBuilder: (context, index) {
                final recording = _filteredRecordings[index];
                return RecordingItem(
                  entry: recording,
                  isPlaying: _currentlyPlayingId == recording.id,
                  onPlayPause: () => _playRecording(recording),
                  onToggleSave: () async {
                    await _store.toggleSave(recording.id);
                    await _loadRecordings();
                  },
                  onDelete: () async {
                    await _store.moveToTrash(recording.id);
                    await _loadRecordings();
                  },
                  onRestore: () async {
                    await _store.restoreFromTrash(recording.id);
                    await _loadRecordings();
                  },
                  onDeletePermanently: () async {
                    await _store.deletePermanently(recording.id);
                    await _loadRecordings();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String text;

    if (_searchController.text.isNotEmpty) {
      icon = Icons.search_off;
      text = 'No matching recordings found';
    } else {
      switch (_currentTabIndex) {
        case 1:
          icon = Icons.bookmark_border;
          text = 'No saved recordings';
          break;
        case 2:
          icon = Icons.delete_outline;
          text = 'Trash is empty';
          break;
        default:
          icon = Icons.mic_none;
          text = 'No recordings yet';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}