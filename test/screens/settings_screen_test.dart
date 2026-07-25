import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/screens/settings/settings_screen.dart';
import 'package:thingviewer/storage/settings_storage.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('tapping Theme opens the theme dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(_wrap(SettingsScreen(settings: settings)));
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Choose theme'), findsOneWidget);
  });

  testWidgets('selecting Dark calls setThemeMode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );
    expect(settings.themeMode, ThemeMode.system);

    await tester.pumpWidget(_wrap(SettingsScreen(settings: settings)));
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });
}
