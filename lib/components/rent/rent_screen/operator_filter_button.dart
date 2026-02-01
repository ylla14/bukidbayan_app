import 'package:flutter/material.dart';

class OperatorFilterButton extends StatelessWidget {
  final bool? isActive;
  final VoidCallback onPressed;

  const OperatorFilterButton({
    super.key,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive == true ? Colors.blue.shade100 : null,
        side: BorderSide(
          color: isActive == true ? Colors.blue : Colors.grey,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(
        Icons.person,
        size: 18,
        color: isActive == true ? Colors.blue.shade900 : Colors.black,
      ),
      label: Text(
        'With Operator',
        style: TextStyle(
          color: isActive == true ? Colors.blue.shade900 : Colors.black,
          fontWeight: isActive == true ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}