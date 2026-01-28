import 'dart:io';

import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/date_picker_field.dart';
import 'package:bukidbayan_app/widgets/requirement_upload_tile.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/components/rent/rent_item_expandable.dart';
import 'package:image_picker/image_picker.dart';


class RequestRentForm extends StatefulWidget {
  final RentItem item;
  const RequestRentForm({super.key, required this.item});

  @override
  State<RequestRentForm> createState() => _RequestRentFormState();
}

class _RequestRentFormState extends State<RequestRentForm> {
  DateTime? startDate;
  DateTime? returnDate;

   DateTime? availableFrom;
  DateTime? availableUntil;
  bool showAvailabilityError = false;


  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final RentRequestService _requestService = RentRequestService();


  final ImagePicker _picker = ImagePicker();
  XFile? landSizeProof;
  XFile? cropHeightProof;

  bool get isScheduleComplete =>
      startDate != null && returnDate != null;


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
            StepHeader(
              title: 'Step 1: Iskedyul ng Pag-upa',
              subtitle: 'Piliin ang petsa at oras ng pickup at return. '
              'Ang return ay dapat hindi bababa sa 1 oras mula sa pickup.',
            ),

          //  Row(
          //   children: [
          //     Expanded(
          //       child: DatePickerField(
          //         label: 'Start / Pickup Date',
          //         value: startDate,
          //         onTap: () => _openDatePicker(
          //           context,
          //           initial: startDate,
          //           availabilityFrom: widget.item.availableFrom!,
          //           availabilityTo: widget.item.availableTo!,
          //           onConfirm: (date) {
          //             setState(() {
          //               startDate = date;
          //               returnDate = null;
          //             });
          //           },
          //         ),
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: DatePickerField(
          //         label: 'Return Date',
          //         value: returnDate,
          //         onTap: startDate == null
          //             ? null
          //             : () => _openDatePicker(
          //                   context,
          //                   initial: returnDate ?? startDate,
          //                   availabilityFrom: widget.item.availableFrom!,
          //                   availabilityTo: widget.item.availableTo!,
          //                   onConfirm: (date) {
          //                     if (date.isBefore(startDate!)) {
          //                       showErrorSnackbar(
          //                         context: context,
          //                         title: 'Invalid date',
          //                         message:
          //                             'Return date must be after pickup date',
          //                       );
          //                       return;
          //                     }
          //                     setState(() => returnDate = date);
          //                   },
          //                 ),
          //       ),
          //     ),
          //   ],
          // ),

          Row(
            children: [
              Expanded(
                child: DatePickerField(
                  label: 'Start / Pickup Date',
                  value: startDate,
                  onTap: () async {
                    final DateTime now = DateTime.now();
                    final DateTime initial = startDate ?? widget.item.availableFrom!;
                    final DateTime first = widget.item.availableFrom!;
                    final DateTime last = widget.item.availableTo!;

                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first,
                      lastDate: last,
                    );

                    if (picked != null) {
                      setState(() {
                        startDate = picked;
                        returnDate = null; // auto-clear return
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DatePickerField(
                  label: 'Return Date',
                  value: returnDate,
                  onTap: startDate == null
                      ? null
                      : () async {
                          final DateTime initial = returnDate ?? startDate!;
                          final DateTime first = startDate!;
                          final DateTime last = widget.item.availableTo!;

                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: first,
                            lastDate: last,
                          );

                          if (picked != null) {
                            if (picked.isBefore(startDate!)) {
                              showErrorSnackbar(
                                context: context,
                                title: 'Invalid date',
                                message: 'Return date must be after pickup date',
                              );
                              return;
                            }
                            setState(() {
                              returnDate = picked;
                            });
                          }
                        },
                ),
              ),
            ],
          ),




            /// STEP 2 — USER INFO
            if (isScheduleComplete) ...[
              const CustomDivider(),
              StepHeader(
                title: 'Step 2: Impormasyon ng Umuupa',
                subtitle: 'Ilagay ang buong pangalan at address.',
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
              StepHeader(
                title: 'Step 3: Patunay ng Requirements',
                subtitle: 'Mag-upload ng larawan bilang patunay sa mga requirement.',
              ),

              if (widget.item.landSizeRequirement == true)
                RequirementUploadTile(
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
                RequirementUploadTile(
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
            if (isScheduleComplete) ...[
             Align(
              alignment: Alignment.center,
              child: OutlinedButton(
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

                  if (landSizeProof != null) {
                    landPath = await _requestService.saveFileLocally(landSizeProof!);
                  }
                  if (cropHeightProof != null) {
                    cropPath = await _requestService.saveFileLocally(cropHeightProof!);
                  }

                  final request = RentRequest(
                    itemId: widget.item.id,
                    itemName: widget.item.title, // <-- added here
                    name: nameController.text,
                    address: addressController.text,
                    start: startDate!,
                    end: returnDate!,
                    landSizeProofPath: landPath,
                    cropHeightProofPath: cropPath,
                  );


                  await _requestService.saveRequest(request);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request sent!')),
                  );

            
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RequestSentPage()),
                  );
                },
                child: Text(
                  'Submit',
                  style: TextStyle(
                    color: lightColorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          ]
        )
      ),
    );
  }

  /// ---------- HELPERS ----------

  // void _openDatePicker(
  //   BuildContext context, {
  //   DateTime? initial,
  //   required DateTime availabilityFrom,
  //   required DateTime availabilityTo,
  //   required Function(DateTime) onConfirm,
  // }) {
  //   DateTime tempDate = initial ?? availabilityFrom;

  //   showModalBottomSheet(
  //     context: context,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder: (_) {
  //       return StatefulBuilder(
  //         builder: (context, setModalState) {
  //           return Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 CalendarDatePicker(
  //                   initialDate: tempDate,
  //                   firstDate: availabilityFrom,
  //                   lastDate: availabilityTo,
  //                   onDateChanged: (date) {
  //                     setModalState(() {
  //                       tempDate = DateTime(
  //                         date.year,
  //                         date.month,
  //                         date.day,
  //                       );
  //                     });
  //                   },
  //                 ),
  //                 const SizedBox(height: 8),
  //                 TextButton(
  //                   onPressed: () {
  //                     Navigator.pop(context);
  //                     onConfirm(tempDate);
  //                   },
  //                   child: const Text('Done'),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

//   Future<void> _pickDate({required bool isStart}) async {
//   final DateTime now = DateTime.now();

//   final DateTime initial = isStart
//       ? now
//       : (availableFrom ?? now);

//   final DateTime first = isStart
//       ? now
//       : (availableFrom ?? now);

//   final DateTime? picked = await showDatePicker(
//     context: context,
//     initialDate: initial,
//     firstDate: first,
//     lastDate: DateTime(now.year + 5),
//   );

//   if (picked != null) {
//     setState(() {
//       if (isStart) {
//         availableFrom = picked;

//         // Auto-clear "until" if invalid
//         if (availableUntil != null &&
//             availableUntil!.isBefore(picked)) {
//           availableUntil = null;
//         }
//       } else {
//         availableUntil = picked;
//       }
//     });
//   }
// }

}
