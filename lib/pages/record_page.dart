// lib/pages/record_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/call_log.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with SingleTickerProviderStateMixin {
  final CallLogStore _store = CallLogStore();
  List<CallLogEntry> _items = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChange);
    _load();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _load();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _store.load(includeDeleted: _currentTabIndex == 2);
    if (!mounted) return;
    setState(() {
      _items = data;
      if (_currentTabIndex == 1) {
        _items = _items.where((e) => e.isSaved).toList();
      }
      _loading = false;
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    } else if (difference.inDays < 7) {
      return '${DateFormat('EEEE').format(dt)}, ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(dt);
    }
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentTabIndex) {
      case 0:
        message = 'No call recordings yet';
        icon = Icons.phone_in_talk;
        break;
      case 1:
        message = 'No saved recordings';
        icon = Icons.bookmark_border;
        break;
      case 2:
        message = 'Trash is empty';
        icon = Icons.delete_outline;
        break;
      default:
        message = 'No items';
        icon = Icons.info_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentTabIndex == 2
                ? 'Items moved to trash will appear here'
                : 'Your call recordings will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingItem(CallLogEntry e) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: e.isDeleted ? Theme.of(context).colorScheme.surfaceVariant : Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          e.isDeleted ? Icons.delete_forever : Icons.phone_callback_rounded,
          color: e.isDeleted ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onPrimaryContainer,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              e.name?.isNotEmpty == true ? e.name! : e.number,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                decoration: e.isDeleted ? TextDecoration.lineThrough : null,
                color: e.isDeleted ? Colors.grey[600] : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (e.isSaved && !e.isDeleted)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.secondary, size: 18),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            e.number,
            style: TextStyle(
              fontSize: 14,
              color: e.isDeleted ? Colors.grey[500] : Colors.grey[600],
              decoration: e.isDeleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: e.isDeleted ? Colors.grey[400] : Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(e.when),
                style: TextStyle(
                  fontSize: 13,
                  color: e.isDeleted ? Colors.grey[500] : Colors.grey[600],
                  decoration: e.isDeleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.grey),
        itemBuilder: (context) {
          if (e.isDeleted) {
            return [
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore_from_trash, size: 20),
                    SizedBox(width: 8),
                    Text('Restore'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_perm',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Permanently', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ];
          }

          return [
            PopupMenuItem(
              value: 'save',
              child: Row(
                children: [
                  Icon(e.isSaved ? Icons.bookmark_remove : Icons.bookmark_add, size: 20),
                  const SizedBox(width: 8),
                  Text(e.isSaved ? 'Remove from saved' : 'Save to favorites'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow, size: 20),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Move to Trash', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ];
        },
        onSelected: (value) async {
          switch (value) {
            case 'play':
            // TODO: Implement play
              break;
            case 'share':
            // TODO: Implement share
              break;
            case 'save':
              await _store.toggleSave(e.id);
              if (mounted) {
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.isSaved ? 'Removed from saved' : 'Saved to favorites'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
              break;
            case 'delete':
              await _store.moveToTrash(e.id);
              if (mounted) {
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Moved to Trash'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              break;
            case 'restore':
              await _store.restoreFromTrash(e.id);
              if (mounted) {
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restored from Trash'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              break;
            case 'delete_perm':
              await _store.deletePermanently(e.id);
              if (mounted) {
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Permanently deleted'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
              break;
          }
        },
      ),
      onTap: () {
        // Handle tap to play recording
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter based on search query and current tab
    var filtered = _items.where((e) {
      if (_query.trim().isNotEmpty) {
        final q = _query.toLowerCase();
        final name = (e.name ?? '').toLowerCase();
        final num = e.number.toLowerCase();
        final note = (e.note ?? '').toLowerCase();
        if (!name.contains(q) && !num.contains(q) && !note.contains(q)) {
          return false;
        }
      }

      // Filter based on tab
      if (_currentTabIndex == 1 && !e.isSaved) return false;
      if (_currentTabIndex == 2 && !e.isDeleted) return false;

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Recordings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3.0,
          tabs: [
            Tab(icon: Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary)),
            Tab(icon: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary)),
            Tab(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search recordings',
                prefixIcon: const Icon(Icons.search, size: 22),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Recordings list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
                itemBuilder: (context, i) => _buildRecordingItem(filtered[i]),
              ),
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // TODO: Start new call
      //   },
      //   backgroundColor: Colors.green[700],
      //   child: const Icon(Icons.phone, color: Colors.white),
      //   elevation: 2,
      // ),
      persistentFooterButtons: _currentTabIndex == 2
          ? [
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Empty Trash'),
                content: const Text('Are you sure you want to permanently delete all items in Trash?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await _store.clearTrash();
              if (mounted) {
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Trash emptied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.delete_forever, color: Colors.white),
          label: const Text('Empty Trash', style: TextStyle(color: Colors.white)),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.red),
          ),
        ),
      ]
          : null,
    );
  }
}