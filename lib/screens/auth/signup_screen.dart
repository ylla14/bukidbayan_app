
import 'package:bukidbayan_app/widgets/sign_button.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignInKey = GlobalKey<FormState>();
  bool rememberPassword = true;
  final AuthService authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isSigningUp = false;


  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

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
                  'Welcome!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 30.0,
                    color: lightColorScheme.primary,
                  ),
                ),

                SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: firstNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please Enter First Name';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          label: const Text('First Name'),
                          hintText: 'Enter First Name',
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
                    ),
                    SizedBox(width: 10), // space between fields
                    Expanded(
                      child: TextFormField(
                        controller: lastNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please Enter Last Name';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          label: const Text('Last Name'),
                          hintText: 'Enter Last Name',
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
                    ),
                  ],
                ),

                SizedBox(height: 25),

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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        hintStyle: TextStyle(color: Colors.black26),

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
                          borderSide: BorderSide(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                    
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Text(
                      '• Minimum of 6 characters\n'
                      '• Avoid common passwords (e.g. "123456", "password", birthdays, etc..)',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 25),

                SignButton(
                  buttonText: _isSigningUp ? 'Signing Up' : 'Sign Up',
                  onPressed: _isSigningUp
                  ? null
                  :() async {
                      if (_formSignInKey.currentState!.validate()) {

                        setState(() => _isSigningUp = true);

                        try {
                          await authService.signUp(emailController.text, passwordController.text, firstNameController.text, lastNameController.text);
                          if (!mounted) return;
                          showConfirmSnackbar(context: context, title: 'Success', message: 'Account Created Successfully!');
                          // Navigate to sign in screen after successful signup
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (e) => const SignInScreen()),
                          );
                         } catch (e){
                          if (mounted) {
                              setState(() => _isSigningUp = false);
                            }
                          showErrorSnackbar(context: context, title: 'Error', message: e.toString().replaceAll('Exception: ', ''));
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
                      'Already have an account? ',
                      style: TextStyle(color: Colors.black45),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (e) => const SignInScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign In',
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


