import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';

class UserInfoStep extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController addressController;

  const UserInfoStep({
    super.key,
    required this.nameController,
    required this.addressController,
  });

  @override
  State<UserInfoStep> createState() => _UserInfoStepState();
}

class _UserInfoStepState extends State<UserInfoStep> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = _authService.currentUser;
    if (user != null) {
      // Prefer Firestore stored name if available
      final userData = await _authService.getUserData(user.uid);
      final name = userData != null
          ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
          : user.displayName ?? '';
      widget.nameController.text = name;
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomDivider(),
        const StepHeader(
          title: 'Step 2: Impormasyon ng Umuupa',
          subtitle: 'Ilagay ang buong pangalan at address.',
        ),
        CustomTextFormField(controller: widget.nameController, hint: 'Buong Pangalan'),
        const SizedBox(height: 12),
        CustomTextFormField(controller: widget.addressController, hint: 'Address', maxLines: 3),
      ],
    );
  }
}
