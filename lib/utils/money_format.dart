String formatPeso(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '${negative ? '-' : ''}₱${buf.toString()}';
}
