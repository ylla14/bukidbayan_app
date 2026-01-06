import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class WelcomeButton extends StatelessWidget {
  const WelcomeButton({super.key, this.buttonText, this.onTap});

  final String? buttonText;
  final Widget? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (e)=> onTap!));
      },
      child: Container(
        padding: EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          color: lightColorScheme.primary,
          border: Border.all(width: 0.5, color: Colors.black)
        ),
        child: Text(buttonText!,
        textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        )
      ),
    );
  }
}