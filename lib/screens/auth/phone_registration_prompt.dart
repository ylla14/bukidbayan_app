import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

/// Shows a bottom sheet prompting an existing email-based user to register
/// their phone number. The user may skip or save.
///
/// Returns true if the user saved a phone number, false if they skipped.
Future<bool> showPhoneRegistrationPrompt(
  BuildContext context,
  String uid,
  AuthService authService,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PhoneRegistrationSheet(uid: uid, authService: authService),
  );
  return result ?? false;
}

class _PhoneRegistrationSheet extends StatefulWidget {
  final String uid;
  final AuthService authService;

  const _PhoneRegistrationSheet({required this.uid, required this.authService});

  @override
  State<_PhoneRegistrationSheet> createState() => _PhoneRegistrationSheetState();
}

class _PhoneRegistrationSheetState extends State<_PhoneRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.authService.registerPhone(widget.uid, _phoneController.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnackbar(
        context: context,
        title: 'Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              'Add your phone number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: lightColorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register your phone number to get faster access. '
              'You can then log in using your phone number instead of your email.',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 24),

            // ── Phone field ───────────────────────────────────────────────
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                  return 'Enter a valid 11-digit PH number (e.g. 09123456789)';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: '09XX XXX XXXX',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
                prefixIcon: Icon(
                  Icons.phone_outlined,
                  color: lightColorScheme.primary,
                  size: 22,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black12),
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black12, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Actions ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: lightColorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 15,
                        color: lightColorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
