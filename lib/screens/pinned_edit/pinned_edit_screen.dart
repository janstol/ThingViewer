import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../storage/pinned_fields_storage.dart';

/// Picker for choosing which fields are pinned to the channel-list dashboard.
///
/// Channels are shown as lazily-expanding tiles: opening a channel is what
/// fires its `readFeed(results: 0)` request for field labels, so simply
/// opening this screen makes no network calls.
class PinnedEditScreen extends StatefulWidget {
  final ThingSpeakApi api;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final List<Channel> channels;

  const PinnedEditScreen({
    super.key,
    required this.api,
    required this.pinnedFieldsStorage,
    required this.channels,
  });

  @override
  State<PinnedEditScreen> createState() => _PinnedEditScreenState();
}

class _PinnedEditScreenState extends State<PinnedEditScreen> {
  final Map<Channel, List<Field>> _fieldsByChannel = {};
  final Map<Channel, ApiErrorCode> _errorsByChannel = {};
  final Set<Channel> _loading = {};

  Future<void> _loadFields(Channel channel) async {
    if (_fieldsByChannel.containsKey(channel) || _loading.contains(channel)) {
      return;
    }
    setState(() => _loading.add(channel));
    try {
      final feedData = await widget.api.readFeed(
        channel,
        ApiParameters(apiKey: channel.apiKey, results: 0),
      );
      if (!mounted) return;
      setState(() {
        _fieldsByChannel[channel] = feedData.fields;
        _loading.remove(channel);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorsByChannel[channel] = e.code;
        _loading.remove(channel);
      });
    }
  }

  Future<void> _togglePin(Channel channel, int fieldId) async {
    await widget.pinnedFieldsStorage.toggle(channel, fieldId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pinnedEditTitle)),
      body: widget.channels.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.pinnedEditEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                return ExpansionTile(
                  title: Text(channel.displayName),
                  onExpansionChanged: (expanded) {
                    if (expanded) _loadFields(channel);
                  },
                  children: _buildChildren(channel, l10n),
                );
              },
            ),
    );
  }

  List<Widget> _buildChildren(Channel channel, AppLocalizations l10n) {
    if (_errorsByChannel.containsKey(channel)) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.pinnedEditChannelLoadFailed),
        ),
      ];
    }
    if (_loading.contains(channel) || !_fieldsByChannel.containsKey(channel)) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.labelLoading,
            ),
          ),
        ),
      ];
    }
    final fields = _fieldsByChannel[channel]!;
    return [
      for (final field in fields)
        CheckboxListTile(
          title: Text(field.displayLabel),
          value: widget.pinnedFieldsStorage.isPinned(channel, field.id),
          onChanged: (_) => _togglePin(channel, field.id),
        ),
    ];
  }
}
