import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/thingspeak_api.dart';
import '../../entry_age.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/settings_storage.dart';
import '../../theme.dart';
import '../channel_add/channel_add_screen.dart';
import '../field_chart/field_chart_screen.dart';
import '../settings/settings_notifier.dart';
import 'channel_detail_notifier.dart';

String? _trimmedDescription(Channel channel) {
  final description = channel.description?.trim();
  return description != null && description.isNotEmpty ? description : null;
}

/// Validates an author-supplied link before offering it as a button.
///
/// Rejects anything that isn't `http`/`https` — `url` is free text from the
/// channel settings and goes straight to [launchUrl], so a scheme like
/// `javascript:` must never reach it.
String? _safeUrl(String? raw) {
  final uri = Uri.tryParse(raw?.trim() ?? '');
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri.toString() : null;
}

String _lastEntryText(
  AppLocalizations l10n,
  SettingsNotifier settings,
  DateTime lastUpdated,
  DateTime now,
) {
  final absolute = settings.formatDateTime(lastUpdated);
  final age = formatEntryAge(l10n, now.difference(lastUpdated));
  return switch (settings.entryTimeDisplay) {
    EntryTimeDisplay.absolute => absolute,
    EntryTimeDisplay.age => age,
    EntryTimeDisplay.both => '$absolute ($age)',
  };
}

bool _hasHeader(Channel channel) =>
    _trimmedDescription(channel) != null ||
    _safeUrl(channel.url) != null ||
    _safeUrl(channel.githubUrl) != null;

class _ChannelHeader extends StatelessWidget {
  final Channel channel;
  final bool centered;

  const _ChannelHeader({required this.channel, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = _trimmedDescription(channel);
    final websiteUrl = _safeUrl(channel.url);
    final sourceUrl = _safeUrl(channel.githubUrl);

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (websiteUrl != null || sourceUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (websiteUrl != null)
                  TextButton.icon(
                    icon: const Icon(Icons.link),
                    label: Text(l10n.channelDetailWebsite),
                    onPressed: () => launchUrl(
                      Uri.parse(websiteUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                if (sourceUrl != null)
                  TextButton.icon(
                    icon: const Icon(Icons.code),
                    label: Text(l10n.channelDetailSource),
                    onPressed: () => launchUrl(
                      Uri.parse(sourceUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
            ),
          ),
        if (description != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              (websiteUrl != null || sourceUrl != null) ? 4 : 16,
              16,
              12,
            ),
            child: SelectableText(
              description,
              textAlign: centered ? TextAlign.center : null,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class ChannelDetailScreen extends StatefulWidget {
  final Channel channel;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final List<Channel> existingChannels;
  final void Function(Channel)? onChannelUpdated;
  final Future<void> Function(Channel original, Channel updated)?
  onChannelEdited;

  const ChannelDetailScreen({
    super.key,
    required this.channel,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    this.existingChannels = const [],
    this.onChannelUpdated,
    this.onChannelEdited,
  });

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  late final ChannelDetailNotifier _notifier;
  late Channel _channel;
  DateTime _now = DateTime.now();
  late final Timer _ageTicker;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _notifier = ChannelDetailNotifier(
      widget.api,
      widget.channel,
      onChannelUpdated: widget.onChannelUpdated,
    );
    _ageTicker = Timer.periodic(
      const Duration(seconds: 60),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ageTicker.cancel();
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _editChannel() async {
    final updated = await Navigator.push<Channel>(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelAddScreen(
          api: widget.api,
          existingChannels: widget.existingChannels,
          initialChannel: _channel,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    final original = _channel;
    await widget.onChannelEdited?.call(original, updated);
    if (!mounted) return;
    setState(() => _channel = updated);
    await _notifier.setChannel(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_channel.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editChannelTooltip,
            onPressed: _editChannel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.channelDetailRefresh,
            onPressed: _notifier.load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _notifier.refresh,
        semanticsLabel: l10n.channelDetailRefresh,
        child: ListenableBuilder(
          listenable: _notifier,
          builder: (context, _) => switch (_notifier.state) {
            ChannelDetailLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ChannelDetailEmpty(:final channel) => _EmptyState(
              channel: channel,
              message: l10n.channelDetailNoFields,
            ),
            ChannelDetailError(:final errorCode, :final serverMessage) =>
              _ScrollableCenter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(switch (errorCode) {
                        ApiErrorCode.network => l10n.errorNetwork,
                        ApiErrorCode.credentials =>
                          l10n.errorApiCredentialsDetail,
                        ApiErrorCode.general =>
                          serverMessage ?? l10n.errorGeneral,
                      }, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _notifier.load,
                        child: Text(l10n.channelDetailRefresh),
                      ),
                    ],
                  ),
                ),
              ),
            ChannelDetailLoaded(:final channel, :final fields) => _FieldList(
              channel: channel,
              fields: fields,
              api: widget.api,
              settings: widget.settings,
              fieldSettingsStorage: widget.fieldSettingsStorage,
              now: _now,
            ),
          },
        ),
      ),
    );
  }
}

class _FieldList extends StatelessWidget {
  final Channel channel;
  final List<Field> fields;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final DateTime now;

  const _FieldList({
    required this.channel,
    required this.fields,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final dataAccent = Theme.of(
          context,
        ).extension<BrandColors>()!.dataAccent;
        final hasHeader = _hasHeader(channel);
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: fields.length + (hasHeader ? 1 : 0),
          itemBuilder: (context, i) {
            if (hasHeader && i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChannelHeader(channel: channel),
                  const Divider(height: 1),
                ],
              );
            }
            final field = fields[hasHeader ? i - 1 : i];
            final lastUpdated = field.lastUpdated;
            final decimals = fieldSettingsStorage
                .settingsFor(channel, field.id)
                .decimals;
            return ListTile(
              title: Text(field.displayLabel),
              subtitle: lastUpdated != null
                  ? Text(
                      '${l10n.channelDetailLastEntry}: '
                      '${_lastEntryText(l10n, settings, lastUpdated, now)}',
                    )
                  : null,
              trailing: field.lastValue != null
                  ? Text(
                      formatFieldValue(field.lastValue!, decimals: decimals),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: dataAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FieldChartScreen(
                    channel: channel,
                    field: field,
                    api: api,
                    settings: settings,
                    fieldSettingsStorage: fieldSettingsStorage,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Channel channel;
  final String message;

  const _EmptyState({required this.channel, required this.message});

  @override
  Widget build(BuildContext context) {
    final hasHeader = _hasHeader(channel);
    return _ScrollableCenter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) ...[
              _ChannelHeader(channel: channel, centered: true),
              const SizedBox(height: 16),
            ],
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// Centres [child] but stays scrollable, so a pull-to-refresh gesture still
/// reaches the enclosing RefreshIndicator on states that have no list.
class _ScrollableCenter extends StatelessWidget {
  final Widget child;
  const _ScrollableCenter({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}
