import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Describes what went wrong reading one storage key. Never constructed for
/// a clean read — a `null` [StorageIssue] means "nothing to report".
class StorageIssue {
  /// The prefs key this issue is about, e.g. `'channels'`.
  final String key;

  /// Entries that individually failed to parse and were dropped. Zero when
  /// [total] is true, since nothing could be salvaged at all.
  final int skipped;

  /// The stored blob itself could not be decoded (not JSON, or the wrong
  /// top-level type) — no entries could be salvaged.
  final bool total;

  const StorageIssue({
    required this.key,
    required this.skipped,
    required this.total,
  });
}

/// Result of loading one storage key: the salvaged collection, plus what
/// went wrong reading it, if anything.
class LoadOutcome<T> {
  final T value;
  final StorageIssue? issue;

  const LoadOutcome(this.value, this.issue);
}

String quarantineKey(String key) => '$key.corrupt';

/// Stashes the unreadable raw string under `<key>.corrupt` so it survives a
/// later write to [key]. Fire-and-forget: `shared_preferences` updates its
/// in-memory cache synchronously before awaiting the platform write, so a
/// following synchronous `getString` on the quarantine key already sees it.
void quarantine(SharedPreferences prefs, String key, String raw) {
  unawaited(prefs.setString(quarantineKey(key), raw));
}

String? quarantinedRaw(SharedPreferences prefs, String key) =>
    prefs.getString(quarantineKey(key));

Future<void> clearQuarantine(SharedPreferences prefs, String key) =>
    prefs.remove(quarantineKey(key));

/// Reads [key] as a JSON list, salvaging what it can.
///
/// - Missing/empty key: clean empty result, any stale quarantine cleared.
/// - Not JSON, or JSON but not a list: nothing salvaged, raw quarantined,
///   [StorageIssue.total] is true.
/// - A list with some entries that don't parse as [T]: those are skipped and
///   counted, the raw is quarantined, everything else is kept.
/// - A fully clean parse clears any stale quarantine left by a previous
///   failure.
LoadOutcome<List<T>> decodeStoredList<T>(
  SharedPreferences prefs,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) {
    unawaited(clearQuarantine(prefs, key));
    return LoadOutcome(<T>[], null);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    quarantine(prefs, key, raw);
    return LoadOutcome(<T>[], StorageIssue(key: key, skipped: 0, total: true));
  }

  if (decoded is! List) {
    quarantine(prefs, key, raw);
    return LoadOutcome(<T>[], StorageIssue(key: key, skipped: 0, total: true));
  }

  final values = <T>[];
  var skipped = 0;
  for (final entry in decoded) {
    try {
      values.add(fromJson(entry as Map<String, dynamic>));
    } catch (_) {
      skipped++;
    }
  }

  if (skipped == 0) {
    unawaited(clearQuarantine(prefs, key));
    return LoadOutcome(values, null);
  }

  quarantine(prefs, key, raw);
  return LoadOutcome(
    values,
    StorageIssue(key: key, skipped: skipped, total: false),
  );
}

/// Reads [key] as a JSON object, salvaging what it can. Same rules as
/// [decodeStoredList], applied entry-by-entry over the map's values.
LoadOutcome<Map<String, T>> decodeStoredMap<T>(
  SharedPreferences prefs,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) {
    unawaited(clearQuarantine(prefs, key));
    return LoadOutcome(<String, T>{}, null);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    quarantine(prefs, key, raw);
    return LoadOutcome(
      <String, T>{},
      StorageIssue(key: key, skipped: 0, total: true),
    );
  }

  if (decoded is! Map<String, dynamic>) {
    quarantine(prefs, key, raw);
    return LoadOutcome(
      <String, T>{},
      StorageIssue(key: key, skipped: 0, total: true),
    );
  }

  final values = <String, T>{};
  var skipped = 0;
  for (final entry in decoded.entries) {
    try {
      values[entry.key] = fromJson(entry.value as Map<String, dynamic>);
    } catch (_) {
      skipped++;
    }
  }

  if (skipped == 0) {
    unawaited(clearQuarantine(prefs, key));
    return LoadOutcome(values, null);
  }

  quarantine(prefs, key, raw);
  return LoadOutcome(
    values,
    StorageIssue(key: key, skipped: skipped, total: false),
  );
}
