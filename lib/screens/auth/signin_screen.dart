import 'package:bukidbayan_app/components/bottom_nav.dart';
import 'package:bukidbayan_app/widgets/sign_button.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/dashboard/home_screen.dart';

import 'package:bukidbayan_app/screens/auth/signup_screen.dart';
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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberPassword = true;
  bool _isPasswordHidden = true;
  bool _isSigningIn = false;


  

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Center(
        child: Padding(
          // margin: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          padding: EdgeInsets.fromLTRB(30.0, 0.0, 30.0, 20.0),
          // decoration: BoxDecoration(
          //   color: Colors.white,
          //   borderRadius: BorderRadius.all(Radius.circular(20)),
          // ),

          child: Form(
            key: _formSignInKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 30.0,
                    color: lightColorScheme.primary,
                  ),
                ),

                SizedBox(height: 40),

                TextFormField(
                  controller: emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please Enter Email';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    label: const Text('Email'),
                    hintText: 'Enter Email',
                    hintStyle: TextStyle(color: Colors.black26),

                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                SizedBox(height: 30),

                TextFormField(
                  controller: passwordController,
                  obscureText: _isPasswordHidden,
                  obscuringCharacter: '*',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please Enter Password!';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    label: const Text('Password'),
                    hintText: 'Enter Password',
                    hintStyle: const TextStyle(color: Colors.black26),

                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: Icon(
                          _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black45,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordHidden = !_isPasswordHidden;
                          });
                        },
                      ),
                    ),

                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),


                SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: rememberPassword,
                          onChanged: (bool? value) {
                            setState(() {
                              rememberPassword = value!;
                            });
                          },
                          activeColor: lightColorScheme.primary,
                        ),
                        const Text(
                          'Remember me',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ],
                    ),
                    GestureDetector(
                      child: Text(
                        'Forget password?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25.0),

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

                SignButton(
                  buttonText: _isSigningIn ? 'Signing In...' : 'Sign In',
                  onPressed: _isSigningIn
                      ? null
                      : () async {
                          if (!_formSignInKey.currentState!.validate()) return;

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
                            var user = await authService.login(
                              emailController.text,
                              passwordController.text,
                            );

                            if (!mounted) return;

                            if (user != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => BottomNav()),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            showErrorSnackbar(
                              context: context,
                              title: 'Error',
                              message: e.toString().replaceAll('Exception: ', ''),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isSigningIn = false);
                            }
                          }
                        },
                ),


                const SizedBox(height: 25.0),

                // don't have an account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Don\'t have an account? ',
                      style: TextStyle(color: Colors.black45),
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
                          fontWeight: FontWeight.bold,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20.0),
              ],
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