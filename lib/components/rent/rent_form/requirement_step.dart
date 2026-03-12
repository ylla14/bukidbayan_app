import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/requirement_upload_tile.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class RequirementStep extends StatelessWidget {
  final Equipment item;

  // ── Now LISTS instead of single XFile ──────────────────────
  final List<XFile> landSizeProofs;
  final List<XFile> cropHeightProofs;

  final Function(XFile) onLandAdd;
  final Function(int) onLandRemove;
  final Function(XFile) onCropAdd;
  final Function(int) onCropRemove;

  final ImagePicker picker;
  final bool keepDarak;
  final VoidCallback onToggleDarak;
  final double? estimatedTotal;
  final TextEditingController? volumeController;
  final String? volumeError;

  const RequirementStep({
    super.key,
    required this.item,
    this.landSizeProofs = const [],
    this.cropHeightProofs = const [],
    required this.onLandAdd,
    required this.onLandRemove,
    required this.onCropAdd,
    required this.onCropRemove,
    required this.picker,
    this.volumeController,
    this.volumeError,
    this.estimatedTotal,
    required this.keepDarak,
    required this.onToggleDarak,
  });

  // ── Source picker sheet ─────────────────────────────────────
  Future<void> _showSourceSheet(
    BuildContext context, {
    required Function(XFile) onPicked,
    bool allowVideo = true,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Photo from camera ───────────────────────────
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kumuha ng Larawan'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final file = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (file != null) onPicked(file);
                } catch (e) {
                  debugPrint('Camera photo error: $e');
                }
              },
            ),

            // ── Video from camera (maxDuration cap prevents OOM) ──
            if (allowVideo)
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Kumuha ng Video'),
                subtitle: const Text(
                  'Max 2 minuto',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final file = await picker.pickVideo(
                      source: ImageSource.camera,
                      maxDuration: const Duration(minutes: 2),
                    );
                    if (file != null) onPicked(file);
                  } catch (e) {
                    debugPrint('Camera video error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Hindi ma-record ang video. Subukan mula sa gallery.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),

            // ── Photo from gallery ──────────────────────────
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pumili ng Larawan mula sa Gallery'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (file != null) onPicked(file);
                } catch (e) {
                  debugPrint('Gallery photo error: $e');
                }
              },
            ),

            // ── Video from gallery (most reliable on Android) ──
            if (allowVideo)
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Pumili ng Video mula sa Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final file = await picker.pickVideo(
                      source: ImageSource.gallery,
                    );
                    if (file != null) onPicked(file);
                  } catch (e) {
                    debugPrint('Gallery video error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hindi ma-load ang video.'),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRiceMill =
        item.category?.toLowerCase().contains('rice mill') == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomDivider(),
        StepHeader(
          title: 'Step 3: Patunay ng Requirements',
          subtitle:
              'Mag-upload ng mga larawan o video bilang patunay sa mga requirement.',
        ),

        // ── Land size proof ─────────────────────────────────
        if (item.landSizeRequirement == true)
          RequirementUploadTile(
            label: 'Patunay ng Laki ng Lupa',
            files: landSizeProofs,
            onPick: () => _showSourceSheet(
              context,
              onPicked: onLandAdd,
            ),
            onRemove: onLandRemove,
          ),

        // ── Crop height proof ───────────────────────────────
        if (item.maxCropHeightRequirement == true)
          RequirementUploadTile(
            label: 'Patunay ng Taas ng Pananim',
            files: cropHeightProofs,
            onPick: () => _showSourceSheet(
              context,
              onPicked: onCropAdd,
            ),
            onRemove: onCropRemove,
          ),

        // ── Rice Mill: volume + darak (unchanged) ───────────
        if (isRiceMill && item.minimumVolumeRequired) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dami ng Palay (Volume)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minimum na kinakailangan: '
                  '${item.minimumVolumeUnit == 'cavans' ? '${(item.minimumVolumeKg! / 50).toStringAsFixed(0)} cavans' : '${item.minimumVolumeKg!.toStringAsFixed(0)} kg'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (item.batchingAllowed) ...[
                  const SizedBox(height: 2),
                  Text(
                    '💡 Hindi pa sapat ang dami? Maaaring mag-batch kasama ang ibang magsasaka.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: volumeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: item.minimumVolumeUnit == 'cavans'
                        ? 'Ilagay ang dami (cavans)'
                        : 'Ilagay ang dami (kg)',
                    suffixText: item.minimumVolumeUnit == 'cavans'
                        ? 'cavans'
                        : 'kg',
                    errorText: volumeError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Darak toggle
                const Text(
                  'Keep Byproduct (Darak)?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Rice Only
                    Expanded(
                      child: GestureDetector(
                        onTap: keepDarak ? onToggleDarak : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !keepDarak
                                ? lightColorScheme.primary
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: !keepDarak
                                  ? lightColorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Rice Only',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !keepDarak
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${item.riceOnlyPricePerKg?.toStringAsFixed(2) ?? '2.00'}/kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: !keepDarak
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Rice + Darak
                    Expanded(
                      child: GestureDetector(
                        onTap: keepDarak ? null : onToggleDarak,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: keepDarak
                                ? lightColorScheme.primary
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: keepDarak
                                  ? lightColorScheme.primary
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Rice + Darak',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: keepDarak
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${item.ricePlusDarakPricePerKg?.toStringAsFixed(2) ?? '3.00'}/kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: keepDarak
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Estimated total
                if (estimatedTotal != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Total',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${estimatedTotal!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${volumeController?.text ?? '0'} ${item.minimumVolumeUnit} × '
                          '₱${keepDarak ? item.ricePlusDarakPricePerKg?.toStringAsFixed(2) ?? '3.00' : item.riceOnlyPricePerKg?.toStringAsFixed(2) ?? '2.00'}/kg',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}