import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/utils/money_format.dart';

class FundingStep extends StatefulWidget {
  final Function(int) onGoalAmountChanged;
  final Function(DateTime) onEndDateChanged;
  final Function(String) onProductionTimelineChanged;
  final int initialGoalAmount;
  final DateTime initialEndDate;
  final String initialProductionTimeline;

  const FundingStep({
    super.key,
    required this.onGoalAmountChanged,
    required this.onEndDateChanged,
    required this.onProductionTimelineChanged,
    required this.initialGoalAmount,
    required this.initialEndDate,
    required this.initialProductionTimeline,
  });

  @override
  State<FundingStep> createState() => _FundingStepState();
}

class _FundingStepState extends State<FundingStep> {
  late TextEditingController _goalAmountController;
  late TextEditingController _productionTimelineController;
  late DateTime _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _goalAmountController =
        TextEditingController(text: widget.initialGoalAmount.toString());
    _productionTimelineController =
        TextEditingController(text: widget.initialProductionTimeline);
    _selectedEndDate = widget.initialEndDate;
  }

  @override
  void dispose() {
    _goalAmountController.dispose();
    _productionTimelineController.dispose();
    super.dispose();
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
      widget.onEndDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Funding Goal (PHP)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint: 'e.g., 50000',
            controller: _goalAmountController,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final amount = int.tryParse(value) ?? 0;
              widget.onGoalAmountChanged(amount);
            },
          ),
          const SizedBox(height: 12),
          if (_goalAmountController.text.isNotEmpty &&
              int.tryParse(_goalAmountController.text) != null)
            Text(
              'Goal: ${formatPeso(int.parse(_goalAmountController.text))}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Campaign End Date',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                '${_selectedEndDate.toLocal().toString().split(' ')[0]} (${_selectedEndDate.difference(DateTime.now()).inDays} days)',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectEndDate,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Production Timeline',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'When will backers receive their rewards?',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          CustomTextFormField(
            hint: 'e.g., Q2 2026, 6 months',
            controller: _productionTimelineController,
            onChanged: (value) {
              widget.onProductionTimelineChanged(value);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
