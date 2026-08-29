import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/thingspeak_api.dart';
import '../../entry_age.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/channel_status.dart';
import '../../models/field.dart';
import '../../storage/channel_snapshot_storage.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../theme.dart';
import '../../widgets/section_header.dart';
import '../channel_add/channel_add_screen.dart';
import '../channel_status/channel_status_screen.dart';
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

bool _hasTopHeader(Channel channel) =>
    _trimmedDescription(channel) != null ||
    _safeUrl(channel.url) != null ||
    _safeUrl(channel.githubUrl) != null;

bool _hasHeader(Channel channel, List<ChannelStatus> statuses) =>
    _hasTopHeader(channel) || statuses.isNotEmpty;

/// Splits [fields] into pinned and unpinned, each keeping the channel's own
/// field order rather than pin-insertion order.
({List<Field> pinned, List<Field> rest}) groupFieldsByPin(
  List<Field> fields,
  Channel channel,
  PinnedFieldsStorage pins,
) {
  final pinned = <Field>[];
  final rest = <Field>[];
  for (final field in fields) {
    (pins.isPinned(channel, field.id) ? pinned : rest).add(field);
  }
  return (pinned: pinned, rest: rest);
}

// This screen's field list is a plain ListView, which already auto-pads
// itself with MediaQuery.padding for the system nav bar. What it can't know
// about is a FAB belonging to an *outer* Scaffold: when this screen is
// embedded as the right-hand panel of the wide split layout
// (ChannelListScreen's _WideLayout), that Scaffold's "add channel" FAB
// floats over this panel's trailing edge. [fabClearance] adds room for it.
const _kFabClearance = 56.0 + kFloatingActionButtonMargin * 2;

void _openStatusLog(
  BuildContext context,
  List<ChannelStatus> statuses,
  SettingsNotifier settings,
) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChannelStatusScreen(statuses: statuses, settings: settings),
  ),
);

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
              16,
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

/// Latest status message under its own section header, with a button to the
/// full log — kept separate from [_ChannelHeader] so the description and the
/// status feed read as distinct sections rather than one mixed block.
class _StatusSection extends StatelessWidget {
  final List<ChannelStatus> statuses;
  final SettingsNotifier settings;
  final DateTime now;

  const _StatusSection({
    required this.statuses,
    required this.settings,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final latest = statuses.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: l10n.channelDetailStatus,
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.channelStatusViewLog,
            onPressed: () => _openStatusLog(context, statuses, settings),
          ),
        ),
        MergeSemantics(
          child: ListTile(
            title: Text(
              latest.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              formatTimestamp(l10n, settings, latest.createdAt, now),
            ),
            onTap: () => _openStatusLog(context, statuses, settings),
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
  final PinnedFieldsStorage pinnedFieldsStorage;
  final ChannelSnapshotStorage channelSnapshotStorage;
  final List<Channel> existingChannels;
  final void Function(Channel)? onChannelUpdated;
  final Future<void> Function(Channel original, Channel updated)?
  onChannelEdited;
  final VoidCallback? onPinnedChanged;
  final bool fabClearance;

  const ChannelDetailScreen({
    super.key,
    required this.channel,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    required this.channelSnapshotStorage,
    this.existingChannels = const [],
    this.onChannelUpdated,
    this.onChannelEdited,
    this.onPinnedChanged,
    this.fabClearance = false,
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
      widget.channelSnapshotStorage,
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

  // Regroups the field list into pinned/other sections after a pin is
  // toggled on the field chart screen — _FieldList reads isPinned at build
  // time, so this screen needs its own rebuild, not just the outer callback.
  void _handlePinnedChanged() {
    widget.onPinnedChanged?.call();
    setState(() {});
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
            ChannelDetailLoading() => Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.labelLoading,
              ),
            ),
            ChannelDetailEmpty(:final channel, :final statuses) => _EmptyState(
              channel: channel,
              statuses: statuses,
              settings: widget.settings,
              now: _now,
              message: l10n.channelDetailNoFields,
            ),
            ChannelDetailError(:final errorCode, :final serverMessage) =>
              _ScrollableCenter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(switch (errorCode) {
                    ApiErrorCode.network => l10n.errorNetwork,
                    ApiErrorCode.credentials => l10n.errorApiCredentialsDetail,
                    ApiErrorCode.general => serverMessage ?? l10n.errorGeneral,
                  }, textAlign: TextAlign.center),
                ),
              ),
            ChannelDetailLoaded(
              :final channel,
              :final fields,
              :final statuses,
              :final cachedAt,
              :final refreshing,
              :final refreshError,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cachedAt != null || refreshError != null)
                    _StaleBanner(
                      cachedAt: cachedAt!,
                      refreshing: refreshing,
                      refreshError: refreshError,
                      now: _now,
                    ),
                  Expanded(
                    child: _FieldList(
                      channel: channel,
                      fields: fields,
                      statuses: statuses,
                      api: widget.api,
                      settings: widget.settings,
                      fieldSettingsStorage: widget.fieldSettingsStorage,
                      pinnedFieldsStorage: widget.pinnedFieldsStorage,
                      onPinnedChanged: _handlePinnedChanged,
                      now: _now,
                      fabClearance: widget.fabClearance,
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

/// Shown above the field list when the values on screen are not from the
/// fetch that just completed: either still loading from cache (`refreshing`)
/// or a refresh attempt failed and cached values stayed on screen.
class _StaleBanner extends StatelessWidget {
  final DateTime cachedAt;
  final bool refreshing;
  final ApiErrorCode? refreshError;
  final DateTime now;

  const _StaleBanner({
    required this.cachedAt,
    required this.refreshing,
    this.refreshError,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final age = formatEntryAge(l10n, now.difference(cachedAt));
    final failed = refreshError != null;
    final background = failed
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = failed
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  failed ? Icons.error_outline : Icons.info_outline,
                  size: 18,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failed
                      ? l10n.channelDetailRefreshFailedCached(age)
                      : l10n.channelDetailCachedData(age),
                  style: TextStyle(color: foreground),
                ),
              ),
            ],
          ),
        ),
        if (refreshing)
          LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: l10n.channelDetailRefreshingSemantics,
          ),
      ],
    );
  }
}

