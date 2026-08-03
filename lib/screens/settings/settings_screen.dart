import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/thingspeak_api.dart';
import '../../backup/backup_service.dart';
import '../../entry_age.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../storage/settings_storage.dart';
import '../../theme.dart';
import '../../widgets/section_header.dart';
import '../pinned_edit/pinned_edit_screen.dart';
import 'settings_notifier.dart';

const _dateFormats = ['dd.MM.yyyy', 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'];
const _timeFormats = ['HH:mm', 'HH:mm:ss', 'hh:mm a', 'hh:mm:ss a'];

class SettingsScreen extends StatelessWidget {
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final List<Channel> channels;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final BackupService backupService;
  final VoidCallback onImported;

  const SettingsScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.channels,
    required this.pinnedFieldsStorage,
    required this.backupService,
    required this.onImported,
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
            SectionHeader(title: l10n.settingsSectionAppearance),
            _ThemeTile(settings: settings),
            SectionHeader(title: l10n.settingsSectionGeneral),
            _StartScreenTile(settings: settings, channels: channels),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(l10n.settingsPinnedFields),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PinnedEditScreen(
                    api: api,
                    pinnedFieldsStorage: pinnedFieldsStorage,
                    channels: channels,
                  ),
                ),
              ),
            ),
            SectionHeader(title: l10n.settingsSectionDateTime),
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
            _TimezoneTile(settings: settings),
            _EntryTimeTile(settings: settings),
            SectionHeader(title: l10n.settingsSectionBackup),
            _ExportTile(backupService: backupService),
            _ImportTile(backupService: backupService, onImported: onImported),
            SectionHeader(title: l10n.settingsSectionInfo),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              onTap: () => launchUrl(
                Uri.parse(
                  'https://sites.google.com/view/thingviewer-privacy-policy/home',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.settingsSourceCode),
              onTap: () => launchUrl(
                Uri.parse('https://github.com/janstol/ThingViewer'),
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
    final current = options.firstWhere((e) => e.$1 == settings.themeMode).$2;

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
        if (selected != null && context.mounted) {
          settings.setThemeMode(selected);
        }
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
    final subtitle =
        current?.displayName ?? l10n.settingsStartScreenChannelList;

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

class _TimezoneTile extends StatelessWidget {
  final SettingsNotifier settings;

  const _TimezoneTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (TimezoneDisplay.off, l10n.settingsTimezoneOff),
      (TimezoneDisplay.offset, l10n.settingsTimezoneOffset),
      (TimezoneDisplay.name, l10n.settingsTimezoneName),
    ];
    final current = options
        .firstWhere((e) => e.$1 == settings.timezoneDisplay)
        .$2;
    final preview = settings.formatDateTime(DateTime.now());

    return ListTile(
      leading: const Icon(Icons.public_outlined),
      title: Text(l10n.settingsTimezone),
      subtitle: Text('$current  ·  $preview'),
      onTap: () async {
        final selected = await showDialog<TimezoneDisplay>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.settingsTimezoneChoose),
            children: [
              RadioGroup<TimezoneDisplay>(
                groupValue: settings.timezoneDisplay,
                onChanged: (v) {
                  if (v != null) Navigator.pop(context, v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (e) => RadioListTile<TimezoneDisplay>(
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
        if (selected != null && context.mounted) {
          settings.setTimezoneDisplay(selected);
        }
      },
    );
  }
}

class _EntryTimeTile extends StatelessWidget {
  final SettingsNotifier settings;

  const _EntryTimeTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (EntryTimeDisplay.absolute, l10n.settingsEntryTimeAbsolute),
      (EntryTimeDisplay.age, l10n.settingsEntryTimeAge),
      (EntryTimeDisplay.both, l10n.settingsEntryTimeBoth),
    ];
    final current = options
        .firstWhere((e) => e.$1 == settings.entryTimeDisplay)
        .$2;
    final now = DateTime.now();
    final sample = now.subtract(const Duration(minutes: 5));
    final preview = _preview(l10n, settings, sample, now);

    return ListTile(
      leading: const Icon(Icons.history_outlined),
      title: Text(l10n.settingsEntryTime),
      subtitle: Text('$current  ·  $preview'),
      onTap: () async {
        final selected = await showDialog<EntryTimeDisplay>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.settingsEntryTimeChoose),
            children: [
              RadioGroup<EntryTimeDisplay>(
                groupValue: settings.entryTimeDisplay,
                onChanged: (v) {
                  if (v != null) Navigator.pop(context, v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (e) => RadioListTile<EntryTimeDisplay>(
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
        if (selected != null && context.mounted) {
          settings.setEntryTimeDisplay(selected);
        }
      },
    );
  }

  static String _preview(
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
}

class _ExportTile extends StatelessWidget {
  final BackupService backupService;

  const _ExportTile({required this.backupService});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.upload_file_outlined),
      title: Text(l10n.settingsExport),
      subtitle: Text(l10n.settingsExportSubtitle),
      onTap: () async {
        final mode = await showDialog<BackupExportMode>(
          context: context,
          builder: (_) => const _BackupExportDialog(),
        );
        if (mode == null || !context.mounted) return;

        final json = await backupService.export(mode: mode);
        final bytes = Uint8List.fromList(utf8.encode(json));
        final infix = mode == BackupExportMode.withoutApiKeys ? '-no-keys' : '';
        final fileName =
            'thingviewer-backup$infix-'
            '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
        final String? path;
        try {
          path = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
        } on PlatformException {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
          return;
        }
        if (path == null || !context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupExportSuccess)));
      },
    );
  }
}

class _BackupExportDialog extends StatefulWidget {
  const _BackupExportDialog();

  @override
  State<_BackupExportDialog> createState() => _BackupExportDialogState();
}

class _BackupExportDialogState extends State<_BackupExportDialog> {
  BackupExportMode _selected = BackupExportMode.full;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.backupExportTitle),
      content: SingleChildScrollView(
        child: RadioGroup<BackupExportMode>(
          groupValue: _selected,
          onChanged: (v) => setState(() => _selected = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<BackupExportMode>(
                value: BackupExportMode.full,
                title: Text(l10n.backupExportModeFull),
                subtitle: Text(l10n.backupExportModeFullSubtitle),
              ),
              RadioListTile<BackupExportMode>(
                value: BackupExportMode.withoutApiKeys,
                title: Text(l10n.backupExportModeNoKeys),
                subtitle: Text(l10n.backupExportModeNoKeysSubtitle),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.labelCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l10n.backupExportAction),
        ),
      ],
    );
  }
}

