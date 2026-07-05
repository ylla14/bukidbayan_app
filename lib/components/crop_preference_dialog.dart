import 'dart:async';

import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class CropPreferenceDialog extends StatefulWidget {
  final String userId;

  const CropPreferenceDialog({super.key, required this.userId});

  @override
  State<CropPreferenceDialog> createState() => _CropPreferenceDialogState();
}

class _CropPreferenceDialogState extends State<CropPreferenceDialog> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one crop.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreService()
          .saveCropPreferences(widget.userId, _selected.toList())
          .timeout(const Duration(seconds: 12));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final message = e is TimeoutException
            ? 'Saving your crop preferences took too long. Please try again.'
            : 'Failed to save preferences: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.eco_rounded,
                  color: lightColorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'What do you grow?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: lightColorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select your crops so we can recommend the right equipment for you.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Crop selection grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allCrops.map((crop) {
                final isSelected = _selected.contains(crop);
                return GestureDetector(
                  onTap: () => setState(() {
                    isSelected ? _selected.remove(crop) : _selected.add(crop);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? lightColorScheme.primary
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? lightColorScheme.primary
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        Text(
                          crop,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightColorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Preferences',
                        style: TextStyle(fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
