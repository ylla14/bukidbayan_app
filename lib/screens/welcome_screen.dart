import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/screens/auth/signup_screen.dart';
import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
import 'package:bukidbayan_app/widgets/welcome_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── Logo / Icon ───────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: lightColorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_city_rounded,
                    size: 52,
                    color: lightColorScheme.primary,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Heading ───────────────────────────────────────────────
                Text(
                  'Welcome to\nBukidbayan!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36.0,
                    fontWeight: FontWeight.w700,
                    color: lightColorScheme.primary,
                    height: 1.25,
                    letterSpacing: 0.2,
                  ),
                ),

                // TextSpan(
                //   text: '\n Enter Personal Details',
                //   style: TextStyle(
                //     fontSize: 20.0,
                //     fontWeight: FontWeight.w400,
                //   ),
                // ),

                const SizedBox(height: 16),

                Text(
                  'Para sa mas magandang ani.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17.0,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 56),

                // ── Sign In Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      );
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Sign Up Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lightColorScheme.primary,
                      side: BorderSide(color: lightColorScheme.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Footer note ───────────────────────────────────────────
                // Text(
                //   'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                //   textAlign: TextAlign.center,
                //   style: const TextStyle(
                //     fontSize: 13,
                //     color: Colors.black38,
                //     height: 1.6,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}