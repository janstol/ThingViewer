import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/screens/field_chart/field_chart_screen.dart';
import 'package:thingviewer/screens/field_chart/field_table.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'field_chart_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

// The notifier's default range is the last 7 days from DateTime.now(), so
// fixture timestamps must be recent or the fetched values get filtered out
// and the chart never leaves the empty state.
final _now = DateTime.now();
final _field = Field(
  id: 1,
  label: 'Temp',
  values: [
    FieldValue(createdAt: _now.subtract(const Duration(days: 2)), value: 1),
    FieldValue(createdAt: _now.subtract(const Duration(days: 1)), value: 2),
    FieldValue(createdAt: _now, value: 3),
  ],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

// Forces 24h time entry so filter-sheet tests can type "23:59" directly,
// without an AM/PM toggle in the way.
Widget _wrap24(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
  home: child,
);

Widget _wrapScaled(Widget child, double scale) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

// Simulates the opaque 3-button nav bar Android reserves at the bottom of
// the window once the app draws edge-to-edge (Android 15+ / API 35+).
Widget _wrapWithBottomInset(Widget child, double bottom) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: EdgeInsets.only(bottom: bottom),
      viewPadding: EdgeInsets.only(bottom: bottom),
    ),
    child: child!,
  ),
  home: child,
);

String _compactDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.year.toString().padLeft(4, '0')}';

Future<SettingsNotifier> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsNotifier(SettingsStorage(prefs));
}

Future<FieldSettingsStorage> _fieldSettingsStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return FieldSettingsStorage(prefs);
}

