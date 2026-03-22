import 'package:bukidbayan_app/models/campaign.dart';
import 'package:flutter/material.dart';

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
    _minPledgeController = TextEditingController(
      text: tier?.minPledge.toString() ?? '',
    );
    _discountValueController = TextEditingController(
      text: tier?.discountValue.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: tier?.usageLimit.toString() ?? '1',
    );
    _validityDaysController = TextEditingController(
      text: tier?.validityDays.toString() ?? '90',
    );
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
    if (_tierNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kailangan ang pangalan ng benepisyo.')),
      );
      return;
    }

    final minPledge = int.tryParse(_minPledgeController.text);
    if (minPledge == null || minPledge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ang minimum na pledge ay dapat higit sa 0.'),
        ),
      );
      return;
    }

    final discountValue = double.tryParse(_discountValueController.text);
    if (discountValue == null || discountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ang halaga ng diskuwento ay dapat higit sa 0.'),
        ),
      );
      return;
    }

    if (_discountType == 'percent' && discountValue > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hindi maaaring lumampas sa 80 ang porsyento ng diskuwento.',
          ),
        ),
      );
      return;
    }

    final usageLimit = int.tryParse(_usageLimitController.text) ?? 1;
    final validityDays = int.tryParse(_validityDaysController.text) ?? 90;

    final tier = RewardTier(
      id:
          widget.initialTier?.id ??
          'tier_${DateTime.now().millisecondsSinceEpoch}',
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
    final campaignTheme = Theme.of(context).copyWith(
      cardTheme: Theme.of(context).cardTheme.copyWith(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return Theme(
      data: campaignTheme,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initialTier == null
                  ? 'Magdagdag ng Benepisyo'
                  : 'I-edit ang Benepisyo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.28),
                ),
              ),
              child: const Text(
                'Tip: Gumamit ng malinaw na pangalan at makatotohanang minimum pledge para madaling maintindihan ng supporters.',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _tierNameController,
              decoration: InputDecoration(
                labelText: 'Pangalan ng Benepisyo*',
                hintText: 'Hal. 10% diskuwento sa isang renta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _minPledgeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum na pledge (PHP)*',
                hintText: 'Hal. 500',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Uri ng Diskuwento*',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Porsyento (%)'),
                  value: 'percent',
                  groupValue: _discountType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _discountType = value);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Nakapirming Halaga (PHP)'),
                  value: 'fixed',
                  groupValue: _discountType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _discountType = value);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _discountValueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Halaga ng Diskuwento*',
                hintText: _discountType == 'percent' ? 'Hal. 10' : 'Hal. 200',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usageLimitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Limit ng Paggamit',
                hintText: 'Hal. 1',
                helperText: 'Ilang beses puwedeng gamitin ang benepisyong ito?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _validityDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bisa ng Benepisyo (araw)',
                hintText: 'Hal. 90',
                helperText: 'Bilang ng araw matapos makuha ang benepisyo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Dagdag na Tala (opsyonal)',
                hintText: 'Hal. Hindi puwedeng pagsabayin sa ibang diskuwento',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Kanselahin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('I-save ang Benepisyo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
