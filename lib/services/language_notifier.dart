import 'package:flutter/foundation.dart';

/// Global language preference.
/// `showTl == false` → display English (default).
/// `showTl == true`  → display Tagalog.
class LanguageNotifier {
  LanguageNotifier._();
  static final ValueNotifier<bool> showTl = ValueNotifier<bool>(false);
}
