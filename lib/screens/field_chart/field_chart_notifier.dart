import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/field.dart';

sealed class FieldChartState {}

class FieldChartLoading extends FieldChartState {}

class FieldChartLoaded extends FieldChartState {
  final DateTimeRange range;
  final List<FieldValue> values;
  final List<DateTime> invalidAt;
  final bool truncated;
  FieldChartLoaded(
    this.range,
    this.values, {
    this.invalidAt = const [],
    this.truncated = false,
  });
}

class FieldChartEmpty extends FieldChartState {
  final DateTimeRange range;
  FieldChartEmpty(this.range);
}

class FieldChartError extends FieldChartState {
  final DateTimeRange range;
  final List<FieldValue> cachedValues;
  final ApiErrorCode errorCode;
  final String? serverMessage;
  FieldChartError(
    this.range,
    this.cachedValues,
    this.errorCode, [
    this.serverMessage,
  ]);
}

class FieldChartNotifier extends ChangeNotifier {
  final ThingSpeakApi _api;
  final Channel _channel;
  final Field _field;
  bool _disposed = false;

  /// Local cache of all fetched values.
  final List<FieldValue> _cache;

  /// Local cache of timestamps of invalid (non-finite) readings, keyed by
  /// timestamp to avoid duplicates across overlapping fetches.
  final Set<DateTime> _invalidCache;

  /// Disjoint, merged ranges the cache is known to fully cover. A range is
  /// served from cache only when it falls entirely within one of these — the
  /// cache's own min/max is not enough, since two fetches can leave a hole
  /// between them.
  final List<DateTimeRange> _covered = [];

  FieldChartState _state = FieldChartLoading();
  FieldChartState get state => _state;

  FieldChartNotifier(this._api, this._channel, this._field)
    : _cache = List.of(_field.values),
      _invalidCache = Set.of(_field.invalidAt) {
    // Always fetch the default range from the API on first open. The single
    // cached value from the channel detail screen is not enough to draw a
    // useful chart, and isn't recorded as covered.
    applyFilter(_defaultRange());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> applyFilter(DateTimeRange range) async {
    _state = FieldChartLoading();
    notifyListeners();

    _state = await _getData(range);
    if (!_disposed) notifyListeners();
  }

  Future<FieldChartState> _getData(DateTimeRange range) async {
    // If a single covered interval already spans the requested range, filter
    // locally instead of fetching.
    if (_isCovered(range)) {
      final filtered = _filterByRange(_cache, range);
      return filtered.isEmpty
          ? FieldChartEmpty(range)
          : FieldChartLoaded(
              range,
              filtered,
              invalidAt: _filterDatesByRange(_invalidCache, range),
            );
    }

    // Fetch from API.
    final bool truncated;
    try {
      final result = await _api.readFieldRange(
        _channel,
        _field.id,
        apiKey: _channel.apiKey,
        start: range.start,
        end: range.end,
      );
      truncated = result.truncated;
      if (result.field.values.isNotEmpty) {
        // Merge new values into the cache (keyed by timestamp) so previously
        // cached data outside the requested range is preserved.
        final merged = {for (final v in _cache) v.createdAt: v};
        for (final v in result.field.values) {
          merged[v.createdAt] = v;
        }
        _cache
          ..clear()
          ..addAll(
            merged.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          );
      }
      _invalidCache.addAll(result.field.invalidAt);
      // The requested range is now covered even if it returned no data —
      // an empty window is a legitimate result, not a hole to re-fetch.
      _addCovered(range);
    } on ApiException catch (e) {
      return FieldChartError(
        range,
        _filterByRange(_cache, range),
        e.code,
        e.serverMessage,
      );
    }

    final filtered = _filterByRange(_cache, range);
    return filtered.isEmpty
        ? FieldChartEmpty(range)
        : FieldChartLoaded(
            range,
            filtered,
            invalidAt: _filterDatesByRange(_invalidCache, range),
            truncated: truncated,
          );
  }

  bool _isCovered(DateTimeRange range) {
    for (final c in _covered) {
      if (!range.start.isBefore(c.start) && !range.end.isAfter(c.end)) {
        return true;
      }
    }
    return false;
  }

  /// Inserts [range] into [_covered], merging it with any overlapping or
  /// adjacent intervals so the list stays sorted and disjoint.
  void _addCovered(DateTimeRange range) {
    final all = [..._covered, range]
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <DateTimeRange>[];
    for (final r in all) {
      if (merged.isEmpty || r.start.isAfter(merged.last.end)) {
        merged.add(r);
      } else if (r.end.isAfter(merged.last.end)) {
        merged[merged.length - 1] = DateTimeRange(
          start: merged.last.start,
          end: r.end,
        );
      }
    }

    _covered
      ..clear()
      ..addAll(merged);
  }

  static List<FieldValue> _filterByRange(
    List<FieldValue> data,
    DateTimeRange range,
  ) => data
      .where(
        (v) =>
            !v.createdAt.isBefore(range.start) &&
            !v.createdAt.isAfter(range.end),
      )
      .toList();

  static List<DateTime> _filterDatesByRange(
    Iterable<DateTime> dates,
    DateTimeRange range,
  ) =>
      dates
          .where((d) => !d.isBefore(range.start) && !d.isAfter(range.end))
          .toList()
        ..sort();

  /// Last 7 days ending now — or, for a field that hasn't reported in a
  /// while, ending at its last known reading instead. Anchoring to
  /// `DateTime.now()` unconditionally would open a stale field's chart on an
  /// empty window even though older data exists.
  DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final lastUpdated = _field.lastUpdated;
    final end = (lastUpdated != null && lastUpdated.isBefore(now))
        ? lastUpdated
        : now;
    return DateTimeRange(
      start: end.subtract(const Duration(days: 7)),
      end: end,
    );
  }
}
