import 'package:bukidbayan_app/services/language_notifier.dart';
import 'package:flutter/widgets.dart';

class AppLanguage {
  AppLanguage._();

  static bool get isTagalog => LanguageNotifier.showTl.value;

  static String text({required String en, required String tl}) {
    return isTagalog ? tl : en;
  }

  static String locationTypeLabel(String value) {
    switch (value) {
      case 'Home':
        return text(en: 'Home', tl: 'Bahay');
      case 'Farm':
        return text(en: 'Farm / Field', tl: 'Bukid / Sakahan');
      case 'Business':
        return text(en: 'Business', tl: 'Negosyo');
      case 'Current Location':
        return text(en: 'Current Location', tl: 'Kasalukuyang Lokasyon');
      default:
        return value;
    }
  }

  static String cropCategoryLabel(String value) {
    switch (value) {
      case 'Current':
        return text(en: 'Current', tl: 'Kasalukuyan');
      case 'My Farm':
        return text(en: 'My Farm', tl: 'Aking Bukid');
      case 'Wet Season':
        return text(en: 'Wet Season', tl: 'Tag-ulan');
      case 'Dry Season':
        return text(en: 'Dry Season', tl: 'Tag-init');
      case 'Year Round':
        return text(en: 'Year Round', tl: 'Buong Taon');
      default:
        return value;
    }
  }

  static String seasonLabel(String value) {
    switch (value) {
      case 'Wet Season':
        return text(en: 'Wet Season', tl: 'Tag-ulan');
      case 'Dry Season':
        return text(en: 'Dry Season', tl: 'Tag-init');
      case 'Year Round':
        return text(en: 'Year Round', tl: 'Buong Taon');
      default:
        return value;
    }
  }
}

class AppLanguageScope extends StatelessWidget {
  final WidgetBuilder builder;

  const AppLanguageScope({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageNotifier.showTl,
      builder: (context, showTl, child) => builder(context),
    );
  }
}