class _FieldList extends StatelessWidget {
  final Channel channel;
  final List<Field> fields;
  final List<ChannelStatus> statuses;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final VoidCallback? onPinnedChanged;
  final DateTime now;
  final bool fabClearance;

  const _FieldList({
    required this.channel,
    required this.fields,
    required this.statuses,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    this.onPinnedChanged,
    required this.now,
    required this.fabClearance,
  });

  /// Rows for one section, with an inset divider between consecutive fields
  /// — lighter weight than the full-bleed dividers at section boundaries.
  List<Widget> _rows(List<Field> sectionFields) => [
    for (var i = 0; i < sectionFields.length; i++) ...[
      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
      _FieldRow(
        channel: channel,
        field: sectionFields[i],
        api: api,
        settings: settings,
        fieldSettingsStorage: fieldSettingsStorage,
        pinnedFieldsStorage: pinnedFieldsStorage,
        onPinnedChanged: onPinnedChanged,
        now: now,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final hasHeader = _hasHeader(channel, statuses);
        final hasTopHeader = _hasTopHeader(channel);
        final grouped = groupFieldsByPin(fields, channel, pinnedFieldsStorage);
        final hasPins = grouped.pinned.isNotEmpty;

        final children = <Widget>[
          if (hasTopHeader) _ChannelHeader(channel: channel),
          if (statuses.isNotEmpty) ...[
            if (hasTopHeader) const Divider(height: 1),
            _StatusSection(statuses: statuses, settings: settings, now: now),
          ],
          if (hasHeader) const Divider(height: 1),
          if (hasPins) ...[
            SectionHeader(title: l10n.pinnedSectionTitle),
            ..._rows(grouped.pinned),
            if (grouped.rest.isNotEmpty) ...[
              const Divider(height: 1),
              SectionHeader(title: l10n.channelDetailOtherFieldsSection),
              ..._rows(grouped.rest),
            ],
          ] else ...[
            if (hasHeader)
              SectionHeader(title: l10n.channelDetailFieldsSection),
            ..._rows(grouped.rest),
          ],
        ];

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: fabClearance
              ? EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + _kFabClearance,
                )
              : null,
          children: children,
        );
      },
    );
  }
}

/// One field's label/value row. Value is the dominant element — this is a
/// quick-look screen, and the value is what a user opens the app to read.
class _FieldRow extends StatelessWidget {
  final Channel channel;
  final Field field;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final VoidCallback? onPinnedChanged;
  final DateTime now;

  const _FieldRow({
    required this.channel,
    required this.field,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    this.onPinnedChanged,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dataAccent = theme.extension<BrandColors>()!.dataAccent;
    final lastUpdated = field.lastUpdated;
    final decimals = fieldSettingsStorage
        .settingsFor(channel, field.id)
        .decimals;
    final timestamp = lastUpdated != null
        ? formatTimestamp(l10n, settings, lastUpdated, now)
        : null;

    return MergeSemantics(
      child: ListTile(
        title: Text(
          field.displayLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: timestamp != null
            ? Text(
                timestamp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                semanticsLabel: '${l10n.channelDetailLastEntry}: $timestamp',
              )
            : null,
        trailing: field.lastValue != null
            ? Text(
                formatFieldValue(field.lastValue!, decimals: decimals),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: dataAccent,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const ExcludeSemantics(child: Icon(Icons.chevron_right)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FieldChartScreen(
              channel: channel,
              field: field,
              api: api,
              settings: settings,
              fieldSettingsStorage: fieldSettingsStorage,
              pinnedFieldsStorage: pinnedFieldsStorage,
              onPinnedChanged: onPinnedChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Channel channel;
  final List<ChannelStatus> statuses;
  final SettingsNotifier settings;
  final DateTime now;
  final String message;

  const _EmptyState({
    required this.channel,
    required this.statuses,
    required this.settings,
    required this.now,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _ScrollableCenter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasTopHeader(channel)) ...[
              _ChannelHeader(channel: channel, centered: true),
              const SizedBox(height: 16),
            ],
            if (statuses.isNotEmpty) ...[
              _StatusSection(statuses: statuses, settings: settings, now: now),
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
