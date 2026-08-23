import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backup/backup_service.dart';
import '../../backup/import_plan.dart';
import '../../l10n/app_localizations.dart';
import '../import_preview/import_preview_screen.dart';
import 'settings_notifier.dart';

/// Runs the pick-file → parse → preview → apply flow for importing a
/// backup. Shared by the settings screen's import tile and the recovery
/// screen, which both need the exact same flow. Returns whether an import
/// actually happened, so the caller knows whether to refresh its state.
Future<bool> runBackupImport(
  BuildContext context,
  BackupService backupService,
  SettingsNotifier settings,
) async {
  final l10n = AppLocalizations.of(context)!;
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(type: FileType.any);
  } on PlatformException {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
    return false;
  }
  if (file == null || !context.mounted) return false;
  final fileName = file.name;
  final bytes = await file.readAsBytes();

  final BackupContents contents;
  try {
    contents = backupService.parse(utf8.decode(bytes));
  } on BackupException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_errorMessage(l10n, e))));
    return false;
  }

  final plan = backupService.planImport(contents);
  if (!context.mounted) return false;
  final selection = await Navigator.of(context).push<ImportSelection>(
    MaterialPageRoute(
      builder: (_) => ImportPreviewScreen(
        plan: plan,
        fileName: fileName,
        settings: settings,
      ),
    ),
  );
  if (selection == null || !context.mounted) return false;

  await backupService.applyImport(contents, selection);
  if (!context.mounted) return true;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.backupImportSuccess)));
  return true;
}

String _errorMessage(AppLocalizations l10n, BackupException e) {
  switch (e.type) {
    case BackupErrorType.notABackup:
      return l10n.backupErrorNotABackup;
    case BackupErrorType.newerVersion:
      return l10n.backupErrorNewerVersion;
    case BackupErrorType.malformed:
      return l10n.backupErrorMalformed;
  }
}
