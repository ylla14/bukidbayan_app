import 'package:flutter/material.dart';
import 'package:bukidbayan_app/models/campaign.dart';

class RewardTierForm extends StatefulWidget {
  final RewardTier? initialTier;
  final Function(RewardTier) onSave;
  final VoidCallback onCancel;

  const RewardTierForm({
    super.key,
    this.initialTier,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<RewardTierForm> createState() => _RewardTierFormState();
}

class _RewardTierFormState extends State<RewardTierForm> {
  late TextEditingController _tierNameController;
  late TextEditingController _minPledgeController;
  late TextEditingController _discountValueController;
  late TextEditingController _usageLimitController;
  late TextEditingController _validityDaysController;
  late TextEditingController _notesController;

  late String _discountType;

  @override
  void initState() {
    super.initState();
    final tier = widget.initialTier;
    _tierNameController = TextEditingController(text: tier?.title ?? '');
    _minPledgeController =
        TextEditingController(text: tier?.minPledge.toString() ?? '');
    _discountValueController =
        TextEditingController(text: tier?.discountValue.toString() ?? '');
    _usageLimitController =
        TextEditingController(text: tier?.usageLimit.toString() ?? '1');
    _validityDaysController =
        TextEditingController(text: tier?.validityDays.toString() ?? '90');
    _notesController = TextEditingController(text: tier?.notes ?? '');
    _discountType = tier?.discountType ?? 'percent';
  }

  @override
  void dispose() {
    _tierNameController.dispose();
    _minPledgeController.dispose();
    _discountValueController.dispose();
    _usageLimitController.dispose();
    _validityDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    // Validation
    if (_tierNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tier name is required.')),
      );
      return;
    }

    final minPledge = int.tryParse(_minPledgeController.text);
    if (minPledge == null || minPledge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum pledge must be greater than 0.')),
      );
      return;
    }

    final discountValue = double.tryParse(_discountValueController.text);
    if (discountValue == null || discountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount value must be greater than 0.')),
      );
      return;
    }

    if (_discountType == 'percent' && discountValue > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percent discount cannot exceed 80.')),
      );
      return;
    }

    final usageLimit = int.tryParse(_usageLimitController.text) ?? 1;
    final validityDays = int.tryParse(_validityDaysController.text) ?? 90;

    final tier = RewardTier(
      id: widget.initialTier?.id ?? 'tier_${DateTime.now().millisecondsSinceEpoch}',
      title: _tierNameController.text,
      minPledge: minPledge,
      discountType: _discountType,
      discountValue: discountValue,
      usageLimit: usageLimit,
      validityDays: validityDays,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    widget.onSave(tier);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              widget.initialTier == null ? 'Add Reward Tier' : 'Edit Reward Tier',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Tier Name
            TextField(
              controller: _tierNameController,
              decoration: InputDecoration(
                labelText: 'Tier name*',
                hintText: 'e.g., 10% off 1 rental',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Minimum Pledge
            TextField(
              controller: _minPledgeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum pledge (₱)*',
                hintText: 'e.g., 500',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Discount Type
            Text(
              'Discount type*',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Percent (%)'),
                    value: 'percent',
                    groupValue: _discountType,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _discountType = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Fixed (₱)'),
                    value: 'fixed',
                    groupValue: _discountType,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _discountType = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Discount Value
            TextField(
              controller: _discountValueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Discount value*',
                hintText:
                    _discountType == 'percent' ? 'e.g., 10' : 'e.g., 200',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Usage Limit
            TextField(
              controller: _usageLimitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Usage limit',
                hintText: 'e.g., 1',
                helperText: 'How many times can this reward be used?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Validity Days
            TextField(
              controller: _validityDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valid for (days)',
                hintText: 'e.g., 90',
                helperText: 'Days after tool purchase',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText:
                    'e.g., Not stackable with other discounts',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save Tier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
