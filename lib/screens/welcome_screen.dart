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
      child: Column(
        children: [
          Flexible(
            flex: 8,
            child: Container(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: 0,
                horizontal: 40,
              ),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text:  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome Back!\n',
                        style: TextStyle(
                          fontSize: 45.0,
                          fontWeight: FontWeight.w600,
                          color: lightColorScheme.primary,
                        ),
                      ),
                      // TextSpan(
                      //   text: '\n Enter Personal Details',
                      //   style: TextStyle(
                      //     fontSize: 20.0,
                      //     fontWeight: FontWeight.w400,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(child: WelcomeButton(
                    buttonText: 'Sign In',
                    onTap: SignInScreen(),
                  )),
                  Expanded(child: WelcomeButton(
                    buttonText: 'Sign Up',
                    onTap: SignUpScreen(),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
