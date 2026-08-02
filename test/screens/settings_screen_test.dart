import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/screens/settings/settings_screen.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'channel_detail_notifier_test.mocks.dart';

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
  theme: AppTheme.light,
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
    PinnedFieldsStorage(prefs),
  );
}

Future<PinnedFieldsStorage> _pinnedFieldsStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return PinnedFieldsStorage(prefs);
}

// file_picker's static API delegates to FilePickerPlatform.instance, a
// swappable federated-plugin singleton — this fake lets tests drive the
// import/export flows without a real OS file dialog.
class _FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  FilePickerResult? pickResult;
  String? savePath;
  Object? error;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (error != null) throw error!;
    return pickResult;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    if (error != null) throw error!;
    return savePath;
  }
}

Uint8List _backupBytes(List<Channel> channels) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'app': 'thingviewer',
      'version': 1,
      'channels': channels.map((c) => c.toJson()).toList(),
    }),
  ),
);

void main() {
  final mockApi = MockThingSpeakApi();

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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
          api: mockApi,
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
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

      await tester.scrollUntilVisible(
        find.text('Export'),
        100,
        scrollable: find.byType(Scrollable),
      );
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
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
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

  group('Import/export with a faked file picker', () {
    late _FakeFilePickerPlatform fakePicker;

    setUp(() {
      fakePicker = _FakeFilePickerPlatform();
      FilePickerPlatform.instance = fakePicker;
    });

    testWidgets(
      'Import stays disabled until a mode is picked, then addChannels merges',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        await channelStorage.saveChannels([_channel]);
        final settings = SettingsNotifier(SettingsStorage(prefs));
        fakePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'backup.json',
            size: 0,
            bytes: _backupBytes([_otherChannel]),
          ),
        ]);

        await tester.pumpWidget(
          _wrap(
            SettingsScreen(
              settings: settings,
              channels: const [_channel],
              api: mockApi,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              backupService: BackupService(
                channelStorage,
                SettingsStorage(prefs),
                FieldSettingsStorage(prefs),
                PinnedFieldsStorage(prefs),
              ),
              onImported: () {},
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Import'),
          100,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();

        expect(find.text('Import backup'), findsOneWidget);
        final confirmButton = find.widgetWithText(TextButton, 'Import');
        expect(tester.widget<TextButton>(confirmButton).onPressed, isNull);

        await tester.tap(find.text('Add channels only'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(confirmButton).onPressed, isNotNull);

        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(find.text('Backup imported'), findsOneWidget);
        expect(channelStorage.loadChannels(), [_channel, _otherChannel]);
      },
    );

    testWidgets('replace mode overwrites the existing saved channels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel]);
      final settings = SettingsNotifier(SettingsStorage(prefs));
      fakePicker.pickResult = FilePickerResult([
        PlatformFile(
          name: 'backup.json',
          size: 0,
          bytes: _backupBytes([_otherChannel]),
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [_channel],
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
            backupService: BackupService(
              channelStorage,
              SettingsStorage(prefs),
              FieldSettingsStorage(prefs),
              PinnedFieldsStorage(prefs),
            ),
            onImported: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Import'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Replace everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Import'));
      await tester.pumpAndSettle();

      expect(channelStorage.loadChannels(), [_otherChannel]);
    });

    testWidgets('a malformed backup file shows an error and no dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );
      fakePicker.pickResult = FilePickerResult([
        PlatformFile(
          name: 'backup.json',
          size: 0,
          bytes: Uint8List.fromList(utf8.encode('not json')),
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
            backupService: await _backupService(),
            onImported: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Import'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(
        find.text('This backup file is corrupted or unreadable.'),
        findsOneWidget,
      );
      expect(find.text('Import backup'), findsNothing);
    });

    testWidgets('Export shows a success snackbar once a save path is chosen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );
      fakePicker.savePath = '/tmp/backup.json';

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('Backup saved'), findsOneWidget);
    });

    testWidgets('Export shows nothing when the save dialog is cancelled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );
      fakePicker.savePath = null;

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('Backup saved'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Export shows an error snackbar when the picker throws', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsNotifier(
        SettingsStorage(await SharedPreferences.getInstance()),
      );
      fakePicker.error = PlatformException(code: 'ENTITLEMENT_REQUIRED_WRITE');

      await tester.pumpWidget(
        _wrap(
          SettingsScreen(
            settings: settings,
            channels: const [],
            api: mockApi,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
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
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't open the file picker."), findsOneWidget);
    });

    testWidgets(
      'Import shows an error snackbar and no dialog when the picker throws',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsNotifier(
          SettingsStorage(await SharedPreferences.getInstance()),
        );
        fakePicker.error = PlatformException(code: 'ENTITLEMENT_NOT_FOUND');

        await tester.pumpWidget(
          _wrap(
            SettingsScreen(
              settings: settings,
              channels: const [],
              api: mockApi,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              backupService: await _backupService(),
              onImported: () {},
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Import'),
          100,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();

        expect(find.text("Couldn't open the file picker."), findsOneWidget);
        expect(find.text('Import backup'), findsNothing);
      },
    );
  });
}
