import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../api/thingspeak_api.dart';
import '../../backup/backup_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../storage/channel_snapshot_storage.dart';
import '../../storage/channel_storage.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../widgets/section_header.dart';
import '../channel_add/channel_add_screen.dart';
import '../channel_detail/channel_detail_screen.dart';
import '../field_chart/field_chart_screen.dart';
import '../pinned_edit/pinned_edit_screen.dart';
import '../recovery/recovery_screen.dart';
import '../settings/import_flow.dart';
import '../settings/settings_notifier.dart';
import '../settings/settings_screen.dart';
import 'channel_list_notifier.dart';
import 'pinned_notifier.dart';
import 'pinned_section.dart';

const _kTabletBreakpoint = 600.0;

class ChannelListScreen extends StatefulWidget {
  final ThingSpeakApi api;
  final ChannelStorage channelStorage;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final BackupService backupService;

  const ChannelListScreen({
    super.key,
    required this.api,
    required this.channelStorage,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    required this.channelSnapshotStorage,
    required this.backupService,
  });

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final ChannelListNotifier _notifier;
  late final PinnedNotifier _pinnedNotifier;
  Channel? _selectedChannel;
  Channel? _pendingStartChannel;
  DateTime _now = DateTime.now();
  Timer? _ageTicker;
  bool _issueBannerDismissed = false;

  List<Channel> get _channels => switch (_notifier.state) {
    ChannelListLoaded(:final channels) => channels,
    _ => const <Channel>[],
  };

  /// Whether some store other than (or in addition to) a fully-corrupted
  /// channel list has unreadable data. `ChannelListCorrupted` already gets
  /// its own blocking body, so the banner only covers the remaining cases.
  bool get _issueBannerVisible =>
      !_issueBannerDismissed &&
      _notifier.state is ChannelListLoaded &&
      (widget.channelStorage.issue != null ||
          widget.pinnedFieldsStorage.issue != null ||
          widget.fieldSettingsStorage.issue != null ||
          widget.channelSnapshotStorage.issue != null);

  void _dismissIssueBanner() => setState(() => _issueBannerDismissed = true);

