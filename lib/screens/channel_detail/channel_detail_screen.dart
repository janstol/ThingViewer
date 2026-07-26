import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/thingspeak_api.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../theme.dart';
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
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
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
            child: Text(
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
  final void Function(Channel)? onChannelUpdated;

  const ChannelDetailScreen({
    super.key,
    required this.channel,
    required this.api,
    required this.settings,
    this.onChannelUpdated,
  });

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  late final ChannelDetailNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ChannelDetailNotifier(
      widget.api,
      widget.channel,
      onChannelUpdated: widget.onChannelUpdated,
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.displayName),
        actions: [
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
            ChannelDetailLoading() =>
              const Center(child: CircularProgressIndicator()),
            ChannelDetailEmpty(:final channel) => _EmptyState(
                channel: channel,
                message: l10n.channelDetailNoFields,
              ),
            ChannelDetailError(:final errorCode, :final serverMessage) =>
              _ScrollableCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(switch (errorCode) {
                      ApiErrorCode.network => l10n.errorNetwork,
                      ApiErrorCode.credentials => l10n.errorApiCredentials,
                      ApiErrorCode.general =>
                        serverMessage ?? l10n.errorGeneral,
                    }),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _notifier.load,
                      child: Text(l10n.channelDetailRefresh),
                    ),
                  ],
                ),
              ),
            ChannelDetailLoaded(:final channel, :final fields) =>
              _FieldList(
                channel: channel,
                fields: fields,
                api: widget.api,
                settings: widget.settings,
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

  const _FieldList({
    required this.channel,
    required this.fields,
    required this.api,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final dateFmt = DateFormat(
          '${settings.dateFormat} ${settings.timeFormat}',
        );
        final dataAccent = Theme.of(context).extension<BrandColors>()!.dataAccent;
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
            return ListTile(
              title: Text(field.displayLabel),
              subtitle: lastUpdated != null
                  ? Text(
                      '${l10n.channelDetailLastEntry}: ${dateFmt.format(lastUpdated)}',
                    )
                  : null,
              trailing: field.lastValue != null
                  ? Text(
                      formatFieldValue(field.lastValue!),
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
