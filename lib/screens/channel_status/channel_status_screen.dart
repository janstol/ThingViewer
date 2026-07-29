import 'dart:async';

import 'package:flutter/material.dart';

import '../../entry_age.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel_status.dart';
import '../settings/settings_notifier.dart';

class ChannelStatusScreen extends StatefulWidget {
  final List<ChannelStatus> statuses;
  final SettingsNotifier settings;

  const ChannelStatusScreen({
    super.key,
    required this.statuses,
    required this.settings,
  });

  @override
  State<ChannelStatusScreen> createState() => _ChannelStatusScreenState();
}

class _ChannelStatusScreenState extends State<ChannelStatusScreen> {
  DateTime _now = DateTime.now();
  late final Timer _ageTicker;

  @override
  void initState() {
    super.initState();
    _ageTicker = Timer.periodic(
      const Duration(seconds: 60),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ageTicker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final newestFirst = widget.statuses.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelStatusTitle)),
      body: newestFirst.isEmpty
          ? Center(child: Text(l10n.channelStatusEmpty))
          : ListenableBuilder(
              listenable: widget.settings,
              builder: (context, _) => Scrollbar(
                thumbVisibility: true,
                interactive: true,
                child: ListView.separated(
                  itemCount: newestFirst.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final status = newestFirst[i];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(status.message),
                          const SizedBox(height: 4),
                          Text(
                            formatTimestamp(
                              l10n,
                              widget.settings,
                              status.createdAt,
                              _now,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