  void _openRecovery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryScreen(
          channelStorage: widget.channelStorage,
          pinnedFieldsStorage: widget.pinnedFieldsStorage,
          fieldSettingsStorage: widget.fieldSettingsStorage,
          channelSnapshotStorage: widget.channelSnapshotStorage,
          backupService: widget.backupService,
          onChanged: _onImported,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  void initState() {
    super.initState();
    _notifier = ChannelListNotifier(widget.channelStorage);
    _pinnedNotifier = PinnedNotifier(
      widget.api,
      widget.pinnedFieldsStorage,
      widget.channelSnapshotStorage,
      _channels,
    );
    _pinnedNotifier.addListener(_syncAgeTicker);
    _syncAgeTicker();
    final startChannel = widget.settings.startChannel(_channels);
    _selectedChannel = startChannel;
    _pendingStartChannel = startChannel;
  }

  void _syncAgeTicker() {
    final hasPins = _pinnedNotifier.entries.isNotEmpty;
    if (hasPins && _ageTicker == null) {
      _ageTicker = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!hasPins && _ageTicker != null) {
      _ageTicker!.cancel();
      _ageTicker = null;
    }
  }

  void _refreshPinned() => _pinnedNotifier.setChannels(_channels);

  void _removeChannel(Channel channel) {
    if (_selectedChannel == channel) {
      setState(() => _selectedChannel = null);
    }
    _notifier.removeChannel(channel);
    widget.channelSnapshotStorage.remove(channel);
    _refreshPinned();
  }

  void _openPinnedEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinnedEditScreen(
          api: widget.api,
          pinnedFieldsStorage: widget.pinnedFieldsStorage,
          channels: _channels,
        ),
      ),
    );
    _refreshPinned();
  }

  void _openPinnedField(PinnedEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldChartScreen(
          channel: entry.channel,
          field: Field(id: entry.pin.fieldId, label: entry.snapshot?.label),
          api: widget.api,
          settings: widget.settings,
          fieldSettingsStorage: widget.fieldSettingsStorage,
          pinnedFieldsStorage: widget.pinnedFieldsStorage,
          onPinnedChanged: _refreshPinned,
        ),
      ),
    ).then((_) => _refreshPinned());
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    _pinnedNotifier.removeListener(_syncAgeTicker);
    _pinnedNotifier.dispose();
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _pinnedNotifier,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kTabletBreakpoint;
            // Consume the pending start channel once, on the first layout pass,
            // regardless of width - this prevents a later rotation from firing
            // a stray push on the narrow layout.
            final pending = _pendingStartChannel;
            if (pending != null) {
              _pendingStartChannel = null;
              if (!isWide) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _openChannel(pending);
                });
              }
            }
            return isWide
                ? _WideLayout(
                    notifier: _notifier,
                    api: widget.api,
                    settings: widget.settings,
                    channelStorage: widget.channelStorage,
                    fieldSettingsStorage: widget.fieldSettingsStorage,
                    pinnedFieldsStorage: widget.pinnedFieldsStorage,
                    channelSnapshotStorage: widget.channelSnapshotStorage,
                    backupService: widget.backupService,
                    onImported: _onImported,
                    selectedChannel: _selectedChannel,
                    onChannelSelected: (c) =>
                        setState(() => _selectedChannel = c),
                    onChannelRemoved: _removeChannel,
                    onChannelEdited: _onChannelEdited,
                    onAddChannel: _openAddChannel,
                    onPinnedChanged: _refreshPinned,
                    pinnedEntries: _pinnedNotifier.entries,
                    now: _now,
                    onEditPinned: _openPinnedEdit,
                    onTapPinned: _openPinnedField,
                    onPinnedRefresh: _pinnedNotifier.refresh,
                    issueBannerVisible: _issueBannerVisible,
                    onDismissIssueBanner: _dismissIssueBanner,
                    onOpenRecovery: _openRecovery,
                    l10n: l10n,
                  )
                : _NarrowLayout(
                    notifier: _notifier,
                    api: widget.api,
                    settings: widget.settings,
                    channelStorage: widget.channelStorage,
                    fieldSettingsStorage: widget.fieldSettingsStorage,
                    pinnedFieldsStorage: widget.pinnedFieldsStorage,
                    channelSnapshotStorage: widget.channelSnapshotStorage,
                    backupService: widget.backupService,
                    onImported: _onImported,
                    onOpenChannel: _openChannel,
                    onDeleteChannel: _removeChannel,
                    onAddChannel: _openAddChannel,
                    pinnedEntries: _pinnedNotifier.entries,
                    now: _now,
                    onEditPinned: _openPinnedEdit,
                    onTapPinned: _openPinnedField,
                    onPinnedRefresh: _pinnedNotifier.refresh,
                    issueBannerVisible: _issueBannerVisible,
                    onDismissIssueBanner: _dismissIssueBanner,
                    onOpenRecovery: _openRecovery,
                    l10n: l10n,
                  );
          },
        );
      },
    );
  }

  void _openChannel(Channel channel) {
    final existing = _channels;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelDetailScreen(
          channel: channel,
          api: widget.api,
          settings: widget.settings,
          fieldSettingsStorage: widget.fieldSettingsStorage,
          pinnedFieldsStorage: widget.pinnedFieldsStorage,
          channelSnapshotStorage: widget.channelSnapshotStorage,
          existingChannels: existing,
          onChannelUpdated: _notifier.updateChannel,
          onChannelEdited: _onChannelEdited,
          onPinnedChanged: _refreshPinned,
        ),
      ),
    ).then((_) => _refreshPinned());
  }

  Future<void> _onChannelEdited(Channel original, Channel updated) async {
    if (original != updated) {
      await widget.fieldSettingsStorage.migrateChannel(original, updated);
      await widget.pinnedFieldsStorage.migrateChannel(original, updated);
      await widget.channelSnapshotStorage.migrateChannel(original, updated);
      if (widget.settings.isStartChannel(original)) {
        await widget.settings.setStartChannel(updated);
      }
    }
    await _notifier.replaceChannel(original, updated);
    if (_selectedChannel == original) {
      setState(() => _selectedChannel = updated);
    }
    _refreshPinned();
  }

  void _openAddChannel() async {
    final existing = _channels;
    final channel = await Navigator.push<Channel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChannelAddScreen(api: widget.api, existingChannels: existing),
      ),
    );
    if (channel != null && mounted) _notifier.addChannel(channel);
  }

  void _onImported() {
    _notifier.reload();
    widget.settings.reload();
    widget.fieldSettingsStorage.reload();
    widget.pinnedFieldsStorage.reload();
    setState(() => _selectedChannel = widget.settings.startChannel(_channels));
    _refreshPinned();
  }
}

