import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';

class BasicInfoStep extends StatefulWidget {
  final Function(String) onTitleChanged;
  final Function(String) onCategoryChanged;
  final Function(String) onImagePathChanged;
  final Function(bool) onIsAssetImageChanged;
  final String initialTitle;
  final String initialCategory;
  final String initialImagePath;
  final bool initialIsAssetImage;

  const BasicInfoStep({
    super.key,
    required this.onTitleChanged,
    required this.onCategoryChanged,
    required this.onImagePathChanged,
    required this.onIsAssetImageChanged,
    required this.initialTitle,
    required this.initialCategory,
    required this.initialImagePath,
    required this.initialIsAssetImage,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late TextEditingController _titleController;
  late TextEditingController _imagePathController;
  late String _selectedCategory;
  late bool _isAssetImage;

  final List<String> _categories = [
    'Agriculture',
    'Sustainability',
    'Marketplace',
    'Technology',
    'Community',
    'Education',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _imagePathController = TextEditingController(text: widget.initialImagePath);
    _selectedCategory = widget.initialCategory;
    _isAssetImage = widget.initialIsAssetImage;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imagePathController.dispose();
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
            'Campaign Title',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint: 'e.g., Community Greenhouse for Urban Farmers',
            controller: _titleController,
            onChanged: (value) {
              widget.onTitleChanged(value);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Category',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categories
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCategory = value);
                widget.onCategoryChanged(value);
              }
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cover Image',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(label: Text('Asset'), value: true),
                    ButtonSegment(label: Text('URL'), value: false),
                  ],
                  selected: {_isAssetImage},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _isAssetImage = newSelection.first);
                    widget.onIsAssetImageChanged(_isAssetImage);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: _isAssetImage
                ? 'e.g., assets/images/farmBg.jpg'
                : 'e.g., https://example.com/image.jpg',
            controller: _imagePathController,
            onChanged: (value) {
              widget.onImagePathChanged(value);
            },
          ),
          const SizedBox(height: 12),
          if (_imagePathController.text.isNotEmpty)
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: _isAssetImage
                  ? Image.asset(_imagePathController.text, fit: BoxFit.cover)
                  : Image.network(_imagePathController.text,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Text('Failed to load image'))),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
