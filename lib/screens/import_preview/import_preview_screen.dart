import 'package:flutter/material.dart';

import '../../backup/import_plan.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/pinned_field.dart';
import '../../storage/settings_storage.dart';
import '../../theme.dart';
import '../../widgets/section_header.dart';
import '../settings/settings_notifier.dart';

/// Shows a diff of [plan] against everything currently saved, lets the user
/// check/uncheck individual channels, chart overrides, pinned fields, and
/// app settings, and pops the resulting [ImportSelection] — or `null` if the
/// user cancels.
class ImportPreviewScreen extends StatefulWidget {
  final ImportPlan plan;
  final String fileName;
  final SettingsNotifier settings;

  const ImportPreviewScreen({
    super.key,
    required this.plan,
    required this.fileName,
    required this.settings,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late final Set<Channel> _selectedChannels;
  late final Set<String> _selectedChartKeys;
  late final Set<PinnedField> _selectedPins;
  late final Set<BackupSettingKey> _selectedSettingKeys;
  bool _removeMissing = false;
  late final List<Channel> _knownChannels;

  ImportPlan get _plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _selectedChannels = {for (final d in _plan.channels) d.incoming};
    _selectedChartKeys = {
      for (final d in _plan.channels) ...d.chartSettingKeys,
      ..._plan.orphanChartSettingKeys,
    };
    _selectedPins = {
      for (final d in _plan.channels) ...d.pinnedFields,
      ..._plan.orphanPinnedFields,
    };
    _selectedSettingKeys = {for (final s in _plan.settings) s.key};
    _knownChannels = [
      for (final d in _plan.channels) d.incoming,
      for (final d in _plan.channels)
        if (d.existing != null) d.existing!,
      ..._plan.onlyOnDevice,
    ];
  }

  ImportSelection get _selection => ImportSelection(
    channels: _selectedChannels,
    fieldChartSettingsKeys: _selectedChartKeys,
    pinnedFields: _selectedPins,
    settingKeys: _selectedSettingKeys,
    removeChannelsNotInBackup: _removeMissing,
  );

  void _toggleChannel(ChannelDiff diff, bool selected) {
    setState(() {
      if (selected) {
        _selectedChannels.add(diff.incoming);
        _selectedChartKeys.addAll(diff.chartSettingKeys);
        _selectedPins.addAll(diff.pinnedFields);
      } else {
        _selectedChannels.remove(diff.incoming);
        _selectedChartKeys.removeAll(diff.chartSettingKeys);
        _selectedPins.removeAll(diff.pinnedFields);
      }
    });
  }

  void _selectAllChannels() {
    setState(() {
      _selectedChannels.addAll(_plan.channels.map((d) => d.incoming));
      for (final d in _plan.channels) {
        _selectedChartKeys.addAll(d.chartSettingKeys);
        _selectedPins.addAll(d.pinnedFields);
      }
    });
  }

  void _selectNoChannels() {
    setState(() {
      for (final d in _plan.channels) {
        _selectedChannels.remove(d.incoming);
        _selectedChartKeys.removeAll(d.chartSettingKeys);
        _selectedPins.removeAll(d.pinnedFields);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final nothingInFile =
        _plan.channels.isEmpty &&
        _plan.settings.isEmpty &&
        _plan.orphanChartSettingKeys.isEmpty &&
        _plan.orphanPinnedFields.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupImportTitle)),
      body: ListView(
        children: [
          ..._buildFileSection(l10n),
          if (nothingInFile)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.importPreviewNothingToImport),
            ),
          if (_plan.channels.isNotEmpty) ..._buildChannelsSection(l10n),
          if (_plan.orphanChartSettingKeys.isNotEmpty ||
              _plan.orphanPinnedFields.isNotEmpty)
            ..._buildOtherOverridesSection(l10n),
          if (_plan.settings.isNotEmpty) ..._buildSettingsSection(l10n),
          if (_plan.onlyOnDevice.isNotEmpty)
            ..._buildOnlyOnDeviceSection(l10n, colorScheme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.labelCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selection.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selection),
                child: Text(l10n.backupImportConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFileSection(AppLocalizations l10n) {
    final contents = _plan.contents;
    return [
      SectionHeader(title: l10n.importPreviewSectionFile),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName),
            if (contents.exportedAt != null)
              Text(
                l10n.importPreviewExportedAt(
                  widget.settings.formatDateTime(contents.exportedAt!),
                ),
              ),
            if (contents.appVersion != null)
              Text(l10n.importPreviewAppVersion(contents.appVersion!)),
            if (contents.apiKeysExcluded) Text(l10n.importPreviewNoApiKeys),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _buildChannelsSection(AppLocalizations l10n) {
    return [
      SectionHeader(
        title: l10n.importPreviewSectionChannels,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: l10n.importPreviewSelectAll,
              onPressed: _selectAllChannels,
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: l10n.importPreviewSelectNone,
              onPressed: _selectNoChannels,
            ),
          ],
        ),
      ),
      for (final diff in _plan.channels) ..._buildChannelTile(l10n, diff),
    ];
  }

  List<Widget> _buildChannelTile(AppLocalizations l10n, ChannelDiff diff) {
    final colorScheme = Theme.of(context).colorScheme;
    final brandColors = Theme.of(context).extension<BrandColors>()!;
    final selected = _selectedChannels.contains(diff.incoming);
    return [
      CheckboxListTile(
        value: selected,
        onChanged: (v) => _toggleChannel(diff, v ?? false),
        title: Text('${diff.incoming.displayName}  #${diff.incoming.id}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusLabel(l10n, diff.change),
              style: TextStyle(
                color: _statusColor(brandColors, diff.change),
                fontWeight: diff.change == ChannelChange.unchanged
                    ? null
                    : FontWeight.bold,
              ),
            ),
            for (final change in diff.changes)
              Text(_changeLine(l10n, diff, change)),
            if (diff.needsApiKey)
              Text(
                l10n.importPreviewNeedsApiKey,
                style: TextStyle(color: colorScheme.error),
              ),
          ],
        ),
      ),
      if (diff.chartSettingKeys.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: CheckboxListTile(
            value: selected && diff.chartSettingKeys.every(_selectedChartKeys.contains),
            onChanged: !selected
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        _selectedChartKeys.addAll(diff.chartSettingKeys);
                      } else {
                        _selectedChartKeys.removeAll(diff.chartSettingKeys);
                      }
                    });
                  },
            title: Text(
              l10n.importPreviewChartOverrides(diff.chartSettingKeys.length),
            ),
          ),
        ),
      if (diff.pinnedFields.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: CheckboxListTile(
            value: selected && diff.pinnedFields.every(_selectedPins.contains),
            onChanged: !selected
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        _selectedPins.addAll(diff.pinnedFields);
                      } else {
                        _selectedPins.removeAll(diff.pinnedFields);
                      }
                    });
                  },
            title: Text(
              l10n.importPreviewPinnedFields(diff.pinnedFields.length),
            ),
          ),
        ),
    ];
  }

  String _statusLabel(AppLocalizations l10n, ChannelChange change) =>
      switch (change) {
        ChannelChange.added => l10n.importPreviewStatusNew,
        ChannelChange.updated => l10n.importPreviewStatusUpdate,
        ChannelChange.unchanged => l10n.importPreviewStatusUnchanged,
      };

  Color? _statusColor(BrandColors brandColors, ChannelChange change) =>
      switch (change) {
        ChannelChange.added => brandColors.dataAccent,
        ChannelChange.updated => brandColors.changeAccent,
        ChannelChange.unchanged => null,
      };

  String _changeLine(
    AppLocalizations l10n,
    ChannelDiff diff,
    ChannelFieldChange change,
  ) {
    final existing = diff.existing!;
    switch (change) {
      case ChannelFieldChange.name:
        return '${l10n.importPreviewChangeName}: '
            '${l10n.importPreviewValueChange(existing.displayName, diff.incoming.displayName)}';
      case ChannelFieldChange.apiKey:
        return l10n.importPreviewChangeApiKey;
      case ChannelFieldChange.visibility:
        return '${l10n.importPreviewChangeVisibility}: '
            '${l10n.importPreviewValueChange(_visibilityLabel(l10n, existing.isPublic), _visibilityLabel(l10n, diff.incoming.isPublic))}';
    }
  }

  String _visibilityLabel(AppLocalizations l10n, bool isPublic) =>
      isPublic ? l10n.fieldPublic : l10n.fieldPrivate;

  List<Widget> _buildOtherOverridesSection(AppLocalizations l10n) {
    return [
      SectionHeader(title: l10n.importPreviewSectionOtherOverrides),
      if (_plan.orphanChartSettingKeys.isNotEmpty)
        CheckboxListTile(
          value: _plan.orphanChartSettingKeys.every(
            _selectedChartKeys.contains,
          ),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selectedChartKeys.addAll(_plan.orphanChartSettingKeys);
            } else {
              _selectedChartKeys.removeAll(_plan.orphanChartSettingKeys);
            }
          }),
          title: Text(
            l10n.importPreviewChartOverrides(
              _plan.orphanChartSettingKeys.length,
            ),
          ),
        ),
      if (_plan.orphanPinnedFields.isNotEmpty)
        CheckboxListTile(
          value: _plan.orphanPinnedFields.every(_selectedPins.contains),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selectedPins.addAll(_plan.orphanPinnedFields);
            } else {
              _selectedPins.removeAll(_plan.orphanPinnedFields);
            }
          }),
          title: Text(
            l10n.importPreviewPinnedFields(_plan.orphanPinnedFields.length),
          ),
        ),
    ];
  }

  List<Widget> _buildSettingsSection(AppLocalizations l10n) {
    return [
      SectionHeader(title: l10n.importPreviewSectionSettings),
      for (final diff in _plan.settings)
        CheckboxListTile(
          value: _selectedSettingKeys.contains(diff.key),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selectedSettingKeys.add(diff.key);
            } else {
              _selectedSettingKeys.remove(diff.key);
            }
          }),
          title: Text(_settingKeyLabel(l10n, diff.key)),
          subtitle: Text(
            diff.changed
                ? l10n.importPreviewValueChange(
                    _settingValueLabel(l10n, diff.key, diff.current),
                    _settingValueLabel(l10n, diff.key, diff.incoming),
                  )
                : l10n.importPreviewValueSame,
          ),
        ),
    ];
  }

  List<Widget> _buildOnlyOnDeviceSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return [
      SectionHeader(title: l10n.importPreviewSectionOnlyHere),
      for (final channel in _plan.onlyOnDevice)
        ListTile(title: Text(channel.displayName)),
      SwitchListTile(
        value: _removeMissing,
        onChanged: (v) => setState(() => _removeMissing = v),
        title: Text(
          l10n.importPreviewRemoveMissing,
          style: TextStyle(color: colorScheme.error),
        ),
        subtitle: Text(l10n.importPreviewRemoveMissingDescription),
      ),
    ];
  }

  String _settingKeyLabel(AppLocalizations l10n, BackupSettingKey key) =>
      switch (key) {
        BackupSettingKey.themeMode => l10n.settingsTheme,
        BackupSettingKey.dateFormat => l10n.settingsDateFormat,
        BackupSettingKey.timeFormat => l10n.settingsTimeFormat,
        BackupSettingKey.timezoneDisplay => l10n.settingsTimezone,
        BackupSettingKey.entryTimeDisplay => l10n.settingsEntryTime,
        BackupSettingKey.startChannel => l10n.settingsStartScreen,
      };

  String _settingValueLabel(
    AppLocalizations l10n,
    BackupSettingKey key,
    Object? value,
  ) {
    switch (key) {
      case BackupSettingKey.themeMode:
        return switch (ThemeMode.values.elementAtOrNull(value as int? ?? 0) ??
            ThemeMode.system) {
          ThemeMode.system => l10n.settingsThemeSystem,
          ThemeMode.light => l10n.settingsThemeLight,
          ThemeMode.dark => l10n.settingsThemeDark,
        };
      case BackupSettingKey.dateFormat:
      case BackupSettingKey.timeFormat:
        return value as String? ?? '';
      case BackupSettingKey.timezoneDisplay:
        return switch (TimezoneDisplay.values.elementAtOrNull(
          value as int? ?? 0,
        ) ??
            TimezoneDisplay.off) {
          TimezoneDisplay.off => l10n.settingsTimezoneOff,
          TimezoneDisplay.offset => l10n.settingsTimezoneOffset,
          TimezoneDisplay.name => l10n.settingsTimezoneName,
        };
      case BackupSettingKey.entryTimeDisplay:
        return switch (EntryTimeDisplay.values.elementAtOrNull(
          value as int? ?? 0,
        ) ??
            EntryTimeDisplay.both) {
          EntryTimeDisplay.absolute => l10n.settingsEntryTimeAbsolute,
          EntryTimeDisplay.age => l10n.settingsEntryTimeAge,
          EntryTimeDisplay.both => l10n.settingsEntryTimeBoth,
        };
      case BackupSettingKey.startChannel:
        if (value == null) return l10n.settingsStartScreenChannelList;
        final (id, serverUrl) = value as (int, String);
        for (final channel in _knownChannels) {
          if (channel.id == id && channel.serverUrl == serverUrl) {
            return channel.displayName;
          }
        }
        return '#$id';
    }
  }
}