// ── Narrow (phone) layout ────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final ChannelListNotifier notifier;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final ChannelStorage channelStorage;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final BackupService backupService;
  final VoidCallback onImported;
  final ValueChanged<Channel> onOpenChannel;
  final ValueChanged<Channel> onDeleteChannel;
  final VoidCallback onAddChannel;
  final List<PinnedEntry> pinnedEntries;
  final DateTime now;
  final VoidCallback onEditPinned;
  final ValueChanged<PinnedEntry> onTapPinned;
  final Future<void> Function() onPinnedRefresh;
  final bool issueBannerVisible;
  final VoidCallback onDismissIssueBanner;
  final VoidCallback onOpenRecovery;
  final AppLocalizations l10n;

  const _NarrowLayout({
    required this.notifier,
    required this.api,
    required this.settings,
    required this.channelStorage,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    required this.channelSnapshotStorage,
    required this.backupService,
    required this.onImported,
    required this.onOpenChannel,
    required this.onDeleteChannel,
    required this.onAddChannel,
    required this.pinnedEntries,
    required this.now,
    required this.onEditPinned,
    required this.onTapPinned,
    required this.onPinnedRefresh,
    required this.issueBannerVisible,
    required this.onDismissIssueBanner,
    required this.onOpenRecovery,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThingViewer'),
        actions: [
          _SettingsButton(
            api: api,
            settings: settings,
            notifier: notifier,
            channelStorage: channelStorage,
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: pinnedFieldsStorage,
            channelSnapshotStorage: channelSnapshotStorage,
            backupService: backupService,
            onImported: onImported,
          ),
        ],
      ),
      body: _ChannelListBody(
        notifier: notifier,
        l10n: l10n,
        channelStorage: channelStorage,
        backupService: backupService,
        onImported: onImported,
        issueBannerVisible: issueBannerVisible,
        onDismissIssueBanner: onDismissIssueBanner,
        onOpenRecovery: onOpenRecovery,
        onTap: onOpenChannel,
        onDelete: onDeleteChannel,
        pinnedEntries: pinnedEntries,
        now: now,
        onEditPinned: onEditPinned,
        onTapPinned: onTapPinned,
        onPinnedRefresh: onPinnedRefresh,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addChannelTooltip,
        onPressed: onAddChannel,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Wide (tablet) layout ─────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final ChannelListNotifier notifier;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final ChannelStorage channelStorage;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final BackupService backupService;
  final VoidCallback onImported;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onChannelSelected;
  final ValueChanged<Channel> onChannelRemoved;
  final Future<void> Function(Channel original, Channel updated)
  onChannelEdited;
  final VoidCallback onAddChannel;
  final VoidCallback onPinnedChanged;
  final List<PinnedEntry> pinnedEntries;
  final DateTime now;
  final VoidCallback onEditPinned;
  final ValueChanged<PinnedEntry> onTapPinned;
  final Future<void> Function() onPinnedRefresh;
  final bool issueBannerVisible;
  final VoidCallback onDismissIssueBanner;
  final VoidCallback onOpenRecovery;
  final AppLocalizations l10n;

  const _WideLayout({
    required this.notifier,
    required this.api,
    required this.settings,
    required this.channelStorage,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    required this.channelSnapshotStorage,
    required this.backupService,
    required this.onImported,
    required this.selectedChannel,
    required this.onChannelSelected,
    required this.onChannelRemoved,
    required this.onChannelEdited,
    required this.onAddChannel,
    required this.onPinnedChanged,
    required this.pinnedEntries,
    required this.now,
    required this.onEditPinned,
    required this.onTapPinned,
    required this.onPinnedRefresh,
    required this.issueBannerVisible,
    required this.onDismissIssueBanner,
    required this.onOpenRecovery,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThingViewer'),
        actions: [
          _SettingsButton(
            api: api,
            settings: settings,
            notifier: notifier,
            channelStorage: channelStorage,
            fieldSettingsStorage: fieldSettingsStorage,
            pinnedFieldsStorage: pinnedFieldsStorage,
            channelSnapshotStorage: channelSnapshotStorage,
            backupService: backupService,
            onImported: onImported,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addChannelTooltip,
        onPressed: onAddChannel,
        child: const Icon(Icons.add),
      ),
      body: Row(
        children: [
          // Left panel: channel list
          SizedBox(
            width: 320,
            child: _ChannelListBody(
              notifier: notifier,
              l10n: l10n,
              channelStorage: channelStorage,
              backupService: backupService,
              onImported: onImported,
              issueBannerVisible: issueBannerVisible,
              onDismissIssueBanner: onDismissIssueBanner,
              onOpenRecovery: onOpenRecovery,
              selectedChannel: selectedChannel,
              onTap: onChannelSelected,
              onDelete: onChannelRemoved,
              pinnedEntries: pinnedEntries,
              now: now,
              onEditPinned: onEditPinned,
              onTapPinned: onTapPinned,
              onPinnedRefresh: onPinnedRefresh,
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel: detail or placeholder
          Expanded(
            child: selectedChannel != null
                ? ChannelDetailScreen(
                    key: ValueKey(selectedChannel),
                    channel: selectedChannel!,
                    api: api,
                    settings: settings,
                    fieldSettingsStorage: fieldSettingsStorage,
                    pinnedFieldsStorage: pinnedFieldsStorage,
                    channelSnapshotStorage: channelSnapshotStorage,
                    existingChannels: switch (notifier.state) {
                      ChannelListLoaded(:final channels) => channels,
                      _ => const <Channel>[],
                    },
                    onChannelUpdated: notifier.updateChannel,
                    onChannelEdited: onChannelEdited,
                    onPinnedChanged: onPinnedChanged,
                  )
                : Center(
                    child: Text(
                      l10n.channelListSelectHint,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SettingsButton extends StatelessWidget {
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final ChannelListNotifier notifier;
  final ChannelStorage channelStorage;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final BackupService backupService;
  final VoidCallback onImported;

  const _SettingsButton({
    required this.api,
    required this.settings,
    required this.notifier,
    required this.channelStorage,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    required this.channelSnapshotStorage,
    required this.backupService,
    required this.onImported,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settingsTooltip,
      onPressed: () {
        final channels = switch (notifier.state) {
          ChannelListLoaded(:final channels) => channels,
          _ => const <Channel>[],
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsScreen(
              api: api,
              settings: settings,
              channels: channels,
              channelStorage: channelStorage,
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: pinnedFieldsStorage,
              channelSnapshotStorage: channelSnapshotStorage,
              backupService: backupService,
              onImported: onImported,
            ),
          ),
        );
      },
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, Channel channel) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.removeChannelTitle),
      content: Text(l10n.removeChannelText(channel.displayName)),
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
}

class _ChannelListBody extends StatelessWidget {
  final ChannelListNotifier notifier;
  final AppLocalizations l10n;
  final ChannelStorage channelStorage;
  final BackupService backupService;
  final VoidCallback onImported;
  final bool issueBannerVisible;
  final VoidCallback onDismissIssueBanner;
  final VoidCallback onOpenRecovery;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onTap;
  final ValueChanged<Channel> onDelete;
  final List<PinnedEntry> pinnedEntries;
  final DateTime now;
  final VoidCallback onEditPinned;
  final ValueChanged<PinnedEntry> onTapPinned;
  final Future<void> Function() onPinnedRefresh;

  const _ChannelListBody({
    required this.notifier,
    required this.l10n,
    required this.channelStorage,
    required this.backupService,
    required this.onImported,
    required this.issueBannerVisible,
    required this.onDismissIssueBanner,
    required this.onOpenRecovery,
    required this.onTap,
    required this.onDelete,
    required this.pinnedEntries,
    required this.now,
    required this.onEditPinned,
    required this.onTapPinned,
    required this.onPinnedRefresh,
    this.selectedChannel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final Widget body = switch (notifier.state) {
          ChannelListLoading() => Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.labelLoading,
            ),
          ),
          ChannelListError(:final message) => Center(child: Text(message)),
          ChannelListCorrupted() => _CorruptedBody(
            channelStorage: channelStorage,
            backupService: backupService,
            onChanged: onImported,
          ),
          ChannelListLoaded(:final channels) =>
            channels.isEmpty
                ? Center(child: Text(l10n.channelListEmpty))
                : ReorderableListView.builder(
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pinnedEntries.isNotEmpty)
                          PinnedSection(
                            entries: pinnedEntries,
                            now: now,
                            onEdit: onEditPinned,
                            onTap: onTapPinned,
                          ),
                        SectionHeader(title: l10n.channelListSectionTitle),
                      ],
                    ),
                    itemCount: channels.length,
                    onReorderItem: notifier.reorderChannels,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return Dismissible(
                        key: ValueKey(channel),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) =>
                            _confirmDelete(context, channel),
                        onDismissed: (_) => onDelete(channel),
                        background: Container(
                          color: Theme.of(context).colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ExcludeSemantics(
                            child: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                        ),
                        child: Semantics(
                          customSemanticsActions: {
                            CustomSemanticsAction(
                              label: l10n.channelListDeleteSemantics,
                            ): () async {
                              if (await _confirmDelete(context, channel) ==
                                  true) {
                                onDelete(channel);
                              }
                            },
                          },
                          child: _ChannelTile(
                            channel: channel,
                            isSelected: channel == selectedChannel,
                            onTap: () => onTap(channel),
                          ),
                        ),
                      );
                    },
                  ),
        };
        final content = pinnedEntries.isEmpty
            ? body
            : RefreshIndicator(
                onRefresh: onPinnedRefresh,
                semanticsLabel: l10n.pinnedSectionTitle,
                child: body,
              );
        if (!issueBannerVisible) return content;
        return Column(
          children: [
            MaterialBanner(
              leading: ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              content: Text(l10n.channelListIssueBannerText),
              actions: [
                TextButton(
                  onPressed: onDismissIssueBanner,
                  child: Text(l10n.channelListIssueBannerDismiss),
                ),
                TextButton(
                  onPressed: onOpenRecovery,
                  child: Text(l10n.channelListIssueBannerAction),
                ),
              ],
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

/// Blocking body shown instead of the channel list when the saved channels
/// could not be read at all. The original data is kept (see [ChannelStorage]),
/// so this offers the same recovery actions as [RecoveryScreen] without
/// forcing a navigation away from the (still live) AppBar and FAB.
class _CorruptedBody extends StatelessWidget {
  final ChannelStorage channelStorage;
  final BackupService backupService;
  final VoidCallback onChanged;

  const _CorruptedBody({
    required this.channelStorage,
    required this.backupService,
    required this.onChanged,
  });

  Future<void> _import(BuildContext context) async {
    if (await runBackupImport(context, backupService)) onChanged();
  }

  Future<void> _save(BuildContext context) async {
    final raw = channelStorage.corruptRaw;
    if (raw == null) return;
    await saveCorruptRaw(context, 'channels', raw);
  }

  Future<void> _discard(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await confirmDiscard(context, l10n.recoveryStoreChannels)) return;
    await channelStorage.discardCorrupt();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.channelListCorruptedTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l10n.channelListCorruptedText, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.recoveryImportBackup),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(l10n.channelListCorruptedSave),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _discard(context),
              icon: Icon(Icons.delete_outline, color: errorColor),
              label: Text(
                l10n.channelListCorruptedDiscard,
                style: TextStyle(color: errorColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    return MergeSemantics(
      child: ListTile(
        leading: Icon(
          channel.isPublic ? Icons.lock_open_outlined : Icons.lock_outline,
          semanticLabel: channel.isPublic
              ? l10n.channelListPublicSemantics
              : l10n.channelListPrivateSemantics,
        ),
        title: Text(channel.displayName),
        subtitle: channel.authError
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${channel.serverUrl} · ${channel.id}'),
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: errorColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.channelListAuthError,
                          style: TextStyle(color: errorColor),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text('${channel.serverUrl} · ${channel.id}'),
        isThreeLine: channel.authError,
        selected: isSelected,
        // ListTile.selected defaults its text/icon colour to colorScheme.primary
        // (brandGreen), which is only 2.43:1 on white — fails WCAG AA. Selection
        // is already conveyed by selectedTileColor, so keep the foreground plain.
        selectedColor: Theme.of(context).colorScheme.onSurface,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
        onTap: onTap,
        trailing: ExcludeSemantics(
          child: Icon(
            Icons.drag_handle,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
