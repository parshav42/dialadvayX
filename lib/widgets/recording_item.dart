// lib/widgets/recording_item.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/call_log.dart';

class RecordingItem extends StatelessWidget {
  final CallLogEntry entry;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onToggleSave;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onDeletePermanently;

  const RecordingItem({
    Key? key,
    required this.entry,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onToggleSave,
    required this.onDelete,
    this.onRestore,
    this.onDeletePermanently,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isPlaying ? Colors.blue.shade100 : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isPlaying ? Colors.blue : Colors.black87,
            ),
            onPressed: onPlayPause,
          ),
        ),
        title: Text(
          entry.name?.isNotEmpty == true ? entry.name! : 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.number,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            Text(
              _formatDate(entry.when),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                entry.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: entry.isSaved ? Colors.orange : Colors.grey,
              ),
              onPressed: onToggleSave,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                switch (value) {
                  case 'share':
                    if (entry.filePath != null) {
                      await Share.shareXFiles([XFile(entry.filePath!)]);
                    }
                    break;
                  case 'delete':
                    onDelete();
                    break;
                  case 'restore':
                    onRestore?.call();
                    break;
                  case 'delete_perm':
                    onDeletePermanently?.call();
                    break;
                }
              },
              itemBuilder: (context) {
                if (entry.isDeleted) {
                  return [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore, size: 20),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete_perm',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Permanently',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ];
                }
                return [
                  if (entry.filePath != null)
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
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Move to Trash',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}