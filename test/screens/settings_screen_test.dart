import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/screens/settings/settings_screen.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Other Channel',
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<BackupService> _backupService() async {
  final prefs = await SharedPreferences.getInstance();
  return BackupService(
    ChannelStorage(prefs),
    SettingsStorage(prefs),
    FieldSettingsStorage(prefs),
  );
}

void main() {
  testWidgets('tapping Theme opens the theme dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
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

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('Start screen tile shows Channel list by default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [_channel, _otherChannel],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );

    expect(find.text('Start screen'), findsOneWidget);
    expect(find.text('Channel list'), findsOneWidget);
  });

  testWidgets('Start screen dialog lists saved channels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [_channel, _otherChannel],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
    await tester.tap(find.text('Start screen'));
    await tester.pumpAndSettle();

    expect(find.text('Choose start screen'), findsOneWidget);
    expect(find.text('My Channel'), findsOneWidget);
    expect(find.text('Other Channel'), findsOneWidget);
  });

  testWidgets('selecting UTC offset calls setTimezoneDisplay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );
    expect(settings.timezoneDisplay, TimezoneDisplay.off);

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Timezone display'),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Timezone display'));
    await tester.pumpAndSettle();

    expect(find.text('Choose timezone display'), findsOneWidget);

    await tester.tap(find.text('UTC offset'));
    await tester.pumpAndSettle();

    expect(settings.timezoneDisplay, TimezoneDisplay.offset);
  });

  testWidgets('shows a Source code tile in the Info section', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Source code'),
      100,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Source code'), findsOneWidget);
  });

  testWidgets('selecting a channel calls setStartChannel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsNotifier(
      SettingsStorage(await SharedPreferences.getInstance()),
    );

    await tester.pumpWidget(
      _wrap(
        SettingsScreen(
          settings: settings,
          channels: const [_channel, _otherChannel],
          backupService: await _backupService(),
          onImported: () {},
        ),
      ),
    );
    await tester.tap(find.text('Start screen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Channel'));
    await tester.pumpAndSettle();

    expect(settings.startChannel([_channel, _otherChannel]), _channel);
  });

  group('Backup section', () {
    testWidgets('renders a section header and both tiles', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            backupService: await _backupService(),
            onImported: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Backup'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Import'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('Export tile warns that API keys are included', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            backupService: await _backupService(),
            onImported: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Export'),
        100,
        scrollable: find.byType(Scrollable),
      );

      expect(
        find.text(
          'Includes API keys for private channels. Store the file securely!',
        ),
        findsOneWidget,
      );
    });
  });
}
