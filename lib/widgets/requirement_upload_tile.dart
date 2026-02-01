import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RequirementUploadTile extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const RequirementUploadTile({
    super.key,
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: OutlinedButton(
        onPressed: file == null ? onPick : null,
        child: Row(
          children: [
            Icon(
              file == null ? Icons.upload_file : Icons.check_circle,
              color: file == null ? Colors.grey : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file == null ? label : 'Uploaded: ${file!.name}',
              ),
            ),
            if (file != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              )
          ],
        ),
      ),
    );
  }
}
