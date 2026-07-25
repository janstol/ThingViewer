import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import 'settings_notifier.dart';

const _dateFormats = [
  'dd.MM.yyyy',
  'dd/MM/yyyy',
  'MM/dd/yyyy',
  'yyyy-MM-dd',
];
const _timeFormats = [
  'HH:mm',
  'HH:mm:ss',
  'hh:mm a',
  'hh:mm:ss a',
];

class SettingsScreen extends StatelessWidget {
  final SettingsNotifier settings;
  final List<Channel> channels;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.channels,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _ThemeTile(settings: settings),
            _StartScreenTile(settings: settings, channels: channels),
            _FormatTile(
              icon: Icons.calendar_today_outlined,
              title: l10n.settingsDateFormat,
              current: settings.dateFormat,
              options: _dateFormats,
              dialogTitle: l10n.settingsDateFormatChoose,
              onSelected: settings.setDateFormat,
            ),
            _FormatTile(
              icon: Icons.access_time_outlined,
              title: l10n.settingsTimeFormat,
              current: settings.timeFormat,
              options: _timeFormats,
              dialogTitle: l10n.settingsTimeFormatChoose,
              onSelected: settings.setTimeFormat,
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              onTap: () => launchUrl(
                Uri.parse('https://sites.google.com/view/thingviewer-privacy-policy/home'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            _AboutTile(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final SettingsNotifier settings;

  const _ThemeTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (ThemeMode.system, l10n.settingsThemeSystem),
      (ThemeMode.light, l10n.settingsThemeLight),
      (ThemeMode.dark, l10n.settingsThemeDark),
    ];
    final current =
        options.firstWhere((e) => e.$1 == settings.themeMode).$2;

    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(l10n.settingsTheme),
      subtitle: Text(current),
      onTap: () async {
        final selected = await showDialog<ThemeMode>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.settingsThemeChoose),
            children: [
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (v) {
                  if (v != null) Navigator.pop(context, v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (e) => RadioListTile<ThemeMode>(
                          title: Text(e.$2),
                          value: e.$1,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
        if (selected != null && context.mounted) settings.setThemeMode(selected);
      },
    );
  }
}

// showDialog<Channel?> can't tell "user picked Channel list" (null) apart
// from "user dismissed the dialog" (also null), so wrap the choice.
class _StartChoice {
  final Channel? channel;
  const _StartChoice(this.channel);
}

class _StartScreenTile extends StatelessWidget {
  final SettingsNotifier settings;
  final List<Channel> channels;

  const _StartScreenTile({required this.settings, required this.channels});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = settings.startChannel(channels);
    final subtitle = current?.displayName ?? l10n.settingsStartScreenChannelList;

    return ListTile(
      leading: const Icon(Icons.home_outlined),
      title: Text(l10n.settingsStartScreen),
      subtitle: Text(subtitle),
      onTap: () async {
        final selected = await showDialog<_StartChoice>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.settingsStartScreenChoose),
            children: [
              RadioGroup<Channel?>(
                groupValue: current,
                onChanged: (v) => Navigator.pop(context, _StartChoice(v)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<Channel?>(
                      title: Text(l10n.settingsStartScreenChannelList),
                      value: null,
                    ),
                    for (final channel in channels)
                      RadioListTile<Channel?>(
                        title: Text(channel.displayName),
                        value: channel,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (selected != null && context.mounted) {
          settings.setStartChannel(selected.channel);
        }
      },
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String current;
  final List<String> options;
  final String dialogTitle;
  final Future<void> Function(String) onSelected;

  const _FormatTile({
    required this.icon,
    required this.title,
    required this.current,
    required this.options,
    required this.dialogTitle,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final preview = DateFormat(current).format(now);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('$current  ·  $preview'),
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(dialogTitle),
            children: [
              RadioGroup<String>(
                groupValue: current,
                onChanged: (v) {
                  if (v != null) Navigator.pop(context, v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (opt) => RadioListTile<String>(
                          title: Text(opt),
                          subtitle: Text(DateFormat(opt).format(now)),
                          value: opt,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
        if (selected != null && context.mounted) onSelected(selected);
      },
    );
  }
}

class _AboutTile extends StatelessWidget {
  final AppLocalizations l10n;

  const _AboutTile({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final linkStyle = themeData.textTheme.bodyMedium?.copyWith(
      color: themeData.colorScheme.primary,
    );
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return AboutListTile(
          icon: const Icon(Icons.info_outline),
          applicationName: l10n.appName,
          applicationVersion: version,
          applicationIcon: const Image(
            image: AssetImage('res/images/thingviewer_icon_150.png'),
            width: 50,
            height: 50,
            fit: BoxFit.scaleDown,
          ),
          aboutBoxChildren: [
            const SizedBox(height: 16),
            Text(l10n.aboutText),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(l10n.aboutThingSpeakUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                l10n.aboutThingSpeakUrl,
                style: linkStyle,
              ),
            ),
          ],
          child: Text(l10n.aboutTitle),
        );
      },
    );
  }
}
