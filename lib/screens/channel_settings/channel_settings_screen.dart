import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/channel_settings.dart';
import '../../models/range_preset.dart';
import '../../widgets/content_width.dart';
import '../../widgets/default_range_tile.dart';
import '../../widgets/section_header.dart';

class ChannelSettingsScreen extends StatefulWidget {
  final ChannelSettings settings;
  final ValueChanged<ChannelSettings> onChanged;
  final VoidCallback onEditChannel;

  const ChannelSettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onEditChannel,
  });

  @override
  State<ChannelSettingsScreen> createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
  late ChannelSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _apply(ChannelSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelSettingsTitle)),
      body: ContentWidth(
        child: ListView(
          children: [
            SectionHeader(title: l10n.channelSettingsSectionCharts),
            DefaultRangeTile(
              current: _settings.defaultRange,
              fallback: RangePreset.last7Days,
              subtitleBuilder: l10n.channelSettingsDefaultRangeSubtitle,
              onChanged: (v) => _apply(
                ChannelSettings(
                  defaultRange: v,
                  rememberRange: _settings.rememberRange,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.history),
              title: Text(l10n.channelSettingsRememberRange),
              subtitle: Text(l10n.channelSettingsRememberRangeSubtitle),
              value: _settings.rememberRange,
              onChanged: (v) => _apply(
                ChannelSettings(
                  defaultRange: _settings.defaultRange,
                  rememberRange: v,
                ),
              ),
            ),
            SectionHeader(title: l10n.channelSettingsSectionConnection),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editChannelTooltip),
              subtitle: Text(l10n.channelSettingsEditChannelSubtitle),
              onTap: widget.onEditChannel,
            ),
          ],
        ),
      ),
    );
  }
}
