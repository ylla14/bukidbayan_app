import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/requirement_upload_tile.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
      ],
    );
  }
}
