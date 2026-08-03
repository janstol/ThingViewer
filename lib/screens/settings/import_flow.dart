import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backup/backup_service.dart';
import '../../l10n/app_localizations.dart';

/// Runs the pick-file → parse → choose-mode → restore flow for importing a
/// backup. Shared by the settings screen's import tile and the recovery
/// screen, which both need the exact same flow. Returns whether an import
/// actually happened, so the caller knows whether to refresh its state.
Future<bool> runBackupImport(
  BuildContext context,
  BackupService backupService,
) async {
  final l10n = AppLocalizations.of(context)!;
  final FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(type: FileType.any, withData: true);
  } on PlatformException {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
    return false;
  }
  final files = result?.files;
  if (files == null || files.isEmpty || !context.mounted) return false;
  final bytes = files.first.bytes;
  if (bytes == null) return false;

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

  final channelsNeedingApiKey = backupService.channelsNeedingApiKey(contents);
  final mode = await showDialog<ImportMode>(
    context: context,
    builder: (ctx) {
      ImportMode? selected;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.backupImportTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.backupImportSummary(_summary(l10n, contents))),
                if (channelsNeedingApiKey > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.backupImportMissingKeys(channelsNeedingApiKey),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
                RadioGroup<ImportMode?>(
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<ImportMode?>(
                        value: ImportMode.addChannels,
                        title: Text(l10n.backupModeAddChannels),
                        subtitle: Text(
                          l10n.backupModeAddChannelsDescription,
                        ),
                      ),
                      RadioListTile<ImportMode?>(
                        value: ImportMode.replace,
                        title: Text(
                          l10n.backupModeReplace,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                        subtitle: Text(l10n.backupModeReplaceDescription),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.labelCancel),
            ),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, selected),
              child: Text(l10n.backupImportConfirm),
            ),
          ],
        ),
      );
    },
  );
  if (mode == null || !context.mounted) return false;

  await backupService.restore(contents, mode);
  if (!context.mounted) return true;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.backupImportSuccess)));
  return true;
}

String _summary(AppLocalizations l10n, BackupContents contents) {
  final parts = <String>[];
  final channels = contents.channels;
  if (channels != null) {
    parts.add(l10n.backupSummaryChannels(channels.length));
  }
  if (contents.settings != null) {
    parts.add(l10n.backupSummarySettings);
  }
  final fieldChartSettings = contents.fieldChartSettings;
  if (fieldChartSettings != null) {
    parts.add(l10n.backupSummaryFieldSettings(fieldChartSettings.length));
  }
  return parts.isEmpty ? l10n.backupSummaryEmpty : parts.join(' · ');
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
