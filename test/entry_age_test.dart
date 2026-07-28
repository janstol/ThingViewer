import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/entry_age.dart';
import 'package:thingviewer/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('negative age clamps to just now', () {
    expect(formatEntryAge(l10n, const Duration(seconds: -5)), 'just now');
  });

  test('just now bucket', () {
    expect(formatEntryAge(l10n, Duration.zero), 'just now');
    expect(formatEntryAge(l10n, const Duration(seconds: 59)), 'just now');
  });

  test('59s/60s boundary', () {
    expect(formatEntryAge(l10n, const Duration(seconds: 59)), 'just now');
    expect(formatEntryAge(l10n, const Duration(seconds: 60)), '1 min ago');
  });

  test('minutes bucket, singular and plural', () {
    expect(formatEntryAge(l10n, const Duration(minutes: 1)), '1 min ago');
    expect(formatEntryAge(l10n, const Duration(minutes: 5)), '5 min ago');
  });

  test('59min/60min boundary', () {
    expect(formatEntryAge(l10n, const Duration(minutes: 59)), '59 min ago');
    expect(formatEntryAge(l10n, const Duration(minutes: 60)), '1 hour ago');
  });

  test('hours bucket, singular and plural', () {
    expect(formatEntryAge(l10n, const Duration(hours: 1)), '1 hour ago');
    expect(formatEntryAge(l10n, const Duration(hours: 5)), '5 hours ago');
  });

  test('23h/24h boundary', () {
    expect(formatEntryAge(l10n, const Duration(hours: 23)), '23 hours ago');
    expect(formatEntryAge(l10n, const Duration(hours: 24)), '1 day ago');
  });

  test('days bucket, singular and plural', () {
    expect(formatEntryAge(l10n, const Duration(days: 1)), '1 day ago');
    expect(formatEntryAge(l10n, const Duration(days: 5)), '5 days ago');
  });

  test('29d/30d boundary', () {
    expect(formatEntryAge(l10n, const Duration(days: 29)), '29 days ago');
    expect(formatEntryAge(l10n, const Duration(days: 30)), '1 month ago');
  });

  test('months bucket, singular and plural', () {
    expect(formatEntryAge(l10n, const Duration(days: 30)), '1 month ago');
    expect(formatEntryAge(l10n, const Duration(days: 90)), '3 months ago');
  });

  test('364d/365d boundary', () {
    expect(formatEntryAge(l10n, const Duration(days: 364)), '12 months ago');
    expect(formatEntryAge(l10n, const Duration(days: 365)), '1 year ago');
  });

  test('years bucket, singular and plural', () {
    expect(formatEntryAge(l10n, const Duration(days: 365)), '1 year ago');
    expect(formatEntryAge(l10n, const Duration(days: 800)), '2 years ago');
  });
}
