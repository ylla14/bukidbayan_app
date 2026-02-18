import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';

class AdditionalInfoStep extends StatefulWidget {
  final Function(String) onWarrantyChanged;
  final Function(String) onSparePartsChanged;
  final Function(String) onRisksChanged;
  final Function(String) onSafetyNotesChanged;
  final String initialWarranty;
  final String initialSpareParts;
  final String initialRisks;
  final String initialSafetyNotes;

  const AdditionalInfoStep({
    super.key,
    required this.onWarrantyChanged,
    required this.onSparePartsChanged,
    required this.onRisksChanged,
    required this.onSafetyNotesChanged,
    required this.initialWarranty,
    required this.initialSpareParts,
    required this.initialRisks,
    required this.initialSafetyNotes,
  });

  @override
  State<AdditionalInfoStep> createState() => _AdditionalInfoStepState();
}

class _AdditionalInfoStepState extends State<AdditionalInfoStep> {
  late TextEditingController _warrantyController;
  late TextEditingController _sparePartsController;
  late TextEditingController _risksController;
  late TextEditingController _safetyNotesController;

  @override
  void initState() {
    super.initState();
    _warrantyController = TextEditingController(text: widget.initialWarranty);
    _sparePartsController =
        TextEditingController(text: widget.initialSpareParts);
    _risksController =
        TextEditingController(text: widget.initialRisks);
    _safetyNotesController =
        TextEditingController(text: widget.initialSafetyNotes);
  }

  @override
  void dispose() {
    _warrantyController.dispose();
    _sparePartsController.dispose();
    _risksController.dispose();
    _safetyNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Warranty',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe any warranty offered to backers (optional)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint: 'e.g., 1 year limited warranty, free repairs',
            controller: _warrantyController,
            maxLines: 3,
            onChanged: (value) {
              widget.onWarrantyChanged(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Spare Parts',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Information about spare parts availability (optional)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint:
                'e.g., Spare parts available for 5 years, dealer network in major cities',
            controller: _sparePartsController,
            maxLines: 3,
            onChanged: (value) {
              widget.onSparePartsChanged(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Risks',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Potential risks and challenges (optional)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint:
                'e.g., Weather delays may affect harvest timeline...',
            controller: _risksController,
            maxLines: 3,
            onChanged: (value) {
              widget.onRisksChanged(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Safety Notes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Important safety information (optional)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint:
                'e.g., Proper handling instructions, protective equipment needed...',
            controller: _safetyNotesController,
            maxLines: 4,
            onChanged: (value) {
              widget.onSafetyNotesChanged(value);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