class _ImportTile extends StatelessWidget {
  final BackupService backupService;
  final VoidCallback onImported;

  const _ImportTile({required this.backupService, required this.onImported});

  String _summary(AppLocalizations l10n, BackupContents contents) {
    final parts = <String>[];
    final channels = contents.channels;
    if (channels != null) {
      parts.add(l10n.backupSummaryChannels(channels.length));
    }
    if (contents.settings != null) {
      parts.add(l10n.backupSummarySettings);
    }
    final fieldChartSettings = contents.fieldChartSettings;
    if (fieldChartSettings != null) {
      parts.add(l10n.backupSummaryFieldSettings(fieldChartSettings.length));
    }
    return parts.isEmpty ? l10n.backupSummaryEmpty : parts.join(' · ');
  }

  String _errorMessage(AppLocalizations l10n, BackupException e) {
    switch (e.type) {
      case BackupErrorType.notABackup:
        return l10n.backupErrorNotABackup;
      case BackupErrorType.newerVersion:
        return l10n.backupErrorNewerVersion;
      case BackupErrorType.malformed:
        return l10n.backupErrorMalformed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.download_outlined),
      title: Text(l10n.settingsImport),
      onTap: () async {
        final FilePickerResult? result;
        try {
          result = await FilePicker.pickFiles(
            type: FileType.any,
            withData: true,
          );
        } on PlatformException {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
          return;
        }
        final files = result?.files;
        if (files == null || files.isEmpty || !context.mounted) return;
        final bytes = files.first.bytes;
        if (bytes == null) return;

        final BackupContents contents;
        try {
          contents = backupService.parse(utf8.decode(bytes));
        } on BackupException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage(l10n, e))));
          return;
        }

        final channelsNeedingApiKey = backupService.channelsNeedingApiKey(
          contents,
        );
        final mode = await showDialog<ImportMode>(
          context: context,
          builder: (ctx) {
            ImportMode? selected;
            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: Text(l10n.backupImportTitle),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.backupImportSummary(_summary(l10n, contents))),
                      if (channelsNeedingApiKey > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.backupImportMissingKeys(channelsNeedingApiKey),
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ),
                      RadioGroup<ImportMode?>(
                        groupValue: selected,
                        onChanged: (v) => setState(() => selected = v),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<ImportMode?>(
                              value: ImportMode.addChannels,
                              title: Text(l10n.backupModeAddChannels),
                              subtitle: Text(
                                l10n.backupModeAddChannelsDescription,
                              ),
                            ),
                            RadioListTile<ImportMode?>(
                              value: ImportMode.replace,
                              title: Text(
                                l10n.backupModeReplace,
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                              ),
                              subtitle: Text(l10n.backupModeReplaceDescription),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.labelCancel),
                  ),
                  TextButton(
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(ctx, selected),
                    child: Text(l10n.backupImportConfirm),
                  ),
                ],
              ),
            );
          },
        );
        if (mode == null || !context.mounted) return;

        await backupService.restore(contents, mode);
        onImported();
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupImportSuccess)));
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
      color: themeData.extension<BrandColors>()!.dataAccent,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(l10n.aboutThingSpeakUrl, style: linkStyle),
              ),
            ),
          ],
          child: Text(l10n.aboutTitle),
        );
      },
    );
  }
}
