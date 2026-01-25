import 'dart:io';

import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:flutter/material.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/components/rent/rent_item_expandable.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:image_picker/image_picker.dart';


class RequestRentForm extends StatefulWidget {
  final RentItem item;
  const RequestRentForm({super.key, required this.item});

  @override
  State<RequestRentForm> createState() => _RequestRentFormState();
}

class _RequestRentFormState extends State<RequestRentForm> {
  DateTime? startDateTime;
  DateTime? returnDateTime;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final RentRequestService _requestService = RentRequestService();


  final ImagePicker _picker = ImagePicker();
  XFile? landSizeProof;
  XFile? cropHeightProof;

  bool get isScheduleComplete =>
      startDateTime != null && returnDateTime != null;

  bool get isStep2Complete =>
      nameController.text.isNotEmpty &&
      addressController.text.isNotEmpty;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Request Form',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: lightColorScheme.primary,
              ),
            ),

            const SizedBox(height: 10),
            RentItemExpandable(item: widget.item),

            /// STEP 1 — DATE & TIME
            const CustomDivider(),
            _stepHeader(
              'Step 1: Iskedyul ng Pag-upa',
              'Piliin ang petsa at oras ng pickup at return. '
              'Ang return ay dapat hindi bababa sa 1 oras mula sa pickup.',
            ),

            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    label: 'Start / Pickup',
                    value: startDateTime,
                    onTap: () => _openDateTimePicker(
                      context,
                      initial: startDateTime,
                      onConfirm: (date) {
                        setState(() {
                          startDateTime = date;
                          returnDateTime = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateButton(
                    label: 'Return Date',
                    value: returnDateTime,
                    onTap: startDateTime == null
                        ? null
                        : () => _openDateTimePicker(
                              context,
                              initial: returnDateTime ?? startDateTime,
                              onConfirm: (date) {
                                if (date.isBefore(
                                  startDateTime!.add(const Duration(hours: 1)),
                                )) {
                                  showErrorSnackbar(
                                    context: context,
                                    title: 'Error',
                                    message:
                                        'Return time must be at least 1 hour after pickup',
                                  );
                                  return;
                                }
                                setState(() => returnDateTime = date);
                              },
                            ),
                  ),
                ),
              ],
            ),

            /// STEP 2 — USER INFO
            if (isScheduleComplete) ...[
              const CustomDivider(),
              _stepHeader(
                'Step 2: Impormasyon ng Umuupa',
                'Ilagay ang buong pangalan at address.',
              ),

              CustomTextFormField(
                controller: nameController,
                hint: 'Buong Pangalan',
              ),
              const SizedBox(height: 12),
              CustomTextFormField(
                controller: addressController,
                hint: 'Address',
                maxLines: 3,
              ),
            ],

            /// STEP 3 — REQUIREMENTS PROOF
            if (isScheduleComplete) ...[
              const CustomDivider(),
              _stepHeader(
                'Step 3: Patunay ng Requirements',
                'Mag-upload ng larawan bilang patunay sa mga requirement.',
              ),

              if (widget.item.landSizeRequirement == true)
                _requirementUploadTile(
                  label: 'Patunay ng Laki ng Lupa',
                  file: landSizeProof,
                  onPick: () async {
                    final image =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() => landSizeProof = image);
                    }
                  },
                  onRemove: () {
                    setState(() => landSizeProof = null);
                  },
                ),

              if (widget.item.maxCropHeightRequirement == true)
                _requirementUploadTile(
                  label: 'Patunay ng Taas ng Pananim',
                  file: cropHeightProof,
                  onPick: () async {
                    final image =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() => cropHeightProof = image);
                    }
                  },
                  onRemove: () {
                    setState(() => cropHeightProof = null);
                  },
                ),
            ],



            const SizedBox(height: 16),

            /// SUBMIT
            OutlinedButton(
            onPressed: () async {
              if (!isScheduleComplete || !isStep2Complete) {
                showErrorSnackbar(
                  context: context,
                  title: 'Incomplete',
                  message: 'Please complete all required fields',
                );
                return;
              }

              String? landPath;
              String? cropPath;

              if (landSizeProof != null) landPath = await _requestService.saveFileLocally(landSizeProof!);
              if (cropHeightProof != null) cropPath = await _requestService.saveFileLocally(cropHeightProof!);

              final request = RentRequest(
                itemId: widget.item.id,
                name: nameController.text,
                address: addressController.text,
                start: startDateTime!,
                end: returnDateTime!,
                landSizeProofPath: landPath,
                cropHeightProofPath: cropPath,
              );

              await _requestService.saveRequest(request);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request saved!')),
              );

              Navigator.pop(context);
            },
            child: Text(
              'Submit',
              style: TextStyle(
                color: lightColorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
          ],
        
        ),
      ),
    );
  }

  /// ---------- HELPERS ----------

  Widget _stepHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

Widget _requirementUploadTile({
  required String label,
  required XFile? file,
  required VoidCallback onPick,
  required VoidCallback onRemove,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: OutlinedButton(
      onPressed: file == null ? onPick : null, // disable tap when uploaded
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(
            file == null ? Icons.upload_file : Icons.check_circle,
            color: file == null ? Colors.grey : Colors.green,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              file == null ? label : 'Uploaded: ${file.name}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          // ❌ REMOVE BUTTON (only when file exists)
          if (file != null)
            IconButton(
              icon: const Icon(Icons.close),
              color: Colors.redAccent,
              tooltip: 'Remove upload',
              onPressed: onRemove,
            ),
        ],
      ),
    ),
  );
}


  Widget _dateButton({
    required String label,
    required DateTime? value,
    VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isDisabled ? Colors.grey.shade400 : lightColorScheme.primary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? Colors.grey : Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              value == null ? 'Select date & time' : _formatDateTime(value),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }


  void _openDateTimePicker(
    BuildContext context, {
    DateTime? initial,
    required Function(DateTime) onConfirm,
  }) {
    DateTime tempDate = initial ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TimePickerSpinner(
                    time: tempDate,
                    is24HourMode: false,
                    onTimeChange: (time) {
                      setModalState(() {
                        tempDate = DateTime(
                          tempDate.year,
                          tempDate.month,
                          tempDate.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    onDateChanged: (date) {
                      setModalState(() {
                        tempDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          tempDate.hour,
                          tempDate.minute,
                        );
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm(tempDate);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} • '
        '${date.hour % 12 == 0 ? 12 : date.hour % 12}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}