Future<PinnedFieldsStorage> _pinnedFieldsStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return PinnedFieldsStorage(prefs);
}

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockThingSpeakApi();
    when(
      mockApi.readFieldRange(
        any,
        any,
        apiKey: anyNamed('apiKey'),
        start: anyNamed('start'),
        end: anyNamed('end'),
      ),
    ).thenAnswer((_) async => FieldRange(field: _field, truncated: false));
  });

  testWidgets(
    'selecting Step in field settings applies isStepLineChart to the rendered chart',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      LineChartData chartData() =>
          tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(chartData().lineBarsData.single.isStepLineChart, isFalse);
      expect(chartData().lineBarsData.single.isCurved, isFalse);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Step'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(chartData().lineBarsData.single.isStepLineChart, isTrue);
      expect(chartData().lineBarsData.single.isCurved, isFalse);
    },
  );

  testWidgets(
    'selecting Spline in field settings applies isCurved to the rendered chart',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spline'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      final chartData = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chartData.lineBarsData.single.isCurved, isTrue);
      expect(chartData.lineBarsData.single.isStepLineChart, isFalse);
    },
  );

  testWidgets('selecting Column renders a BarChart and no LineChart', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FieldChartScreen(
          channel: _channel,
          field: _field,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Column'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('Scatter is not offered in the type picker', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FieldChartScreen(
          channel: _channel,
          field: _field,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();

    expect(find.text('Scatter'), findsNothing);
  });

  testWidgets(
    // Scatter is hidden from the picker but stays implemented — a field
    // already set to it (from before it was hidden) must still render and
    // must not crash the settings screen's label lookup.
    'a field already set to Scatter keeps rendering it, picker unaffected',
    (tester) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(type: ChartType.scatter),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chartData = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chartData.lineBarsData.single.barWidth, 0);
      expect(chartData.lineBarsData.single.dotData.show, isTrue);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Scatter'), findsOneWidget); // shown as current value
    },
  );

  testWidgets(
    'gapOnInvalid inserts a null spot at the invalid reading; off by default',
    (tester) async {
      // Tall viewport so the new switch doesn't need scrolling into view.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Between the day-2 and day-1 real values.
      final invalidAt = _now.subtract(const Duration(hours: 36));
      final fieldWithInvalid = Field(
        id: 1,
        label: 'Temp',
        values: _field.values,
        invalidAt: [invalidAt],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: fieldWithInvalid, truncated: false),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      List<FlSpot> spots() => tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots;

      // Off by default: connected across the invalid reading, no null spot.
      expect(spots().any((s) => s.x.isNaN), isFalse);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Break line at invalid readings'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final withGap = spots();
      final nullIndex = withGap.indexWhere((s) => s.x.isNaN);
      expect(nullIndex, greaterThan(-1));
      expect(
        withGap[nullIndex - 1].x,
        _field.values[0].createdAt.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        withGap[nullIndex + 1].x,
        _field.values[1].createdAt.millisecondsSinceEpoch.toDouble(),
      );
    },
  );

  group('pinch-zoom clamping', () {
    // _field spans exactly 2 days: floor = fullRange / 500, ceiling = fullRange.
    const fullRangeMs = 2 * 24 * 60 * 60 * 1000.0;

    testWidgets('spreading fingers apart clamps the range to the floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(center - const Offset(1, 0));
      final pointerB = await tester.startGesture(center + const Offset(1, 0));
      await tester.pump();

      await pointerA.moveTo(center - const Offset(2000, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(2000, 0));
      await tester.pump();

      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.maxX - data.minX, closeTo(fullRangeMs / 500, 0.01));
    });

    testWidgets('pinching together from the full view stays at the ceiling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(center - const Offset(300, 0));
      final pointerB = await tester.startGesture(center + const Offset(300, 0));
      await tester.pump();

      await pointerA.moveTo(center - const Offset(1, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(1, 0));
      await tester.pump();

      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(
        data.minX,
        _field.values.first.createdAt.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        data.maxX,
        _field.values.last.createdAt.millisecondsSinceEpoch.toDouble(),
      );
    });
  });

  testWidgets(
    'a single-point series pads the view symmetrically and ignores pinch gestures',
    (tester) async {
      final singleValueField = Field(
        id: 1,
        label: 'Temp',
        values: [FieldValue(createdAt: _now, value: 1)],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: singleValueField, truncated: false),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: singleValueField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final anchorMs = _now.millisecondsSinceEpoch.toDouble();
      const paddingMs = 60 * 60 * 1000.0;

      LineChartData data() =>
          tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data().minX, anchorMs - paddingMs);
      expect(data().maxX, anchorMs + paddingMs);

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(center - const Offset(1, 0));
      final pointerB = await tester.startGesture(center + const Offset(1, 0));
      await tester.pump();
      await pointerA.moveTo(center - const Offset(2000, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(2000, 0));
      await tester.pump();
      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      expect(data().minX, anchorMs - paddingMs);
      expect(data().maxX, anchorMs + paddingMs);
    },
  );

  testWidgets(
    'Column chart shows the no-data message when there are no values to bucket',
    (tester) async {
      final singleValueField = Field(
        id: 1,
        label: 'Temp',
        values: [FieldValue(createdAt: _now, value: 1)],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: singleValueField, truncated: false),
      );
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        singleValueField.id,
        const FieldChartSettings(type: ChartType.column, showDelta: true),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: singleValueField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('No data at this zoom level.'), findsOneWidget);
    },
  );

  testWidgets(
    'Column chart bottom titles thin out to every Nth label past 5 bars',
    (tester) async {
      final manyValuesField = Field(
        id: 1,
        label: 'Temp',
        values: [
          for (var i = 0; i < 20; i++)
            FieldValue(
              createdAt: _now.subtract(Duration(hours: 6 * (19 - i))),
              value: i.toDouble(),
            ),
        ],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: manyValuesField, truncated: false),
      );
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        manyValuesField.id,
        const FieldChartSettings(type: ChartType.column),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: manyValuesField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      // 20 bars => labelStep = (20 / 5).ceil() = 4.
      final getTitles = data.titlesData.bottomTitles.sideTitles.getTitlesWidget;
      final meta = TitleMeta(
        min: 0,
        max: 20,
        parentAxisSize: 400,
        axisPosition: 0,
        appliedInterval: 1,
        sideTitles: data.titlesData.bottomTitles.sideTitles,
        formattedValue: '',
        axisSide: AxisSide.bottom,
        rotationQuarterTurns: 0,
      );

      expect(getTitles(0.0, meta), isA<SideTitleWidget>());
      expect(getTitles(1.0, meta), isA<SizedBox>());
      expect(getTitles(4.0, meta), isA<SideTitleWidget>());
      expect(getTitles(-1.0, meta), isA<SizedBox>());
      expect(getTitles(20.0, meta), isA<SizedBox>());
    },
  );

  group('edge-to-edge nav bar clearance', () {
    testWidgets('the Filter button clears the simulated nav bar inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const bottomInset = 48.0;

      await tester.pumpWidget(
        _wrapWithBottomInset(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
          bottomInset,
        ),
      );
      await tester.pumpAndSettle();

      final buttonRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Filter'),
      );
      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(800 - bottomInset),
        reason: 'Filter button must not sit under the simulated nav bar',
      );
    });

    testWidgets(
      'the filter sheet Apply button clears the simulated nav bar inset',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const bottomInset = 48.0;

        await tester.pumpWidget(
          _wrapWithBottomInset(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
            bottomInset,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();

        final applyRect = tester.getRect(
          find.widgetWithText(FilledButton, 'Apply'),
        );
        expect(
          applyRect.bottom,
          lessThanOrEqualTo(800 - bottomInset),
          reason: 'Apply button must not sit under the simulated nav bar',
        );
      },
    );
  });

  group('filter sheet', () {
    testWidgets('cancelling leaves the current range unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minXBefore = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .minX;

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final minXAfter = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .minX;
      expect(minXAfter, minXBefore);
    });

    testWidgets('picking a From value past the current To clamps it back', (
      tester,
    ) async {
      final rangeEnd = _field.values.last.createdAt;
      final settings = await _settings();

      await tester.pumpWidget(
        _wrap24(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: settings,
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From'));
      await tester.pumpAndSettle();

      // Date picker: switch to text input, type a date past the current To.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        _compactDate(rangeEnd),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Time picker: switch to text input, type a time past the current To.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.byType(TextFormField);
      await tester.enterText(timeFields.at(0), '23');
      await tester.enterText(timeFields.at(1), '59');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final expected = rangeEnd.subtract(const Duration(minutes: 1));
      expect(find.text(settings.formatDateTime(expected)), findsOneWidget);
    });

    testWidgets('picking a future To value clamps it back to now', (
      tester,
    ) async {
      final rangeEnd = _field.values.last.createdAt;
      final settings = await _settings();

      await tester.pumpWidget(
        _wrap24(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: settings,
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('To'));
      await tester.pumpAndSettle();

      // Default pre-filled date is already the current To's date; accept it.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Time picker: switch to text input, type a time later than now.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.byType(TextFormField);
      await tester.enterText(timeFields.at(0), '23');
      await tester.enterText(timeFields.at(1), '59');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final unclamped = DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
        23,
        59,
      );
      expect(find.text(settings.formatDateTime(unclamped)), findsNothing);
    });
  });

  group('table view', () {
    testWidgets('tapping the toggle swaps the chart for the table and back', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(FieldTable), findsNothing);

      await tester.tap(find.byIcon(Icons.table_rows));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsNothing);
      expect(find.byType(FieldTable), findsOneWidget);

      await tester.tap(find.byIcon(Icons.show_chart));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(FieldTable), findsNothing);
    });

    testWidgets('rows are newest first and honour the decimals setting', (
      tester,
    ) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(decimals: 2),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.table_rows));
      await tester.pumpAndSettle();

      final newestY = tester.getTopLeft(find.text('3.00')).dy;
      final oldestY = tester.getTopLeft(find.text('1.00')).dy;
      expect(newestY, lessThan(oldestY));
    });

    testWidgets('showDelta shows one fewer row, newest delta first', (
      tester,
    ) async {
      final deltaField = Field(
        id: 1,
        label: 'Temp',
        values: [
          FieldValue(
            createdAt: _now.subtract(const Duration(days: 2)),
            value: 10,
          ),
          FieldValue(
            createdAt: _now.subtract(const Duration(days: 1)),
            value: 13,
          ),
          FieldValue(createdAt: _now, value: 17),
        ],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: deltaField, truncated: false),
      );

      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        deltaField.id,
        const FieldChartSettings(showDelta: true, decimals: 0),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: deltaField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.table_rows));
      await tester.pumpAndSettle();

      // Only the two deltas (4 = 17-13, 3 = 13-10) are shown, not the raw values.
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('17'), findsNothing);

      final newestDeltaY = tester.getTopLeft(find.text('4')).dy;
      final olderDeltaY = tester.getTopLeft(find.text('3')).dy;
      expect(newestDeltaY, lessThan(olderDeltaY));
    });

    group('pagination', () {
      final manyValuesField = Field(
        id: 1,
        label: 'Temp',
        values: [
          for (var i = 0; i < 120; i++)
            FieldValue(
              createdAt: _now.subtract(Duration(minutes: 72 * (119 - i))),
              value: i.toDouble(),
            ),
        ],
      );

      Future<void> pumpTableAtPage1(WidgetTester tester) async {
        when(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: anyNamed('start'),
            end: anyNamed('end'),
          ),
        ).thenAnswer(
          (_) async => FieldRange(field: manyValuesField, truncated: false),
        );

        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          manyValuesField.id,
          const FieldChartSettings(decimals: 0),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: manyValuesField,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.table_rows));
        await tester.pumpAndSettle();
      }

      testWidgets('page 1 shows the newest 50, prev disabled, next advances, '
          'next disabled on the last page', (tester) async {
        await pumpTableAtPage1(tester);

        // 120 values, 50 per page => 3 pages.
        expect(find.text('Page 1 of 3'), findsOneWidget);
        IconButton prevButton() => tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_left),
        );
        IconButton nextButton() => tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right),
        );
        expect(prevButton().onPressed, isNull);
        expect(nextButton().onPressed, isNotNull);

        // Newest value (index 119) should be visible on page 1.
        expect(find.text('119'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(find.text('Page 2 of 3'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(find.text('Page 3 of 3'), findsOneWidget);
        expect(nextButton().onPressed, isNull);
        expect(prevButton().onPressed, isNotNull);

        // Oldest value (index 0) is on the last page, at the bottom of the
        // list — scroll down to bring it into the (lazily built) viewport.
        await tester.dragUntilVisible(
          find.text('0'),
          find.byType(Scrollable),
          const Offset(0, -300),
        );
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('applying a new filter while on page 2 resets to page 1', (
        tester,
      ) async {
        await pumpTableAtPage1(tester);

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(find.text('Page 2 of 3'), findsOneWidget);

        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(find.text('Page 1 of 3'), findsOneWidget);
      });
    });
  });

  group('CSV export', () {
    testWidgets('download button is absent in chart view', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_outlined), findsNothing);
    });

    testWidgets('download button appears in table view and opens a dialog '
        'offering both modes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.table_rows));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Raw'), findsOneWidget);
      expect(find.text('Formatted'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Raw'), findsNothing);
    });
  });

  group('stats bar', () {
    testWidgets('renders in the loaded state with the expected formatted '
        'numbers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // _field.values = 1, 2, 3 -> count 3, sum 6, avg 2, min 1, max 3.
      expect(find.text('Showing 3 values'), findsOneWidget);
      expect(find.text('Sum 6.00'), findsOneWidget);
      expect(find.text('Avg 2.00'), findsOneWidget);
      expect(find.text('Min 1.00'), findsOneWidget);
      expect(find.text('Max 3.00'), findsOneWidget);
    });

    testWidgets('reflects the delta series when showDelta is on', (
      tester,
    ) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(showDelta: true, decimals: 0),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deltas of 1, 2, 3 are 1 and 1 -> sum 2, avg 1, min 1, max 1. The
      // count stays the raw reading count, unaffected by showDelta.
      expect(find.text('Showing 3 values'), findsOneWidget);
      expect(find.text('Sum 2'), findsOneWidget);
      expect(find.text('Avg 1'), findsOneWidget);
      expect(find.text('Min 1'), findsOneWidget);
      expect(find.text('Max 1'), findsOneWidget);
    });

    testWidgets('appears in the error state with cached values', (
      tester,
    ) async {
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenThrow(ApiException(ApiErrorCode.network));
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(decimals: 0),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Showing 3 values'), findsOneWidget);
      expect(find.text('Sum 6'), findsOneWidget);
      expect(find.text('Avg 2'), findsOneWidget);
      expect(find.text('Min 1'), findsOneWidget);
      expect(find.text('Max 3'), findsOneWidget);
    });

    testWidgets('hides only the toggled-off entries, count and the rest '
        'stay', (tester) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(
          decimals: 0,
          showSum: false,
          showMin: false,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Showing 3 values'), findsOneWidget);
      expect(find.text('Sum 6'), findsNothing);
      expect(find.text('Min 1'), findsNothing);
      expect(find.text('Avg 2'), findsOneWidget);
      expect(find.text('Max 3'), findsOneWidget);
    });

    testWidgets(
      'in auto mode, the whole row rounds to the precision min/max need, '
      'not each entry independently',
      (tester) async {
        // Average 4/3 = 1.333... never terminates at 2 decimals the way
        // sum/min/max (whole-number readings) do — reproduces the
        // inconsistent-rounding report.
        final unevenField = Field(
          id: 1,
          label: 'Temp',
          values: [
            FieldValue(createdAt: _now.subtract(const Duration(days: 2)), value: 1),
            FieldValue(createdAt: _now.subtract(const Duration(days: 1)), value: 1),
            FieldValue(createdAt: _now, value: 2),
          ],
        );
        when(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: anyNamed('start'),
            end: anyNamed('end'),
          ),
        ).thenAnswer(
          (_) async => FieldRange(field: unevenField, truncated: false),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: unevenField,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // min/max (1, 2) only need 2 decimals; the whole row -- including
        // the average, which on its own would show '1.333333' -- rounds to
        // that shared count instead.
        expect(find.text('Sum 4.00'), findsOneWidget);
        expect(find.text('Avg 1.33'), findsOneWidget);
        expect(find.text('Min 1.00'), findsOneWidget);
        expect(find.text('Max 2.00'), findsOneWidget);
        expect(find.text('Avg 1.333333'), findsNothing);
      },
    );

    testWidgets(
      'Avg/Min/Max carry a full-word spoken label distinct from the '
      'visible abbreviation; Sum has none to translate',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Visible text stays abbreviated.
        expect(find.text('Avg 2.00'), findsOneWidget);
        expect(find.text('Min 1.00'), findsOneWidget);
        expect(find.text('Max 3.00'), findsOneWidget);

        // The abbreviation is excluded from what a screen reader hears.
        expect(find.bySemanticsLabel('Avg 2.00'), findsNothing);
        expect(find.bySemanticsLabel('Min 1.00'), findsNothing);
        expect(find.bySemanticsLabel('Max 3.00'), findsNothing);

        // The spoken label uses the full word instead.
        expect(find.bySemanticsLabel('Average 2.00'), findsOneWidget);
        expect(find.bySemanticsLabel('Minimum 1.00'), findsOneWidget);
        expect(find.bySemanticsLabel('Maximum 3.00'), findsOneWidget);
        expect(find.bySemanticsLabel('Sum 6.00'), findsOneWidget);

        handle.dispose();
      },
    );
  });

  group('chart markers', () {
    testWidgets('default settings draw no markers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.extraLinesData.horizontalLines, isEmpty);
      expect(data.lineBarsData.single.dotData.show, isFalse);
      // No markers on: the Y-axis auto-range is left to fl_chart, unpadded
      // (fl_chart represents "unset" as NaN internally, not null).
      expect(data.minY.isNaN, isTrue);
      expect(data.maxY.isNaN, isTrue);
    });

    testWidgets(
      'markMax pads the auto Y-axis max above the series max, so its '
      'label does not land exactly on the axis boundary',
      (tester) async {
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          _field.id,
          const FieldChartSettings(markMax: true, decimals: 0),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // _field.values = 1, 2, 3 -> max is 3.
        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.maxY.isNaN, isFalse);
        expect(data.maxY, greaterThan(3));
        // markMin is off: the bottom stays fl_chart's own auto minimum.
        expect(data.minY.isNaN, isTrue);
      },
    );

    testWidgets(
      'markMin pads the auto Y-axis min below the series min, so its '
      'label does not land exactly on the axis boundary',
      (tester) async {
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          _field.id,
          const FieldChartSettings(markMin: true, decimals: 0),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // _field.values = 1, 2, 3 -> min is 1.
        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.minY.isNaN, isFalse);
        expect(data.minY, lessThan(1));
        expect(data.maxY.isNaN, isTrue);
      },
    );

    testWidgets(
      'a manually set yMax is left unpadded even with markMax on',
      (tester) async {
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          _field.id,
          const FieldChartSettings(markMax: true, yMax: 3, decimals: 0),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.maxY, 3);
      },
    );

    testWidgets(
      'markMax draws one horizontal line at the series max with a '
      'formatted label, and marks only the max spot',
      (tester) async {
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          _field.id,
          const FieldChartSettings(markMax: true, decimals: 0),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // _field.values = 1, 2, 3 -> max is 3.
        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.extraLinesData.horizontalLines, hasLength(1));
        final line = data.extraLinesData.horizontalLines.single;
        expect(line.y, 3);
        expect(line.label.labelResolver(line), 'Max 3');

        final barData = data.lineBarsData.single;
        expect(barData.dotData.show, isTrue);
        final maxSpot = barData.spots.firstWhere((s) => s.y == 3);
        final minSpot = barData.spots.firstWhere((s) => s.y == 1);
        expect(barData.dotData.checkToShowDot(maxSpot, barData), isTrue);
        expect(barData.dotData.checkToShowDot(minSpot, barData), isFalse);
      },
    );

    testWidgets('markMin and markMax both on draw two horizontal lines', (
      tester,
    ) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(markMin: true, markMax: true, decimals: 0),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.extraLinesData.horizontalLines, hasLength(2));
    });

    testWidgets(
      'a flat series with both markers on draws a single collapsed line',
      (tester) async {
        final flatField = Field(
          id: 1,
          label: 'Temp',
          values: [
            FieldValue(
              createdAt: _now.subtract(const Duration(days: 1)),
              value: 5,
            ),
            FieldValue(createdAt: _now, value: 5),
          ],
        );
        when(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: anyNamed('start'),
            end: anyNamed('end'),
          ),
        ).thenAnswer(
          (_) async => FieldRange(field: flatField, truncated: false),
        );
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          flatField.id,
          const FieldChartSettings(
            markMin: true,
            markMax: true,
            decimals: 0,
          ),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: flatField,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(data.extraLinesData.horizontalLines, hasLength(1));
        final line = data.extraLinesData.horizontalLines.single;
        expect(line.label.labelResolver(line), 'Max 5');
      },
    );

    testWidgets(
      'markers follow showDelta, using the delta series extremes',
      (tester) async {
        final deltaField = Field(
          id: 1,
          label: 'Temp',
          values: [
            FieldValue(
              createdAt: _now.subtract(const Duration(days: 2)),
              value: 10,
            ),
            FieldValue(
              createdAt: _now.subtract(const Duration(days: 1)),
              value: 13,
            ),
            FieldValue(createdAt: _now, value: 17),
          ],
        );
        when(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: anyNamed('start'),
            end: anyNamed('end'),
          ),
        ).thenAnswer(
          (_) async => FieldRange(field: deltaField, truncated: false),
        );
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          deltaField.id,
          const FieldChartSettings(
            showDelta: true,
            markMax: true,
            decimals: 0,
          ),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: deltaField,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Deltas of 10, 13, 17 are 3 and 4 -> max delta is 4, not the raw
        // series' max of 17.
        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        final line = data.extraLinesData.horizontalLines.single;
        expect(line.y, 4);
      },
    );

    testWidgets(
      'Column chart type carries the marker lines via BarChartData',
      (tester) async {
        final fieldSettingsStorage = await _fieldSettingsStorage();
        await fieldSettingsStorage.save(
          _channel,
          _field.id,
          const FieldChartSettings(
            type: ChartType.column,
            markMax: true,
            decimals: 0,
          ),
        );

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _field,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final data = tester.widget<BarChart>(find.byType(BarChart)).data;
        expect(data.extraLinesData.horizontalLines, hasLength(1));
      },
    );
  });

  testWidgets('chart axes do not overflow at 2x text scale', (tester) async {
    await tester.pumpWidget(
      _wrapScaled(
        FieldChartScreen(
          channel: _channel,
          field: _field,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
        ),
        2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
