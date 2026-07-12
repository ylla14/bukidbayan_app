import 'package:bukidbayan_app/services/app_language.dart';
import 'package:bukidbayan_app/services/language_notifier.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Future<void> Function() onLogout;

  const CustomDrawer({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: lightColorScheme.onPrimary,
      surfaceTintColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(30),
        children: [
          // ── Language toggle ────────────────────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: LanguageNotifier.showTl,
            builder: (_, showTl, _) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLanguage.text(en: 'Language', tl: 'Wika')),
                subtitle: Text(
                  showTl
                      ? AppLanguage.text(en: 'Tagalog', tl: 'Tagalog')
                      : AppLanguage.text(en: 'English', tl: 'English'),
                  style: TextStyle(
                    fontSize: 12,
                    color: lightColorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: ToggleButtons(
                  isSelected: [!showTl, showTl],
                  onPressed: (i) => LanguageNotifier.showTl.value = i == 1,
                  borderRadius: BorderRadius.circular(6),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 32,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  children: const [Text('EN'), Text('TL')],
                ),
              );
            },
          ),

          const Divider(),

          // ── Logout ─────────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              AppLanguage.text(en: 'Logout', tl: 'Mag-logout'),
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await onLogout();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
