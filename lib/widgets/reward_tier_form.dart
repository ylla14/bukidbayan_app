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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tierNameController;
  late TextEditingController _minPledgeController;
  late TextEditingController _discountValueController;
  late TextEditingController _usageLimitController;
  late TextEditingController _validityDaysController;
  late TextEditingController _notesController;

  late String _discountType;
  bool _showValidation = false;

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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      alignLabelWithHint: true,
    );
  }

  String? _validateRequiredText(String? value, String message) {
    if ((value ?? '').trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _validateMinPledge(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ilagay ang minimum na pledge.';
    }

    final minPledge = int.tryParse(value!.trim());
    if (minPledge == null || minPledge <= 0) {
      return 'Ang minimum na pledge ay dapat higit sa 0.';
    }

    return null;
  }

  String? _validateDiscountValue(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ilagay ang halaga ng diskuwento.';
    }

    final discountValue = double.tryParse(value!.trim());
    if (discountValue == null || discountValue <= 0) {
      return 'Ang halaga ng diskuwento ay dapat higit sa 0.';
    }

    if (_discountType == 'percent' && discountValue > 80) {
      return 'Hindi maaaring lumampas sa 80 ang porsyento ng diskuwento.';
    }

    return null;
  }

  String? _validateOptionalPositiveNumber(String? value, String label) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return '$label ay dapat higit sa 0.';
    }

    return null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _showValidation = true);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final minPledge = int.parse(_minPledgeController.text.trim());
    final discountValue = double.parse(_discountValueController.text.trim());
    final usageLimit = int.tryParse(_usageLimitController.text.trim()) ?? 1;
    final validityDays =
        int.tryParse(_validityDaysController.text.trim()) ?? 90;

    final tier = RewardTier(
      id:
          widget.initialTier?.id ??
          'tier_${DateTime.now().millisecondsSinceEpoch}',
      title: _tierNameController.text.trim(),
      minPledge: minPledge,
      discountType: _discountType,
      discountValue: discountValue,
      usageLimit: usageLimit,
      validityDays: validityDays,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
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
    final isEditing = widget.initialTier != null;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outlineColor = primaryColor.withValues(alpha: 0.24);

    return Theme(
      data: campaignTheme,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form(
              key: _formKey,
              autovalidateMode: _showValidation
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditing
                        ? 'I-edit ang Benepisyo'
                        : 'Magdagdag ng Benepisyo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing
                        ? 'Ayusin ang detalye para malinaw pa rin sa supporters ang matatanggap nila.'
                        : 'Ilagay ang benepisyo na makikita ng supporters kapag pumili sila ng pledge.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineColor),
                    ),
                    child: const Text(
                      'Tip: Gumamit ng malinaw na pangalan at makatotohanang minimum pledge para madaling maintindihan ng supporters.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _tierNameController,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _validateRequiredText(
                      value,
                      'Kailangan ang pangalan ng benepisyo.',
                    ),
                    decoration: _inputDecoration(
                      label: 'Pangalan ng Benepisyo*',
                      hint: 'Hal. 10% diskuwento sa isang renta',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minPledgeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: _validateMinPledge,
                    decoration: _inputDecoration(
                      label: 'Minimum na pledge (PHP)*',
                      hint: 'Hal. 500',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Uri ng Diskuwento*',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineColor),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Porsyento (%)'),
                          value: 'percent',
                          groupValue: _discountType,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _discountType = value);
                            if (_showValidation) {
                              _formKey.currentState?.validate();
                            }
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        RadioListTile<String>(
                          title: const Text('Nakapirming Halaga (PHP)'),
                          value: 'fixed',
                          groupValue: _discountType,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _discountType = value);
                            if (_showValidation) {
                              _formKey.currentState?.validate();
                            }
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _discountValueController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: _validateDiscountValue,
                    decoration: _inputDecoration(
                      label: 'Halaga ng Diskuwento*',
                      hint: _discountType == 'percent' ? 'Hal. 10' : 'Hal. 200',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usageLimitController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _validateOptionalPositiveNumber(
                      value,
                      'Ang limit ng paggamit',
                    ),
                    decoration: _inputDecoration(
                      label: 'Limit ng Paggamit',
                      hint: 'Hal. 1',
                      helperText:
                          'Ilang beses puwedeng gamitin ang benepisyong ito?',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _validityDaysController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _validateOptionalPositiveNumber(
                      value,
                      'Ang bisa ng benepisyo',
                    ),
                    decoration: _inputDecoration(
                      label: 'Bisa ng Benepisyo (araw)',
                      hint: 'Hal. 90',
                      helperText: 'Bilang ng araw matapos makuha ang benepisyo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: _inputDecoration(
                      label: 'Dagdag na Tala (opsyonal)',
                      hint:
                          'Hal. Hindi puwedeng pagsabayin sa ibang diskuwento',
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;
                      final closeButton = SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Isara',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                      final saveButton = SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isEditing
                                ? 'I-update ang Benepisyo'
                                : 'I-save ang Benepisyo',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                          ),
                        ),
                      );

                      if (isCompact) {
                        return Column(
                          children: [
                            closeButton,
                            const SizedBox(height: 12),
                            saveButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: closeButton),
                          const SizedBox(width: 12),
                          Expanded(child: saveButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
