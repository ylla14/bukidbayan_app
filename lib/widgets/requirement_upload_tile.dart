import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RequirementUploadTile extends StatelessWidget {
  final String label;
  final List<XFile> files;
  final VoidCallback onPick; // opens camera/gallery sheet
  final Function(int index) onRemove;
  final int maxFiles;

  const RequirementUploadTile({
    super.key,
    required this.label,
    required this.files,
    required this.onPick,
    required this.onRemove,
    this.maxFiles = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canAdd = files.length < maxFiles;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row ──────────────────────────────────────
          Row(
            children: [
              Icon(
                files.isEmpty ? Icons.upload_file : Icons.check_circle,
                size: 18,
                color: files.isEmpty ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${files.length}/$maxFiles',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Media grid ─────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: files.length + (canAdd ? 1 : 0),
            itemBuilder: (_, index) {
              // "Add" tile
              if (index == files.length) {
                return GestureDetector(
                  onTap: onPick,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: cs.primary,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final file = files[index];
              final isVideo = _isVideo(file.name);

              // Media tile
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isVideo
                        ? _VideoThumbnail(file: file)
                        : Image.file(
                            File(file.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  // Video badge
                  if (isVideo)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 12),
                            SizedBox(width: 3),
                            Text(
                              'VID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Remove button
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () => onRemove(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Hint text if empty ──────────────────────────────
          if (files.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Pindutin ang + para magdagdag ng larawan o video (max $maxFiles)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  bool _isVideo(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);
  }
}

/// Simple video thumbnail — shows a dark placeholder with a play icon
/// (video_thumbnail packages need native setup; this avoids that dependency)
class _VideoThumbnail extends StatelessWidget {
  final XFile file;
  const _VideoThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[850],
      child: const Center(
        child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
      ),
    );
  }
}