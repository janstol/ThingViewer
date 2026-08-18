import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/field_chart_settings.dart';

void main() {
  group('isDefault', () {
    test('defaults are default', () {
      expect(FieldChartSettings.defaults.isDefault, isTrue);
    });

    test('any non-default field makes it non-default', () {
      expect(
        FieldChartSettings.defaults.copyWith(showDelta: true).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(type: ChartType.step).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(decimals: 2).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(gapOnInvalid: true).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(showSum: false).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(showAverage: false).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(showMin: false).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(showMax: false).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(markMin: true).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(markMax: true).isDefault,
        isFalse,
      );
    });
  });

  group('toJson', () {
    test('defaults produce an empty map', () {
      expect(FieldChartSettings.defaults.toJson(), isEmpty);
    });

    test('non-default fields are all included', () {
      const settings = FieldChartSettings(
        type: ChartType.step,
        title: 'Custom title',
        xAxisLabel: 'Time',
        yAxisLabel: 'Value',
        yMin: 0,
        yMax: 100,
        decimals: 2,
        showDelta: true,
        gapOnInvalid: true,
        showSum: false,
        showAverage: false,
        showMin: false,
        showMax: false,
        markMin: true,
        markMax: true,
      );

      expect(settings.toJson(), {
        'type': 'step',
        'title': 'Custom title',
        'xAxisLabel': 'Time',
        'yAxisLabel': 'Value',
        'yMin': 0.0,
        'yMax': 100.0,
        'decimals': 2,
        'showDelta': true,
        'gapOnInvalid': true,
        'showSum': false,
        'showAverage': false,
        'showMin': false,
        'showMax': false,
        'markMin': true,
        'markMax': true,
      });
    });

    test('gapOnInvalid is omitted when false, like showDelta', () {
      const settings = FieldChartSettings(showDelta: true, gapOnInvalid: false);

      expect(settings.toJson().containsKey('gapOnInvalid'), isFalse);
    });

    test(
      'showSum/showAverage/showMin/showMax are omitted when true, the '
      'opposite default direction from showDelta/gapOnInvalid',
      () {
        expect(FieldChartSettings.defaults.toJson().containsKey('showSum'), isFalse);
        expect(
          FieldChartSettings.defaults.toJson().containsKey('showAverage'),
          isFalse,
        );
        expect(FieldChartSettings.defaults.toJson().containsKey('showMin'), isFalse);
        expect(FieldChartSettings.defaults.toJson().containsKey('showMax'), isFalse);
      },
    );

    test('markMin/markMax are omitted when false, like showDelta', () {
      expect(FieldChartSettings.defaults.toJson().containsKey('markMin'), isFalse);
      expect(FieldChartSettings.defaults.toJson().containsKey('markMax'), isFalse);
    });
  });

  group('fromJson round-trip', () {
    test('round-trips a fully populated instance', () {
      const settings = FieldChartSettings(
        type: ChartType.spline,
        title: 'Custom title',
        xAxisLabel: 'Time',
        yAxisLabel: 'Value',
        yMin: -5.5,
        yMax: 42.25,
        decimals: 4,
        showDelta: true,
        gapOnInvalid: true,
        showSum: false,
        showAverage: false,
        showMin: false,
        showMax: false,
        markMin: true,
        markMax: true,
      );

      final roundTripped = FieldChartSettings.fromJson(settings.toJson());

      expect(roundTripped, settings);
    });

    test('settings stored before gapOnInvalid existed still parse', () {
      // Simulates a JSON blob persisted before this field was introduced.
      final roundTripped = FieldChartSettings.fromJson({
        'type': 'spline',
        'showDelta': true,
      });

      expect(roundTripped.gapOnInvalid, isFalse);
      expect(roundTripped.showDelta, isTrue);
    });

    test(
      'settings stored before the stats toggles existed still parse, '
      'defaulting to shown',
      () {
        // Simulates a JSON blob persisted before showSum/showAverage/showMin/
        // showMax were introduced — they must default to true (shown), not
        // false, so a pre-existing user's stats bar doesn't go blank.
        final roundTripped = FieldChartSettings.fromJson({
          'type': 'spline',
          'showDelta': true,
        });

        expect(roundTripped.showSum, isTrue);
        expect(roundTripped.showAverage, isTrue);
        expect(roundTripped.showMin, isTrue);
        expect(roundTripped.showMax, isTrue);
      },
    );

    test(
      'settings stored before markMin/markMax existed still parse, '
      'defaulting to off',
      () {
        final roundTripped = FieldChartSettings.fromJson({
          'type': 'spline',
          'showDelta': true,
        });

        expect(roundTripped.markMin, isFalse);
        expect(roundTripped.markMax, isFalse);
      },
    );

    test('round-trips defaults', () {
      final roundTripped = FieldChartSettings.fromJson(
        FieldChartSettings.defaults.toJson(),
      );

      expect(roundTripped, FieldChartSettings.defaults);
    });

    test('round-trips column', () {
      const settings = FieldChartSettings(type: ChartType.column);
      final roundTripped = FieldChartSettings.fromJson(settings.toJson());

      expect(roundTripped, settings);
    });

    test('round-trips scatter', () {
      const settings = FieldChartSettings(type: ChartType.scatter);
      final roundTripped = FieldChartSettings.fromJson(settings.toJson());

      expect(roundTripped, settings);
    });
  });

  group('fromJson tolerance', () {
    test('unknown type string falls back to line', () {
      final settings = FieldChartSettings.fromJson({'type': 'bar'});

      expect(settings.type, ChartType.line);
    });

    test('missing type falls back to line', () {
      final settings = FieldChartSettings.fromJson({});

      expect(settings.type, ChartType.line);
    });

    test('non-numeric bounds fall back to null (auto)', () {
      final settings = FieldChartSettings.fromJson({
        'yMin': 'not a number',
        'yMax': <String, dynamic>{},
        'decimals': 'two',
      });

      expect(settings.yMin, isNull);
      expect(settings.yMax, isNull);
      expect(settings.decimals, isNull);
    });

    test('integer bounds are parsed as doubles', () {
      final settings = FieldChartSettings.fromJson({'yMin': 0, 'yMax': 100});

      expect(settings.yMin, 0.0);
      expect(settings.yMax, 100.0);
    });
  });
}
