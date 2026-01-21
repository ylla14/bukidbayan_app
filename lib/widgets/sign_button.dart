import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class SignButton extends StatelessWidget {
  const SignButton({
    super.key,
    required this.buttonText,
    this.onPressed,
  });

  final String buttonText;
  final Future<void> Function()? onPressed; // ✅ async-safe

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
        ),
        onPressed: onPressed == null
            ? null
            : () {
                onPressed!(); // execute async callback
              },
        child: Text(buttonText),
      ),
    );
  }
}
