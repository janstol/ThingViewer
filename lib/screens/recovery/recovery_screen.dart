import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../backup/backup_service.dart';
import '../../l10n/app_localizations.dart';
import '../../storage/channel_snapshot_storage.dart';
import '../../storage/channel_storage.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../storage/storage_recovery.dart';
import '../../widgets/section_header.dart';
import '../settings/import_flow.dart';
import '../settings/settings_notifier.dart';

/// Writes [raw] to a user-chosen file named after [storeKey], so unreadable
/// data can be inspected or attached to a bug report instead of lost.
Future<void> saveCorruptRaw(
  BuildContext context,
  String storeKey,
  String raw,
) async {
  final l10n = AppLocalizations.of(context)!;
  final fileName =
      'thingviewer-corrupt-$storeKey-'
      '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
  final bytes = Uint8List.fromList(utf8.encode(raw));
  final String? path;
  try {
    path = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
  } on PlatformException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
    return;
  }
  if (path == null || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.recoverySaveSuccess)));
}

/// Confirms permanently discarding the unreadable data named [storeName].
/// Returns whether the user confirmed.
Future<bool> confirmDiscard(BuildContext context, String storeName) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.recoveryDiscardTitle),
      content: Text(l10n.recoveryDiscardText(storeName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.labelCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            l10n.labelDelete,
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _RecoverableStore {
  final String key;
  final String title;
  final StorageIssue issue;
  final String? Function() rawOf;
  final Future<void> Function() discard;

  const _RecoverableStore({
    required this.key,
    required this.title,
    required this.issue,
    required this.rawOf,
    required this.discard,
  });
}

/// One surface for every storage key that could not be fully read: save the
/// raw unreadable value to a file, or discard it. Also offers importing a
/// backup, since that is the other way back to a working state.
class RecoveryScreen extends StatefulWidget {
  final ChannelStorage channelStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final FieldSettingsStorage fieldSettingsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final BackupService backupService;
  final SettingsNotifier settings;

  /// Called after an import or a discard changes any of the storages above,
  /// so the caller can refresh whatever else depends on them.
  final VoidCallback onChanged;

  const RecoveryScreen({
    super.key,
    required this.channelStorage,
    required this.pinnedFieldsStorage,
    required this.fieldSettingsStorage,
    required this.channelSnapshotStorage,
    required this.backupService,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  List<_RecoverableStore> _stores(AppLocalizations l10n) {
    final stores = <_RecoverableStore>[];
    void addIfIssue(
      String key,
      String title,
      StorageIssue? issue,
      String? Function() rawOf,
      Future<void> Function() discard,
    ) {
      if (issue == null) return;
      stores.add(
        _RecoverableStore(
          key: key,
          title: title,
          issue: issue,
          rawOf: rawOf,
          discard: discard,
        ),
      );
    }

    addIfIssue(
      'channels',
      l10n.recoveryStoreChannels,
      widget.channelStorage.issue,
      () => widget.channelStorage.corruptRaw,
      widget.channelStorage.discardCorrupt,
    );
    addIfIssue(
      'pinnedFields',
      l10n.recoveryStorePinnedFields,
      widget.pinnedFieldsStorage.issue,
      () => widget.pinnedFieldsStorage.corruptRaw,
      widget.pinnedFieldsStorage.discardCorrupt,
    );
    addIfIssue(
      'fieldChartSettings',
      l10n.recoveryStoreChartSettings,
      widget.fieldSettingsStorage.issue,
      () => widget.fieldSettingsStorage.corruptRaw,
      widget.fieldSettingsStorage.discardCorrupt,
    );
    addIfIssue(
      'channelSnapshots',
      l10n.recoveryStoreCachedValues,
      widget.channelSnapshotStorage.issue,
      () => widget.channelSnapshotStorage.corruptRaw,
      widget.channelSnapshotStorage.discardCorrupt,
    );
    return stores;
  }

  Future<void> _import() async {
    final imported = await runBackupImport(
      context,
      widget.backupService,
      widget.settings,
    );
    if (!imported) return;
    widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _save(_RecoverableStore store) async {
    final raw = store.rawOf();
    if (raw == null) return;
    await saveCorruptRaw(context, store.key, raw);
  }

  Future<void> _discard(_RecoverableStore store) async {
    if (!await confirmDiscard(context, store.title)) return;
    await store.discard();
    widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stores = _stores(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.recoveryImportBackup),
            onTap: _import,
          ),
          if (stores.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.recoveryNothingToRecover),
            )
          else
            for (final store in stores) ...[
              SectionHeader(title: store.title),
              _StoreTile(
                store: store,
                onSave: () => _save(store),
                onDiscard: () => _discard(store),
              ),
            ],
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final _RecoverableStore store;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _StoreTile({
    required this.store,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = store.issue.total
        ? l10n.recoveryIssueTotal
        : l10n.recoveryIssuePartial(store.issue.skipped);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(l10n.recoverySaveRawData),
              ),
              TextButton.icon(
                onPressed: onDiscard,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  l10n.recoveryDiscard,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
