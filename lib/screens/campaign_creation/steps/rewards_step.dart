import 'package:flutter/material.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';

class RewardsStep extends StatefulWidget {
  final Function(List<RewardTier>) onRewardsChanged;
  final List<RewardTier> initialRewards;

  const RewardsStep({
    super.key,
    required this.onRewardsChanged,
    required this.initialRewards,
  });

  @override
  State<RewardsStep> createState() => _RewardsStepState();
}

class _RewardsStepState extends State<RewardsStep> {
  late List<RewardTier> _rewards;
  late TextEditingController _titleController;
  late TextEditingController _minPledgeController;
  late TextEditingController _discountValueController;
  late TextEditingController _usageLimitController;
  late TextEditingController _validityDaysController;
  late TextEditingController _notesController;

  String _discountType = 'percent'; // "percent" or "fixed"
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _rewards = List.from(widget.initialRewards);
    _titleController = TextEditingController();
    _minPledgeController = TextEditingController();
    _discountValueController = TextEditingController();
    _usageLimitController = TextEditingController();
    _validityDaysController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minPledgeController.dispose();
    _discountValueController.dispose();
    _usageLimitController.dispose();
    _validityDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _titleController.clear();
    _minPledgeController.clear();
    _discountValueController.clear();
    _usageLimitController.clear();
    _validityDaysController.clear();
    _notesController.clear();
    _discountType = 'percent';
    _editingIndex = null;
  }

  void _addOrUpdateReward() {
    if (_titleController.text.isEmpty ||
        _minPledgeController.text.isEmpty ||
        _discountValueController.text.isEmpty ||
        _usageLimitController.text.isEmpty ||
        _validityDaysController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final newReward = RewardTier(
      id: _editingIndex != null
          ? _rewards[_editingIndex!].id
          : 'r${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text,
      minPledge: int.parse(_minPledgeController.text),
      discountType: _discountType,
      discountValue: double.parse(_discountValueController.text),
      usageLimit: int.parse(_usageLimitController.text),
      validityDays: int.parse(_validityDaysController.text),
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    setState(() {
      if (_editingIndex != null) {
        _rewards[_editingIndex!] = newReward;
        _editingIndex = null;
      } else {
        _rewards.add(newReward);
      }
    });

    widget.onRewardsChanged(_rewards);
    _clearForm();
  }

  void _editReward(int index) {
    final reward = _rewards[index];
    _titleController.text = reward.title;
    _minPledgeController.text = reward.minPledge.toString();
    _discountValueController.text = reward.discountValue.toString();
    _usageLimitController.text = reward.usageLimit.toString();
    _validityDaysController.text = reward.validityDays.toString();
    _notesController.text = reward.notes ?? '';
    _discountType = reward.discountType;
    _editingIndex = index;
    setState(() {});
  }

  void _deleteReward(int index) {
    setState(() => _rewards.removeAt(index));
    widget.onRewardsChanged(_rewards);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Add Reward Tiers',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: 'Reward title (e.g., Early Bird)',
            controller: _titleController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: 'Minimum pledge amount (PHP)',
            controller: _minPledgeController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _discountType,
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Percentage')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                  ],
                  onChanged: (value) {
                    setState(() => _discountType = value ?? 'percent');
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextFormField(
                  hint: _discountType == 'percent' ? 'e.g., 10' : 'e.g., 5000',
                  controller: _discountValueController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: 'Usage limit (times)',
            controller: _usageLimitController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: 'Validity period (days)',
            controller: _validityDaysController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          CustomTextFormField(
            hint: 'Notes (optional)',
            controller: _notesController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addOrUpdateReward,
              child: Text(_editingIndex != null ? 'Update Reward' : 'Add Reward'),
            ),
          ),
          if (_editingIndex != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _clearForm();
                    setState(() {});
                  },
                  child: const Text('Cancel Editing'),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Rewards Added',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_rewards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No rewards added yet. Add at least one reward tier.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rewards.length,
              itemBuilder: (context, index) {
                final reward = _rewards[index];
                final discountDisplay = reward.discountType == 'percent'
                    ? '${reward.discountValue.toStringAsFixed(0)}% off'
                    : '${formatPeso(reward.discountValue.toInt())} off';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reward.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Min pledge: ${formatPeso(reward.minPledge)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editReward(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteReward(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discount: $discountDisplay • Usage limit: ${reward.usageLimit}x • Valid for ${reward.validityDays} days',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (reward.notes != null && reward.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${reward.notes}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
