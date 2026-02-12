import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/date_picker_field.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';

class DateStep extends StatelessWidget {
  final Equipment item;
  final DateTime? startDate;
  final DateTime? returnDate;
  final Function(DateTime) onStartDatePicked;
  final Function(DateTime) onReturnDatePicked;

  const DateStep({
    super.key,
    required this.item,
    this.startDate,
    this.returnDate,
    required this.onStartDatePicked,
    required this.onReturnDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CustomDivider(),
        StepHeader(
          title: 'Step 1: Iskedyul ng Pag-upa',
          subtitle: 'Piliin ang petsa at oras ng pickup at return. Ang return ay dapat hindi bababa sa 1 oras mula sa pickup.',
        ),
        Row(
          children: [
            Expanded(
              child: DatePickerField(
                label: 'Start / Pickup Date',
                value: startDate,
                onTap: () async {
                  final now = DateTime.now();
                  final earliest = item.availableFrom!.isAfter(now) ? item.availableFrom! : now;
                  final last = item.availableUntil!;
                  final initial = startDate ?? earliest;

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: earliest,
                    lastDate: last,
                  );

                  if (picked != null) onStartDatePicked(picked);
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
                        final initial = returnDate ?? startDate!;
                        final first = startDate!;
                        final last = item.availableUntil!;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: first,
                          lastDate: last,
                        );

                        if (picked != null) {
                          if (picked.isBefore(startDate!)) {
                            showErrorSnackbar(context: context, title: 'Invalid date', message: 'Return date must be after pickup date');
                            return;
                          }
                          onReturnDatePicked(picked);
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
