import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/requirement_upload_tile.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class RequirementStep extends StatelessWidget {
  final Equipment item;
  final XFile? landSizeProof;
  final XFile? cropHeightProof;
  final Function(XFile) onLandPick;
  final VoidCallback onLandRemove;
  final Function(XFile) onCropPick;
  final VoidCallback onCropRemove;
  final ImagePicker picker;

  // NEW: for minimum volume
  final TextEditingController? volumeController;
  final String? volumeError;

  const RequirementStep({
    super.key,
    required this.item,
    this.landSizeProof,
    this.cropHeightProof,
    required this.onLandPick,
    required this.onLandRemove,
    required this.onCropPick,
    required this.onCropRemove,
    required this.picker,
    this.volumeController,
    this.volumeError,
  });

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
          subtitle: 'Mag-upload ng larawan bilang patunay sa mga requirement.',
        ),
        if (item.landSizeRequirement == true)
          RequirementUploadTile(
            label: 'Patunay ng Laki ng Lupa',
            file: landSizeProof,
            onPick: () async {
              final image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) onLandPick(image);
            },
            onRemove: onLandRemove,
          ),
        if (item.maxCropHeightRequirement == true)
          RequirementUploadTile(
            label: 'Patunay ng Taas ng Pananim',
            file: cropHeightProof,
            onPick: () async {
              final image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) onCropPick(image);
            },
            onRemove: onCropRemove,
          ),

        // MINIMUM VOLUME (Rice Mill only)
        if (isRiceMill && item.minimumVolumeRequired) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dami ng Palay (Volume)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
                    suffixText: item.minimumVolumeUnit == 'cavans' ? 'cavans' : 'kg',
                    errorText: volumeError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}