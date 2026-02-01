import 'package:flutter/material.dart';

String formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

void openDatePicker({
  required BuildContext context,
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required Function(DateTime) onConfirm,
}) {
  DateTime tempDate = initial;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalendarDatePicker(
                  initialDate: tempDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (date) {
                    setState(() => tempDate = date);
                  },
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm(tempDate);
                  },
                  child: const Text('Done'),
                )
              ],
            ),
          );
        },
      );
    },
  );
}
