import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../utils/date_utils.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: lightColorScheme.primary),
        backgroundColor: isDisabled ? Colors.grey.shade200 : Colors.white,
      ),
      child: Text(
        value == null
            ? label
            : '${label.split('/').first.trim()}: ${formatDate(value!)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDisabled ? Colors.grey : lightColorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
