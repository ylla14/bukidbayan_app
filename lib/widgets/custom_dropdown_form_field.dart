import 'package:flutter/material.dart';

class CustomDropdownFormField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String hint;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;

  const CustomDropdownFormField({
    super.key,
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        prefixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      items: options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}