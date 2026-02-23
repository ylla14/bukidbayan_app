import 'package:bukidbayan_app/components/bottom_nav.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/sign_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared OTP screen for both sign-up and login.
///
/// For **sign-up**: pass [firstName], [lastName], [address], [locationType],
/// and optionally [latitude]/[longitude]. A new Firestore profile is created.
///
/// For **login**: leave all profile fields null. Firebase just signs the
/// existing user in — nothing extra is written to Firestore.
class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  // Sign-up only — null means this is a login flow
  final String? firstName;
  final String? lastName;
  final String? address;
  final String? locationType;
  final double? latitude;
  final double? longitude;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    // optional — omit for login
    this.firstName,
    this.lastName,
    this.address,
    this.locationType,
    this.latitude,
    this.longitude,
  });

  bool get _isSignUp => firstName != null;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final AuthService _authService  = AuthService();
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      showErrorSnackbar(
        context: context,
        title: 'Invalid Code',
        message: 'Please enter the 6-digit code sent to ${widget.phoneNumber}.',
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await _authService.verifyOtpAndSignUp(
        verificationId: widget.verificationId,
        smsCode:        code,
        firstName:      widget.firstName,
        lastName:       widget.lastName,
        address:        widget.address,
        locationType:   widget.locationType,
        latitude:       widget.latitude,
        longitude:      widget.longitude,
      );

      if (!mounted) return;

      if (widget._isSignUp) {
        showConfirmSnackbar(
          context: context,
          title: 'Success',
          message: 'Account created successfully!',
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BottomNav()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      showErrorSnackbar(
        context: context,
        title: 'Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sms_rounded, size: 64, color: lightColorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: lightColorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A 6-digit code was sent to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 36),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SignButton(
                buttonText: _isVerifying
                    ? 'Verifying…'
                    : widget._isSignUp
                        ? 'Verify & Create Account'
                        : 'Verify & Sign In',
                onPressed: _isVerifying ? null : _verify,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Go Back & Resend'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}