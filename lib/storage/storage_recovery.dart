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

  Map<String, dynamic> toJson() => {'skipped': skipped, 'total': total};

  static StorageIssue? fromMeta(String key, String? metaRaw) {
    if (metaRaw == null) return null;
    try {
      final decoded = jsonDecode(metaRaw);
      if (decoded is! Map<String, dynamic>) return null;
      return StorageIssue(
        key: key,
        skipped: decoded['skipped'] as int? ?? 0,
        total: decoded['total'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Result of loading one storage key: the salvaged collection, plus what
/// went wrong reading it, if anything.
class LoadOutcome<T> {
  final T value;
  final StorageIssue? issue;

  const LoadOutcome(this.value, this.issue);
}

String quarantineKey(String key) => '$key.corrupt';

String quarantineMetaKey(String key) => '$key.corrupt.meta';

/// Stashes the unreadable raw string under `<key>.corrupt` so it survives a
/// later write to [key], along with a `<key>.corrupt.meta` description of the
/// issue for a later clean read to still report. Fire-and-forget:
/// `shared_preferences` updates its in-memory cache synchronously before
/// awaiting the platform write, so a following synchronous `getString` on the
/// quarantine key already sees it.
///
/// Never overwrites an existing quarantine — the first one holds the
/// original user data, and a later corrupt write (e.g. of an already
/// partially-salvaged collection) must not clobber it.
void quarantine(
  SharedPreferences prefs,
  String key,
  String raw,
  StorageIssue issue,
) {
  if (quarantinedRaw(prefs, key) != null) return;
  unawaited(prefs.setString(quarantineKey(key), raw));
  unawaited(prefs.setString(quarantineMetaKey(key), jsonEncode(issue.toJson())));
}

String? quarantinedRaw(SharedPreferences prefs, String key) =>
    prefs.getString(quarantineKey(key));

Future<void> clearQuarantine(SharedPreferences prefs, String key) => Future.wait([
  prefs.remove(quarantineKey(key)),
  prefs.remove(quarantineMetaKey(key)),
]);

/// Reads [key] as a JSON list, salvaging what it can.
///
/// - Missing/empty key: clean empty result. If an earlier read quarantined
///   unresolved data under this key, that quarantine is not cleared and its
///   issue is still reported — only an explicit discard resolves it.
/// - Not JSON, or JSON but not a list: nothing salvaged, raw quarantined,
///   [StorageIssue.total] is true.
/// - A list with some entries that don't parse as [T]: those are skipped and
///   counted, the raw is quarantined, everything else is kept.
/// - A fully clean parse still reports a pre-existing quarantine, if any —
///   the quarantine, not the current parse, is the source of truth for
///   "there is unresolved data".
LoadOutcome<List<T>> decodeStoredList<T>(
  SharedPreferences prefs,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) {
    return LoadOutcome(<T>[], _existingIssue(prefs, key));
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    final issue = StorageIssue(key: key, skipped: 0, total: true);
    quarantine(prefs, key, raw, issue);
    return LoadOutcome(<T>[], issue);
  }

  if (decoded is! List) {
    final issue = StorageIssue(key: key, skipped: 0, total: true);
    quarantine(prefs, key, raw, issue);
    return LoadOutcome(<T>[], issue);
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
    return LoadOutcome(values, _existingIssue(prefs, key));
  }

  final issue = StorageIssue(key: key, skipped: skipped, total: false);
  quarantine(prefs, key, raw, issue);
  return LoadOutcome(values, issue);
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
    return LoadOutcome(<String, T>{}, _existingIssue(prefs, key));
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    final issue = StorageIssue(key: key, skipped: 0, total: true);
    quarantine(prefs, key, raw, issue);
    return LoadOutcome(<String, T>{}, issue);
  }

  if (decoded is! Map<String, dynamic>) {
    final issue = StorageIssue(key: key, skipped: 0, total: true);
    quarantine(prefs, key, raw, issue);
    return LoadOutcome(<String, T>{}, issue);
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
    return LoadOutcome(values, _existingIssue(prefs, key));
  }

  final issue = StorageIssue(key: key, skipped: skipped, total: false);
  quarantine(prefs, key, raw, issue);
  return LoadOutcome(values, issue);
}

/// Rebuilds a [StorageIssue] from a quarantine left by an earlier read, if
/// one exists for [key]. Used when the current parse is clean but an
/// unresolved quarantine still needs reporting.
StorageIssue? _existingIssue(SharedPreferences prefs, String key) {
  if (quarantinedRaw(prefs, key) == null) return null;
  return StorageIssue.fromMeta(key, prefs.getString(quarantineMetaKey(key))) ??
      StorageIssue(key: key, skipped: 0, total: true);
}
