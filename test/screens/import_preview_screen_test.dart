import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/backup/import_plan.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/screens/import_preview/import_preview_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

const _existingChannel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

const _updatedChannel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel Renamed',
);

const _newChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'New Channel',
);

const _pin = PinnedField(
  serverUrl: 'https://api.thingspeak.com',
  channelId: 1,
  fieldId: 1,
);

const _chartKey = 'https://api.thingspeak.com|1|1';

ImportPlan _plan() => ImportPlan(
  contents: const BackupContents(channels: [_updatedChannel, _newChannel]),
  channels: [
    ChannelDiff(
      incoming: _updatedChannel,
      existing: _existingChannel,
      change: ChannelChange.updated,
      changes: const {ChannelFieldChange.name},
      needsApiKey: false,
      chartSettingKeys: const [_chartKey],
      pinnedFields: const [_pin],
    ),
    const ChannelDiff(
      incoming: _newChannel,
      existing: null,
      change: ChannelChange.added,
      changes: {},
      needsApiKey: false,
      chartSettingKeys: [],
      pinnedFields: [],
    ),
  ],
  settings: const [],
  orphanChartSettingKeys: const [],
  orphanPinnedFields: const [],
  onlyOnDevice: const [],
);

Future<SettingsNotifier> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsNotifier(SettingsStorage(prefs));
}

/// Pushes [ImportPreviewScreen] from a host screen so the test can observe
/// the [ImportSelection] (or `null`) it pops with.
class _Host extends StatefulWidget {
  final ImportPlan plan;
  final SettingsNotifier settings;
  final ValueChanged<ImportSelection?> onResult;

  const _Host({
    required this.plan,
    required this.settings,
    required this.onResult,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.of(context).push<ImportSelection>(
        MaterialPageRoute(
          builder: (_) => ImportPreviewScreen(
            plan: widget.plan,
            fileName: 'backup.json',
            settings: widget.settings,
          ),
        ),
      );
      widget.onResult(result);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

Future<ImportSelection?> _pump(
  WidgetTester tester, {
  ImportPlan? plan,
}) async {
  ImportSelection? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Host(
        plan: plan ?? _plan(),
        settings: await _settings(),
        onResult: (r) => result = r,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders channel rows with their change reason', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.textContaining('My Channel Renamed'), findsWidgets);
    expect(find.textContaining('New Channel'), findsWidgets);
  });

  testWidgets(
    'unchecking a channel disables its nested override/pin rows',
    (tester) async {
      await _pump(tester);

      final checkboxes = find.byType(CheckboxListTile);
      // First checkbox is the updated channel's own row; its nested chart
      // override and pin rows follow immediately after.
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      final nested = tester.widgetList<CheckboxListTile>(checkboxes).toList();
      // The two nested tiles (chart overrides, pinned fields) belonging to
      // the unchecked channel must now be unchecked and disabled.
      final overrideTile = nested[1];
      final pinTile = nested[2];
      expect(overrideTile.value, isFalse);
      expect(overrideTile.onChanged, isNull);
      expect(pinTile.value, isFalse);
      expect(pinTile.onChanged, isNull);
    },
  );

  testWidgets('select none then select all round-trips the full selection', (
    tester,
  ) async {
    final plan = _plan();
    await _pump(tester, plan: plan);

    await tester.tap(find.byTooltip('Select none'));
    await tester.pumpAndSettle();

    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.value, isFalse);
    }

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();

    for (final tile in tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .take(1)) {
      expect(tile.value, isTrue);
    }
  });

  testWidgets('Import is disabled once nothing is selected', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Select none'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Import pops the selection built from the checked rows', (
    tester,
  ) async {
    ImportSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(
          plan: _plan(),
          settings: await _settings(),
          onResult: (r) => result = r,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.channels, {_updatedChannel, _newChannel});
    expect(result!.fieldChartSettingsKeys, {_chartKey});
    expect(result!.pinnedFields, {_pin});
    expect(result!.removeChannelsNotInBackup, isFalse);
  });

  testWidgets('Cancel pops null', (tester) async {
    ImportSelection? result;
    bool called = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(
          plan: _plan(),
          settings: await _settings(),
          onResult: (r) {
            result = r;
            called = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });
}
