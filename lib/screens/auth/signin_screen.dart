import 'package:bukidbayan_app/components/bottom_nav.dart';
import 'package:bukidbayan_app/widgets/sign_button.dart';
import 'package:flutter/material.dart';

import 'package:bukidbayan_app/screens/auth/signup_screen.dart';
import 'package:bukidbayan_app/screens/auth/phone_registration_prompt.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formSignInKey = GlobalKey<FormState>();
  final AuthService authService = AuthService();
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberPassword = true;
  bool _isPasswordHidden = true;
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 24.0,
            ),
            child: Form(
              key: _formSignInKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── App Icon / Logo Area ──────────────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: lightColorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 44,
                      color: lightColorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Heading ───────────────────────────────────────────────
                  Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 32.0,
                      color: lightColorScheme.primary,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17.0,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Identifier Field ──────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email or Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: identifierController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(fontSize: 17),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email or phone number';
                      }
                      if (!AuthService.isValidIdentifier(value)) {
                        return 'Enter a valid email or 11-digit phone number';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Email or 09XX XXX XXXX',
                      hintStyle: const TextStyle(
                        color: Colors.black38,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.contact_phone_outlined,
                        color: lightColorScheme.primary,
                        size: 24,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.black12,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: lightColorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Password Field ────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    obscureText: _isPasswordHidden,
                    obscuringCharacter: '*',
                    style: const TextStyle(fontSize: 17),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: const TextStyle(
                        color: Colors.black38,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        color: lightColorScheme.primary,
                        size: 24,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: IconButton(
                          iconSize: 26,
                          icon: Icon(
                            _isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black45,
                          ),
                          tooltip: _isPasswordHidden
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _isPasswordHidden = !_isPasswordHidden;
                            });
                          },
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.black12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.black12,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: lightColorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Remember Me + Forgot Password ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: rememberPassword,
                              onChanged: (bool? value) {
                                setState(() {
                                  rememberPassword = value!;
                                });
                              },
                              activeColor: lightColorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 2,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: lightColorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30.0),

                  // ── Commented original ElevatedButton (kept as-is) ────────
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton(
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: lightColorScheme.primary,
                  //       foregroundColor: lightColorScheme.onPrimary
                  //     ),
                  //     child: const Text('Sign In'),
                  //     onPressed: () async{
                  //       if (_formSignInKey.currentState!.validate() &&
                  //           rememberPassword) {
                  //         bool success = await authService.login(emailController.text, passwordController.text);

                  //         if(success){
                  //           // showConfirmSnackbar(context: context, title: 'Welcome', message: 'Logging In');
                  //           Navigator.pushReplacement(context, MaterialPageRoute(builder: (e) => HomeScreen()));
                  //         } else {
                  //             showErrorSnackbar(context: context, title: 'Error', message: 'Invalid Credentials');
                  //         }
                  //       } else if (!rememberPassword) {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           const SnackBar(
                  //             content: Text(
                  //               'Please agree to the processing of personal data',
                  //             ),
                  //           ),
                  //         );
                  //       }
                  //     },
                  //   ),
                  // ),

                  // ── Sign In Button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: SignButton(
                      buttonText: _isSigningIn ? 'Signing In...' : 'Sign In',
                      onPressed: _isSigningIn
                          ? null
                          : () async {
                              if (!_formSignInKey.currentState!.validate()) {
                                return;
                              }

                              if (!rememberPassword) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please agree to the processing of personal data',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() => _isSigningIn = true);

                              try {
                                final identifier = identifierController.text;

                                final user = await authService.login(
                                  identifier,
                                  passwordController.text,
                                );

                                if (!mounted) return;

                                if (user != null) {
                                  final isCoop = await authService
                                      .isCoopAccount(user.uid);

                                  if (!mounted) return;

                                  if (isCoop) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CoopBottomNav(),
                                      ),
                                    );
                                    return;
                                  }

                                  // Prosumer flow: prompt for phone if missing
                                  final userData = await authService
                                      .ensureUserDocument(user);
                                  final hasPhone =
                                      (userData['phoneNumber'] as String?)
                                          ?.isNotEmpty ==
                                      true;
                                  final isPhoneUser =
                                      userData['isPhoneUser'] == true;

                                  if (!mounted) return;
                                  if (!hasPhone && !isPhoneUser) {
                                    await showPhoneRegistrationPrompt(
                                      context,
                                      user.uid,
                                      authService,
                                    );
                                  }

                                  if (!mounted) return;
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BottomNav(),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;

                                showErrorSnackbar(
                                  context: context,
                                  title: 'Error',
                                  message: e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSigningIn = false);
                                }
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // ── Divider ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.black12, thickness: 1.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'New here?',
                          style: TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.black12, thickness: 1.2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20.0),

                  // ── Sign Up Link ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (e) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: lightColorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: lightColorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// //import 'package:bukidbayan_app/widgets/sign_button.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import 'package:bukidbayan_app/screens/auth/signup_screen.dart';
