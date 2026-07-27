import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../storage/channel_storage.dart';
import '../../storage/field_settings_storage.dart';
import '../channel_add/channel_add_screen.dart';
import '../channel_detail/channel_detail_screen.dart';
import '../settings/settings_notifier.dart';
import '../settings/settings_screen.dart';
import 'channel_list_notifier.dart';

const _kTabletBreakpoint = 600.0;

class ChannelListScreen extends StatefulWidget {
  final ThingSpeakApi api;
  final ChannelStorage channelStorage;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;

  const ChannelListScreen({
    super.key,
    required this.api,
    required this.channelStorage,
    required this.settings,
    required this.fieldSettingsStorage,
  });

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final ChannelListNotifier _notifier;
  Channel? _selectedChannel;
  Channel? _pendingStartChannel;

  @override
  void initState() {
    super.initState();
    _notifier = ChannelListNotifier(widget.channelStorage);
    final channels = switch (_notifier.state) {
      ChannelListLoaded(:final channels) => channels,
      _ => const <Channel>[],
    };
    final startChannel = widget.settings.startChannel(channels);
    _selectedChannel = startChannel;
    _pendingStartChannel = startChannel;
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                fieldSettingsStorage: widget.fieldSettingsStorage,
                selectedChannel: _selectedChannel,
                onChannelSelected: (c) =>
                    setState(() => _selectedChannel = c),
                onChannelRemoved: (c) {
                  if (_selectedChannel == c) {
                    setState(() => _selectedChannel = null);
                  }
                  _notifier.removeChannel(c);
                },
                onAddChannel: _openAddChannel,
                l10n: l10n,
              )
            : _NarrowLayout(
                notifier: _notifier,
                api: widget.api,
                settings: widget.settings,
                onOpenChannel: _openChannel,
                onAddChannel: _openAddChannel,
                l10n: l10n,
              );
      },
    );
  }

  void _openChannel(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelDetailScreen(
          channel: channel,
          api: widget.api,
          settings: widget.settings,
          fieldSettingsStorage: widget.fieldSettingsStorage,
          onChannelUpdated: _notifier.updateChannel,
        ),
      ),
    );
  }

  void _openAddChannel() async {
    final existing = switch (_notifier.state) {
      ChannelListLoaded(:final channels) => channels,
      _ => const <Channel>[],
    };
    final channel = await Navigator.push<Channel>(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelAddScreen(
          api: widget.api,
          existingChannels: existing,
        ),
      ),
    );
    if (channel != null && mounted) _notifier.addChannel(channel);
  }
}

// ── Narrow (phone) layout ────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final ChannelListNotifier notifier;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final ValueChanged<Channel> onOpenChannel;
  final VoidCallback onAddChannel;
  final AppLocalizations l10n;

  const _NarrowLayout({
    required this.notifier,
    required this.api,
    required this.settings,
    required this.onOpenChannel,
    required this.onAddChannel,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThingViewer'),
        actions: [_SettingsButton(settings: settings, notifier: notifier)],
      ),
      body: _ChannelListBody(
        notifier: notifier,
        l10n: l10n,
        onTap: onOpenChannel,
        onDelete: notifier.removeChannel,
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
  final FieldSettingsStorage fieldSettingsStorage;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onChannelSelected;
  final ValueChanged<Channel> onChannelRemoved;
  final VoidCallback onAddChannel;
  final AppLocalizations l10n;

  const _WideLayout({
    required this.notifier,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.selectedChannel,
    required this.onChannelSelected,
    required this.onChannelRemoved,
    required this.onAddChannel,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThingViewer'),
        actions: [_SettingsButton(settings: settings, notifier: notifier)],
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
              selectedChannel: selectedChannel,
              onTap: onChannelSelected,
              onDelete: onChannelRemoved,
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
                    onChannelUpdated: notifier.updateChannel,
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
  final SettingsNotifier settings;
  final ChannelListNotifier notifier;

  const _SettingsButton({required this.settings, required this.notifier});

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
              settings: settings,
              channels: channels,
            ),
          ),
        );
      },
    );
  }
}

class _ChannelListBody extends StatelessWidget {
  final ChannelListNotifier notifier;
  final AppLocalizations l10n;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onTap;
  final ValueChanged<Channel> onDelete;

  const _ChannelListBody({
    required this.notifier,
    required this.l10n,
    required this.onTap,
    required this.onDelete,
    this.selectedChannel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) => switch (notifier.state) {
        ChannelListLoading() =>
          const Center(child: CircularProgressIndicator()),
        ChannelListError(:final message) => Center(child: Text(message)),
        ChannelListLoaded(:final channels) => channels.isEmpty
            ? Center(child: Text(l10n.channelListEmpty))
            : ReorderableListView.builder(
                itemCount: channels.length,
                onReorderItem: notifier.reorderChannels,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return Dismissible(
                    key: ValueKey(channel),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => showDialog<bool>(
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
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => onDelete(channel),
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    child: _ChannelTile(
                      channel: channel,
                      isSelected: channel == selectedChannel,
                      onTap: () => onTap(channel),
                    ),
                  );
                },
              ),
      },
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
    return ListTile(
      leading: Icon(
        channel.isPublic ? Icons.lock_open_outlined : Icons.lock_outline,
      ),
      title: Text(channel.displayName),
      subtitle: Text('${channel.serverUrl} · ${channel.id}'),
      selected: isSelected,
      // ListTile.selected defaults its text/icon colour to colorScheme.primary
      // (brandGreen), which is only 2.43:1 on white — fails WCAG AA. Selection
      // is already conveyed by selectedTileColor, so keep the foreground plain.
      selectedColor: Theme.of(context).colorScheme.onSurface,
      selectedTileColor: Theme.of(context)
          .colorScheme
          .secondaryContainer
          .withValues(alpha: 0.4),
      onTap: onTap,
      trailing: Icon(
        Icons.drag_handle,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

