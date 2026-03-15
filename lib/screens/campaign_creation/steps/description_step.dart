import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';

class DescriptionStep extends StatefulWidget {
  final Function(String) onShortBlurbChanged;
  final Function(String) onDescriptionChanged;
  final String initialShortBlurb;
  final String initialDescription;

  const DescriptionStep({
    super.key,
    required this.onShortBlurbChanged,
    required this.onDescriptionChanged,
    required this.initialShortBlurb,
    required this.initialDescription,
  });

  @override
  State<DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends State<DescriptionStep> {
  late TextEditingController _shortBlurbController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _shortBlurbController =
        TextEditingController(text: widget.initialShortBlurb);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _shortBlurbController.dispose();
    _descriptionController.dispose();
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
            'Short Blurb',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'A one-liner summary of your campaign',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint: 'e.g., A shared greenhouse for sustainable urban farming',
            controller: _shortBlurbController,
            maxLines: 2,
            onChanged: (value) {
              widget.onShortBlurbChanged(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Full Description / Story',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell the story of your campaign. Include context, purpose, and impact.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint:
                'We are building a small greenhouse with basic irrigation...',
            controller: _descriptionController,
            maxLines: 8,
            onChanged: (value) {
              widget.onDescriptionChanged(value);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
