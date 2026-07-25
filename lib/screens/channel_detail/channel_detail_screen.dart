import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) => switch (_notifier.state) {
          ChannelDetailLoading() =>
            const Center(child: CircularProgressIndicator()),
          ChannelDetailEmpty(:final channel) => _EmptyState(
              channel: channel,
              message: l10n.channelDetailNoFields,
            ),
          ChannelDetailError(:final errorCode, :final serverMessage) => Center(
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
        final description = _trimmedDescription(channel);
        final hasDescription = description != null;
        return ListView.builder(
          itemCount: fields.length + (hasDescription ? 1 : 0),
          itemBuilder: (context, i) {
            if (hasDescription && i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }
            final field = fields[hasDescription ? i - 1 : i];
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
    final description = _trimmedDescription(channel);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (description != null) ...[
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
            ],
            Text(message),
          ],
        ),
      ),
    );
  }
}