// import 'package:bukidbayan_app/screens/auth/otp_screen.dart';
// import 'package:bukidbayan_app/services/auth_services.dart';
// import 'package:bukidbayan_app/theme/theme.dart';
// import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
// import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

// class SignInScreen extends StatefulWidget {
//   const SignInScreen({super.key});

//   @override
//   State<SignInScreen> createState() => _SignInScreenState();
// }

// class _SignInScreenState extends State<SignInScreen> {
//   final _formKey        = GlobalKey<FormState>();
//   final AuthService     _authService = AuthService();
//   final _phoneController = TextEditingController();

//   static const String _countryCode = '+63';

//   bool _isSendingOtp = false;

//   @override
//   void dispose() {
//     _phoneController.dispose();
//     super.dispose();
//   }

//   Future<void> _onSignIn() async {
//     if (!_formKey.currentState!.validate()) return;

//     final rawPhone   = _phoneController.text.trim();
//     final normalised = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
//     final fullPhone  = '$_countryCode$normalised';

//     setState(() => _isSendingOtp = true);

//     await _authService.sendOtp(
//       phoneNumber: fullPhone,
//       onCodeSent: (verificationId) {
//         if (!mounted) return;
//         setState(() => _isSendingOtp = false);
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => OtpScreen(
//               verificationId: verificationId,
//               phoneNumber:    fullPhone,
//             ),
//           ),
//         );
//       },
//       onError: (error) {
//         if (!mounted) return;
//         setState(() => _isSendingOtp = false);
//         showErrorSnackbar(context: context, title: 'Error', message: error);
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CustomScaffold(
//       child: Center(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(30.0, 0.0, 30.0, 20.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text(
//                   'Welcome Back!',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 30.0,
//                     color: lightColorScheme.primary,
//                   ),
//                 ),

//                 const SizedBox(height: 12),

//                 Text(
//                   'Enter your phone number to receive an OTP.',
//                   style: TextStyle(color: Colors.black45, fontSize: 13),
//                   textAlign: TextAlign.center,
//                 ),

//                 const SizedBox(height: 40),

//                 // ── Phone Number ────────────────────────────────────────────
//                 TextFormField(
//                   controller: _phoneController,
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   validator: (v) {
//                     if (v == null || v.isEmpty) return 'Please enter your phone number';
//                     final stripped = v.startsWith('0') ? v.substring(1) : v;
//                     if (stripped.length != 9 && stripped.length != 10) {
//                       return 'Enter a valid PH mobile number';
//                     }
//                     return null;
//                   },
//                   decoration: InputDecoration(
//                     label: const Text('Phone Number'),
//                     hintText: '09XX XXX XXXX',
//                     hintStyle: const TextStyle(color: Colors.black26),
//                     prefixIcon: Container(
//                       margin: const EdgeInsets.only(right: 8),
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
//                       decoration: const BoxDecoration(
//                         border: Border(right: BorderSide(color: Colors.black12)),
//                       ),
//                       child: Text(
//                         _countryCode,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ),
//                     border: OutlineInputBorder(
//                       borderSide: const BorderSide(color: Colors.black12),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderSide: const BorderSide(color: Colors.black12),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 30),

//                 SignButton(
//                   buttonText: _isSendingOtp ? 'Sending OTP…' : 'Sign In',
//                   onPressed: _isSendingOtp ? null : _onSignIn,
//                 ),

//                 const SizedBox(height: 25.0),

//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text(
//                       'Don\'t have an account? ',
//                       style: TextStyle(color: Colors.black45),
//                     ),
//                     GestureDetector(
//                       onTap: () => Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (_) => const SignUpScreen()),
//                       ),
//                       child: Text(
//                         'Sign Up',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: lightColorScheme.primary,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 20.0),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
